;*******************************************************************************
;  serport.asm - serial port driver.
;  (c) 1995 David Lindauer.
;  (c) 1999 Yuri Zaporogets.
;*******************************************************************************

include "serport.ah"

; --- Definitions ---

SER_MAXPORTS		EQU	4		; Maximum number of supported ports
SER_MAXOPENCOUNT	EQU	64

; Device parameters structure
struc tSPdevParm
 BasePort	DW	0
 IRQ		DB	0
 State		DB	0

 Type		DB	0
 FIFOsize	DB	0
 OpenCount	DB	0
 Reserved1	DB	?

 Baud		DD	0
 InpBuf		DD	0
 OutBuf		DD	0

 ErrFlags	DW	0
 Reserved2	DT	?
ends

SPDstrucSize		EQU	32
SPDstrucShift		EQU	5

; State flags
SERST_DISABLED		EQU	128

; Error flags
SERERR_BUFOVERFLOW	EQU	100h

; Serial buffer parameters structure
struc tSerialBuf
 Size		DW	?
 Used		DW	?
 BufAddr	DD	?
 CQin		DD	?
 CQout		DD	?
ends


; Circle queue macro
macro mCircleQueue xxx
	inc	[edi+tSerialBuf.&xxx]
	mov	eax,[edi+tSerialBuf.&xxx]
	push	ecx
	movzx	ecx,[edi+tSerialBuf.Size]
	sub	eax,ecx
	pop	ecx
	cmp	eax,[edi+tSerialBuf.BufAddr]
	jc	short @@DONE
	mov	eax,[edi+tSerialBuf.BufAddr]
	mov	[edi+tSerialBuf.&xxx],eax
@@DONE:
endm


; --- Data ---
segment KDATA
; Serial driver main structure
DrvSerial	tDriver <"%serial         ",offset DrvSerialET,DRVFL_Char>

; Driver entry points table
DrvSerialET	tDrvEntries < SER_Init, \
			      SER_HandleEvent, \
			      SER_Open, \
			      SER_Close, \
			      SER_Read, \
			      SER_Write, \
			      NULL, \
			      DrvSer_Ctrl >

DrvSer_Ctrl	DD	SER_GetInitStatStr
		DD	SER_GetParameters
		DD	NULL
		DD	NULL
		DD	NULL
		DD	SER_ClearReceiveBuffer
		DD	SER_ClearTransmitBuffer
		DD	NULL

		DD	SER_GetUARTmode
		DD	SER_SetUARTmode
		DD	SER_GetRXbufStat
		DD	SER_GetTXbufStat


SP_InitStatStr	DB	9,": 0 port(s) detected",0
SP_NotPresent	DB	9,": not present",0
SP_BaseStr	DB	9,": base port ",0
SP_IRQstr	DB	", IRQ ",0
SP_UARTstr	DB	", UART ",0
SP_FIFOstr	DB	", FIFO ",0
SP_8250		DB	"8250",0
SP_16450	DB	"16450",0
SP_16550	DB	"16550",0
SP_16550A	DB	"16550A",0
SP_Unknown	DB	"unknown",0
SP_16650	DB	"16650",0

SP_TypeStrs	DD	SP_Unknown,SP_8250,SP_16450,SP_16550,SP_16550A
		DD	SP_Unknown,SP_16650
ends


; --- Variables ---
segment KVARS
SerPortBases	DW	3F8h			; Port base addresses
		DW	2F8h
		DW	3E8h
		DW	2E8h

SerPortIRQs	DB	4			; IRQ channels
		DB	3
		DB	4
		DB	3

NumOfSerPorts	DB	0			; Number of initialized ports

COM1parms	tSPdevParm <>			; Port parameters
COM2parms	tSPdevParm <>
COM3parms	tSPdevParm <>
COM4parms	tSPdevParm <>

BufParms	tSerialBuf <>			; COM1 input buffer
		tSerialBuf <>			; COM1 output buffer
		tSerialBuf <>			; COM2 input buffer
		tSerialBuf <>			; COM2 output buffer
		tSerialBuf <>			; COM3 input buffer
		tSerialBuf <>			; COM3 output buffer
		tSerialBuf <>			; COM4 input buffer
		tSerialBuf <>			; COM4 output buffer
ends


; --- Procedures ---
segment KCODE

		; SER_Init - initialize the driver.
		; Input: AL!=0 - maximum number of supported ports (1..8);
		;	 AL==0 - get number of ports and base addresses
		;		 from BIOS data area,
		;	 CX=input buffer size,
		;	 ECX (high word)=output buffer size,
		;	 ESI=buffer for init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_Init near
@@statstraddr	EQU	ebp-4
@@bufsizes	EQU	ebp-8

		push	ebp
		mov	ebp,esp
		sub	esp,8
		push	ebx ecx edx esi edi

		mov	[@@statstraddr],esi
		mov	[@@bufsizes],ecx

		or	al,al
		jz	short @@FromBIOS
		cmp	al,8
		ja	@@Err
		mov	cl,al
		mov	edi,offset SerPortBases
		jmp	short @@InitParams

@@FromBIOS:	mov	cx,[BIOSDA_Begin+tBIOSDA.Hardware]
		shr	ecx,9
		and	cl,7
		lea	edi,[BIOSDA_Begin+tBIOSDA.COM1addr]

@@InitParams:	or	cl,cl
		jz	@@FillString
		mov	[NumOfSerPorts],cl
		xor	ecx,ecx
		mov	ebx,offset COM1parms		; Prepare to fill
		mov	edx,offset SerPortIRQs		; device parameters
		mov	esi,offset BufParms		; structure

@@FillTblLoop:	mov	ax,[edi]
		mov	[ebx+tSPdevParm.BasePort],ax	; Port base address
		or	ax,ax				; Present?
		jz	short @@Next
		mov	al,[edx]
		mov	[ebx+tSPdevParm.IRQ],al		; IRQ
		xor	eax,eax
		mov	[ebx+tSPdevParm.State],al	; State
		mov	[ebx+tSPdevParm.OpenCount],al	; Open counter

		push	ecx
		mov	cx,[@@bufsizes]
		call	SER_AllocBuffer			; Allocate input buffer
		pop	ecx
		jc	short @@Exit
		mov	[ebx+tSPdevParm.InpBuf],esi
		add	esi,size tSerialBuf
		push	ecx
		mov	cx,[@@bufsizes+2]
		call	SER_AllocBuffer			; Allocate output buffer
		pop	ecx
		jc	short @@Exit
		mov	[ebx+tSPdevParm.OutBuf],esi

		call	SER_DetectUART			; Determine UART type
                jc	short @@Exit

		mov	al,[edx]			; Enable interrupt
		call	PIC_EnbIRQ

		push	ecx edx				; Initialize UART
		call	SER_Disable			; Disable port
		mov	ecx,9600			; Set it to 9600,n,8,1
		cmp	[ebx+tSPdevParm.Type],UART_16550
		jb	short @@SetMode			; If UART is 16550+
		mov	ecx,57600			; set it to 57600
@@SetMode:	mov	dx,UART_LCR_PARITYNONE+UART_LCR_WLEN8
		call	SER_SetMode
		pop	edx ecx

@@Next:		inc	cl
		cmp	cl,SER_MAXPORTS
		je	short @@FillString
		add	ebx,SPDstrucSize
		inc	edi
		inc	edi
		inc	edx
		add	esi,size tSerialBuf
		jmp	@@FillTblLoop

@@FillString:	xor	edx,edx
		mov	esi,[@@statstraddr]
		call	SER_GetInitStatStr

@@Exit:		pop	edi esi edx ecx ebx
		leave
		ret

@@Err:		mov	ax,ERR_SER_BadNumOfPorts
		stc
		jmp	short @@Exit
endp		;---------------------------------------------------------------


		; SER_HandleEvent - handle driver events.
		; Input: EAX=event code.
		; Output: none.
proc SER_HandleEvent near
		test	eax,EV_IRQ
		jnz	short @@Do
		stc
		ret
@@Do:           push	ebx
		cmp	al,3
		jne	short @@IRQ4
		mov	ebx,offset COM2parms		; Service port 2
		call	SER_Interrupt
		mov	ebx,offset COM4parms		; Service port 4
		call	SER_Interrupt
		jmp	short @@OK

@@IRQ4:		mov	ebx,offset COM1parms		; Service port 1
		call	SER_Interrupt
		mov	ebx,offset COM3parms		; Service port 3
		call	SER_Interrupt

@@OK:		call	DSF_Run
		clc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; SER_Open - "open" device.
		; Input:  EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_Open near
		push	ebx edx
		call	SER_Minor2PortNum
		jc	short @@Exit
		mov	al,[ebx+tSPdevParm.OpenCount]
		cmp	al,SER_MAXOPENCOUNT
		je	short @@Err
		or	al,al
		jnz	short @@Enabled
		call	SER_Enable
@@Enabled:	inc	[ebx+tSPdevParm.OpenCount]

@@OK:		xor	eax,eax
@@Exit:		pop	edx ebx
		ret

@@Err:		mov	ax,ERR_DRV_OpenOverflow
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_Close - "close" device.
		; Input:  EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_Close near
		push	ebx edx
		call	SER_Minor2PortNum
		jc	short @@Exit
		mov	al,[ebx+tSPdevParm.OpenCount]
		or	al,al
		je	short @@Err
                dec	al
		mov	[ebx+tSPdevParm.OpenCount],al
		or	al,al
		jnz	short @@OK
		call	SER_Disable

@@OK:		xor	eax,eax
@@Exit:		pop	edx ebx
		ret

@@Err:		mov	ax,ERR_DRV_NotOpened
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_Read - get one character from input buffer.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, AL=character;
		;	  CF=1 - error, AX=error code.
proc SER_Read near
		push	ebx edx edi
		call	SER_Minor2PortNum
		jc	short @@Exit
		cmp	[ebx+tSPdevParm.BasePort],0
		je	short @@Err1

		mov	edi,[ebx+tSPdevParm.InpBuf]	; Input buffer pointer
		cmp	[edi+tSerialBuf.Used],0		; Anything there?
		je	short @@Err2			; No, exit
		dec	[edi+tSerialBuf.Used]		; Decrement count
		push	edi				; Get char
		mov	edi,[edi+tSerialBuf.CQout]
		mov	al,[edi]
		pop	edi
		push	eax
		mCircleQueue CQout			; Update queue
		pop	eax
		clc
@@Exit:		pop	edi edx ebx
		ret

@@Err1:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	@@Exit
@@Err2:		mov	ax,ERR_SER_InpBufEmpty
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_Write - add one character to the output buffer.
		; Input: EDX (high word) = full minor number of device,
		;	 AL=character.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_Write near
		push	ebx ecx edx
		mov	cl,al
		call	SER_Minor2PortNum
		jc	short @@Exit
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	short @@Err

		push	edi
		mov	edi,[ebx+tSPdevParm.OutBuf]	; Get output buffer
		mov	ax,[edi+tSerialBuf.Size]	; See if full
		cmp	ax,[edi+tSerialBuf.Used]
		jbe	short @@BufOverflow		; Yes, exit
		inc	[edi+tSerialBuf.Used]		; Inc buffer count
		push	edi				; Put char in buffer
		mov	edi,[edi+tSerialBuf.CQin]
		mov	[edi],cl
		pop	edi
		mCircleQueue CQin			; Update queue pointer
		clc					; No errors
		jmp	short @@DidOut

@@BufOverflow:	stc
@@DidOut:	pushfd					; Save return status
		add	dl,UART_LSR			; Index to LSR
		in	al,dx				; Check THRE bit
		test	al,UART_LSR_THRE
		jz	short @@Sending			; Not set, send in progress
		call	SER_OutputChar			; Else do the first send
@@Sending:	popfd					; Return status
		pop	edi
		jnc	short @@Exit
		mov	ax,ERR_SER_OutBufFull		; Error: buffer full
		stc

@@Exit:		pop	edx ecx ebx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_GetInitStatStr - get initialization status string.
		; Input: ESI=buffer for string.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc SER_GetInitStatStr near
		push	ebx edx esi edi
		mov	edi,esi
		mov	esi,offset DrvSerial		; Copy "%serial"
		call	StrCopy
		call	StrEnd

		test	edx,0FFFF0000h			; Minor present?
		jnz	short @@Minor
		mov	esi,offset SP_InitStatStr
		call	StrCopy
		mov	al,[NumOfSerPorts]
		add	al,30h
		mov	[edi+3],al
		jmp	@@OK

@@Minor:	call	SER_Minor2PortNum		; Get port number
		jc	@@Exit				; and DPS address
		add	dl,'1'
		mov	[edi],dl
		inc	edi
		cmp	[ebx+tSPdevParm.BasePort],0
		jne	short @@Present
		mov	esi,offset SP_NotPresent
		call	StrCopy
		jmp	short @@OK

@@Present:	mov	esi,offset SP_BaseStr
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	ax,[ebx+tSPdevParm.BasePort]
		call	K_HexW2Str
		mov	edi,esi
		mov	[byte edi],'h'
		inc	edi
		mov	esi,offset SP_IRQstr
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		xor	eax,eax
		mov	al,[ebx+tSPdevParm.IRQ]
		call	K_DecD2Str

		mov	esi,offset SP_UARTstr
		call	StrAppend
		xor	eax,eax
		mov	al,[ebx+tSPdevParm.Type]
		mov	esi,[SP_TypeStrs+eax*4]
		push	eax
		call	StrAppend
		pop	eax
		cmp	al,UART_16550A
		jb	short @@OK
		mov	esi,offset SP_FIFOstr
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		xor	eax,eax
		mov	al,[ebx+tSPdevParm.FIFOsize]
		call	K_DecD2Str

@@OK:		clc
@@Exit:		pop	edi esi edx ebx
		ret
endp		;---------------------------------------------------------------


		; SER_GetParameters - get device parameters.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DX=base address,
		;		    BL=IRQ,
		;		    BH=UART type.
		;	  CF=1 - error, AX=error code.
proc SER_GetParameters near
		call	SER_Minor2PortNum
		jc	short @@Exit
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	short @@Err
		mov	al,[ebx+tSPdevParm.IRQ]
		mov	ah,[ebx+tSPdevParm.Type]
		mov	bx,ax
		xor	eax,eax
@@Exit:		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		ret
endp		;---------------------------------------------------------------


		; SER_ClearReceiveBuffer - clear receive buffer.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_ClearReceiveBuffer near
		push	ebx edx
		call	SER_Minor2PortNum
		jc	short @@Exit
		cmp	[ebx+tSPdevParm.BasePort],0
		je	short @@Err

		mov	ebx,[ebx+tSPdevParm.InpBuf]
		mov	eax,[ebx+tSerialBuf.BufAddr]
		cli
		mov	[ebx+tSerialBuf.Used],0		; Wipe count
		mov	[ebx+tSerialBuf.CQin],eax	; Reset buffer pointers
		mov	[ebx+tSerialBuf.CQout],eax
		sti
		xor	eax,eax

@@Exit:		pop	edx ebx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_ClearTransmitBuffer - clear transmit buffer.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_ClearTransmitBuffer near
		push	ebx edx
		call	SER_Minor2PortNum
		jc	short @@Exit
		cmp	[ebx+tSPdevParm.BasePort],0
		je	short @@Err

		mov	ebx,[ebx+tSPdevParm.OutBuf]
		mov	eax,[ebx+tSerialBuf.BufAddr]
		cli
		mov	[ebx+tSerialBuf.Used],0		; Wipe count
		mov	[ebx+tSerialBuf.CQin],eax	; Reset buffer pointers
		mov	[ebx+tSerialBuf.CQout],eax
		sti
		xor	eax,eax

@@Exit:		pop	edx ebx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_GetUARTmode - get current UART settings.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0,
		;		    ECX=current baud rate,
		;		    BL=UART line status bits,
		;		    BH=UART modem status bits;
		;	  CF=1 - error, AX=error code.
proc SER_GetUARTmode near
		push	edx
		call	SER_Minor2PortNum
		jc	short @@Exit
		call	SER_GetMode
		jc	short @@Exit
		mov	ecx,[ebx+tSPdevParm.Baud]
		mov	bx,dx
@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_SetUARTmode - get current UART settings.
		; Input: EDX (high word) = full minor number of device,
		;	 ECX=baud rate,
		;	 BL=line control word,
		;	 BH=modem control word.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_SetUARTmode near
		push	edx ebx
		call	SER_Minor2PortNum
		pop	edx
		jc	short @@Exit
		call	SER_SetMode
@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_GetRXbufStat - get receive buffer status.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DX=number of bytes in buffer,
		;		    CX=buffer size;
		;	  CF=1 - error, AX=error code.
proc SER_GetRXbufStat near
		push	ebx
		call	SER_Minor2PortNum
		jc	short @@Exit
		cmp	[ebx+tSPdevParm.BasePort],0
		je	short @@Err
		mov	ebx,[ebx+tSPdevParm.InpBuf]
		mov	dx,[ebx+tSerialBuf.Used]
		mov	cx,[ebx+tSerialBuf.Size]
		xor	eax,eax

@@Exit:		pop	ebx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; SER_GetTXbufStat - get receive buffer status.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DX=space left in buffer,
		;		    CX=buffer size;
		;	  CF=1 - error, AX=error code.
proc SER_GetTXbufStat near
		push	ebx
		call	SER_Minor2PortNum
		jc	short @@Exit
		cmp	[ebx+tSPdevParm.BasePort],0
		je	short @@Err
		mov	ebx,[ebx+tSPdevParm.InpBuf]
		mov	dx,[ebx+tSerialBuf.Size]
		mov	cx,dx
		sub	dx,[ebx+tSerialBuf.Used]
		xor	eax,eax

@@Exit:		pop	ebx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


; --- Implementation routines ---


		; SER_DetectUART - determine UART type.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: fills 'Type' and 'FIFOsize' fields in parameters
		;	structure.
proc SER_DetectUART near
		push	ecx edx
		mov	[ebx+tSPdevParm.Type],UART_Unknown
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	@@Err
		cli

		; A simple existence test
		add	dx,UART_IER
		in	al,dx
		mov	ah,al
		xor	al,al
		out	dx,al
		dec	al
		out	PORT_Diagnostic,al
		in	al,dx
		xchg	al,ah
		out	dx,al
		or	ah,ah
		jnz	@@Err

		add	dx,UART_LCR-UART_IER
		in	al,dx
		mov	cl,al
		or	al,UART_LCR_DLAB
		out	dx,al
		push	dx
		add	dx,UART_FCR-UART_LCR
		xor	al,al
		out	dx,al
		pop	dx
		mov	al,cl
		out	dx,al
		add	dx,UART_FCR-UART_LCR
		mov	al,UART_FCR_ENABLE_FIFO
		out	dx,al
		add	dx,UART_IIR-UART_FCR
		in	al,dx
		shr	al,6
		mov	ch,al
		mov	[ebx+tSPdevParm.FIFOsize],1

		or	ch,ch
		jz	short @@16450
		cmp	ch,1
		je	short @@Unknown
		cmp	ch,2
		je	short @@16550
		cmp	ch,3
		jne	short @@Unknown

		add	dx,UART_LCR-UART_IIR		; 16550A or 16650?
		mov	al,cl
		or	al,UART_LCR_DLAB
		out	dx,al
		add	dx,UART_FCR-UART_LCR
		in	al,dx
		or	al,al
		jnz	short @@16550A
		mov	[ebx+tSPdevParm.Type],UART_16650
		mov	[ebx+tSPdevParm.FIFOsize],32
		jmp	short @@OK

@@16550A:	mov	[ebx+tSPdevParm.Type],UART_16550A
		mov	[ebx+tSPdevParm.FIFOsize],16
		jmp	short @@OK

@@16450:	add	dx,UART_SCR-UART_IIR
		in	al,dx
		mov	ah,al
		mov	al,0A5h
		out	dx,al
		PORTDELAY
		in	al,dx
		mov	cl,al
		mov	al,5Ah
		out	dx,al
		PORTDELAY
		in	al,dx
		mov	ch,al
		mov	al,ah
		out	dx,al
		cmp	cl,0A5h
		jne	short @@8250
		cmp	ch,05Ah
		jne	short @@8250
		mov	[ebx+tSPdevParm.Type],UART_16450
		jmp	short @@OK

@@8250:		mov	[ebx+tSPdevParm.Type],UART_8250
		jmp	short @@OK

@@16550:	mov	[ebx+tSPdevParm.Type],UART_16550
		jmp	short @@OK

@@Unknown:
@@OK:		clc
@@Exit:		sti
		pop	edx ecx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	short @@Exit
endp		;---------------------------------------------------------------


		; SER_AllocBuffer - allocate buffer.
		; Input: ESI=pointer to buffer parameters structure,
		;	 CX=buffer size.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_AllocBuffer near
		push	ebx
		and	ecx,0FFFFh
		call	EDRV_AllocData
		jc	short @@Exit
		mov	[esi+tSerialBuf.Size],cx
		mov	[esi+tSerialBuf.Used],0
		mov	[esi+tSerialBuf.BufAddr],ebx
		mov	[esi+tSerialBuf.CQin],ebx
		mov	[esi+tSerialBuf.CQout],ebx
@@Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; SER_Interrupt - handle serial port interrupts.
		; Input: EBX=address of port parameters structure.
		; Output: none.
proc SER_Interrupt near
		push	edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	short @@Exit
		 IFDEF DEBUG
		 mWrChar '!'				; debugging
		 ENDIF

@@Loop:		add	dl,UART_IIR			; Index to IIR
		in	al,dx				; Get interrupt
		test	al,UART_IIR_NONE		; Interrupt pending?
		jnz	short @@Exit
		sub	dl,UART_IIR			; Index to buffer
		and	al,UART_IIR_ID			; Mask out
		cmp	al,UART_IIR_RDI			; interrupt type bits
		jne	short @@Output			; Check for RDI
@@Input:	call	SER_InputChar			; Yes, read a char
		jmp	@@Loop

@@Output:	cmp	al,UART_IIR_THRI		; Check for THRI
		jne	@@Loop
		call	SER_OutputChar			; Yes, write a char
		jmp	@@Loop				; Loop till no more ints buffered

@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_InputChar - input a character to buffer.
		; Input: EBX=address of port parameters structure.
		; Output: none.
proc SER_InputChar near
		push	edx edi
		mov	dx,[ebx+tSPdevParm.BasePort]	; Get base port
		mov	edi,[ebx+tSPdevParm.InpBuf]	; and input buffer
		mov	ax,[edi+tSerialBuf.Used]	; See if full
		cmp	ax,[edi+tSerialBuf.Size]
		in	al,dx				; Get input char
		jb	short @@GetChar			; Not full, go put it
		or	[ebx+tSPdevParm.ErrFlags],SERERR_BUFOVERFLOW ; Buffer full!
	        jmp	short @@ChkPortErr		; Check other erros

@@GetChar:	inc	[edi+tSerialBuf.Used]		; Increase used count
		push	edi				; Put character
		mov	edi,[edi+tSerialBuf.CQin]	; in buffer
		mov	[edi],al
		pop	edi
		mCircleQueue CQin			; Update queue pointer

@@ChkPortErr:	add	dl,UART_LSR			; Index LSR
		in	al,dx				; Read error bits
		mov	[byte ebx+tSPdevParm.ErrFlags],al
		pop	edi edx
		ret
endp		;---------------------------------------------------------------


		; SER_OutputChar - output a character from buffer.
		; Input: EBX=address of port parameters structure.
		; Output: none.
proc SER_OutputChar near
		push	edi
		mov	edi,[ebx+tSPdevParm.OutBuf]	; Get output buffer
		cmp	[edi+tSerialBuf.Used],0		; See if buffer empty
		je	short @@Exit

@@1:		dec	[edi+tSerialBuf.Used]		; Else decrease
		push	edx edi				; the count
		mov	edi,[edi+tSerialBuf.CQout]	; Get CQ deletion
		mov	al,[edi]			; Grab a char
		mov	dx,[ebx+tSPdevParm.BasePort]	; Put it out the port
		out	dx,al
		pop	edi edx
		mCircleQueue CQout			; Update queue pointer
@@Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; SER_Disable - disable a serial line.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_Disable near
		push	edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		add	dl,UART_IER
		xor	al,al				; Disable any
		out	dx,al				; interrupts
		add	dl,UART_MCR-UART_IER
		mov	al,UART_MCR_MEI			; Set down DTR and RTS
		out	dx,al
		or	[ebx+tSPdevParm.State],SERST_DISABLED
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_Enable - enable a serial line.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_Enable near
		push	edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		add	dl,UART_IER
		mov	al,UART_IER_RDI+UART_IER_THRI	; Enable interrupts
		out	dx,al
		add	dl,UART_MCR-UART_IER
		mov	al,UART_MCR_DTR+UART_MCR_RTS+UART_MCR_MEI
		out	dx,al
		mov	al,[ebx+tSPdevParm.FIFOsize]
		cmp	al,1
		je	short @@NoFIFO
		cmp	al,16
		jne	short @@No16
		mov	al,UART_FCR_TRIGGER_14
		jmp	short @@SetFIFO
@@No16:		shl	al,4
@@SetFIFO:	add	dl,UART_FCR-UART_MCR
		or	al,UART_FCR_ENABLE_FIFO
		out	dx,al

@@NoFIFO:	and	[ebx+tSPdevParm.State],not SERST_DISABLED
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_SetMode - set UART mode.
		; Input: EBX=address of port parameters structure.
		;	 ECX=speed in baud,
		;	 DL=line control word,
		;	 DH=modem control word.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_SetMode near
		push	ebx ecx edx
		mov	eax,edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	short @@Err

                mov	[ebx+tSPdevParm.Baud],ecx
		mov	ebx,eax				; EBX = modes
		add	dl,UART_MCR			; Point at MCR
		mov	al,bh
		or	al,UART_MCR_MEI			; Must have this bit
		cli					; for interrupts
		out	dx,al
		sub	dl,UART_MCR-UART_LCR		; Point at LCR
		mov	eax,UART_MAXBAUD		; Divide MAXBAUD
		push	edx				; by baud rate
		xor	edx,edx				; And get timer
		div	ecx				; divide count
		pop	edx
		mov	ecx,eax

		mov	al,bl				; Load LCR
		or	al,UART_LCR_DLAB		; and turn on LAB
		out	dx,al                           ; Load LCR
		sub	dl,UART_LCR-UART_DLL		; Point at DLAB LSB
		mov	al,cl				; Output LSB
		out	dx,al
		mov	al,ch				; MSB
		inc	dx				; Point at DLAB MSB
		out	dx,al				; Out MSB
		mov	al,bl				; Get LCR data
		add	dl,UART_LCR-UART_DLM		; And LCR reg
		out	dx,al				; Turn DLAB latch off
		sti
		xor	eax,eax
@@Exit:		pop	edx ecx ebx
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	short @@Exit
endp		;---------------------------------------------------------------


		; SER_GetMode - get UART mode.
		; Input: EBX=address of port parameters structre.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DL=line control word,
		;		    DH=modem control word;
		;	  CF=1 - error, AX=error code.
proc SER_GetMode near
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	short @@Err

		add	dl,UART_MSR			; Point at MSR
		in	al,dx
		mov	ah,al
		add	dl,UART_LSR-UART_MSR
		in	al,dx
		mov	dx,ax
		xor	eax,eax
		ret

@@Err:		mov	ax,ERR_SER_PortNotExist
		stc
		ret
endp		;---------------------------------------------------------------


		; SER_Minor2PortNum - convert minor number to port number
		;		      and get address of parameters structure.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    DL=port number (0..),
		;		    EBX=structure address;
		;	  CF=1 - error, AX=error code.
proc SER_Minor2PortNum near
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl
		jz	short @@Err1
		dec	bl
		cmp	bl,SER_MAXPORTS
		jae	short @@Err2
		mov	dl,bl
		shl	ebx,SPDstrucShift
		add	ebx,offset COM1parms
		clc
		ret

@@Err1:		mov	ax,ERR_DRV_NoMinor
		stc
		ret
@@Err2:		mov	ax,ERR_DRV_BadMinor
		stc
		ret
endp		;---------------------------------------------------------------

ends
