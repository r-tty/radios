
		; PrintDwordHex - print dword (EAX) in hex;
		; PrintWordHex - print word (AX) in hex;
		; PrintByteHex - print byte (AL) in hex.
		; PrintNibbleHex - print nibble (AL) in hex.
proc PrintDwordHex
		push	eax		; To print a dword
		shr	eax,16		; Print the high 16 bits
		call	PrintWordHex
		pop	eax		; And the low 16 bits
PrintWordHex:	push	eax		; To print a word
		mov	al,ah		; Print the high byte
		call	PrintByteHex
		pop	eax		; And the low byte
PrintByteHex:	push	eax		; To print a byte
		shr	eax,4		; Print the high nibble
		call	PrintNibbleHex
		pop	eax		; And the low nibble
PrintNibbleHex:	and	al,0Fh		; Get a nibble
		add	al,'0'		; Make it numeric
		cmp	al,'9'		; If supposed to be alphabetic
		jle	.Numeric
		add	al,7		; Add 7
.Numeric:	call	PrintChar
		ret
endp		;---------------------------------------------------------------
