;-------------------------------------------------------------------------------
;  regs.asm - display/modify registers routines
;-------------------------------------------------------------------------------

; --- Data ---
segment KVARS
; Registers image
rEFLAGS		DD	0
rEAX		DD	0
rEBX		DD	0
rECX		DD	0
rEDX		DD	0
rESI		DD	0
rEDI		DD	0
rEBP		DD	0
rESP		DD	0
rEIP            DD	0
rCS		DW	0
rDS		DW	0
rES		DW	0
rSS		DW	0
rFS		DW	0
rGS		DW	0

rtoss		DD	0
sstoss		DD	0
ends

segment KDATA
; List corresponding ASCII names for general purpose registers
; with the address the value can be found at
pEAX		DD	rEAX
		DB	NL,"eax:",0
pEBX		DD	rEBX
		DB	"ebx:",0
pECX		DD	rECX
		DB	"ecx:",0
pEDX		DD	rEDX
		DB	"edx:",0
pESI		DD	rESI
		DB	"esi:",0
pEDI		DD	rEDI
		DB	"edi:",0
pEBP		DD	rEBP
		DB	10,"ebp:",0
pESP		DD	rESP
		DB	"esp:",0
pEIP		DD	rEIP
		DB	"eip:",0
		DD	0

; List corresponding ASCII names for segment registers with
; the address the value can be found at
pDS		DD	rDS
		DB	10,"ds: ",0
pES		DD	rES
		DB	"es:",0
pFS		DD	rFS
		DB	"fs:",0
pGS		DD	rGS
		DB	"gs:",0
pSS		DD	rSS
		DB	"ss:",0
pCS		DD	rCS
		DB	"cs:",0
		DD	0

pEFLAGS		DD	rEFLAGS
		DB	"eflags:",0

FlagChars	DB	"ODITSZ-A-P-C"
ends


; --- Procedures ---

		; MON_Registers - handle 'r' command (display/modify registers).
		; Input: ESI=monitor input line pointer.
		; Output: CF=0 - OK,
		;	  CF=1 - error.
proc MON_Registers near
		call	WadeSpace		; Wade through spaces
		cmp	al,13			; If CR
		je	DisplayRegisters	; Display registers
		push	esi
		xor	ecx,ecx			; Point at text-1
		dec	ecx			; Default count at -1
		dec	esi
@@Loop:		inc	esi 			; Next text
		inc	ecx			; Next count
		mov	al,[esi]		; Get char
		cmp	al,13			; IF CR or space
		je	short @@GotEnd
		cmp	al,' '
		jne	@@Loop

@@GotEnd:	pop	esi			; Then we have the length of reg name
		cmp	cl,2			; If 2
		jne	@@Check3
		mov	ebx,offset pDS		; Read in a segment reg
		call	ReadReg
		jmp	short @@Exit		; End
@@Check3:	cmp	cl,3			; If not 3
		jne	@@Err			; Bad reg name
		mov	ebx,offset pEAX		; Read in a general purpose reg
		call	ReadReg
		jmp	short @@Exit
@@Err:		stc				; Error
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DisplayRegisters - Display the processor registers.
proc DisplayRegisters near
		mov	esi,offset pEAX		; Print GP regs
		mov	edx,offset PutDword	; with the DWORD function
		call	PrintAFew		; Print them
		mov	esi,offset pEFLAGS	; Put the flags
		call	PutDword
		mWrChar ' '
		mov	ebx,[rEFLAGS]		; Print flags in char. form
		shl	bx,4
		mov	esi,offset FlagChars
		mov	cl,12
@@Loop:		shl	bx,1
		jnc	short @@Space
		mov	al,[esi]
		jmp	short @@Print
@@Space:	mov	al,'-'
@@Print:	call	WriteChar
		inc	esi
		dec	cl
		jnz	@@Loop
		IFNDEF USER
		 mov	esi,offset pDS		; Now put the segs
		 mov	edx,offset PutWord
		 call	PrintAFew
		ENDIF
		mov	ebx,[rEIP]		; Dissassemble
		movzx	edx,[rCS]		; at current code pointer
		call	DisOneLine
		clc
		ret
endp		;---------------------------------------------------------------


		; ReadReg - read register value.
proc ReadReg near
		push	es
		push	ds
		pop	es
@@2:		mov	edi,ebx			; Point at list
		test	[dword edi],-1		; See if found trailer
		jz	@@NotFound		; Quit if so
		add	edi,4			; Skip past value
		cmp	[byte edi],10		; Skip past line feed, if exists
		jnz	@@NotLF			;
		inc	edi
@@NotLF:	push	ecx			; Compare specified reg name to list
		push	esi
		repe	cmpsb
		pop	esi
		pop	ecx
		jz	short @@Got		; Got it
		add	ebx,4			; Else skip past value
@@Wade:		inc	ebx			; Skip past name
		test	[byte ebx-1],-1
		jnz	@@Wade
		jmp	@@2			; Check next name
@@Got:		add	esi,ecx         	; Point after reg name
		call	WadeSpace		; Wade through spaces
		cmp	al,13			; Don't prompt if input is here
		jne	@@GotInput
		push	ecx
		mWrString RegPrompt
		mov	esi,offset InputBuffer
		mov	cl,8
		call	ReadString		; Get input line
		movzx	ecx,cl
		mov	[byte esi+ecx],13
		pop	ecx
		call	WadeSpace		; Ignore spaces
		cmp	al,13			; See if CR
		je	@@Exit			; Quit if so
@@GotInput:	mov	ebx,[ebx]		; Get pointer to addres
		call	ReadNumber		; Read number
		jc	short @@NotFound	; Error if bad number
		cmp	cl,2			; Check if is segment reg
		je	short @@Word		; Yes, go verify it
		mov	[ebx],eax		; Else just save offset
		jmp	short @@Exit
@@Word:		call	VerifySelector		; Verify selector
		jc	short @@NotFound	; Quit if error
		mov	[ebx],ax		; Save segment
@@Exit:		clc				; Get out no errors
		pop	es
		ret
@@NotFound:	stc				; Get out, errors
		pop	es
		ret
endp		;---------------------------------------------------------------


		; PutDword - print a general purpose reg and it's value.
proc PutDword near
		lodsd			; Get pointer to val
		mov	eax,[eax]	; Get val
		push	eax		;
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		pop	eax
		call	PrintDwordHex	; Print value
		mWrChar ' '
		ret
endp		;---------------------------------------------------------------


		; PutWord - print a segment reg and its value.
proc PutWord near
		lodsd			; Get pointer to value
		mov	ax,[eax]	; Get value
		push	eax		;
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		pop	eax		;
		call	PrintWordHex	; Print value
		mWrChar ' '
		ret
endp		;---------------------------------------------------------------


		; PrintAFew - print either the GP regs or the SEG regs.
proc PrintAFew near
		call	edx		; Call the print routine
@@Loop: 	lodsb			; Wade past the text
		or	al,al
		jnz	@@Loop
		test	[dword esi],-1	; See if trailer found
		jnz	PrintAFew	; Go print another
		ret
endp		;---------------------------------------------------------------
