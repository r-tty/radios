;-------------------------------------------------------------------------------
; util.nasm - miscellaneous routines (conversion, etc)
;-------------------------------------------------------------------------------

; --- Exports ---

global HexB2Str, HexW2Str
global HexD2Str, DecD2Str
global ValByteDec, ValDwordDec, ValDwordHex
global CharToUpper, CharToLower


; --- Procedures ---

section .text

		; HexD2Str - convert dword (EAX) to string in hex;
		; HexW2Str - convert word (AX) to string in hex;
		; HexB2Str - convert byte (AL) to string in hex.
		; HexN2Str - convert nibble (AL) to string in hex.
		; Note: string address in ESI;
		;	returns pointer to last character+1 (ESI).
proc HexD2Str
		push	eax		; To print a dword
		shr	eax,16		; Print the high 16 bits
		call	HexW2Str
		pop	eax		; And the low 16 bits
HexW2Str:	push	eax		; To print a word
		mov	al,ah		; Print the high byte
		call	HexB2Str
		pop	eax		; And the low byte
HexB2Str:	push	eax		; To print a byte
		shr	eax,4		; Print the high nibble
		call	HexN2Str
		pop	eax		; And the low nibble
HexN2Str:	and	al,0Fh		; Get a nibble
		add	al,'0'		; Make it numeric
		cmp	al,'9'		; If supposed to be alphabetic
		jle	.Numeric
		add	al,7		; Add 7
.Numeric:	mov	[esi],al
		inc	esi
		ret
endp		;---------------------------------------------------------------


		; DecD2Str - convert dword to string in decimal.
		; Input: EAX=dword,
		;	 ESI=buffer address.
		; Output: none.
proc DecD2Str
		mpush	ebx,ecx,edx,esi,edi
		mov	edi,esi
		mov	ebx,10
		xor	ecx,ecx
		
		; First, get reversed string
.DivLoop:	xor	edx,edx	
		div	ebx
		add	dl,'0'
		mov	[esi],dl
		inc	esi
		inc	ecx
		or	eax,eax
		jnz	.DivLoop
		mov	[esi],al			; Trailing NULL
		shr	ecx,1
		
		; And reverse it back
.Reverse:	dec	esi
		mov	al,[esi]
		xchg	al,[edi]
		inc	edi
		loop	.Reverse
		mpop	edi,esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; CharToUpper - convert character to upper case.
		; Input: AL=character code.
		; Output: AL=converted code.
proc CharToUpper
		cmp	al,'a'
		jb	.Exit
		cmp	al,'z'
		ja	.Exit
		sub	al,20h
.Exit:		ret
endp		;---------------------------------------------------------------


		; CharToLower - convert character to lower case.
		; Input: AL=character code.
		; Output: AL=converted code.
proc CharToLower
		cmp	al,'A'
		jb	.Exit
		cmp	al,'Z'
		ja	.Exit
		add	al,20h
.Exit:		ret
endp		;---------------------------------------------------------------


		; ValByteDec - convert string to byte (decimal).
		; Input: ESI=pointer to string.
		; Output: CF=0 - OK, AL=byte.
		;	  CF=1 - error.
proc ValByteDec
		mpush	ecx,edx,edi
		mov	edi,esi
		call	StrLen
		cmp	ecx,4
		cmc
		jc	short .Exit
		add	edi,ecx
		xor	eax,eax
		xor	edx,edx
		inc	dl

.Loop:		dec	edi
		mov	al,[edi]
		cmp	al,'0'
		jc	short .Exit
		cmp	al,'9'+1
		cmc
		jc	short .Exit
		sub	al,'0'
		mul	dl
		cmp	ax,100h				; Overflow?
		cmc
		jc	short .Exit
		add	ch,al
		lea	edx,[edx*4+edx]			; EDX*=10
		shl	edx,1
		dec	cl
		jnz	.Loop

.OK:		mov	al,ch
		clc
.Exit:		mpop	edi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; ValDwordDec - convert string to dword (decimal).
		; Input: ESI=pointer to string.
		; Output: CF=0 - OK, EAX=result;
		;	  CF=1 - error.
proc ValDwordDec
		mpush	ebx,ecx,edx,esi,edi
		mov	edi,esi
		call	StrLen
		cmp	ecx,11
		cmc
		jc	short .Exit
		add	esi,ecx
		xor	eax,eax
		xor	ebx,ebx
		xor	edi,edi
		inc	edi

.Loop:		dec	esi
		mov	al,[esi]
		cmp	al,'0'
		jc	short .Exit
		cmp	al,'9'+1
		cmc
		jc	short .Exit
		sub	al,'0'
		and	eax,15
		mul	edi
		add	ebx,eax
		lea	edi,[edi*4+edi]			; EDX*=10
		shl	edi,1
		dec	cl
		jnz	.Loop

.OK:		mov	eax,ebx
		clc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; ValDwordHex - convert string to dword (hex).
		; Input: ESI=pointer to string.
		; Output: CF=0 - OK, EAX=result;
		;	  CF=1 - error.
proc ValDwordHex
		mpush	ecx,edx,edi
		mov	edi,esi
		call	StrLen
		cmp	ecx,9
		cmc
		jc	short .Exit
		add	edi,ecx
		xor	eax,eax
		xor	edx,edx
		xchg	ch,cl

.Loop:		dec	edi
		mov	al,[edi]
		cmp	al,'0'
		jc	short .Exit
		cmp	al,'9'+1
		jae	short .ChkLetter
		sub	al,'0'
		jmp	short .1

.ChkLetter:	or	al,20h				; Make lowercase
		cmp	al,'a'
		jc	short .Exit
		cmp	al,'g'
		cmc
		jc	short .Exit
		sub	al,'a'-10

.1:		and	eax,15
		shl	eax,cl
		add	edx,eax
		add	cl,4
		dec	ch
		jnz	.Loop

.OK:		mov	eax,edx
		clc
.Exit:		mpop	edi,edx,ecx
		ret
endp		;---------------------------------------------------------------
