;-------------------------------------------------------------------------------
;  enter.asm - handle hex data entry.
;-------------------------------------------------------------------------------


; --- Procedures ---

		; InputNumber - input function for a number
proc InputNumber near
		push	edx
		push	ecx
		push	ebx
		xor	ecx,ecx 			; Number of digits = 0
		xor	ebx,ebx				; Data = 0
@@Loop:		mCallDriver [DrvId_Con],DRVF_Read	; Get a char
		call	CharToUpper			; & make uppercase
		mov	ah,al				; AH = data
		cmp	al,13				; ENTER, data is complete
		je	@@CR
		cmp	al,'.'
		je	@@Quit				; '.' = quit entering
		cmp	al,8				; BACKSPACE handle it
		je	@@BS
		sub	al,'0'				; Convert to binary,
		jc	@@Loop				; ignore if not valid
		cmp	al,10
		jb	@@GotDigit
		sub	al,7
		cmp	al,10
		jc	@@Loop
		cmp	al,16
		jnc	@@Loop
@@GotDigit:	cmp	cl,2			; If got two digits don't accept
		je	@@Loop
		shl	bl,4			; Add in the digit
		or	bl,al			;
		mWrChar ah			; Echo the char
		inc	ecx			; Inc digit count
		jmp	@@Loop			; Next digit

@@BS:		or	ecx,ecx			; Get next digit
		jz	@@Loop			; if nothing in buffer
		mov	dl,8			; Erase echoed char
		mWrChar dl
		mWrChar	' '
		mov	dl,8			; Point at next echo space
		mWrChar	dl
		dec	ecx			; Dec digit count
		jmp	@@Loop

@@Quit:		or	ecx,ecx				; '.' - set ZF and quit
		stc
		jmp	@@Exit

@@CR:		or	ecx,ecx			; ENTER, clear ZF and quit
@@Exit:		pushfd
		mov	al,3			; Space to line up in columns
		sub	al,cl
		mov	cl,al

@@SpLoop:	mWrChar	' '
		loop	@@SpLoop
		popfd
		mov	eax,ebx			; AX = number input
		pop	ebx
		pop	ecx
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; MON_Enter - number entry with prompt.
proc MON_Enter near
		call	PageTrapErr		; Trap if no page
		call	WadeSpace		; Wade through commad spaces
		inc	esi			; Point at first non-space
		cmp	al,13			; Error if no address given
		je	@@Err
		dec	esi
		call	ReadAddress		; Read the address
		jc	@@Err			; Bad address ,error
		or	dx,dx			; Default to DS if null selector
		jnz	@@GotSel
		mov	dx,[rDS]
@@GotSel:	push	gs
		mov	eax,ABSDS			; Absolute segment
		mov	gs,eax
		mov	ecx,-1
		push	esi
		call	BaseAndLimit
		pop	edi
		xchg	esi,edi
		call	WadeSpace			; Wade through spaces
		cmp	al,13				; If no values specified
		je	@@Prompt			; Go do prompt version

@@ReadLoop:	call	ReadNumber			; Else read number off command line
		jc	@@Err2				; Quit if error
		mov	[gs:edi],al			; Save value
		inc	edi				; Point to next input pos
		call	WadeSpace			; Wade through spaces
		cmp	al,13				; Quit if CR
		je	@@OK
		jmp	@@ReadLoop			; Else get next value
@@Prompt:
		mWrChar NL
		mov	eax,edx				; Print segment
		call	PrintWordHex
		mWrChar ':'				; Print ':'
		mov	eax,ebx
		call	PrintDwordHex			; Print offset
@@Loop:		mWrChar	' '				; Space over two spaces
		mWrChar	' '
		mov	al,[gs:edi]			; Print current value
		call	PrintByteHex
		mWrChar '.'				; Print '.'
		push	ecx
		call	InputNumber			; Get a number
		pop	ecx
		jz	@@NextItem			; No number, go do next
		mov	[gs:edi],al			; Save value

@@NextItem:	jc	@@OK				; Quit if ENTER key
		dec	ecx				; Quit if end of segment
		jz	@@OK
		inc	edi				; Point at next value
		inc	ebx				; Next address
		test	ebx,7				; If address mod 7 = 0
		jz	@@Prompt			; Do another prompt
		jmp	@@Loop

@@OK:		pop	gs
		clc				; No errors
		jmp	short @@Done
@@Err2:		pop	gs
@@Err:          stc     			; Errors
@@Done:		pushfd				; Restore user page trap
		call	PageTrapUnerr
		popfd
		ret
endp		;---------------------------------------------------------------
