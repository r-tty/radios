;-------------------------------------------------------------------------------
;  except.asm - exceptions handling.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Macro which sets things up to call the generic exception handler
macro mEXCEPTION Num,Error,CLflag
Exception&Num:	push	ds			; Switch to system data seg
		push	KERNELDATA
		pop	ds
		mov	[ExcNum],Num		; Save exception number
		IFNB <Error>			; If it has an error # on stack
		 inc	[HasErr]		; Set the error flag
		ENDIF
		IFNB <CLflag>			; If is int #1
		 test	[dword esp+12],FLAG_TF	; See if trap is set in flags
		 jz	short @@NoTrace		; No, not tracing
		 or	[Tracing],1		; Else set tracing flag
@@NoTrace:	 and	[dword esp+12],not FLAG_TF ; Reset trap flag
		ENDIF
		jmp	ExceptionHandler	; Jump to exception handler
endm


; --- Data ---
segment KDATA
; Table of exception handlers offsets
ExcVectors	DD	15			; Number of handlers
		DD	Exception0,Exception1,Exception2,Exception3
		DD	Exception4,Exception5,Exception6,Exception7
		DD	Exception8,Exception9,Exception10,Exception11
		DD	Exception12,Exception13,Exception14,Exception15
		DD	Exception16,Exception17

; Exception messages
MsgException	DB NL,"Exception ",0
MsgErrorCode	DB ", error code: ",0
MsgExc00	DB "divide error",0
MsgExc01	DB "debugging",0
MsgExc02	DB "non-maskable interrupt",0
MsgExc03	DB "breakpoint",0
MsgExc04	DB "INTO overflow",0
MsgExc05	DB "bound range exceed",0
MsgExc06	DB "invalid operation code",0
MsgExc07	DB "processor extension not available",0
MsgExc08	DB "double exception",0
MsgExc09	DB "processor extension protection error (80386/387)",0
MsgExc10	DB "invalid task state segment",0
MsgExc11	DB "segment not present",0
MsgExc12	DB "stack fault",0
MsgExc13	DB "general protection violation",0
MsgExc14	DB "page fault",0
MsgExc15	DB "reserved",0
MsgExc16	DB "coprocessor error",0
MsgExc17	DB "alignment check",0

ExcStrings	DD	MsgExc00,MsgExc01,MsgExc02,MsgExc03,MsgExc04,MsgExc05
		DD	MsgExc06,MsgExc07,MsgExc08,MsgExc09,MsgExc10,MsgExc11
		DD	MsgExc12,MsgExc13,MsgExc14,MsgExc15,MsgExc16,MsgExc17
ends

; --- Variables ---
segment KVARS
HasErr		DW	0		; If there is an error # on stack
ErrNum		DW	0		; The error number
ExcNum		DB	0		; The exception number
Tracing		DB	0		; True if tracing
ends

; --- Procedures ---

		; SaveRegisters - save an image of the registers.
		; Note: This procedure MUST be the first thing the trap handler
		;	calls; it assumes there is ONE PUSH (return address)
		;	followed by the DS at the time of interrupt followed
		;	by the interrupt data
proc SaveRegisters near
		mov	[rEAX],eax	; Save GP regs
		mov	[rEBX],ebx
		mov	[rECX],ecx
		mov	[rEDX],edx
		mov	[rESI],esi
		mov	[rEDI],edi
		mov	[rEBP],ebp
		mov	ebp,esp		; Point BP at interrupt data
		add	ebp,4
		mov	ax,[ebp]	; Get the DS
		mov	[rDS],ax	;
		mov	ebx,4		; Offset past this routine's return
		bt	[HasErr],0	; See if an error
		jnc	@@NoErr
      		add	ebp,4		; Yes, point at eip,cs
		add	ebx,4		; Offset to eip,cs
		mov	ax,[ebp]	; Get the error #
		mov	[ErrNum],ax

@@NoErr:	mov	eax,[ebp+4]	; Get CS:eip
		mov	[rEIP],eax
		mov	ax,[ebp+8]
		mov	[rCS],ax
		mov	ax,es		; Get other segs
		mov	[rES],ax
		mov	ax,fs
		mov	[rFS],ax
		mov	ax,gs
		mov	[rGS],ax
		mov	eax,[ebp + 12]	; Get flags
		mov	[rEFLAGS],eax
		add	ebx,12		; Offset past CS:eip & flags
		mov	ax,cs		; See if CS has a selector other than 0
					; ( this program runs in ring 0 )
		xor	ax,[rCS]
		and	ax,SELECTOR_RPL
		jnz	@@StackOfStack	; Yes, we must pull the ring x stack ptr off the ring 0 stack
		mov	ax,ss		; Otherwise just save the current
		mov	[rSS],ax	; stack pointer before we started pushing
		mov	eax,ebp		; things in the trap routine
		add	eax,16
		mov	[rESP],eax
		jmp	short @@Exit	; Done, get out

@@StackOfStack:	add	ebx,8		; Offset pass SP:ESS
		mov	eax,[ebp+16]	; Get SP:ESS from ring 0 stack
		mov	[rESP],eax
		mov	ax,[ebp + 20]
		mov	[rSS],ax
@@Exit:		ret
endp		;---------------------------------------------------------------


		; AdjustEIP - adjust EIP to trap if it's not int 3.
proc AdjustEIP near
		cmp	[ExcNum],3		; See if int 3
		jne	short @@Exit		; No, exit
		push	gs			; Else get CS:EIP
		push	ABSDS
		pop	gs
		mov	ebx,[rEIP]
		movzx	edx,[rCS]
		call	BaseAndLimit		; Refer to it in abs. segment
		dec	esi
		cmp	[byte gs:esi],0CCh 	; See if is an INT 3
		je	short @@NoDecr		; Get out if so
		dec	[rEIP]			; Else point at trap
@@NoDecr:	pop	gs
@@Exit:		ret
endp		;---------------------------------------------------------------


		; ExceptionHandler - generic exception handler
proc ExceptionHandler near
		call	SaveRegisters		; Save Regs
		add	esp,ebx			; Find usable top of stack
		mov	[sstoss],ss		; Save it for page error routine
		mov	[rtoss],esp
		test	[Tracing],1		; See if tracing
		jnz	short @@Tracing
		call	DisableBreaks		; Disable breakpoints if not
@@Tracing:	call	AdjustEIP		; Adjust EIP to point to breakpoint
		mov	[Tracing],0		; Clear tracing flag
		mWrChar NL
		cmp	[ExcNum],3		; No stats if it is int 3
		je	@@DispRegs
		cmp	[ExcNum],1		; or int 1
		je	@@DispRegs

		mWrString MsgException		; Else tell it's a exception
		mov	al,[ExcNum]
		call	PrintByteDec
		mWrChar ' '
		mWrChar '('
		movzx	eax,[ExcNum]
		mov	esi,[ExcStrings+eax*4]
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar ')'
		btr	[HasErr],0		; If has error
		jnc	short @@DispRegs
		mWrString MsgErrorCode		; Say there's an error
		mov	ax,[ErrNum]		; Say which one
		call	PrintDwordHex
		mWrChar NL
@@DispRegs:	call	DisplayRegisters	; Display registers
		jmp	InputHandler		; Go do input
endp		;---------------------------------------------------------------


; Individual trap handlers

mEXCEPTION	0
mEXCEPTION	1,,YES
mEXCEPTION	2
mEXCEPTION	3
mEXCEPTION	4
mEXCEPTION	5
mEXCEPTION	6
mEXCEPTION	7
mEXCEPTION	8,YES
mEXCEPTION	9
mEXCEPTION	10,YES
mEXCEPTION	11,YES
mEXCEPTION	12,YES
mEXCEPTION	13,YES
mEXCEPTION	14,YES
mEXCEPTION	15
mEXCEPTION	16,YES
mEXCEPTION	17,YES

