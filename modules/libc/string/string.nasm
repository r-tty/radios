;-------------------------------------------------------------------------------
; string.nasm - string library.
;-------------------------------------------------------------------------------

module libc.string

; Exports

exportproc memchr, memcmp, memcpy, memmove, memset
exportproc strcat, strcmp, strcpy, strcspn, strlen
exportproc strncat, strncmp, strncpy, strpbrk
exportproc strrchr, strstr, strspn, strcspn
exportproc strlwr, strupr
publicproc libc_init_string


; Code

section .text 

		; void memchr(const void *s, int c, size_t n);
proc memchr
		prologue
		push	edi
		mov	ecx,[ebp+16]
		mov	eax,[ebp+12]
		mov	edi,[ebp+8]
		cld
		repne	scasb
		jne	.Done
		dec	edi
		mov	ecx,edi
.Done:
		mov	eax,ecx
	     	pop	edi
		epilogue
		ret
endp		;---------------------------------------------------------------

	
		; int memcmp(const void s1, const void s2, size_t size);
proc memcmp
		prologue
		mpush	esi,edi
		mov	edi,[12+ebp]
		mov	esi,[8+ebp]
		mov	ecx,[16+ebp]
		cld
		repe	cmpsb
		je	.Zero
		jc	.Neg
		xor	eax,eax
		inc	eax
		jmp	short .Done
.Zero:
		xor	eax,eax
		jmp	.Done
.Neg:
		xor	eax,eax
		not	eax
.Done:
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------
		

		; void *memcpy(void *to, const void *from, size_t size);
proc memcpy
		prologue
		mpush	esi,edi
		mov	esi,[ebp+12]
		mov	edi,[ebp+8]
		mov	eax,edi
		mov	ecx,[ebp+16]
		cld
		rep	movsb
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void *memmove(void *to, const void *from, size_t size);
proc memmove
		prologue
		mpush	esi,edi
		mov	ecx,[ebp+16]
		mov	esi,[ebp+12]
		mov	edi,[ebp+8]
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

.Done:		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void *memset(void *block, unsigned char c, size_t size);
proc memset
		prologue
		push	edi
		mov	ecx,[16+ebp]
		mov	eax,[12+ebp]
		mov	edi,[8+ebp]
		cld
		rep	stosb
		mov	eax,[8+ebp]
		pop	edi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strcat(char *to, const char *from);
proc strcat
		prologue
		mpush	esi,edi
	
		mov	edi,[8+ebp]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		dec	edi
		push	edi
		mov	edi,[12+ebp]
		mov	esi,edi
		mov	ecx,-1
		sub	al,al
		repne	scasb
		neg	ecx
		dec	ecx
		pop	edi
		rep	movsb
		mov	eax,[8+ebp]
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strchr(const char *s, unsigned char c);
proc strchr
		prologue
		push	edi
		mov	edi,[8+ebp]
		sub	al,al
		cld
		mov	ecx,-1
		repne	scasb
		not	ecx
		mov	edi,[8+ebp]
		mov	eax,[12+ebp]
		repne	scasb
		je	.OK
		sub	edi,edi
		inc 	edi
.OK:
		mov	eax,edi
		dec	eax
		pop	edi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int strcmp(const char *s1, const char *s2);
proc strcmp
		prologue
		mpush	esi,edi
		mov	edi,[8+ebp]
		mov	esi,edi
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		not	ecx
		mov	edi,[12+ebp]
		repe	cmpsb
		je	.Zero
		js	.Neg
		mov	eax,1
		jmp	.Done
.Zero:
		sub	eax,eax
		jmp	.Done
.Neg:
		mov	eax,-1
.Done:
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strcpy(char *to, const char *from);
proc strcpy
		prologue
		mpush	esi,edi
		mov	esi,[12+ebp]
		mov	edi,esi
		sub	al,al
		mov	ecx,-1
		cld
		repne	scasb
		not	ecx
		mov	edi,[8+ebp]
		mov	eax,edi
		rep	movsb
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; size_t strcspn(const char *string, const char stopset);
proc strcspn
		prologue
		mpush	esi,edi
		mov	esi,[8+ebp]
		mov	edx,[12+ebp]
		sub	eax,eax
.Loop:
		inc	eax
		test	byte [esi],0FFh
		je	.Done
		mov	edi,edx
		mov	cl,[esi]
		inc	esi
.Loop1:
		test	byte [edi],0FFh
		je	.Loop
		cmp	cl,[edi]
		je	.Done
		inc	edi
		jmp	.Loop1
.Done:
		dec	eax
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; size_t strlen(const char *s);
proc strlen
		prologue
		push	edi
		mov	edi,[ebp+8]
		sub	al,al
		mov	ecx,-1
		cld
		repne	scasb
		not	ecx
		dec	ecx
		mov	eax,ecx
		pop	edi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strlwr(char *s);
proc strlwr
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
proc strncat
		prologue
		mpush	esi,edi
		mov	edi,[ebp+8]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		dec	edi
		mov	esi,[ebp+12]
		mov	ecx,[ebp+16]
		rep	movsb
		mov	byte [edi],0
		mov	eax,[ebp+8]
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------

 
		; int strncmp(const char *s1, const char *s2, size_t n);
proc strncmp
		prologue
		mpush	esi,edi
		mov	ecx,[16+ebp]
		jecxz	.Zero
		mov	edi,[12+ebp]
		mov	esi,[8+ebp]
		cld
		repe	cmpsb
		je	.Zero
		js	.Neg
		mov	eax,1
		jmp	.Done
.Zero:
		sub	eax,eax
		jmp	.Done
.Neg:
		mov	eax,-1
.Done:
		mpop	edi,esi
		epilogue
		ret
endp		;--------------------------------------------------------------- 


		; char *strncpy(char *to, const char *from, size_t size);
proc strncpy
		prologue
		mpush	esi,edi
		mov	edi,[ebp+12]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		not	ecx
		dec	ecx
		mov	edx,[ebp+16]
		sub	edx,ecx
		jge	.UseECX
		mov	ecx,[ebp+16]
.UseECX:
		mov	esi,[ebp+12]
		mov	edi,[ebp+8]
		rep	movsb

		or	edx,edx
		jle	.NoPad
		mov	ecx,edx
		sub	al,al
		rep	stosb

.NoPad:		mov	eax,[ebp+8]
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strpbrk(const char *s, const char *stopset);
proc strpbrk
		prologue
		mpush	esi,edi
		mov	esi,[8+ebp]
		mov	edx,[12+ebp]
		sub	eax,eax
.Loop:
		inc	eax
		test	byte [esi],0ffh
		je	short .ex1
		mov	edi,edx
		mov	cl,[esi]
		inc	esi
.Loop1:
		test	byte [edi],0ffh
		je	.Loop
		cmp	cl,[edi]
		je	short .ex2
		inc	edi
		jmp	.Loop1
		
.ex1:		sub	eax,eax
		jmp	short .Done
		
.ex2:		dec	eax
		add	eax,[8+ebp]
		
.Done:		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------

	
		; char *strrchr(const char *s, unsigned char c);
proc strrchr
		prologue
		push	edi
		mov	edi,[ebp+8]
		mov	ecx,-1
		sub	al,al
		cld
		repne	scasb
		not	ecx
		dec	edi
		mov	al,[ebp+12]
		std
		repne	scasb
		cld
		je	.OK
		sub	eax,eax
		jmp	.Done
		
.OK:		add	ecx,[ebp+8]
		mov	eax,ecx
		inc	eax
		
.Done:		pop	edi
		epilogue
		ret
endp		;---------------------------------------------------------------	
	

		; size_t strspn(const char *s, const char *skipset);
proc strspn
		prologue
		mpush	esi,edi
		mov	esi,[12+ebp]
		mov	edx,[8+ebp]
		sub	eax,eax
		
.Loop:		inc	eax
		test	byte [esi],0ffh
		je	.Done
		mov	edi,edx
		mov	cl,[esi]
		inc	esi
		
.Loop1:		test	byte [edi],0ffh
		je	.Done
		cmp	cl,[edi]
		je	.Loop
		inc	edi
		jmp	.Loop1
		
.Done:		dec	eax
		mpop	 edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------	


		; char *strstr(const char *s1, const char s2);
proc strstr
		prologue
		mpush	esi,edi
		mov	edi,[ebp+12]
		push	edi
		sub	al,al
		mov	ecx,-1
		cld
		repne	scasb
		not	ecx
		dec	ecx
		pop	edi
		mov	esi,[ebp+8]
		
.Loop:		mov	al,[esi]
		or	al,al
		je	.NotFound
		cmp	al,[edi]
		jne	.NoComp
		mpush	ecx,esi,edi
		rep	cmpsb
		mpop	edi,esi,ecx
		je	.Done
		
.NoComp:	inc esi
		jmp	.Loop
		
.NotFound:	sub	esi,esi
	
.Done:		mov	eax,esi
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; char *strupr(char *s);
proc strupr
		push	esi
		mov	esi,[esp+8]
		
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

.Done:		mov	eax,[esp + 8]
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; Initialization
proc libc_init_string
		ret
endp		;---------------------------------------------------------------
