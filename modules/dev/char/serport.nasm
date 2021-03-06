;*******************************************************************************
; serport.nasm - serial port driver.
; Copyright (c) 1999, 2002 RET & COM Research.
; Based on the OS-32 serial driver (c) 1995 David Lindauer.
;*******************************************************************************

module $serport

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "hw/ports.ah"

%include "serport.ah"


; --- Exports ---

exportdata ModuleInfo


; --- Imports ---


; --- Definitions ---

%define	SER_MAXPORTS		4		; Maximum number of supported ports
%define	SER_MAXOPENCOUNT	64

; Device parameters structure
struc tSPdevParm
.BasePort	RESW	1
.IRQ		RESB	1
.State		RESB	1

.Type		RESB	1
.FIFOsize	RESB	1
.OpenCount	RESW	1

.Baud		RESD	1
.InpBuf		RESD	1
.OutBuf		RESD	1

.ErrFlags	RESW	1
.Reserved	RESB	10
endstruc

%define	SPDstrucShift		5

; State flags
%define	SERST_DISABLED		128

; Error flags
%define	SERERR_BUFOVERFLOW	100h

; Serial buffer parameters structure
struc tSerialBuf
.Size		RESW	1
.Used		RESW	1
.BufAddr	RESD	1
.CQin		RESD	1
.CQout		RESD	1
endstruc


; Circle queue macro
%macro mCircleQueue 1
	inc	dword [edi+tSerialBuf.%1]
	mov	eax,[edi+tSerialBuf.%1]
	push	ecx
	movzx	ecx,word [edi+tSerialBuf.Size]
	sub	eax,ecx
	pop	ecx
	cmp	eax,[edi+tSerialBuf.BufAddr]
	jc	%%Done
	mov	eax,[edi+tSerialBuf.BufAddr]
	mov	[edi+tSerialBuf.%1],eax
%%Done:
%endmacro


; --- Data ---

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
    field(Entry,	DD	SER_Main)
iend

SerPortBases	DW	3F8h			; Port base addresses
		DW	2F8h
		DW	3E8h
		DW	2E8h


; --- Variables ---

section .bss

?SerPortIRQs	RESB	4			; IRQ channels
?LastIRQnum	RESB	1			; Used by 'DetectIRQ'

?NumOfSerPorts	RESB	1			; Number of initialized ports

?PortParameters	RESB	4*tSPdevParm_size	; Port parameters

?BufParms	RESB	8*tSerialBuf_size


; --- Procedures ---

section .text

		; SER_Main - main loop.
proc SER_Main
		mpush	ebx,ecx,edx,esi,edi

		mov	edi,SerPortBases
		mov	[NumOfSerPorts],SER_MAXPORTS
		xor	ecx,ecx
		mov	ebx,?PortParameters		; Prepare to fill
		mov	edx,?SerPortIRQs		; device parameters
		mov	esi,?BufParms			; structure

.FillTblLoop:	mov	ax,[edi]
		mov	[ebx+tSPdevParm.BasePort],ax	; Port base address
		or	ax,ax				; Present?
		jz	.Next
		call	SER_DetectIRQ			; Detect IRQ
		sti
		or	al,al
		jz	.Next
		mov	[edx],al
		mov	[ebx+tSPdevParm.IRQ],al
		xor	eax,eax
		mov	[ebx+tSPdevParm.State],al	; State
		mov	[ebx+tSPdevParm.OpenCount],ax	; Open counter

		push	ecx
		mov	cx,[.bufsizes]
		call	SER_AllocBuffer			; Allocate input buffer
		pop	ecx
		jc	.Exit
		mov	[ebx+tSPdevParm.InpBuf],esi
		add	esi,tSerialBuf_size
		push	ecx
		mov	cx,[.bufsizes+2]
		call	SER_AllocBuffer			; Allocate output buffer
		pop	ecx
		jc	.Exit
		mov	[ebx+tSPdevParm.OutBuf],esi

		call	SER_DetectUART			; Determine UART type
                jc	.Exit

		mov	al,[edx]			; Enable interrupt
		call	PIC_EnbIRQ
		mpush	ecx,edx				; Initialize UART
		call	SER_Disable			; Disable port
		mov	ecx,9600			; Set it to 9600,n,8,1
		cmp	byte [ebx+tSPdevParm.Type],UART_16550
		jb	.SetMode			; If UART is 16550+
		mov	ecx,57600			; set it to 57600
.SetMode:	mov	dx,UART_LCR_PARITYNONE+UART_LCR_WLEN8
		call	SER_SetMode
		mpop	edx,ecx

.Next:		inc	cl
		cmp	cl,SER_MAXPORTS
		je	.FillString
		add	ebx,tSPdevParm_size
		inc	edi
		inc	edi
		inc	edx
		add	esi,tSerialBuf_size
		jmp	.FillTblLoop

.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret

.Err:		mov	ax,ERR_SER_BadNumOfPorts
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_HandleEvent - handle driver events.
		; Input: EAX=event code.
		; Output: none.
proc SER_HandleEvent
		ror	eax,16
		cmp	ax,EV_IRQ
		je	.Do
		stc
		ret
.Do:		push	ebx
		ror	eax,16
		cmp	al,3
		jne	.IRQ4
		mov	ebx,PortParameters+tSPdevParm_size	; Service port 2
		call	SER_Interrupt
		mov	ebx,PortParameters+3*tSPdevParm_size	; Service port 4
		call	SER_Interrupt
		jmp	.OK

.IRQ4:		mov	ebx,PortParameters			; Service port 1
		call	SER_Interrupt
		mov	ebx,PortParameters+2*tSPdevParm_size	; Service port 3
		call	SER_Interrupt

.OK:		;call	DSF_Run
		clc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; SER_Open - "open" device.
		; Input:  EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_Open
		mpush	ebx,edx
		call	SER_Minor2PortNum
		jc	.Exit
		mov	ax,[ebx+tSPdevParm.OpenCount]
		cmp	ax,SER_MAXOPENCOUNT
		je	.Err
		or	ax,ax
		jnz	.Enabled
		call	SER_Enable
.Enabled:	inc	word [ebx+tSPdevParm.OpenCount]

.OK:		xor	eax,eax
.Exit:		mpop	edx,ebx
		ret

.Err:		mov	ax,ERR_DRV_OpenOverflow
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_Close - "close" the device.
		; Input:  EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_Close
		mpush	ebx,edx
		call	SER_Minor2PortNum
		jc	.Exit
		mov	ax,[ebx+tSPdevParm.OpenCount]
		or	ax,ax
		je	.Err
                dec	ax
		mov	[ebx+tSPdevParm.OpenCount],ax
		or	ax,ax
		jnz	.OK
		call	SER_Disable

.OK:		xor	eax,eax
.Exit:		mpop	edx,ebx
		ret

.Err:		mov	ax,ERR_DRV_NotOpened
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_Read - get one character from input buffer.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, AL=character;
		;	  CF=1 - error, AX=error code.
proc SER_Read
		mpush	ebx,edx,edi
		call	SER_Minor2PortNum
		jc	.Exit
		cmp	word [ebx+tSPdevParm.BasePort],0
		je	.Err1

		mov	edi,[ebx+tSPdevParm.InpBuf]	; Input buffer pointer
		cmp	word [edi+tSerialBuf.Used],0	; Anything there?
		je	.Err2			; No, exit
		dec	word [edi+tSerialBuf.Used]	; Decrement count
		push	edi				; Get char
		mov	edi,[edi+tSerialBuf.CQout]
		mov	al,[edi]
		pop	edi
		push	eax
		mCircleQueue CQout			; Update queue
		pop	eax
		clc
.Exit:		mpop	edi,edx,ebx
		ret

.Err1:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
.Err2:		mov	ax,ERR_SER_InpBufEmpty
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_Write - add one character to the output buffer.
		; Input: EDX (high word) = full minor number of device,
		;	 AL=character.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_Write
		mpush	ebx,ecx,edx
		mov	cl,al
		call	SER_Minor2PortNum
		jc	.Exit
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	.Err

		push	edi
		mov	edi,[ebx+tSPdevParm.OutBuf]	; Get output buffer
		mov	ax,[edi+tSerialBuf.Size]	; See if full
		cmp	ax,[edi+tSerialBuf.Used]
		jbe	.BufOverflow		; Yes, exit
		inc	word [edi+tSerialBuf.Used]	; Inc buffer count
		push	edi				; Put char in buffer
		mov	edi,[edi+tSerialBuf.CQin]
		mov	[edi],cl
		pop	edi
		mCircleQueue CQin			; Update queue pointer
		clc					; No errors
		jmp	.DidOut

.BufOverflow:	stc
.DidOut:	pushfd					; Save return status
		add	dl,UART_LSR			; Index to LSR
		in	al,dx				; Check THRE bit
		test	al,UART_LSR_THRE
		jz	.Sending			; Not set, send in progress
		call	SER_OutputChar			; Else do the first send
.Sending:	popfd					; Return status
		pop	edi
		jnc	.Exit
		mov	ax,ERR_SER_OutBufFull		; Error: buffer full
		stc

.Exit:		mpop	edx,ecx,ebx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_GetParameters - get device parameters.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DX=base address,
		;		    BL=IRQ,
		;		    BH=UART type.
		;	  CF=1 - error, AX=error code.
proc SER_GetParameters
		call	SER_Minor2PortNum
		jc	.Exit
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	.Err
		mov	al,[ebx+tSPdevParm.IRQ]
		mov	ah,[ebx+tSPdevParm.Type]
		mov	bx,ax
		xor	eax,eax
.Exit:		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		ret
endp		;---------------------------------------------------------------


		; SER_ClearReceiveBuffer - clear receive buffer.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_ClearReceiveBuffer
		mpush	ebx,edx
		call	SER_Minor2PortNum
		jc	.Exit
		cmp	word [ebx+tSPdevParm.BasePort],0
		je	.Err

		mov	ebx,[ebx+tSPdevParm.InpBuf]
		mov	eax,[ebx+tSerialBuf.BufAddr]
		cli
		mov	word [ebx+tSerialBuf.Used],0	; Wipe count
		mov	[ebx+tSerialBuf.CQin],eax	; Reset buffer pointers
		mov	[ebx+tSerialBuf.CQout],eax
		sti
		xor	eax,eax

.Exit:		mpop	edx,ebx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_ClearTransmitBuffer - clear transmit buffer.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_ClearTransmitBuffer
		mpush	ebx,edx
		call	SER_Minor2PortNum
		jc	.Exit
		cmp	word [ebx+tSPdevParm.BasePort],0
		je	.Err

		mov	ebx,[ebx+tSPdevParm.OutBuf]
		mov	eax,[ebx+tSerialBuf.BufAddr]
		cli
		mov	word [ebx+tSerialBuf.Used],0	; Wipe count
		mov	[ebx+tSerialBuf.CQin],eax	; Reset buffer pointers
		mov	[ebx+tSerialBuf.CQout],eax
		sti
		xor	eax,eax

.Exit:		mpop	edx,ebx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_GetUARTmode - get current UART settings.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0,
		;		    ECX=current baud rate,
		;		    BL=UART line status bits,
		;		    BH=UART modem status bits;
		;	  CF=1 - error, AX=error code.
proc SER_GetUARTmode
		push	edx
		call	SER_Minor2PortNum
		jc	.Exit
		call	SER_GetMode
		jc	.Exit
		mov	ecx,[ebx+tSPdevParm.Baud]
		mov	bx,dx
.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_SetUARTmode - get current UART settings.
		; Input: EDX (high word) = full minor number of device,
		;	 ECX=baud rate,
		;	 BL=line control word,
		;	 BH=modem control word.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc SER_SetUARTmode
		mpush	edx,ebx
		call	SER_Minor2PortNum
		pop	edx
		jc	.Exit
		call	SER_SetMode
.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_GetRXbufStat - get receive buffer status.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DX=number of bytes in buffer,
		;		    CX=buffer size;
		;	  CF=1 - error, AX=error code.
proc SER_GetRXbufStat
		push	ebx
		call	SER_Minor2PortNum
		jc	.Exit
		cmp	word [ebx+tSPdevParm.BasePort],0
		je	.Err
		mov	ebx,[ebx+tSPdevParm.InpBuf]
		mov	dx,[ebx+tSerialBuf.Used]
		mov	cx,[ebx+tSerialBuf.Size]
		xor	eax,eax

.Exit:		pop	ebx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_GetTXbufStat - get receive buffer status.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DX=space left in buffer,
		;		    CX=buffer size;
		;	  CF=1 - error, AX=error code.
proc SER_GetTXbufStat
		push	ebx
		call	SER_Minor2PortNum
		jc	.Exit
		cmp	word [ebx+tSPdevParm.BasePort],0
		je	.Err
		mov	ebx,[ebx+tSPdevParm.InpBuf]
		mov	dx,[ebx+tSerialBuf.Size]
		mov	cx,dx
		sub	dx,[ebx+tSerialBuf.Used]
		xor	eax,eax

.Exit:		pop	ebx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; SER_DetectIRQ - detect a serial IRQ.
		; Input: AX=port base address.
		; Output: CF=0 - OK, AL=IRQ number;
		;	  CF=1 - error.
proc SER_DetectIRQ
		mpush	ecx,edx
		cli
		mov	dword [DrvSerialET+4],.IRQhandler
		mov	byte [LastIRQnum],0
		mov	dx,ax
		add	dl,UART_IER
		in	al,dx
		mov	cl,al
		add	dl,UART_MCR-UART_IER
		in	al,dx
		mov	ch,al

		mov	al,UART_MCR_DTR | UART_MCR_RTS | UART_MCR_MEI
		out	dx,al
		sub	dl,UART_MCR-UART_IER
		mov	al,15
		out	dx,al
		sti

		add	dl,UART_LSR-UART_IER
		in	al,dx
		sub	dl,UART_LSR-UART_RX
		in	al,dx
		add	dl,UART_IIR-UART_RX
		in	al,dx
		add	dl,UART_MSR-UART_IIR
		in	al,dx

		push	ecx
		mov	ecx,1000
.Loop:		cmp	byte [LastIRQnum],0
		jne	.1
		call	MT_SuspendCurr1ms
		loop	.Loop

.1:		cli
		pop	ecx
		sub	dl,UART_MSR-UART_IER
		mov	al,cl
		out	dx,al
		add	dl,UART_MCR-UART_IER
		mov	al,ch
		out	dx,al

		mov	dword [DrvSerialET+4],SER_HandleEvent
		mov	al,[LastIRQnum]
		mpop	edx,ecx
		ret

.IRQhandler:	mov	[LastIRQnum],al
		ret
endp		;---------------------------------------------------------------


		; SER_DetectUART - determine UART type.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: fills 'Type' and 'FIFOsize' fields in parameters
		;	structure.
proc SER_DetectUART
		mpush	ecx,edx
		mov	byte [ebx+tSPdevParm.Type],UART_Unknown
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	near .Err
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
		jnz	near .Err

		add	dl,UART_LCR-UART_IER
		in	al,dx
		mov	cl,al
		or	al,UART_LCR_DLAB
		out	dx,al
		push	dx
		add	dl,UART_FCR-UART_LCR
		xor	al,al
		out	dx,al
		pop	dx
		mov	al,cl
		out	dx,al
		add	dl,UART_FCR-UART_LCR
		mov	al,UART_FCR_ENABLE_FIFO
		out	dx,al
		add	dl,UART_IIR-UART_FCR
		in	al,dx
		shr	al,6
		mov	ch,al
		mov	byte [ebx+tSPdevParm.FIFOsize],1

		or	ch,ch
		jz	.16450
		cmp	ch,1
		je	.Unknown
		cmp	ch,2
		je	.16550
		cmp	ch,3
		jne	.Unknown

		add	dl,UART_LCR-UART_IIR		; 16550A or 16650?
		mov	al,cl
		or	al,UART_LCR_DLAB
		out	dx,al
		add	dl,UART_FCR-UART_LCR
		in	al,dx
		or	al,al
		jnz	.16550A
		mov	byte [ebx+tSPdevParm.Type],UART_16650
		mov	byte [ebx+tSPdevParm.FIFOsize],32
		jmp	.OK

.16550A:	mov	byte [ebx+tSPdevParm.Type],UART_16550A
		mov	byte [ebx+tSPdevParm.FIFOsize],16
		jmp	.OK

.16450:		add	dl,UART_SCR-UART_IIR
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
		jne	.8250
		cmp	ch,05Ah
		jne	.8250
		mov	byte [ebx+tSPdevParm.Type],UART_16450
		jmp	.OK

.8250:		mov	byte [ebx+tSPdevParm.Type],UART_8250
		jmp	.OK

.16550:		mov	byte [ebx+tSPdevParm.Type],UART_16550
		jmp	.OK

.Unknown:
.OK:		clc
.Exit:		sti
		mpop	edx,ecx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_AllocBuffer - allocate buffer.
		; Input: ESI=pointer to buffer parameters structure,
		;	 CX=buffer size.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_AllocBuffer
		mpush	ebx,edx
		and	ecx,0FFFFh
		mov	dl,1
		call	AllocPhysMem
		jc	.Exit
		mov	[esi+tSerialBuf.Size],cx
		mov	word [esi+tSerialBuf.Used],0
		mov	[esi+tSerialBuf.BufAddr],ebx
		mov	[esi+tSerialBuf.CQin],ebx
		mov	[esi+tSerialBuf.CQout],ebx
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; SER_Interrupt - handle serial port interrupts.
		; Input: EBX=address of port parameters structure.
		; Output: none.
proc SER_Interrupt
		push	edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	.Exit
%ifdef DEBUG_IRQ
		mPrintChar '!'				; debugging
%endif

.Loop:		add	dl,UART_IIR			; Index to IIR
		in	al,dx				; Get interrupt
		test	al,UART_IIR_NONE		; Interrupt pending?
		jnz	.Exit
		sub	dl,UART_IIR			; Index to buffer
		and	al,UART_IIR_ID			; Mask out
		cmp	al,UART_IIR_RDI			; interrupt type bits
		jne	.Output			; Check for RDI
.Input:		call	SER_InputChar			; Yes, read a char
		jmp	.Loop

.Output:	cmp	al,UART_IIR_THRI		; Check for THRI
		jne	.Loop
		call	SER_OutputChar			; Yes, write a char
		jmp	.Loop				; Loop till no more ints buffered

.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_InputChar - input a character to buffer.
		; Input: EBX=address of port parameters structure.
		; Output: none.
proc SER_InputChar
		mpush	edx,edi
		mov	dx,[ebx+tSPdevParm.BasePort]	; Get base port
		mov	edi,[ebx+tSPdevParm.InpBuf]	; and input buffer
		mov	ax,[edi+tSerialBuf.Used]	; See if full
		cmp	ax,[edi+tSerialBuf.Size]
		in	al,dx				; Get input char
		jb	.GetChar			; Not full, go put it
		or	word [ebx+tSPdevParm.ErrFlags],SERERR_BUFOVERFLOW ; Buffer full!
	        jmp	.ChkPortErr		; Check other erros

.GetChar:	inc	word [edi+tSerialBuf.Used]	; Increase used count
		push	edi				; Put character
		mov	edi,[edi+tSerialBuf.CQin]	; in buffer
		mov	[edi],al
		pop	edi
		mCircleQueue CQin			; Update queue pointer

.ChkPortErr:	add	dl,UART_LSR			; Index LSR
		in	al,dx				; Read error bits
		mov	[ebx+tSPdevParm.ErrFlags],al
		mpop	edi,edx
		ret
endp		;---------------------------------------------------------------


		; SER_OutputChar - output a character from buffer.
		; Input: EBX=address of port parameters structure.
		; Output: none.
proc SER_OutputChar
		push	edi
		mov	edi,[ebx+tSPdevParm.OutBuf]	; Get output buffer
		cmp	word [edi+tSerialBuf.Used],0	; See if buffer empty
		je	.Exit

.1:		dec	word [edi+tSerialBuf.Used]	; Else decrease
		mpush	edx,edi				; the count
		mov	edi,[edi+tSerialBuf.CQout]	; Get CQ deletion
		mov	al,[edi]			; Grab a char
		mov	dx,[ebx+tSPdevParm.BasePort]	; Put it out the port
		out	dx,al
		mpop	edi,edx
		mCircleQueue CQout			; Update queue pointer
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; SER_Disable - disable a serial line.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_Disable
		push	edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		add	dl,UART_IER
		xor	al,al				; Disable any
		out	dx,al				; interrupts
		add	dl,UART_MCR-UART_IER
		mov	al,UART_MCR_MEI			; Set down DTR and RTS
		out	dx,al
		or	byte [ebx+tSPdevParm.State],SERST_DISABLED
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; SER_Enable - enable a serial line.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SER_Enable
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
		je	.NoFIFO
		cmp	al,16
		jne	.No16
		mov	al,UART_FCR_TRIGGER_14
		jmp	.SetFIFO
.No16:		shl	al,4
.SetFIFO:	add	dl,UART_FCR-UART_MCR
		or	al,UART_FCR_ENABLE_FIFO
		out	dx,al

.NoFIFO:	and	byte [ebx+tSPdevParm.State],~SERST_DISABLED
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
proc SER_SetMode
		mpush	ebx,ecx,edx
		mov	eax,edx
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	.Err

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
.Exit:		mpop	edx,ecx,ebx
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; SER_GetMode - get UART mode.
		; Input: EBX=address of port parameters structre.
		; Output: CF=0 - OK:
		;		    EAX=0;
		;		    DL=line control word,
		;		    DH=modem control word;
		;	  CF=1 - error, AX=error code.
proc SER_GetMode
		mov	dx,[ebx+tSPdevParm.BasePort]
		or	dx,dx
		jz	.Err

		add	dl,UART_MSR			; Point at MSR
		in	al,dx
		mov	ah,al
		add	dl,UART_LSR-UART_MSR
		in	al,dx
		mov	dx,ax
		xor	eax,eax
		ret

.Err:		mov	ax,ERR_SER_PortNotExist
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
proc SER_Minor2PortNum
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl
		jz	.Err1
		dec	bl
		cmp	bl,SER_MAXPORTS
		jae	.Err2
		mov	dl,bl
		shl	ebx,SPDstrucShift
		add	ebx,PortParameters
		clc
		ret

.Err1:		mov	ax,ERR_DRV_NoMinor
		stc
		ret
.Err2:		mov	ax,ERR_DRV_BadMinor
		stc
		ret
endp		;---------------------------------------------------------------
