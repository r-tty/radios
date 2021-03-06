;-------------------------------------------------------------------------------
; stdlib.nasm - standard library routines.
;-------------------------------------------------------------------------------

module libc.stdlib

%include "cpu/paging.ah"
%include "locstor.ah"
%include "lib/stdlib.ah"

exportproc _ldiv, _malloc, _calloc, _realloc, _free

publicproc libc_init_stdlib

externproc _AllocPages


; Header of the memory block allocated by malloc()
struc tMallocHdr
.Addr		RESD	1
.Size		RESD	1
endstruc

tMallocHdr_shift	EQU	3		; log2(tMallocHdr_size)

FixNeg			EQU	-1 / 2		; for _ldiv

section .text

		; ldiv_t ldiv(long numer, long denom);
proc _ldiv
		arg	_plh, numer, denom
		locauto	val, tLdiv_size
		prologue
		mpush	ecx,esi,edi
		mov	edi,[%$numer]
		mov	esi,[%$denom]
		mov	eax,edi
		mov	ecx,esi
		cdq
		idiv	ecx
		mov	[%$val+tLdiv.Quot],eax
		imul	esi,[%$val+tLdiv.Quot]
		sub	edi,esi
		mov	[%$val+tLdiv.Rem],edi
		mov	edi,FixNeg
		or	edi,edi
		jge	.NoFix
		mov	edi,[%$val+tLdiv.Quot]
		or	edi,edi
		jge	.NoFix
		mov	edi,[%$val+tLdiv.Rem]
		or	edi,edi
		je	.NoFix
		inc	dword [%$val+tLdiv.Quot]
		mov	edi,[%$denom]
		sub	[%$val+tLdiv.Rem],edi
		
.NoFix:		mov	edi,[%$_plh]
		lea	esi,[%$val]
		mov	ecx,8
		cld
		rep	movsb

		epilogue
		ret
endp		;---------------------------------------------------------------


		; void *malloc(size_t size);
proc _malloc
		arg	size
		prologue
		savereg	ebx,ecx,edx,esi,edi

		; Calculate the number of units
		mov	ecx,[%$size]
		add	ecx,byte tMallocHdr_size-1
		shr	ecx,tMallocHdr_shift
		inc	ecx
		
		; Get a TLS pointer and check if there is a free block list
		tlsptr(edx)
		mov	esi,[edx+tTLS.HlastPtr]
		or	esi,esi
		jnz	.NotFirst
		xor	eax,eax
		lea	esi,[edx+tTLS.HheadPtr]
		mov	[edx+tTLS.HlastPtr],esi
		mov	[esi+tMallocHdr.Addr],esi
		mov	[esi+tMallocHdr.Size],eax

		; Walk through the list looking for a block of suitable size
.NotFirst:	mov	edi,[esi+tMallocHdr.Addr]
.Loop:		cmp	[edi+tMallocHdr.Size],ecx
		jb	.CheckWrap
		je	.Exact
		; Allocate tail end
		sub	[edi+tMallocHdr.Size],ecx
		mov	eax,ecx
		shl	eax,tMallocHdr_shift
		add	edi,eax
		mov	[edi+tMallocHdr.Size],ecx
		jmp	.OK
		; Exact size
.Exact:		mov	eax,[edi+tMallocHdr.Addr]
		mov	[esi+tMallocHdr.Addr],eax
		mov	[edx+tTLS.HlastPtr],esi
		jmp	.OK

.Next:		mov	esi,edi
		mov	edi,[edi+tMallocHdr.Addr]
		jmp	.Loop

		; If wrapped around the free list - get a new block
.CheckWrap:	cmp	edi,[edx+tTLS.HlastPtr]
		jne	.Next
		call	GetMem
		js	.Exit
.OK:		lea	eax,[edi+tMallocHdr_size]

.Exit:		epilogue
		ret

		; Subroutine: get a memory block of ECX units and
		; return block address in EDI.
		; Before asking for memory pages, we will round the block
		; size up to PAGESIZE.
GetMem:		mpush	ecx,esi
		mov	eax,ecx
		add	eax,PAGESIZE/tMallocHdr_size-1
		and	eax,~(PAGESIZE/tMallocHdr_size-1)
		mov	ecx,eax
		shl	eax,tMallocHdr_shift
		Ccall	_AllocPages, eax
		test	eax,eax
		js	.Done
		mov	[eax+tMallocHdr.Size],ecx
		add	eax,byte tMallocHdr_size

		Ccall	_free, eax
		mov	edi,[edx+tTLS.HheadPtr]

.Done:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; void *calloc(size_t nmemb, size_t size);
proc _calloc
		arg	nmemb, size
		prologue
		savereg	ecx,edx,edi
		mov	eax,[%$size]
		mov	ecx,[%$nmemb]
		mul	ecx
		mov	ecx,eax
		Ccall	_malloc, ecx
		or	eax,eax
		je	.Exit
		mov	edi,eax
		mov	edx,eax
		xor	eax,eax
		cld
		rep	stosb
		mov	eax,edx
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; void *realloc(void *ptr, size_t size);
proc _realloc
		arg	ptr, size
		prologue
		mov	eax,[%$ptr]
		or	eax,eax
		jz	.Alloc
		Ccall	_free, eax
.Alloc:		Ccall	_malloc, dword [%$size]
		or	eax,eax
		jz	.Exit
		mov	[%$ptr],eax
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; void free(void *addr);
proc _free
		arg	addr
		prologue
		savereg	ebx,edx,esi,edi

		mov	edi,[%$addr]
		or	edi,edi
		jz	.Exit
		sub	edi,byte tMallocHdr_size
		tlsptr(edx)
		mov	esi,[edx+tTLS.HlastPtr]
		or	esi,esi
		jz	.Exit

.Loop:		cmp	esi,[esi+tMallocHdr.Addr]
		jb	.1
		cmp	edi,esi
		ja	.CheckUpper
		cmp	edi,[esi+tMallocHdr.Addr]
		jb	.CheckUpper
.1:		cmp	edi,esi
		jbe	.Next
		cmp	edi,[esi+tMallocHdr.Addr]
		ja	.CheckUpper
.Next:		mov	esi,[esi+tMallocHdr.Addr]
		jmp	.Loop

.CheckUpper:	mov	eax,edi
		add	eax,[edi+tMallocHdr.Size]
		cmp	eax,[esi+tMallocHdr.Addr]
		jne	.2
		; Join to upper
		mov	ebx,[esi+tMallocHdr.Addr]
		mov	eax,[ebx+tMallocHdr.Size]
		add	[edi+tMallocHdr.Size],eax
		mov	eax,[ebx+tMallocHdr.Addr]
		mov	[edi+tMallocHdr.Addr],eax
		jmp	.CheckLower
.2:		mov	eax,[esi+tMallocHdr.Addr]
		mov	[edi+tMallocHdr.Addr],eax

.CheckLower:	mov	eax,esi
		add	eax,[esi+tMallocHdr.Size]
		cmp	eax,edi
		jne	.3
		; Join to lower
		mov	eax,[edi+tMallocHdr.Size]
		add	[esi+tMallocHdr.Size],eax
		mov	eax,[edi+tMallocHdr.Addr]
		mov	[esi+tMallocHdr.Addr],eax
		jmp	.OK
.3:		mov	[esi+tMallocHdr.Addr],edi

.OK:		mov	[edx+tTLS.HlastPtr],esi
		xor	eax,eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
