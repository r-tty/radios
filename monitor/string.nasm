;-------------------------------------------------------------------------------
; string.nasm - ASCIIZ string manipulation routines.
;-------------------------------------------------------------------------------

; --- Exports ---

global StrLen, StrEnd, StrMove, StrCopy, StrAppend
global StrComp, StrLComp, StrLIComp
global StrScan, StrRScan, StrPos
global StrLower, StrUpper

section .text

		; StrLen - count length of string (without NULL-terminator).
		; Input: EDI=pointer to string.
		; Output: ECX=length of string.
proc StrLen
		mpush	eax,edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		mov	eax,-2
		sub	eax,ecx
		mov	ecx,eax
		mpop	edi,eax
		ret
endp		;---------------------------------------------------------------


		; StrEnd - return pointer to NULL-terminator of string.
		; Input: EDI=pointer to string.
		; Output: EDI=pointer to NULL-terminator.
proc StrEnd
		mpush	eax,ecx
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		dec	edi
		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; StrMove - copy exactly ECX chars from one string to another.
		; Input: ESI=pointer to source string,
		;	 EDI=pointer to destination string,
		;	 ECX=number of chars.
		; Output: none.
		; Note: strings may overlap.
proc StrMove
		mpush	ecx,esi,edi
		cld
		cmp	esi,edi
		jae	.Do
		std
		add	esi,ecx
		add	edi,ecx
		dec	edi
		dec	esi
.Do:		rep	movsb
		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; StrCopy - copy one string to another.
		; Input: ESI=pointer to source string,
		;	 EDI=pointer to destination string.
		; Output: none.
proc StrCopy
		mpush	eax,ecx,esi,edi
		mov	edi,esi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		not	ecx
		pop	edi
		push	edi
		rep	movsb
		mpop	edi,esi,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; StrAppend - append a copy of source string to the end of
		;	      destination.
		; Input: ESI=pointer to source string,
		;	 EDI=pointer to destination string.
		; Output: none.
proc StrAppend
		push	edi
		call	StrEnd
		call	StrCopy
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; StrComp - compare one string to another.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2.
		; Output: AL=0 - string1=string2,
		;	  AL<1 - string1<string2,
		;	  AL>1 - string1>string2.
proc StrComp
		mpush	ecx,esi,edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		not	ecx
		pop	edi
		push	edi
		repe	cmpsb
		mov	al,[esi-1]
		sub	al,[edi-1]
		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; StrLComp - compare first ECX chars of strings.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2,
		;	 ECX=number of chars to compare.
		; Output: AL=0 - string1=string2,
		;	  AL<1 - string1<string2,
		;	  AL>1 - string1>string2.
proc StrLComp
		or	ecx,ecx
		jz	.Exit
		mpush	ebx,ecx,esi,edi
		mov	ebx,ecx
		xor	al,al
		cld
		repnz	scasb
		sub	ebx,ecx
		mov	ecx,ebx
		pop	edi
		push	edi
		repe	cmpsb
		mov	al,[esi-1]
		sub	al,[edi-1]
		mpop	edi,esi,ecx,ebx
.Exit:		ret
endp		;---------------------------------------------------------------


		; StrLIComp - compare first ECX chars of strings without case
		;	      sensitivity.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2,
		;	 ECX=number of chars to compare.
		; Output: AL=0 - string1=string2,
		;	  AL<1 - string1<string2,
		;	  AL>1 - string1>string2.
proc StrLIComp
		or	ecx,ecx
		jz	.Exit
		mpush	ebx,ecx,esi,edi
		mov	ebx,ecx
		xor	al,al
		cld
		repnz	scasb
		sub	ebx,ecx
		mov	ecx,ebx
		pop	edi
		push	edi
.Loop:		repe	cmpsb
		je	.Exit
		mov	al,[esi-1]
		cmp	al,'a'
		jb	.1
		cmp	al,'z'
		ja	.1
		sub	al,20h
.1:		mov	bl,[edi-1]
		cmp	bl,'a'
		jb	.2
		cmp	bl,'z'
		ja	.2
		sub	bl,20h
.2:		sub	al,bl
		jz	.Loop
		mpop	edi,esi,ecx,ebx
.Exit:		ret
endp		;---------------------------------------------------------------


		; StrScan - search first occurence of char in string.
		; Input: EDI=pointer to string,
		;	 AL=char to search.
		; Output: EDI=pointer to first occurrence of char in string
		;	  or 0, if char doesn't occur.
proc StrScan
		mpush	ecx,esi
		push	eax
		mov	esi,edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		not	ecx
		mov	edi,esi
		pop	eax
		repne	scasb
		jne	.NotFound
		dec	edi
		jmp	short .OK
.NotFound:	xor	edi,edi
.OK:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; StrRScan - search last occurence of char in string.
		; Input: EDI=pointer to string,
		;	 AL=char to search.
		; Output: EDI=pointer to last occurrence of char in string
		;	  or 0, if char doesn't occur.
proc StrRScan
		mpush	ecx,eax
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		not	ecx
		dec	edi
		pop	eax
		std
		repne	scasb
		je	.OK
		xor	edi,edi
.OK:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; StrPos - search first occurence of string1 in string2.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2.
		; Output: EDI=pointer to first occurrence of string1
		;	  in string2 or 0, if string2 doesn't occur.
proc StrPos
		mpush	eax,ebx,ecx,edx,esi
		mov	ebx,edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scasb
		not	ecx
		dec	ecx
		jz	.NotOccur
		mov	edx,ecx
		mov	edi,esi
		push	edi
		mov	ecx,-1
		repnz	scasb
		pop	edi
		not	ecx
		sub	ecx,edx
		jbe	.NotOccur
.Search:	mov	esi,ebx
		lodsb
		repne	scasb
		jne	.NotOccur
		mov	eax,ecx
		push	edi
		mov	ecx,edx
		dec	ecx
		repe	cmpsb
		pop	edi
		mov	ecx,eax
		jne	.Search
		dec	edi
		jmp	short .OK
.NotOccur:	xor	edi,edi
.OK:		mpop	esi,edx,ecx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; StrLower - convert string to lower case.
		; Input: EDI=pointer to string
		; Output: none.
proc StrLower
		push	eax
		push	edi
.Loop:		mov	al,[edi]
		inc	edi
		or	al,al
		jz	.OK
		cmp	al,'A'
		jb	.Loop
		cmp	al,'Z'
		ja	.Loop
		add	al,20h
		mov	[edi-1],al
		jmp	.Loop
.OK:		pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; StrUpper - convert string to upper case.
		; Input: EDI=pointer to string
		; Output: none.
proc StrUpper
		push	eax
		push	edi
.Loop:		mov	al,[edi]
		inc	edi
		or	al,al
		jz	.OK
		cmp	al,'a'
		jb	.Loop
		cmp	al,'z'
		ja	.Loop
		sub	al,20h
		mov	[edi-1],al
		jmp	.Loop
.OK:		pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------
