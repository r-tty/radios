;-------------------------------------------------------------------------------
; cons.nasm - basic console routines.
;-------------------------------------------------------------------------------

; --- Exports ---

global PrintChar, PrintCharRaw, PrintString
global PrintByteDec, PrintWordDec, PrintDwordDec
global PrintByteHex, PrintWordHex, PrintDwordHex
global ReadChar, ReadString
global K_PopUp


; --- Code ---

section .text

		; PrintCharRaw - print a character in "raw" mode.
		; Input: AL=character.
		; Note: cursor moves as usual.
proc PrintCharRaw
		mServPrintCharRaw
		ret
endp		;---------------------------------------------------------------


		; PrintChar - print a character in TTY mode.
		; Input: AL=character code.
proc PrintChar
		mServPrintChar
		ret
endp		;---------------------------------------------------------------


		; PrintString - print an ASCIIZ string.
		; Input: ESI=string address.
		; Output: none.
proc PrintString
		mServPrintStr
		ret
endp		;---------------------------------------------------------------


		; PrintByteDec - print byte in decimal form.
		; Input: AL=byte.
		; Output: none.
proc PrintByteDec
		mpush	eax
		movzx	eax,al
		mServPrintDec
		mpop	eax
		ret
endp		;---------------------------------------------------------------


		; PrintWordDec - print word in decimal form.
		; Input: AX=word.
		; Output: none.
proc PrintWordDec
		mpush	eax
		movzx	eax,ax
		mServPrintDec
		mpop	eax
		ret
endp		;---------------------------------------------------------------


		; PrintDwordDec - print dword in decimal.
		; Input: EAX=dword.
		; Output: none.
proc PrintDwordDec
		mServPrintDec
		ret
endp		;---------------------------------------------------------------


		; PrintByteHex - print byte in hexadecimal form.
		; Input: AL=byte.
		; Output: none.
proc PrintByteHex
		mServPrint8h
		ret
endp		;---------------------------------------------------------------


		; PrintWordHex - print word in hexadecimal form.
		; Input: AX=word.
		; Output: none.
proc PrintWordHex
		mServPrint16h
		ret
endp		;---------------------------------------------------------------


		; PrintDwordHex - print double word in hexadecimal form.
		; Input: EAX=dword.
		; Output: none.
proc PrintDwordHex
		mServPrint32h
		ret
endp		;---------------------------------------------------------------


		; ReadChar - read a character from kernel console.
		; Input: none:
		; Output: AL=character.
proc ReadChar
		mServReadKey
		ret
endp		;---------------------------------------------------------------


		; ReadString - read string from kernel console in buffer.
		; Input: ESI=buffer address,
		;	 CL=maximum string length.
		; Output: CL=number of read characters.
		; Note: destroys CH and high word of ECX.
proc ReadString
		prologue 0
		movzx	ecx,cl			; Allocate memory
		sub	esp,ecx			; for local buffer

		mpush	eax,esi,edi

		mov	edi,ebp
		sub	edi,ecx
		push	edi			; EDI=local buffer address
		push	ecx
		cld
		rep	movsb
		pop	ecx
		pop	edi
		mov	esi,edi			; ESI=EDI=local buffer address

.ReadKey:	call	ReadChar
		or	al,al
		jz	.FuncKey
		cmp	al,ASC_BS
		je	.BS
		cmp	al,ASC_CR
		je	.Done
		cmp	al,' '			; Another ASCII CTRL?
		jb	.ReadKey		; Yes, ignore it.
		cmp	edi,ebp			; Buffer full?
		je	.ReadKey		; Yes, ignore it.
		mov	[edi],al		; Store read character
		inc	edi
		call	PrintChar
		jmp	.ReadKey

.FuncKey:	jmp	.ReadKey

.BS:		cmp	edi,esi
		je	.ReadKey
		dec	edi
		call	PrintChar
		jmp	.ReadKey

.Done:		mov	ecx,edi
		sub	ecx,esi
		mov	edi,[esp+4]		; EDI=target buffer address
		push	ecx			; ECX=number of read characters
		cld
		rep	movsb
		pop	ecx

		mpop	edi,esi,eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; K_PopUp - draw a "pop-up" window on system console and wait
		;	    until a key will be pressed.
		; Input: ESI=address to string with message.
		; Output: none.
		; Note: the string must be in such form:
		;	   ":TITLE:procedure_name:message"
proc K_PopUp
		ret
endp		;---------------------------------------------------------------
