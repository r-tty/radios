;-------------------------------------------------------------------------------
; string.nasm - string library.
;-------------------------------------------------------------------------------

module libc.string

; Exports

exportproc _memchr, _memcmp, _memcpy, _memmove, _memset
exportproc _strcat, _strcmp, _strcpy, _strcspn, _strlen
exportproc _strncat, _strncmp, _strncpy, _strpbrk
exportproc _strchr, _strrchr, _strstr, _strspn, _strcspn
exportproc _strlwr, _strupr, _strend
publicproc libc_init_string


; Code

section .text 

		; void memchr(const void *s, int c, size_t n);
proc _memchr
		arg	str, char, size
		prologue
		savereg	ecx,edi
		mov	ecx,[%$size]
		mov	eax,[%$char]
		mov	edi,[%$str]
		cld
		repne	scasb
		jne	.Done
		dec	edi
		mov	ecx,edi

.Done:		mov	eax,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------

	
		; int memcmp(const void s1, const void s2, size_t size);
proc _memcmp
		arg	s1, s2, size
		prologue
		savereg	ecx,esi,edi
		xor	eax,eax
		mov	esi,[%$s1]
		mov	edi,[%$s2]
		mov	ecx,[%$size]
		cld
		repe	cmpsb
		je	.Done
		jc	.Neg
		inc	eax
		jmp	.Done

.Neg:		not	eax
.Done:		epilogue
		ret
endp		;---------------------------------------------------------------
		

		; void *memcpy(void *to, const void *from, size_t size);
proc _memcpy
		arg	to, from, size
		prologue
		savereg	ecx,esi,edi
		mov	esi,[%$from]
		mov	edi,[%$to]
		mov	eax,edi
		mov	ecx,[%$size]
		cld
		rep	movsb
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void *memmove(void *to, const void *from, size_t size);
proc _memmove
		arg	to, from, size
		prologue
		savereg	ecx,esi,edi
		mov	ecx,[%$size]
		mov	esi,[%$from]
		mov	edi,[%$to]
		mov	eax,edi
		cmp	edi,esi	
		ja	.NegMove
		cld
		rep	movsb
		jmp	.Done
		
.NegMove:	add	esi,ecx
		add	edi,ecx
		dec	esi
		dec	edi
		std
		rep	movsb
		cld

.Done:		epilogue
		ret
endp		;---------------------------------------------------------------


		; void *memset(void *block, unsigned char c, size_t size);
proc _memset
		arg	block, char, size
		prologue
		savereg	ecx,edi
		mov	ecx,[%$size]
		mov	eax,[%$char]
		mov	edi,[%$block]
		cld
		rep	stosb
		mov	eax,[%$block]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strcat(char *to, const char *from);
proc _strcat
		arg	to, from
		prologue
		savereg	ecx,esi,edi
	
		mov	edi,[%$to]
		mov	ecx,-1
		xor	al,al
		cld
		repne	scasb
		dec	edi
		push	edi
		mov	edi,[%$from]
		mov	esi,edi
		mov	ecx,-1
		sub	al,al
		repne	scasb
		neg	ecx
		dec	ecx
		pop	edi
		rep	movsb
		mov	eax,[%$to]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strchr(const char *s, unsigned char c);
proc _strchr
		arg	str, char
		prologue
		savereg	ecx,edi
		mov	edi,[%$str]
		xor	al,al
		cld
		mov	ecx,-1
		repne	scasb
		not	ecx
		mov	edi,[%$str]
		mov	eax,[%$char]
		repne	scasb
		je	.OK
		sub	edi,edi
		inc 	edi

.OK:		mov	eax,edi
		dec	eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int strcmp(const char *s1, const char *s2);
proc _strcmp
		arg	s1, s2
		prologue
		savereg	ecx,esi,edi
		mov	edi,[%$s1]
		mov	esi,edi
		mov	ecx,-1
		xor	al,al
		cld
		repne	scasb
		not	ecx
		mov	edi,[%$s2]
		repe	cmpsb
		je	.Zero
		js	.Neg
		mov	eax,1
		jmp	.Done
		
.Zero:		xor	eax,eax
		jmp	.Done
		
.Neg:		mov	eax,-1

.Done:		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strcpy(char *to, const char *from);
proc _strcpy
		arg	to, from
		prologue
		savereg	ecx,esi,edi
		mov	esi,[%$from]
		mov	edi,esi
		xor	al,al
		mov	ecx,-1
		cld
		repne	scasb
		not	ecx
		mov	edi,[%$to]
		mov	eax,edi
		rep	movsb
		epilogue
		ret
endp		;---------------------------------------------------------------


		; size_t strcspn(const char *string, const char stopset);
proc _strcspn
		arg	str, stopset
		prologue
		savereg	ecx,edx,esi,edi
		mov	esi,[%$str]
		mov	edx,[%$stopset]
		sub	eax,eax

.Loop:		inc	eax
		test	byte [esi],0FFh
		je	.Done
		mov	edi,edx
		mov	cl,[esi]
		inc	esi

.Loop1:		test	byte [edi],0FFh
		je	.Loop
		cmp	cl,[edi]
		je	.Done
		inc	edi
		jmp	.Loop1

.Done:		dec	eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; size_t strlen(const char *s);
proc _strlen
		arg	str
		prologue
		savereg	ecx,edi
		mov	edi,[%$str]
		xor	al,al
		mov	ecx,-1
		cld
		repne	scasb
		not	ecx
		dec	ecx
		mov	eax,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strlwr(char *s);
proc _strlwr
		push	esi
		mov	esi,[esp+8]
		
.Loop:		lodsb
		or	al,al
		jz	.EOL
		cmp	al,'A'
		jc	.Loop
		cmp	al,'Z'
		ja	.Loop
		or	al, 20h
		mov	[esi-1],al
		jmp	.Loop
		
.EOL:		mov	eax,[esp+8]
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; char *strncat(char *to, const char *from, size_t size);
proc _strncat
		arg	to, from, size
		prologue
		savereg	ecx,esi,edi
		mov	edi,[%$to]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		dec	edi
		mov	esi,[%$from]
		mov	ecx,[%$size]
		rep	movsb
		mov	byte [edi],0
		mov	eax,[%$to]
		epilogue
		ret
endp		;---------------------------------------------------------------

 
		; int strncmp(const char *s1, const char *s2, size_t n);
proc _strncmp
		arg	s1, s2, n
		prologue
		savereg	ecx,esi,edi
		mov	ecx,[%$n]
		jecxz	.Zero
		mov	edi,[%$s2]
		mov	esi,[%$s1]
		cld
		repe	cmpsb
		je	.Zero
		js	.Neg
		mov	eax,1
		jmp	.Done
		
.Zero:		sub	eax,eax
		jmp	.Done
		
.Neg:		mov	eax,-1

.Done:		epilogue
		ret
endp		;--------------------------------------------------------------- 


		; char *strncpy(char *to, const char *from, size_t size);
proc _strncpy
		arg	to, from, size
		prologue
		savereg	ecx,esi,edi
		mov	edi,[%$from]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		not	ecx
		dec	ecx
		mov	edx,[%$size]
		sub	edx,ecx
		jge	.UseECX
		mov	ecx,[%$size]
		
.UseECX:	mov	esi,[%$from]
		mov	edi,[%$to]
		rep	movsb

		or	edx,edx
		jle	.NoPad
		mov	ecx,edx
		sub	al,al
		rep	stosb

.NoPad:		mov	eax,[%$to]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strpbrk(const char *s, const char *stopset);
proc _strpbrk
		arg	str, stopset
		prologue
		savereg	ecx,esi,edi
		mov	esi,[%$str]
		mov	edx,[%$stopset]
		sub	eax,eax
.Loop:
		inc	eax
		test	byte [esi],0ffh
		je	.ex1
		mov	edi,edx
		mov	cl,[esi]
		inc	esi
.Loop1:
		test	byte [edi],0ffh
		je	.Loop
		cmp	cl,[edi]
		je	.ex2
		inc	edi
		jmp	.Loop1
		
.ex1:		sub	eax,eax
		jmp	.Done
		
.ex2:		dec	eax
		add	eax,[%$str]
		
.Done:		epilogue
		ret
endp		;---------------------------------------------------------------

	
		; char *strrchr(const char *s, unsigned char c);
proc _strrchr
		arg	str, char
		prologue
		savereg	ecx,edi
		mov	edi,[%$str]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		not	ecx
		dec	edi
		mov	al,[%$char]
		std
		repne	scasb
		cld
		je	.OK
		sub	eax,eax
		jmp	.Done
		
.OK:		add	ecx,[%$str]
		mov	eax,ecx
		inc	eax
		
.Done:		epilogue
		ret
endp		;---------------------------------------------------------------	
	

		; size_t strspn(const char *s, const char *skipset);
proc _strspn
		arg	str, skipset
		prologue
		savereg	ecx,edx,esi,edi
		mov	esi,[%$skipset]
		mov	edx,[%$str]
		sub	eax,eax
		
.Loop:		inc	eax
		test	byte [esi],0ffh
		je	.Done
		mov	edi,edx
		mov	cl,[esi]
		inc	esi
		
.Loop1:		test	byte [edi],0FFh
		je	.Done
		cmp	cl,[edi]
		je	.Loop
		inc	edi
		jmp	.Loop1
		
.Done:		dec	eax
		epilogue
		ret
endp		;---------------------------------------------------------------	


		; char *strstr(const char *s1, const char s2);
proc _strstr
		arg	s1, s2
		prologue
		savereg	ecx,esi,edi
		mov	edi,[%$s2]
		push	edi
		sub	al,al
		mov	ecx,-1
		cld
		repne	scasb
		not	ecx
		dec	ecx
		pop	edi
		mov	esi,[%$s1]
		
.Loop:		mov	al,[esi]
		or	al,al
		je	.NotFound
		cmp	al,[edi]
		jne	.NoComp
		mpush	ecx,esi,edi
		rep	cmpsb
		mpop	edi,esi,ecx
		je	.Done
		
.NoComp:	inc	esi
		jmp	.Loop
		
.NotFound:	sub	esi,esi
	
.Done:		mov	eax,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strupr(char *s);
proc _strupr
		arg	str
		prologue
		savereg	esi
		mov	esi,[%$str]
		
.Loop:		lodsb
		or	al,al
		jz	.Done
		cmp	al,'a'
		jc	.Loop
		cmp	al,'z'
		ja	.Loop
		and	al, ~20h
		mov	[esi-1],al
		jmp	.Loop

.Done:		mov	eax,[%$str]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char strend(const char *s);
proc _strend
		arg	str
		prologue
		savereg	ecx,edi
		mov	edi,[%$str]
		xor	ecx,ecx
		dec	ecx
		xor	al,al
		cld
		repne	scasb
		mov	eax,edi
		epilogue
		ret
endp		;---------------------------------------------------------------
