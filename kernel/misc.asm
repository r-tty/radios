;-------------------------------------------------------------------------------
;  misc.asm - miscellaneous kernel procedures.
;-------------------------------------------------------------------------------

; ============================ Delay procedures ================================

		; K_TTDelay - kernel delay (using timer ticks counter).
		; Input: ECX=number of quantum of times in delay.
		; Output: none.
proc K_TTDelay near
		push	eax
		push	ecx
		mov	eax,[TimerTicksLo]
		lea	ecx,[eax+ecx]
TDel_Loop:	mov	eax,[TimerTicksLo]
		cmp	eax,ecx
		jb	TDel_Loop
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_LDelay - kernel delay (using LOOP).
		; Input: ECX=number of repeats in loop.
		; Output: none.
		; Note: uses CPUspeed variable.
proc K_LDelay near
		push	eax
		push	ecx
		push	edx
		xor	edx,edx
		mov	eax,[CPUspeed]
		mul	ecx
		mov	ecx,eax
LDel:		loop	LDel
		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


; =================== Dec/hex write and convert procedures =====================

		; K_WrDecD - write decimal dword.
		; Input: EAX=dword,
		;	 EDI=address of "Write char" procedure
		; Output: none.
proc K_WrDecD near
		push	eax
		push	ebx
		push	ecx
		push	edx
		mov	ebx,1000000000
		xor	cl,cl
		or	eax,eax
		jnz	@@Loop
		mov	al,'0'
                call	edi
                jmp	@@Exit

@@Loop:		xor	edx,edx
		div	ebx
		or	al,al
		jnz	@@NZ
		or	cl,cl
		jz	@@Z

@@NZ:		mov	cl,1
		add	al,48
		call	edi
@@Z:		mov	eax,edx
                xor	edx,edx
                push	eax
                mov	eax,ebx
                mov	ebx,10
                div	ebx
                mov	ebx,eax
                pop	eax
                or	ebx,ebx
                jnz	@@Loop

@@Exit:		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_WrHexB - write byte in hex.
		; Input: AL=byte,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrHexB near
		push	eax
		mov	ah,al
		shr	al,4
		call	@@1
		mov	al,ah
		call	@@1
		pop	eax
		ret

@@1:		and	al,0Fh
		cmp	al,0Ah
		jb	@@2
		add	al,7
@@2:		add	al,30h
		call	edi
		retn
endp		;---------------------------------------------------------------


		; K_WrHexW - write word in hex.
		; Input: AX=word,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrHexW near
		ror	ax,8
		call	K_WrHexB
		ror	ax,8
		call	K_WrHexB
		ret
endp		;---------------------------------------------------------------


		; K_WrHexD - write double word in hex.
		; Input: EAX=dword,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrHexD near
		ror	eax,16
		call	K_WrHexW
		ror	eax,16
		call	K_WrHexW
		ret
endp		;---------------------------------------------------------------


		; K_HexW2Str - convert word to string in hex.
		; Input: AX=word,
		;	 EDI=buffer address.
		; Output: none.
proc K_HexW2Str near
                push	esi
		push	edi
		mov	esi,edi
		mov	edi,offset Dig2StrProc
		call	K_WrHexW
		mov	[byte esi],0
		pop	edi
		pop	esi
		ret
Dig2StrProc:	mov	[byte esi],al
		inc	esi
		retn
endp		;---------------------------------------------------------------


		; K_DecD2Str - convert dword to string in decimal.
		; Input: EAX=dword,
		;	 EDI=buffer address.
		; Output: none.
proc K_DecD2Str near
                push	esi
		push	edi
		mov	esi,edi
		mov	edi,offset Dig2StrProc
		call	K_WrDecD
		mov	[byte esi],0
		pop	edi
		pop	esi
		ret
endp		;---------------------------------------------------------------


; ========================= ASCIIZ strings procedures ==========================

		; StrLen - count length of string (without NULL-terminator).
		; Input: EDI=pointer to string.
		; Output: ECX=length of string.
proc StrLen near
		push	eax
		push	edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		mov	eax,-2
		sub	eax,ecx
		mov	ecx,eax
		pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; StrEnd - return pointer to NULL-terminator of string.
		; Input: EDI=pointer to string.
		; Output: EDI=pointer to NULL-terminator.
proc StrEnd near
		push	eax
		push	ecx
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		dec	edi
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; StrMove - copy exactly ECX chars from one string to another.
		; Input: ESI=pointer to source string,
		;	 EDI=pointer to destination string,
		;	 ECX=number of chars.
		; Output: none.
		; Note: strings may overlap.
proc StrMove near
		push	ecx
		push	esi
		push	edi
		cld
		cmp	esi,edi
		jae	@@Do
		std
		add	esi,ecx
		add	edi,ecx
		dec	edi
		dec	esi
@@Do:		rep	movs [byte edi],[byte esi]
		pop	edi
		pop	esi
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; StrCopy - copy one string to another.
		; Input: ESI=pointer to source string,
		;	 EDI=pointer to destination string.
		; Output: none.
proc StrCopy near
		push	eax
		push	ecx
		push	esi
		push	edi
		mov	edi,esi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		not	ecx
		pop	edi
		push	edi
		rep	movs [byte edi],[byte esi]
		pop	edi
		pop	esi
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; StrAppend - append a copy of source string to the end of
		;	      destination.
		; Input: ESI=pointer to source string,
		;	 EDI=pointer to destination string.
		; Output: none.
proc StrAppend near
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
proc StrComp near
		push	ecx
		push	esi
		push	edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		not	ecx
		pop	edi
		push	edi
		repe	cmps [byte edi],[byte esi]
		mov	al,[esi-1]
		sub	al,[edi-1]
		pop	edi
		pop	esi
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; StrLComp - compare first ECX chars of strings.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2,
		;	 ECX=number of chars to compare.
		; Output: AL=0 - string1=string2,
		;	  AL<1 - string1<string2,
		;	  AL>1 - string1>string2.
proc StrLComp near
		or	ecx,ecx
		jz	@@Exit
		push	ebx
		push	ecx
		push	esi
		push	edi
		mov	ebx,ecx
		xor	al,al
		cld
		repnz	scas [byte edi]
		sub	ebx,ecx
		mov	ecx,ebx
		pop	edi
		push	edi
		repe	cmps [byte edi],[byte esi]
		mov	al,[esi-1]
		sub	al,[edi-1]
		pop	edi
		pop	esi
		pop	ecx
		pop	ebx
@@Exit:		ret
endp		;---------------------------------------------------------------


		; StrLIComp - compare first ECX chars of strings without case
		;	      sensitivity.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2,
		;	 ECX=number of chars to compare.
		; Output: AL=0 - string1=string2,
		;	  AL<1 - string1<string2,
		;	  AL>1 - string1>string2.
proc StrLIComp near
		or	ecx,ecx
		jz	@@Exit
		push	ebx
		push	ecx
		push	esi
		push	edi
		mov	ebx,ecx
		xor	al,al
		cld
		repnz	scas [byte edi]
		sub	ebx,ecx
		mov	ecx,ebx
		pop	edi
		push	edi
@@Loop:		repe	cmps [byte edi],[byte esi]
		je	@@Exit
		mov	al,[esi-1]
		cmp	al,'a'
		jb	@@1
		cmp	al,'z'
		ja	@@1
		sub	al,20h
@@1:		mov	bl,[edi-1]
		cmp	bl,'a'
		jb	@@2
		cmp	bl,'z'
		ja	@@2
		sub	bl,20h
@@2:		sub	al,bl
		jz	@@Loop
		pop	edi
		pop	esi
		pop	ecx
		pop	ebx
@@Exit:		ret
endp		;---------------------------------------------------------------


		; StrScan - search first occurence of char in string.
		; Input: EDI=pointer to string,
		;	 AL=char to search.
		; Output: EDI=pointer to first occurrence of char in string
		;	  or 0, if char doesn't occur.
proc StrScan near
		push	ecx
		push	esi
		push	eax
		mov	esi,edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		not	ecx
		mov	edi,esi
		pop	eax
		repne	scas [byte edi]
		je	@@OK
		xor	edi,edi
@@OK:		pop	esi
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; StrRScan - search last occurence of char in string.
		; Input: EDI=pointer to string,
		;	 AL=char to search.
		; Output: EDI=pointer to last occurrence of char in string
		;	  or 0, if char doesn't occur.
proc StrRScan near
		push	ecx
		push	eax
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		not	ecx
		dec	edi
		pop	eax
		std
		repne	scas [byte edi]
		je	@@OK
		xor	edi,edi
@@OK:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; StrPos - search first occurence of string1 in string2.
		; Input: ESI=pointer to string1,
		;	 EDI=pointer to string2.
		; Output: EDI=pointer to first occurrence of string1
		;	  in string2 or 0, if string2 doesn't occur.
proc StrPos near
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	esi
		mov	ebx,edi
		mov	ecx,-1
		xor	al,al
		cld
		repnz	scas [byte edi]
		not	ecx
		dec	ecx
		jz	@@NotOccur
		mov	edx,ecx
		mov	edi,esi
		push	edi
		mov	ecx,-1
		repnz	scas [byte edi]
		pop	edi
		not	ecx
		sub	ecx,edx
		jbe	@@NotOccur
@@Search:	mov	esi,ebx
		lods	[byte esi]
		repne	scas [byte edi]
		jne	@@NotOccur
		mov	eax,ecx
		push	edi
		mov	ecx,edx
		dec	ecx
		repe	cmps [byte edi],[byte esi]
		pop	edi
		mov	ecx,eax
		jne	@@Search
		dec	edi
		jmp	short @@OK
@@NotOccur:	xor	edi,edi
@@OK:           pop	esi
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; StrLower - convert string to lower case.
		; Input: EDI=pointer to string
		; Output: none.
proc StrLower near
		push	eax
		push	edi
@@Loop:		mov	al,[edi]
		inc	edi
		or	al,al
		jz	@@OK
		cmp	al,'A'
		jb	@@Loop
		cmp	al,'Z'
		ja	@@Loop
		add	al,20h
		mov	[edi-1],al
		jmp	@@Loop
@@OK:		pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; StrUpper - convert string to upper case.
		; Input: EDI=pointer to string
		; Output: none.
proc StrUpper near
		push	eax
		push	edi
@@Loop:		mov	al,[edi]
		inc	edi
		or	al,al
		jz	@@OK
		cmp	al,'a'
		jb	@@Loop
		cmp	al,'z'
		ja	@@Loop
		sub	al,20h
		mov	[edi-1],al
		jmp	@@Loop
@@OK:		pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------


;============================ Character procedures =============================

		; CharToUpper - convert character to upper case.
		; Input: AL=character code.
		; Output: AL=converted code.
proc CharToUpper near
		cmp	al,'a'
		jb	@@Exit
		cmp	al,'z'
		ja	@@Exit
		sub	al,20h
@@Exit:		ret
endp		;---------------------------------------------------------------

		; CharToLower - convert character to lower case.
		; Input: AL=character code.
		; Output: AL=converted code.
proc CharToLower near
		cmp	al,'A'
		jb	@@Exit
		cmp	al,'Z'
		ja	@@Exit
		add	al,20h
@@Exit:		ret
endp		;---------------------------------------------------------------


; ========================== Read string procedrure ============================

		; K_ReadString - read string from current console in buffer.
		; Input: ESI=buffer address,
		;	 CL=maximum string length.
		; Output: CL=number of read characters.
		; Note: destroys CH and high word of ECX.
proc K_ReadString near
		push	ebp
		mov	ebp,esp
		movzx	ecx,cl			; Allocate memory
		sub	esp,ecx			; for local buffer

		push	esi
		push	edi
		push	edx

		mov	edi,ebp
		sub	edi,ecx
		mov	edx,edi			; EDX=EDI=local buffer address
		push	ecx
		cld
		rep	movs [byte edi],[byte esi]
		pop	ecx
		mov	edi,edx
		mov	esi,edx			; ESI=EDI=local buffer address
		mov	edx,ecx

@@ReadKey:	mCallDriver [DrvId_Con],DRVF_Read
		or	al,al
		jz	@@FuncKey
		cmp	al,ASC_BS
		je	@@BS
		cmp	al,ASC_CR
		je	@@Done
		cmp	al,' '			; Another ASCII CTRL?
		jb	@@ReadKey		; Yes, ignore it.
		cmp	edi,ebp			; Buffer full?
		je	@@ReadKey		; Yes, ignore it.
		mov	[edi],al		; Store read character
		inc	edi
		mCallDriver [DrvId_Con],DRVF_Write
		jmp	@@ReadKey

@@FuncKey:	jmp	@@ReadKey

@@BS:		cmp	edi,esi
		je	@@ReadKey
		dec	edi
		mCallDriver [DrvId_Con],DRVF_Write
		jmp	@@ReadKey

@@Done:		mov	ecx,edi
		sub	ecx,esi
		mov	dl,cl			; DL=number of read characters
		mov	edi,[esp+8]		; EDI=target buffer address
		cld
		rep	movs [byte edi],[byte esi]
		mov	cl,dl

		pop	edx
		pop	edi
		pop	esi
		leave
		ret
endp		;---------------------------------------------------------------
