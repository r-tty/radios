;-------------------------------------------------------------------------------
; hashtable.nasm - routines for hash table manipulations.
;-------------------------------------------------------------------------------

module kernel.hashtable

%include "errors.ah"
%include "pool.ah"
%include "hash.ah"

externproc PG_AllocContBlock
externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk

exportproc K_InitHashPool, K_CreateHashTab
exportproc K_HashAdd, K_HashRelease, K_HashLookup


section .bss

?HashElemCount	RESD	1
?MaxHashElems	RESD	1
?HashPool	RESB	tMasterPool_size


section .text

		; Initialize hash element pool.
		; Input: EAX=maximum number of hash elements.
		; Output: none.
proc K_InitHashPool
		mpush	ebx,ecx
		mov	[?MaxHashElems],eax
		mov	ebx,?HashPool
		mov	ecx,tHashElem_size
		xor	edx,edx
		call	K_PoolInit
.Done:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; Create a hash table and initialize it.
		; Input: none.
		; Output: CF=0 - OK, ESI=table address;
		;	  CF=1 - error, AX=error code.
proc K_CreateHashTab
		mpush	ebx,ecx,edx,edi
		mov	ecx,HASH_NUMBER*Ptr_size
		mov	dl,1
		call	PG_AllocContBlock
		jc	.Exit
		mov	edi,ebx
		shr	ecx,2
		xor	eax,eax
		cld
		rep	stosd
		mov	esi,ebx
.Exit:		mpop	edi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; K_HashAdd - put an element into the table.
		; Input: EAX=identifier,
		;	 EBX=key,
		;	 ESI=table address,
		;	 EDI=data pointer.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc K_HashAdd
		locals	id, key
		prologue
		savereg	ebx,edx,esi

		mov	[%$id],eax
		mov	[%$key],ebx
		mHashFunction
		lea	edx,[esi+edx*4]
		Cmp32	?HashElemCount,?MaxHashElems
		jae	.NoFreeElem
		mov	ebx,?HashPool
		call	K_PoolAllocChunk
		jc	.NoFreeElem
		mov	[esi+tHashElem.Data],edi
		Mov32	esi+tHashElem.Id,%$id
		Mov32	esi+tHashElem.Key,%$key
		mEnqueue dword [edx], Next, Prev, esi, tHashElem, ebx
		inc	dword [?HashElemCount]
		xor	eax,eax
		
.Exit:		epilogue
		ret

.NoFreeElem:	mov	eax,ERR_NoFreeHashElem
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; K_HashRemove - remove the element from the table.
		; Input: EDX=table slot address,
		;	 EDI=element address.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error.
proc K_HashRelease
		push	ebx
		mov	eax,[?HashElemCount]
		or	eax,eax
		stc
		jz	.Exit
		dec	dword [?HashElemCount]
		mDequeue dword [edx], Next, Prev, esi, tHashElem, ebx
		call	K_PoolFreeChunk
.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; K_HashLookup - search in the hash table.
		; Input: EAX=identifier,
		;	 EBX=key,
		;	 ESI=table address.
		; Output: CF=0 - element found:
		;		  EDX=table slot address,
		;		  EDI=element address;
		;	  CF=1 - element not found.
proc K_HashLookup
		push	esi
		mpush	eax,ebx
		mHashFunction
		mpop	ebx,eax
		lea	edx,[esi+edx*4]
.Loop:		mov	edi,[edx]
		or	edi,edi
		jz	.NotFound
		cmp	[edi+tHashElem.Id],eax
		jne	.Next
		cmp	[edi+tHashElem.Key],ebx
		je	.Exit
.Next:		mov	esi,edi
		mov	edi,[edi+tHashElem.Next]
		cmp	edi,esi
		jne	.Loop
.NotFound:	stc
		jmp	.Exit

.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------
