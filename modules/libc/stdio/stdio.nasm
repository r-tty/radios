
module libc.stdio

%include "serventry.ah"
%include "asciictl.ah"

publicproc libc_init_stdio

exportproc _fgets

		; Initialization
proc libc_init_stdio
		ret
endp		;---------------------------------------------------------------


		; char *fgets(char *s, int size, FILE *stream);
proc _fgets
		arg	str, size, stream
		prologue
		
		mov	ecx,[%$size]
		sub	esp,ecx			; Allocate local buffer

		mpush	esi,edi
		mov	esi,[%$str]
		mov	edi,ebp
		sub	edi,ecx
		push	edi			; EDI=local buffer address
		push	ecx
		cld
		rep	movsb
		pop	ecx
		pop	edi
		mov	esi,edi			; ESI=EDI=local buffer address

.ReadKey:	mServReadKey
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
		mServPrintChar
		jmp	.ReadKey

.FuncKey:	jmp	.ReadKey

.BS:		cmp	edi,esi
		je	.ReadKey
		dec	edi
		mServPrintChar
		jmp	.ReadKey

.Done:		mov	ecx,edi
		sub	ecx,esi
		mov	edi,[esp+4]		; EDI=target buffer address
		push	ecx			; ECX=number of read characters
		cld
		rep	movsb
		mov	byte [edi],0
		pop	ecx

		mov	eax,[%$str]
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------
