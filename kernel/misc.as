;-------------------------------------------------------------------------------
;  misc.asm - miscellaneous kernel procedures.
;-------------------------------------------------------------------------------

module kernel.misc

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "asciictl.ah"

; --- Exports ---

global K_TTDelay, K_LDelay, K_LDelayMs, K_MicroDelay
global K_GetDate, K_GetTime

global HexB2Str, HexW2Str
global HexD2Str, DecD2Str

global ValByteDec, ValDwordDec, ValDwordHex
global BCDB2Dec, BCDW2Dec

global StrLen, StrEnd, StrMove, StrCopy, StrAppend
global StrComp, StrLComp, StrLIComp
global StrScan, StrRScan, StrPos
global StrLower, StrUpper
global CharToUpper, CharToLower
global MemSet, BZero


; --- Imports ---

library kernel
extern ?TicksCounter, ?CPUspeed

library kernel.driver
extern DRV_CallDriver:near, DRV_GetFlags:near

library kernel.kconio
extern K_WrDecD:near


; --- Procedures ---

section .text

; ============================ Delay procedures ================================

		; K_TTDelay - kernel delay (using timer ticks counter).
		; Input: ECX=number of quantum of times in delay.
		; Output: none.
proc K_TTDelay
		push	eax
		push	ecx
		mov	eax,[?TicksCounter]
		lea	ecx,[eax+ecx]
.Loop:		mov	eax,[?TicksCounter]
		cmp	eax,ecx
		jb	.Loop
		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; K_LDelay - kernel delay (using LOOP).
		; Input: ECX=number of repeats in loop.
		; Output: none.
		; Note: uses ?CPUspeed variable.
proc K_LDelay
		mpush	eax,ecx,edx
		xor	edx,edx
		mov	eax,[?CPUspeed]
		mul	ecx
		mov	ecx,eax
		align 4
.LDel:		nop
		dec	ecx
		js	short .Exit
		jmp	.LDel
.Exit:		mpop	edx,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; K_LDelayMs - loop delay (in milliseconds)
		; Input: ECX=time of delay (ms).
		; Output: none.
proc K_LDelayMs
		mpush	eax,ecx,edx
		mov	eax,159
		xor	edx,edx
		mul	ecx
		mov	ecx,eax
		call	K_LDelay
		mpop	edx,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; K_MicroDelay - loop delay (in microseconds)
		; Input: ECX=number of microseconds.
		; Output: none.
proc K_MicroDelay
		ret
endp		;---------------------------------------------------------------


; ========================== Time/date procedures ==============================

		; K_GetDate - get current date.
		; Input: none.
		; Output: BL=day,
		;	  BH=month,
		;	  CX=year.
proc K_GetDate
		ret
endp		;---------------------------------------------------------------


		; K_GetTime - get current time.
		; Input: none.
		; Output: BH=hour,
		;	  BL=minute,
		;	  CL=second.
proc K_GetTime
		ret
endp		;---------------------------------------------------------------


		; K_SetSysDate - set system date.
		; Input: AH=seconds,
		;	 BL=minutes,
		;	 BH=hours,
		;	 DL=day,
		;	 DH=month,
		;	 CX=year.
		; Output:
proc K_SetSysDate
		ret
endp		;---------------------------------------------------------------

; =================== Dec/hex write and convert procedures =====================



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
		mpush	esi,edi
		mov	edi,Dig2StrProc
		call	K_WrDecD
		mov	byte [esi],0
		mpop	edi,esi
		ret
Dig2StrProc:	mov	[esi],al
		inc	esi
		ret
endp		;---------------------------------------------------------------


; ========================== Print/write procedures ============================

		; WrStrToDev - write string to character device.
		; Input: EDX=full device ID,
		;	 ESI=pointer to string.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc WrStrToDev
		mpush	esi,edi
		mov	edi,edx
		mov	eax,edx
		call	DRV_GetFlags
		jc	short .Exit
		test	ax,DRVFL_Char
		jz	short .Err

.Loop:		lodsb
		or	al,al
		jz	short .OK
		mCallDriver edi, byte DRVF_Write
		jc	short .Exit
		jmp	.Loop
.OK:		xor	ax,ax

.Exit:		mpop	edi,esi
		ret

.Err:		mov	ax,ERR_DRV_NotCharDev
		stc
		jmp	short .Exit
endp		;---------------------------------------------------------------


		; BCDW2Dec - convert BCD word to decimal.
		; Input: AX=BCD word.
		; Output: AX=converted word.
proc BCDW2Dec
		call	BCDB2Dec
		xchg	al,ah
		call	BCDB2Dec
		xchg	al,ah
		ret

BCDB2Dec:	push	ecx
		movzx	ecx,ah
		shl	ecx,16
		mov	cl,al
		mov	ch,10
		and	al,0F0h
		shr	al,4
		xor	ah,ah
		mul	ch
		and	cl,0Fh
		add	al,cl
		shr	ecx,16
		mov	ah,cl
		pop	ecx
		ret
endp		;---------------------------------------------------------------


; ========================= ASCIIZ strings procedures ==========================

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


;============================ Character procedures =============================

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


		; MemSet - fill memory with a constant byte.
		; Input: EBX=block address,
		;	 ECX=block size,
		;	 AL=value.
		; Output: none.
proc MemSet
		mpush	eax,ecx,edi
		mov	edi,ebx
		mov	ah,al
		cld
		shr	ecx,byte 1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; BZero - fill memory with a NULL.
		; Input: EBX=block address,
		;	 ECX=block size.
		; Output: none.
proc BZero
		mpush	eax,ecx,edi
		mov	edi,ebx
		xor	eax,eax
		cld
		shr	ecx,1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------

; ============================== VAL procedures ================================

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
