;-------------------------------------------------------------------------------
; hashtable.nasm - routines for hash table manipulations.
;-------------------------------------------------------------------------------

module kernel.hashtable

%include "cpu/paging.ah"

externproc PG_AllocContBlock

publicproc K_CreateHashTab


HASH_NUMBER	EQU	131

section .text

		; Create a hash table and initialize it.
		; Input: none.
		; Output: CF=0 - OK, EDI=table address;
		;	  CF=1 - error, AX=error code.
proc K_CreateHashTab
		mpush	ebx,ecx,edx
		mov	ecx,HASH_NUMBER*PAGESIZE
		mov	dl,1
		call	PG_AllocContBlock
		jc	.Exit
		mov	edi,ebx
		xor	eax,eax
		shr	ecx,2
		cld
		rep	stosd
		mov	edi,ebx
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------
