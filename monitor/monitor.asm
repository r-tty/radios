;*******************************************************************************
;  monitor.asm - RadiOS kernel monitor/debugger.
;  Ported from David Lindauer's OS-32 by Yuri Zaporogets.
;*******************************************************************************

.386p
Ideal

include "segments.ah"
include "macros.ah"
include "kernel.ah"
include "gdt.ah"
include "errdefs.ah"
include "drivers.ah"
include "drvctrl.ah"
include "asciictl.ah"
include "strings.ah"
include "misc.ah"

		public MonitorInit


; --- Definitions ---
InputBufSize			EQU	72		; Input string max. size

; --- Data ---
segment KDATA
MonPrompt	DB NL,"* ",0
RegPrompt	DB NL,": ",0
MsgPageFault	DB NL,"Invalid paging",NL,0
MsgHelp		DB NL,"Monitor commands:",NL
		DB " %drvname fun",9,"  - call driver function",NL
		DB " b# addr",9,"  - set a breakpoint",NL
		DB " d addr[,addr1]",9,"  - dump",NL
		DB " e addr",9,9,"  - examine address",NL
		DB " g [addr][,addr1] - run from addr to addr1 (sets special breakpoint 0)",NL
		DB " p",9,9,"  - proceed, only runs calls though",NL
		DB " q",9,9,"  - quit",NL
		DB " r [reg]",9,"  - view/modify registers",NL
		DB " t",9,9,"  - single step",NL
		DB " u [addr]",9,"  - dissassemble",NL,0
ends


; --- Variables ---
segment KVARS
InputBuffer	DB InputBufSize dup (0)			; Input string buffer
OldPgExc	DD ?
		DW ?
ends


; --- Procedures ---
segment KCODE

include "dump.asm"
include "regs.asm"
include "except.asm"
include "disasm.asm"
include "enter.asm"
include "exec.asm"
include "breaks.asm"


		; MonitorInit - install all exception handlers.
proc MonitorInit near
		pushad
		mov	ecx,[ExcVectors]		; Number of vectors
		mov	esi,offset ExcVectors+4		; Exc0 vector offset
		xor	edi,edi				; Exception number
@@Loop:		lodsd
		mov	ebx,eax
		mov	edx,cs
		mov	eax,edi
		call	K_SetExceptionVec
		inc	edi
		loop	@@Loop
		popad
		ret
endp		;---------------------------------------------------------------


                ; InputHandler - monitor input handler.
proc InputHandler near
		sti					; Enable ints
@@WaitCmd:	mWrString MonPrompt
		mov	esi,offset InputBuffer
		mov	cl,InputBufSize-1
		call	ReadString			; Read command line
		or	cl,cl
		jz	@@WaitCmd
		movzx	ecx,cl				; Put CR at end of line
		mov	[byte esi+ecx],ASC_CR
		call	WadeSpace
		inc	esi

		cmp	al,'q'
		je	@@Reset
		push	offset @@CheckErr		; Prepare to run command
		cmp     al,'d'
		je      MON_Dump			; Display dump
		cmp     al,'r'
		je      MON_Registers			; View/modify registers
                cmp     al,'e'
		je      MON_Enter			; Modify bytes
                cmp     al,'u'
		je      MON_Disassembly			; Disassembly
		cmp	al,'t'
		je	MON_Trace			; Trace
		cmp	al,'p'
		je	MON_Proceed			; Proceed
		cmp	al,'g'
		je	MON_Go				; Go
		cmp	al,'b'
		je	MON_Breaks			; Breakpoint
		cmp	al,'%'
		je	MON_CallDriver			; Call driver
		cmp	al,'?'
		je	MON_Help			; Help
		add     esp,4				; Restore stack
		stc					; if no command

@@CheckErr:	jnc	@@WaitCmd
		call	DisplayErr			; Display error pos.
		jmp     @@WaitCmd

@@Reset:	mov	eax,[rEAX]			; Load exit code
		jmp	SysReset
endp		;---------------------------------------------------------------


		; BaseAndLimit - get the base and limit of memory to access.
		; Input: DX=selector;
		;	 EBX=offset;
		;	 ECX=requested length.
		; Output: ESI=absolute address,
		;	  ECX=maximum length.
proc BaseAndLimit near
		push	ebx
		push	edi
		mov	esi,ebx
		call	K_DescriptorAddress	; Get descriptor address in EBX
		call	K_GetDescriptorBase	; Get it's base and limit
		call	K_GetDescriptorLimit	; (EDI = base, EAX = limit)
		sub	eax,esi			; Calculate max length
		cmp	eax,ecx			; left in segment
		jae	@@OK			; If < user specified length -
		mov	ecx,eax			; switch to max length
@@OK:		add	esi,edi			; Calculate start address
		pop	edi
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; VerifySelector - check whether selectot exists
		;		   and is a memory selector.
		; Input: AX=selector.
		; Output: CF=0 - OK,
		;	  CF=1 - error.
proc VerifySelector near
		push	eax
		cmp	ax,size tRGDT			; Error if beyod GDT
		jae	@@Err
		push	ebx
		push	edx
		movzx	edx,ax
		call	K_DescriptorAddress
		call	K_GetDescriptorAR		; Get descriptor ARs
		pop	edx
		pop	ebx
		test	al,ARpresent			; Error if not present
		jz	@@Err
		test	al,ARsegment			; Error if not
		jz	@@Err				; memory descriptor
	IFDEF USER
		and	al,AR_DPL3			; Error if not DPL3
		cmp	al,AR_DPL3
		jne	@@Err
	ENDIF
		clc					; OK
		jmp	short @@Exit
@@Err:		stc					; Bad descriptor
@@Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PageTrapErr - set up monitor page trap error.
proc PageTrapErr near
		push	eax ebx edx
		mov	al,14			; Get user trap interrupt
		call	K_GetExceptionVec
		mov	[dword OldPgExc],ebx
		mov	[word OldPgExc+4],dx
		mov	edx,cs			; Set Monitor trap interrupt
		mov	ebx,offset PageTrapped
		mov	al,14
		call	K_SetExceptionVec
		pop	edx ebx eax
		ret
endp		;---------------------------------------------------------------

		; PageTrapUnerr - set user page trap error
		;		  (unset monitor error).
proc PageTrapUnerr near
		push	eax ebx edx
		mov	ebx,[dword OldPgExc]	; Restore user value
		mov	dx,[word OldPgExc+4]
		mov	al,14
		call	K_SetExceptionVec
		pop	edx ebx eax
		ret
endp		;---------------------------------------------------------------

		; Temporairy paging exception handler
proc PageTrapped near
		mov	ss,[sstoss]		; Get top of stack
		mov	esp,[rtoss]		;
		call	PageTrapUnerr		; Turn page trap off
		mWrString MsgPageFault		; Print 'trapped' message
		jmp	InputHandler		; Go do more input
endp		;---------------------------------------------------------------



; Additional procedures

		; WadeSpace - wade spaces and commas in command line.
		; Input: ESI=pointer to command line.
		; Output: ESI=pointer to last space or comma.
proc WadeSpace near
@@Wade:		lodsb
		cmp     al,' '
		jz      short @@Wade
		cmp     al,','
		jz      short @@Wade
		dec     esi
		ret
endp		;---------------------------------------------------------------


		; ScanDigit - search decimal digit in string.
		; Input: ESI=pointer to string.
		; Output: CF=0 - OK, ESI=pointer to first occurence of digit
		;		     in string,
		;		     AL=occured digit;
		;	  CF=1 - string doesn't contain any digit.
proc ScanDigit near
@@Loop:		lods	[byte esi]
		or	al,al
		je	@@NotFound
		cmp	al,'0'
		jb	@@Loop
		cmp	al,'9'
		ja	@@Loop
		dec	esi
		clc
		ret
@@NotFound:	stc
		ret
endp		;---------------------------------------------------------------



                ; ReadNumber - get number from command line.
		; Output: CF=0 - OK, EAX=got number;
		;	  CF=1 - error, EAX=error pos.
proc ReadNumber near
		push    ebx
		xor     ebx,ebx			; Number = 0
		push    ecx
		push    edx
		xor     ecx,ecx			; digits = 0

@@Loop:		lods	[byte esi]		; Get character
		call	CharToUpper
		sub	al,'0'			; Convert to binary
		jc      @@Done			; < '0' is an error
		cmp	al,10			; See if is a digit
		jb	@@GotDigit		; Yes, got it
		sub     al,7                    ; Convert letters to binary
		cmp     al,16                   ; Make sure is < 'G'
		jae	@@Done			; Quit if not
		cmp	al,10			; Make sure not < 'A'
		jb	@@Done

@@GotDigit:	shl	ebx,4			; It is a hex digit, add in
		or	bl,al
		inc	ecx			; Set flag to indicate we got digits
		jmp	@@Loop

@@Done:		dec	esi			; Point at first non-digit
		test	cl,-1			; See if got any
		jnz	@@Exit
		stc				; No, error
@@Exit:		pop	edx
		pop	ecx
		mov	eax,ebx
		pop	ebx
		ret
endp		;---------------------------------------------------------------



		; Read address - get address from command line.
		; Note: address composed of a number and a possible selector.
proc ReadAddress near
		lodsw				; Get first two bytes
		cmp	ax,"sd"			; Translate selectors to their vals
		mov	dx,[rDS]
	        je	@@GotSel
	        cmp	ax,"se"
		mov     dx,[rES]
		je	@@GotSel
		cmp	ax,"sf"
		mov	dx,[rFS]
		je	@@GotSel
		cmp	ax,"sg"
		mov	dx,[rGS]
		je	@@GotSel
		cmp	ax,"ss"
		mov	dx,[rSS]
		je	@@GotSel
		cmp	ax,"sc"
		mov	dx,[rCS]
		je	@@GotSel
		xor	edx,edx			; Not a reg selector, assume NULL selector
		dec	esi			; Point back at first byte
		dec	esi
		call	ReadNumber		; Read a number
		jc	@@Err			; Quit if error
		mov	ebx,eax			; Number to EBX
		cmp     [byte esi],':'		; See if is selector
		jne	@@OK			; No, quit
		mov	edx,eax			; Else EDX = selector
		call	VerifySelector		; Verify it
		jc	@@Err			; Get out on error
		jmp	short @@GetAddr

@@GotSel:	cmp	[byte esi],':'		; Make sure is a selector
		jne	@@Err			; Error if not
		mov     eax,edx			; Verify it
		call	VerifySelector
		jc	@@Err			; Error if non-existant
@@GetAddr:	inc	esi			; Point past ':'
		call	ReadNumber		; Read in offset
		jc	@@Err			; Quit if error
		mov	ebx,eax
@@OK:		clc                             ; OK, exit
		jmp	short @@Exit
@@Err:		stc				; Error
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DisplayErr - display error position if input is wrong.
proc DisplayErr near
		mWrChar NL				; Next line
		sub	esi,(offset InputBuffer)-2	; Calculate error pos
		mov	ecx,esi
		jcxz	@@Start
		dec	ecx
		jcxz	@@Start
@@Loop:		mWrChar ' '
		loop	@@Loop
@@Start:	mWrChar '^'				; Display error
		stc					; Did an error
		ret
endp		;---------------------------------------------------------------


		; MON_Help - display short monitor help.
proc MON_Help near
		mWrString MsgHelp
		ret
endp		;---------------------------------------------------------------


		; MON_CallDriver - call driver.
proc MON_CallDriver near
@@DrvMajorNum	EQU	[word ebp-4]
@@DrvMinorNum	EQU	[word ebp-2]
@@DrvFun	EQU	[word ebp-8]
@@DrvFunCtrl	EQU	[word ebp-6]
		push	ebp
		mov	ebp,esp
		sub	esp,8
		call	WadeSpace
		cmp	al,13			; Fun. number present?
		je	@@Exit			; No, exit
		mov	edi,esi
		mov	al,' '			; Search first space
		call	StrScan
		or	edi,edi
		jz	@@Exit
		mov	[byte edi],0		; EDI+1=pointer to fun. num.

		mov	edx,esi			; EDX=pointer to driver name
		dec	edx
		mov	@@DrvMinorNum,0
		call	ScanDigit
		jc	@@NoMinorNum
		push	esi			; ESI=pointer to first digit
		call	ReadNumber
		pop	esi
		jc	@@Exit
		call	BCDW2Dec
		cmp	eax,10000h
		jae	@@Err
		mov	@@DrvMinorNum,ax
		mov	[byte esi],0

@@NoMinorNum:	mov	esi,edx
		call	DRV_FindName		; Find driver by name
		jnc	@@DrvFound
		inc	esi			; ESI=error position
		inc	esi
		jmp	@@Err

@@DrvFound:	mov	@@DrvMajorNum,ax
		mov	esi,edi			; Read function number
		inc	esi
		call	WadeSpace
		cmp	al,ASC_CR
		je	@@Err
		call	ReadNumber
		jc	@@Exit
		call	BCDW2Dec
		mov	@@DrvFun,ax
		mov	@@DrvFunCtrl,0

		call	WadeSpace
		cmp	al,ASC_CR		; Does subfunction present?
		je	@@OK			; No, call driver
		call	ReadNumber		; Else read subfunction num.
		jc	@@Exit
		call	BCDW2Dec
		mov	@@DrvFunCtrl,ax

@@OK:		mov	eax,[rEAX]
		mov	ebx,[rEBX]
		mov	ecx,[rECX]
		mov	edx,[rEDX]
		mov	esi,[rESI]
		mov	edi,[rEDI]
		call	DRV_CallDriver
		pushfd
		pop	[rEFLAGS]
		mov	[rEAX],eax
		mov	[rEBX],ebx
		mov	[rECX],ecx
		mov	[rEDX],edx
		mov	[rESI],esi
		mov	[rEDI],edi
		pop	ebp
		clc
		ret
@@Err:		stc
@@Exit:		leave
		ret
endp		;---------------------------------------------------------------

ends
end