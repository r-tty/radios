
; Offsets in BIOS data area.
%define	BDA_BaseMemSz	413h
%define	BDA_VidMode	449h
%define	BDA_VidPgOfs	44Eh
%define BDA_ActVidPage	462h
%define BDA_CurCol	450h
%define BDA_CurRow	451h

; Macro to set column position for printing.
%macro mSetPrintPos 1
	mov	[BDA_CurCol],al
%endmacro


; --- Data ---

section .data

Color		DB	15				; Foreground color

FunctionTable	DD	PrintChar			; Service entries
		DD	PrintStr
		DD	PrintDwordHex
		DD	PrintWordHex
		DD	PrintByteHex


; --- Code ---

section .text

		; GetVidMemAddr - get begin address of first video page.
		; Input: none.
		; Output: EBX=address.
proc GetVidMemAddr
		movzx	ebx,word [BDA_VidPgOfs]		; EBX=Video page offset
		cmp	byte [BDA_VidMode],7		; Monochrome mode?
		je	short .Mono
		add	ebx,0B8000h
		ret
.Mono		add	ebx,0B0000h
		ret
endp		;---------------------------------------------------------------


		; PrintChar - print character (direct in video memory).
		; Input: AL=character.
proc PrintChar
		mpush	ebx,ecx,esi
		mov	cl,al
		call	GetVidMemAddr
		movzx	esi,byte [BDA_ActVidPage]	; SI=active video page
		shl	esi,1
		cmp	cl,0Ah
		jne	short .ChkTab
		call	.LF
		jmp	short .Done
.ChkTab:	cmp	cl,9				; TAB?
		je	short .TAB
		xor	eax,eax
		mov	al,[esi+BDA_CurCol]		; AL=cursor column
		cmp	al,80
		jb	short .NoLF
		call	.LF
.NoLF		shl	al,1
		add	ebx,eax
		mov	al,[esi+BDA_CurRow]		; AL=cursor row
		shl	eax,byte 5
		lea	eax,[eax*4+eax]			; Row*=160
		add	ebx,eax
		mov	ch,[Color]			; White color
		mov	[ebx],cx
		inc	byte [esi+BDA_CurCol]
.Done:		mpop	esi,ecx,ebx
		ret
		
.TAB:		mov	al,[esi+BDA_CurCol]
		shr	al,3
		inc	al
		shl	al,3
		inc	al
		mov	[esi+BDA_CurCol],al
		jmp	.Done
		
.LF:		xor	al,al
		mov	[esi+BDA_CurCol],al
		cmp	byte [esi+BDA_CurRow],24
		jne	short .NoScroll
		call	Scroll
		ret
.NoScroll:	inc	byte [esi+BDA_CurRow]
		ret
endp		;---------------------------------------------------------------


		; PrintStr - print ASCIIZ string.
		; Input: ESI=pointer to string.
proc PrintStr
		push	esi
		cld
.Loop:		lodsb
		or	al,al
		jz	.Done
		call	PrintChar
		jmp	.Loop
.Done:		pop	esi
		ret
endp		;---------------------------------------------------------------


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


		; Scroll - scroll screen one line up.
proc Scroll
		mpush	ebx,ecx,esi,edi
		call	GetVidMemAddr
		add	bx,[44Eh]
		mov	edi,ebx
		lea	esi,[ebx+160]
		mov	ecx,960
		cld
		rep	movsd
		mov	ecx,40
		mov	eax,07000700h
		rep	stosd
		mpop	edi,esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; ServiceEntry - entry used for kernel debugging.
		; Input: function code must be on the stack.
		;	 Arguments passed in the registers as usual.
		; Output: function results.
proc ServiceEntry
		push	ebp
		mov	ebp,esp
		push	dword .Done			; Return address
		push	eax
		mov	eax,[ebp+8]
		mov	eax,[FunctionTable+eax*4]
		xchg	eax,[esp]
		ret					; Call routine
.Done:		leave
		ret
endp		;---------------------------------------------------------------
