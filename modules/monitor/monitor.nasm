;*******************************************************************************
; monitor.nasm - RadiOS kernel monitor/debugger.
; Ported from David Lindauer's OS-32 by Yuri Zaporogets.
;*******************************************************************************

module $monitor

%include "sys.ah"
%include "errors.ah"
%include "asciictl.ah"
%include "module.ah"
%include "syscall.ah"
%include "cpu/stkframe.ah"
%include "monitor.ah"

; --- Imports ---

library $rmk
importproc K_GetExceptionVec, K_SetExceptionVec
importproc K_GetDescriptorBase, K_GetDescriptorAR
importproc K_DescriptorAddress, K_GetDescriptorLimit
importproc K_InstallSoftIntHandler
importproc StrComp
importproc ExitKernel
importproc PrintChar, PrintCharRaw, PrintString
importproc PrintByteDec, PrintWordDec, PrintDwordDec
importproc PrintByteHex, PrintWordHex, PrintDwordHex
importproc ReadChar, ReadString


; --- Definitions ---
%define	InputBufSize	72		; Input string max. size


; --- Data ---

section .data

%ifndef LINKMONITOR
exportdata ModuleInfo
ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_KERNEL)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	-1)
    field(Entry,	DD	MonitorInit)
iend
%else
exportproc MonitorInit
%endif

TxtOptNoPFH	DB "nopfh",0
TxtOptNoKDB	DB "nokdb",0
MonPrompt	DB NL,"* ",0
RegPrompt	DB NL,": ",0
TxtPageFault	DB NL,"Invalid paging",NL,0
TxtHelp		DB NL,"Monitor commands:",NL
		DB " b# addr",9,"  - set a breakpoint",NL
		DB " d addr[,addr1]",9,"  - dump",NL
		DB " e addr",9,9,"  - examine address",NL
		DB " g [addr][,addr1] - run from addr to addr1 (sets special breakpoint 0)",NL
		DB " p",9,9,"  - proceed, only runs calls though",NL
		DB " q",9,9,"  - exit from kernel",NL
		DB " r [reg]",9,"  - view/modify registers",NL
		DB " t",9,9,"  - single step",NL
		DB " u [addr]",9,"  - disassemble",NL,0


; --- Variables ---

section .bss

InputBuffer	RESB	InputBufSize			; Input string buffer
OldPgExc	RESD	1
		RESW	1


; --- Procedures ---

section .text

%include "util.nasm"
%include "dump.nasm"
%include "regs.nasm"
%include "except.nasm"
%include "disasm.nasm"
%include "enter.nasm"
%include "exec.nasm"
%include "breaks.nasm"


		; MonitorInit - initialize the monitor.
		; Input: EBX=module descriptor if loaded as module, 0 otherwise
		; Note: this procedure installs all exception handlers.
		;	If an argument "nopfh" was passed in command line,
		;	page fault handler won't be installed.
		;	Also it registers the handler of DebugKDBread unless
		;	an argument "nokdb" is passed.
proc MonitorInit
		pushad
		call	.CheckArg
		mov	ecx,[ExcVectors]		; Number of vectors
		mov	esi,ExcVectors+4		; Exc0 vector offset
		xor	edi,edi				; Exception number
.Loop:		lodsd
		or	eax,eax				; Install new handler?
		jz	.Next
		mov	ebx,eax
		mov	edx,cs
		mov	eax,edi
		call	K_SetExceptionVec
.Next:		inc	edi
		loop	.Loop
.Exit:		popad
		ret

		; Subroutine: check command-line arguments
.CheckArg:	or	ebx,ebx				; Loaded as module?
		jz	.Ret
		mov	edi,[ebx+tModule.ARGPaddr]
		cmp	byte [edi],1			; argc == 1?
		jbe	.Ret
		mov	esi,[edi+8]			; ESI=argc[1]
		mov	edi,TxtOptNoPFH
		call	StrComp				; Compare argument
		or	al,al
		jnz	.ChkKDB
		mov	dword [ExcVectors+4+14*4],0	; Don't install pfh
.ChkKDB:	mov	edi,TxtOptNoKDB
		call	StrComp
		or	al,al
		jz	.Ret
		mov	al,KDEBUG_TRAP
		mov	ebx,DebugKDBreak
		call	K_InstallSoftIntHandler
.Ret:		ret
endp		;---------------------------------------------------------------


		; Handler of DebugKDBreak trap.
proc DebugKDBreak
		push	ebp
		lea	ebp,[esp+8]
		mov	eax,[ebp+tStackFrame.ESDS]
		mov	[rES],ax
		ror	eax,16
		mov	[rDS],ax
		mov	eax,fs
		mov	[rFS],ax
		mov	eax,gs
		mov	[rGS],ax
		Mov16	rCS,ebp+tStackFrame.ECS
		Mov32	rEIP,ebp+tStackFrame.EIP
		Mov16	rSS,ebp+tStackFrame.ESS
		Mov32	rESP,ebp+tStackFrame.ESP
		Mov32	rEFLAGS,ebp+tStackFrame.EFLAGS
		Mov32	rEDI,ebp+tStackFrame.EDI
		Mov32	rESI,ebp+tStackFrame.ESI
		Mov32	rEBP,ebp+tStackFrame.EBP
		Mov32	rEBX,ebp+tStackFrame.EBX
		Mov32	rEDX,ebp+tStackFrame.EDX
		Mov32	rECX,ebp+tStackFrame.ECX
		Mov32	rEAX,ebp+tStackFrame.EAX
		sldt	[rLDTR]
		mPrintChar NL
		call	DisplayRegisters
		jmp	InputHandler
endp		;---------------------------------------------------------------


                ; InputHandler - monitor input handler.
proc InputHandler
		sti					; Enable ints
.WaitCmd:	mPrintString MonPrompt
		mov	esi,InputBuffer
		mov	cl,InputBufSize-1
		call	ReadString			; Read command line
		call	StrLen
		or	ecx,ecx
		jz	.WaitCmd
		mov	byte [esi+ecx],ASC_CR		; Put CR at end of line
		call	WadeSpace
		inc	esi

		cmp	al,'q'
		je	near .Reset
		push	dword .CheckErr			; Prepare to run command
		cmp     al,'d'
		je      near MON_Dump			; Display dump
		cmp     al,'r'
		je      near MON_Registers		; View/modify registers
                cmp     al,'e'
		je      near MON_Enter			; Modify bytes
                cmp     al,'u'
		je      near MON_Disassembly		; Disassembly
		cmp	al,'t'
		je	near MON_Trace			; Trace
		cmp	al,'p'
		je	near MON_Proceed		; Proceed
		cmp	al,'g'
		je	near MON_Go			; Go
		cmp	al,'b'
		je	near MON_Breaks			; Breakpoint
		cmp	al,'?'
		je	near MON_Help			; Help
		add     esp,byte 4			; Restore stack
		stc					; if no command

.CheckErr:	jnc	near .WaitCmd
		call	DisplayErr			; Display error pos.
		jmp     .WaitCmd

.Reset:		xor	eax,eax
		jmp	ExitKernel
endp		;---------------------------------------------------------------


		; BaseAndLimit - get the base and limit of memory to access.
		; Input: DX=selector;
		;	 EBX=offset;
		;	 ECX=requested length.
		; Output: ESI=absolute address,
		;	  ECX=maximum length.
proc BaseAndLimit
		push	ebx
		push	edi
		mov	esi,ebx
		call	K_DescriptorAddress	; Get descriptor address in EBX
		call	K_GetDescriptorBase	; Get it's base and limit
		call	K_GetDescriptorLimit	; (EDI = base, EAX = limit)
		sub	eax,esi			; Calculate max length
		cmp	eax,ecx			; left in segment
		jae	.OK			; If < user specified length -
		mov	ecx,eax			; switch to max length
.OK:		add	esi,edi			; Calculate start address
		pop	edi
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; VerifySelector - check whether a selector exists
		;		   and is a memory selector.
		; Input: AX=selector.
		; Output: CF=0 - OK,
		;	  CF=1 - error.
proc VerifySelector
		push	eax
		cmp	ax,GDT_limit			; Error if beyond GDT
		ja	.Err
		mpush	ebx,edx
		movzx	edx,ax
		call	K_DescriptorAddress
		call	K_GetDescriptorAR		; Get descriptor ARs
		mpop	edx,ebx
		test	al,ARpresent			; Error if not present
		jz	.Err
		test	al,ARsegment			; Error if not
		jz	.Err				; memory descriptor
%ifdef USER
		and	al,AR_DPL3			; Error if not DPL3
		cmp	al,AR_DPL3
		jne	.Err
%endif
		clc					; OK
		jmp	.Exit
.Err:		stc					; Bad descriptor
.Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PageTrapErr - set up monitor page trap error.
proc PageTrapErr
		mpush	eax,ebx,edx
		mov	al,14			; Get user trap interrupt
		call	K_GetExceptionVec
		mov	dword [OldPgExc],ebx
		mov	word [OldPgExc+4],dx
		mov	edx,cs			; Set Monitor trap interrupt
		mov	ebx,PageTrapped
		mov	al,14
		call	K_SetExceptionVec
		mpop	edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; PageTrapUnerr - set user page trap error
		;		  (unset monitor error).
proc PageTrapUnerr
		mpush	eax,ebx,edx
		mov	ebx,dword [OldPgExc]	; Restore user value
		mov	dx,word [OldPgExc+4]
		mov	al,14
		call	K_SetExceptionVec
		mpop	edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; Temporairy paging exception handler
proc PageTrapped
		mov	ss,[sstoss]		; Get top of stack
		mov	esp,[rtoss]
		call	PageTrapUnerr		; Turn page trap off
		mPrintString TxtPageFault	; Print 'trapped' message
		jmp	InputHandler		; Go do more input
endp		;---------------------------------------------------------------



; Additional procedures

		; WadeSpace - wade spaces and commas in command line.
		; Input: ESI=pointer to command line.
		; Output: ESI=pointer to last space or comma.
proc WadeSpace
.Wade:		lodsb
		cmp	al,' '
		jz	.Wade
		cmp	al,','
		jz	.Wade
		dec	esi
		ret
endp		;---------------------------------------------------------------


		; ScanDigit - search decimal digit in string.
		; Input: ESI=pointer to string.
		; Output: CF=0 - OK, ESI=pointer to first occurence of digit
		;		     in string,
		;		     AL=occured digit;
		;	  CF=1 - string doesn't contain any digit.
proc ScanDigit
.Loop:		lodsb
		or	al,al
		je	.NotFound
		cmp	al,'0'
		jb	.Loop
		cmp	al,'9'
		ja	.Loop
		dec	esi
		clc
		ret
.NotFound:	stc
		ret
endp		;---------------------------------------------------------------



                ; ReadNumber - get number from command line.
		; Output: CF=0 - OK, EAX=got number;
		;	  CF=1 - error, EAX=error pos.
proc ReadNumber
		push    ebx
		xor     ebx,ebx			; Number = 0
		push    ecx
		push    edx
		xor     ecx,ecx			; digits = 0

.Loop:		lodsb				; Get character
		call	CharToUpper
		sub	al,'0'			; Convert to binary
		jc      .Done			; < '0' is an error
		cmp	al,10			; See if is a digit
		jb	.GotDigit		; Yes, got it
		sub     al,7                    ; Convert letters to binary
		cmp     al,16                   ; Make sure is < 'G'
		jae	.Done			; Quit if not
		cmp	al,10			; Make sure not < 'A'
		jb	.Done

.GotDigit:	shl	ebx,4			; It is a hex digit, add in
		or	bl,al
		inc	ecx			; Set flag to indicate we got digits
		jmp	.Loop

.Done:		dec	esi			; Point at first non-digit
		test	cl,-1			; See if got any
		jnz	.Exit
		stc				; No, error
.Exit:		pop	edx
		pop	ecx
		mov	eax,ebx
		pop	ebx
		ret
endp		;---------------------------------------------------------------



		; Read address - get address from command line.
		; Note: address composed of a number and a possible selector.
proc ReadAddress
		lodsw				; Get first two bytes
		cmp	ax,"sd"			; Translate selectors to their vals
		mov	dx,[rDS]
	        je	.GotSel
	        cmp	ax,"se"
		mov     dx,[rES]
		je	.GotSel
		cmp	ax,"sf"
		mov	dx,[rFS]
		je	.GotSel
		cmp	ax,"sg"
		mov	dx,[rGS]
		je	.GotSel
		cmp	ax,"ss"
		mov	dx,[rSS]
		je	.GotSel
		cmp	ax,"sc"
		mov	dx,[rCS]
		je	.GotSel
		xor	edx,edx			; Not a reg selector, assume NULL selector
		dec	esi			; Point back at first byte
		dec	esi
		call	ReadNumber		; Read a number
		jc	.Err			; Quit if error
		mov	ebx,eax			; Number to EBX
		cmp	byte [esi],':'		; See if is selector
		jne	.OK			; No, quit
		mov	edx,eax			; Else EDX = selector
		call	VerifySelector		; Verify it
		jc	.Err			; Get out on error
		jmp	.GetAddr

.GotSel:	cmp	byte [esi],':'		; Make sure is a selector
		jne	.Err			; Error if not
		mov     eax,edx			; Verify it
		call	VerifySelector
		jc	.Err			; Error if non-existant
.GetAddr:	inc	esi			; Point past ':'
		call	ReadNumber		; Read in offset
		jc	.Err			; Quit if error
		mov	ebx,eax
.OK:		clc                             ; OK, exit
		jmp	.Exit
.Err:		stc				; Error
.Exit:		ret
endp		;---------------------------------------------------------------


		; DisplayErr - display error position if input is wrong.
proc DisplayErr
		mPrintChar NL				; Next line
		sub	esi,InputBuffer-2		; Calculate error pos
		mov	ecx,esi
		jcxz	.Start
		dec	ecx
		jcxz	.Start
.Loop:		mPrintChar ' '
		loop	.Loop
.Start:		mPrintChar '^'				; Display error
		stc					; Did an error
		ret
endp		;---------------------------------------------------------------


		; MON_Help - display short monitor help.
proc MON_Help
		mPrintString TxtHelp
		ret
endp		;---------------------------------------------------------------

