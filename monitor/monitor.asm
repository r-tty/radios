;*******************************************************************************
;  monitor.asm - RadiOS kernel monitor/debugger.
;  Ported from David Lindauer's OS-32 by Yuri Zaporogets.
;*******************************************************************************

.386
ideal

include "monitor.ah"

segment RADIOSKRNLSEG public 'code' use32
assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG

; --- Publics ---
                public MonitorEntry

; --- Definitions ---
DUMPLEN		EQU	80h


; --- Data ---
MonPrompt	DB NL,"* ",0

DumpIndex	DD	0
DumpIndexSeg	DW	0


; --- Variables ---
InpStrBuffer	DB MonStrBufSize dup (0)        ; Input string buffer

rEFLAGS		DD	0                       ; Registers image
rEAX		DD	0
rEBX		DD	0
rECX		DD	0
rEDX		DD	0
rESI		DD	0
rEDI		DD	0
rEBP		DD	0
rESP		DD	0
rEIP            DD	0
rtoss		DD	0
sstoss		DD	0
rCS		DW	0
rDS		DW	0
rES		DW	0
rSS		DW	0
rFS		DW	0
rGS		DW	0


; --- Procedures ---

include "commands.asm"
include "except.asm"

                ; MonitorEntry - monitor entry point.
                ; Action: call debugger.
proc MonitorEntry near

	pushad
	mov [rDS],16

@@WaitCmd:	mWrString MonPrompt

		mov	esi,offset InpStrBuffer
		mov	cl,MonStrBufSize-1
		call	K_ReadString			; Read command line
		or	cl,cl
		jz	@@WaitCmd
		movzx	ecx,cl				; Put CR at end of line
		mov	[byte esi+ecx],ASC_CR
		call	WadeSpace
		inc	esi

		cmp	al,'q'
		je	@@Exit
		push	offset @@WaitCmd		; Prepare to run command
		cmp     al,'d'
		je      MON_Dump			; Display dump
		cmp     al,'r'
		je      MON_Registers			; View/modify registers
                cmp     al,'e'
		je      MON_Enter			; Modify bytes
                cmp     al,'u'
		je      MON_Disassembly			; Disassembly

		add     esp,4				; Restore stack
		jmp     @@WaitCmd			; if no command

@@Exit:	popad
		ret
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
		cmp	ax,56				; Error if beyod GDT
		jae	@@Err
		call	K_DescriptorAddress
		call	K_GetDescriptorAR		; Get descriptor ARs
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
		pop	eax
		ret
@@Err:		stc					; Bad descriptor
		pop	eax
		ret
endp		;---------------------------------------------------------------



; Additional procedures

		; WadeSpace - wade spaces and tabs in command line.
		; Input: ESI=pointer to command line.
		; Output: ESI=pointer to last space or tab character.
proc WadeSpace near
@@Wade:		lodsb
		cmp     al,' '
		jz      short @@Wade
		cmp     al,9
		jz      short @@Wade
		dec     esi
		ret
endp		;---------------------------------------------------------------


                ; ReadNumber - get number from command line.
proc ReadNumber near
		push    ebx
		xor     ebx,ebx			; Number = 0
		push    ecx
		push    edx
		xor     ecx,ecx			; digits = 0

@@Loop:		lodsb				; Get character
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
	        jz	@@GotSel
	        cmp	ax,"se"
		mov     dx,[rES]
		jz	@@GotSel
		cmp	ax,"sf"
		mov	dx,[rFS]
		jz	@@GotSel
		cmp	ax,"sg"
		mov	dx,[rGS]
		jz	@@GotSel
		cmp	ax,"ss"
		mov	dx,[rSS]
		jz	@@GotSel
		cmp	ax,"sc"
		mov	dx,[rCS]
		jz	@@GotSel
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

@@GetAddr:	inc	esi			; Point past ':'
		call	ReadNumber		; Read in offset
		jc	@@Err			; Quit if error
		mov	ebx,eax

@@OK:		clc                             ; OK, exit
		ret

@@GotSel:	cmp	[byte esi],':'		; Make sure is a selector
		jne	@@Err			; Error if not
		mov     eax,edx			; Verify it
		call	VerifySelector
		jc	@@Err			; Error if non-existant
		jmp	@@GetAddr		; Go get offset
@@Err:		stc
		ret
endp		;---------------------------------------------------------------


ends
end