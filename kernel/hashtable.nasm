;-------------------------------------------------------------------------------
; hashtable.nasm - routines for hash table manipulations.
;-------------------------------------------------------------------------------

module kernel.hashtable

%include "errors.ah"
%include "pool.ah"
%include "hash.ah"

externproc PG_AllocContBlock
externproc K_PoolInit

publicproc K_InitHashPool, K_CreateHashTab
publicproc K_HashAdd, K_HashRelease, K_HashLookup


section .bss

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
		; Output: CF=0 - OK, EDI=table address;
		;	  CF=1 - error, AX=error code.
proc K_CreateHashTab
		mpush	ebx,ecx,edx
		mov	ecx,HASH_NUMBER*Ptr_size
		mov	dl,1
		call	PG_AllocContBlock
		jc	.Exit
		mov	edi,ebx
		shr	ecx,HASH_ELIST_SHIFT
		mov	eax,HASH_SIG_FREE
.Loop:		mov	[edi+tHashElem.Sig],eax
		add	edi,tHashElem_size
		loop	.Loop
		mov	edi,ebx
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; K_HashAdd - find a free element and use it for hash data.
		; Input: EAX=identifier,
		;	 EBX=key,
		;	 ESI=table address,
		;	 EDI=data pointer.
		; Output: CF=0 - OK, EDX=element address;
		;	  CF=1 - error, AX=error code.
proc K_HashAdd
		push	eax
		push	ebx
		mHashFunction
		shl	edx,HASH_ELIST_SHIFT
		add	edx,esi
		call	FindFreeElem
		jc	.NoFreeElem
		mov	dword [edx+tHashElem.Sig],HASH_SIG_USED
		mov	[edx+tHashElem.Data],edi
		pop	ebx
		mov	[edx+tHashElem.Key],ebx
		pop	eax
		mov	[edx+tHashElem.Id],eax
		ret

.NoFreeElem:	mpop	ebx,eax
		mov	eax,ERR_NoFreeHashElem
		ret
endp		;---------------------------------------------------------------


		; K_HashRelease - release the element.
		; Input: EDX=element address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_HashRelease
		cmp	dword [edx+tHashElem.Sig],HASH_SIG_USED
		jne	.BadSig
		mov	dword [edx+tHashElem.Sig],HASH_SIG_FREE
		ret

.BadSig:	mov	ax,ERR_BadHashElemSig
		stc
		ret
endp		;---------------------------------------------------------------


		; K_HashLookup - search in the hash table.
		; Input: EAX=identifier,
		;	 EBX=key,
		;	 ESI=table address.
		; Output: CF=0 - element found, EDX=element address;
		;	  CF=1 - element not found.
proc K_HashLookup
		mpush	ecx,eax,ebx
		mHashFunction
		mpop	ebx,eax
		shl	edx,HASH_ELIST_SHIFT
		add	edx,esi
		mov	ecx,HASH_ELIST_SIZE / tHashElem_size
.Loop:		
		ret
endp		;---------------------------------------------------------------


		; Auxillary routine: find a free element in the list.
		; Input: EDX=list address.
		; Output: CF=0 - OK, EDX=element address;
		;	  CF=1 - no free elements left.
proc FindFreeElem
		push	ecx
		mov	ecx,HASH_ELIST_SIZE / tHashElem_size
.Loop:		cmp	dword [edx+tHashElem.Sig],HASH_SIG_FREE
		je	.Exit
		add	edx,tHashElem_size
		loop	.Loop
		stc
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------
