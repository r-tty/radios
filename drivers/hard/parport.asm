;*******************************************************************************
;  parport.asm - parallel port driver.
;  (c) 1999 Yuri Zaporogets.
;*******************************************************************************

; --- Definitions ---

; Structure of device parameters
struc tPPdevParm
 BasePort	DW	?
 IRQ		DB	?
 State		DB	?
 OpenCount	DB	?
 Reserved	DB	?,?,?
ends

PPDstrucSize		EQU	8
PPDstrucShift		EQU	3


; --- Data ---
segment KDATA

; Driver main structure
DrvParallel	tDriver <"%parallel       ",offset DrvParallelET,DRVFL_Char>

; Driver entry points table
DrvParallelET	tDrvEntries < PAR_Init,\
			      PAR_HandleEvent,\
			      PAR_Open,\
			      PAR_Close,\
			      PAR_Read,\
			      PAR_Write,\
			      NULL,\
			      DrvPar_Ctrl >

DrvPar_Ctrl	DD	PAR_GetInitStatStr
		DD	PAR_GetParameters

PP_InitStatStr	DB	9,": 0 port(s) detected",0
PP_BaseStr	DB	9,": base port ",0
PP_IRQstr	DB	", IRQ ",0
ends


; --- Variables ---
segment KVARS
ParPortBases	DW	378h			; Port base addresses
		DW	278h
		DW	3BCh
		DW	2BCh
		DW	0
		DW	0
		DW	0
		DW	0

ParPortIRQs	DB	7			; LPT1 IRQ
		DB	5			; LPT2 IRQ
		DB	6 dup (0)

PPtblHnd	DW	0			; Handle and address of
PPtblAddr	DD	0			; port parameters structures
NumOfParPorts	DB	0			; Number of supported ports
ends


; --- Procedures ---

		; PAR_Init - initialize driver.
		; Input: AL!=0 - maximum number of supported ports (1..8);
		;	 AL==0 - get number of ports and base addresses
		;		 from BIOS data area.
		;	 ESI=buffer for init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PAR_Init near
		cmp	[PPtblHnd],0
		jne	@@Err2
		push	ebx ecx esi edi
		or	al,al
		jz	short @@FromBIOS
		cmp	al,8
		ja	short @@Err
		mov	cl,al
		mov	edi,offset ParPortBases
		jmp	short @@AllocMem

@@FromBIOS:	mov	cx,[BIOSDA_Begin+tBIOSDA.Hardware]
		shr	ecx,14
		lea	edi,[BIOSDA_Begin+tBIOSDA.LPT1addr]

@@AllocMem:	or	cl,cl
		jz	short @@FillString
		mov	[NumOfParPorts],cl
		and	ecx,0FFh
		shl	ecx,PPDstrucShift
		call	KH_Alloc
		jc	short @@Exit
		mov	[PPtblHnd],ax
		mov	[PPtblAddr],ebx
		xor	ecx,ecx
		mov	edx,offset ParPortIRQs

@@FillTblLoop:	mov	ax,[edi]
		mov	[ebx+tPPdevParm.BasePort],ax
		mov	al,[edx]
		mov	[ebx+tPPdevParm.IRQ],al
		xor	eax,eax
		mov	[ebx+tPPdevParm.State],al
		mov	[ebx+tPPdevParm.OpenCount],al
		inc	cl
		cmp	cl,[NumOfParPorts]
		je	short @@FillString
		add	ebx,PPDstrucSize
		inc	edi
		inc	edi
		inc	edx
		jmp	@@FillTblLoop

@@FillString:	xor	edx,edx
		call	PAR_GetInitStatStr

@@Exit:		pop	edi esi ecx ebx
		ret
@@Err:		mov	ax,ERR_PAR_BadNumOfPorts
		stc
		jmp	short @@Exit
@@Err2:		mov	ax,ERR_DRV_AlreadyInitialized
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_Open - "open" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc PAR_Open near
		push	ebx edx
		call	PAR_Minor2PortNum
		jc	short @@Exit
		cmp	[ebx+tPPdevParm.OpenCount],255
		je	short @@Err
		inc	[ebx+tPPdevParm.OpenCount]
		clc
@@Exit:		pop	edx ebx
		ret
@@Err:		mov	ax,ERR_DRV_OpenOverflow
		stc
		jmp	short @@Exit
endp		;---------------------------------------------------------------


		; PAR_Close -  "close" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc PAR_Close near
		ret
endp		;---------------------------------------------------------------


		; PAR_Read - read one byte from port (ECP/EPP only).
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, AL=byte;
		;	  CF=1 - error, AX=error code.
proc PAR_Read near
		ret
endp		;---------------------------------------------------------------


		; PAR_Write - write one byte to port.
		; Input: EDX (high word) = full minor number of device,
		;	 AL=byte to write.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc PAR_Write near
		ret
endp		;---------------------------------------------------------------


		; PAR_HandleEvent - handle parallel port interrupts.
		; Input: EAX=event code.
		; Output: none.
proc PAR_HandleEvent near
		ret
endp		;---------------------------------------------------------------


		; PAR_GetInitStatStr - get initialization status string.
		; Input: ESI=buffer for string.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc PAR_GetInitStatStr near
		push	ebx esi edi
		mov	edi,esi
		mov	esi,offset DrvParallel		; Copy "%parallel"
		call	StrCopy
		call	StrEnd

		test	edx,0FFFF0000h			; Minor present?
		jnz	short @@Minor
		mov	esi,offset PP_InitStatStr
		call	StrCopy
		mov	al,[NumOfParPorts]
		add	al,30h
		mov	[edi+3],al
		jmp	short @@OK

@@Minor:	call	PAR_Minor2PortNum		; Get port number
		jc	short @@Exit			; and DPS address
		add	dl,'1'
		mov	[edi],dl
		inc	edi
		mov	esi,offset PP_BaseStr
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	ax,[ebx+tPPdevParm.BasePort]
		call	K_HexW2Str
		mov	edi,esi
		mov	[byte edi],'h'
		inc	edi
		mov	esi,offset PP_IRQstr
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		xor	eax,eax
		mov	al,[ebx+tPPdevParm.IRQ]
		call	K_DecD2Str

@@OK:		clc
@@Exit:		pop	edi esi ebx
		ret
endp		;---------------------------------------------------------------


		; PAR_GetParameters - get device parameters.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PAR_GetParameters near
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; PAR_Minor2PortNum - convert minor number to port number
		;		      and get address of parameters structure.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    DL=port number (0..),
		;		    EBX=structure address;
		;	  CF=1 - error, AX=error code.
proc PAR_Minor2PortNum near
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl
		jz	short @@Err1
		dec	bl
		cmp	bl,[NumOfParPorts]
		jae	short @@Err2
		mov	dl,bl
		shl	ebx,PPDstrucShift
		add	ebx,[PPtblAddr]
		clc
		ret

@@Err1:		mov	ax,ERR_DRV_NoMinor
		stc
		ret
@@Err2:		mov	ax,ERR_DRV_BadMinor
		stc
		ret
endp		;---------------------------------------------------------------
