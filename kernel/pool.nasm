;*******************************************************************************
; pool.nasm - routines for manipulations with the memory "pools".
; Copyright (c) 2000-2002 RET & COM Research.
; This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.pool

%include "errors.ah"
%include "sync.ah"
%include "pool.ah"
%include "cpu/paging.ah"


; --- Exports ---

exportproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
exportproc K_PoolChunkNumber, K_PoolChunkAddr


; --- Imports ---

library kernel.paging
externproc PG_Alloc, PG_Dealloc

library kernel.sync
externproc K_SemP, K_SemV


; --- Variables ---

section .bss

?PoolCount	RESD	1
?PoolPageCount	RESD	1		; Count total pages used by pools


; --- Code ---

section .text

		; K_PoolInit - initialize the master pool.
		; Input: EBX=address of the master pool,
		;	 ECX=chunk size,
		;	 DL=flags.
		; Output: none.
proc K_PoolInit
		xor	eax,eax
		mov	[ebx+tMasterPool.Pools],eax
		mov	[ebx+tMasterPool.Hint],eax
		mov	[ebx+tMasterPool.Count],eax
		mov	[ebx+tMasterPool.Size],ecx
		mov	[ebx+tMasterPool.Flags],dl
		mov	[ebx+tMasterPool.Signature],ebx
		lea	eax,[ebx+tMasterPool.SemLock]
		mSemInit eax
		inc	dword [?PoolCount]
		xor	eax,eax
		ret
endp		;---------------------------------------------------------------


		; K_PoolNew - allocate a new pool for a given master pool.
		;	      Actually rips some memory and initializes
		;	      pool descriptor.
		; Input: EBX=address of the master pool.
		; Output: CF=0 - OK, ESI=pool address;
		;	  CF=1 - error, AX=error code.
proc K_PoolNew
		mpush	ebx,ecx,edx
		
		; See how many chunks will fit into a page.
		; Take into account pool descriptor at the beginning of a page.
		mov	eax,PAGESIZE-tPoolDesc_size
		mov	ecx,[ebx+tMasterPool.Size]
		xor	edx,edx
		div	ecx
		mov	ecx,eax				; ECX=number of chunks

		; Get a page of memory
		mov	dl,[ebx+tMasterPool.Flags]	; Low or high memory?
		and	dl,POOLFL_HIMEM			; Mask unused flags
		call	PG_Alloc
		jc	.Done
		and	eax,PGENTRY_ADDRMASK		; Mask status bits
		mov	esi,eax				; ESI=address of page
		
		inc	dword [?PoolPageCount]		; Global page counter

		; Initialize pool descriptor
		mov	[esi+tPoolDesc.Master],ebx
		mov	dword [esi+tPoolDesc.RefCount],0
		mov	[esi+tPoolDesc.ChunksTotal],ecx
		mov	[esi+tPoolDesc.ChunksFree],ecx
		mov	edx,[ebx+tMasterPool.Size]	; EDX=chunk size
		mov	[esi+tPoolDesc.ChunkSize],edx
		lea	eax,[esi+tPoolDesc_size]
		mov	[esi+tPoolDesc.FreeHead],eax
		mpush	esi,eax				; Keep page address
							; and free list head
		; Update master pool information: list links and count.
		mov	eax,[ebx+tMasterPool.Pools]
		mov	[ebx+tMasterPool.Pools],esi
		inc	dword [ebx+tMasterPool.Count]

		; Initialize free list pointers for every chunk
		; trailing with null. Also mark every chunk with a signature.
		pop	esi				; ESI=free list head
		dec	ecx				; ECX=chunks-1
		jz	.TrailNULL
		mov	eax,[ebx+tMasterPool.Signature]
.Loop:		lea	ebx,[esi+edx]
		mov	[esi],ebx
		mov	[esi+4],eax
		add	esi,edx
		dec	ecx
		jnz	.Loop
.TrailNULL:	mov	dword [esi],0
		pop	esi				; Return address of a
		xor	eax,eax				; new pool in ESI
.Done		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; K_PoolAllocChunk - allocate single chunk from
 		;		     given master pool.
		; Input: EBX=master pool address.
		; Output: CF=0 - OK, ESI=chunk address;
		;	  CF=1 - error, AX=error code.
		; Note: if pool was initialized for "bucket allocation", ECX
		;	will return number of chunks fit in one page.
proc K_PoolAllocChunk
		mpush	ebx,edx
		mov	esi,ebx

		lea	eax,[esi+tMasterPool.SemLock]	; Lock master pool
		call	K_SemP
		
		; First check if "bucket alloc" flag is set. If so - 
		; immediately allocate new pool.
		test	byte [esi+tMasterPool.Flags],POOLFL_BUCKETALLOC
		jnz	.AllocPool

		; Now check if hint is valid. If not, go through pool list
		; to find one containing some free chunks
		; If no pools with free space, get a new one.
		; Always update hint for future use.
		mov	edx,[esi+tMasterPool.Hint]
		or	edx,edx
		jz	.FindHint
		cmp	dword [edx+tPoolDesc.FreeHead],0
		jnz	.HintOK

.FindHint:	mov	ebx,[esi+tMasterPool.Pools]
.FindHintLoop:	or	ebx,ebx
		jz	.AllocPool
		cmp	dword [ebx+tPoolDesc.FreeHead],0
		jne	.GotHint
		mov	ebx,[ebx+tPoolDesc.Next]
		jmp	.FindHintLoop
.GotHint:	mov	[esi+tMasterPool.Hint],ebx
		mov	edx,ebx
		jmp	.HintOK

.AllocPool:	mov	ebx,esi
		mov	edx,esi				; Save master pool addr
		call	K_PoolNew
		jc	.Done
		xchg	edx,esi
		mov	[esi+tMasterPool.Hint],edx

		; Get a chunk and maintain pointers
.HintOK:	mov	ebx,[edx+tPoolDesc.FreeHead]
		mov	eax,[ebx]
		mov	[edx+tPoolDesc.FreeHead],eax
		inc	dword [edx+tPoolDesc.RefCount]
		dec	dword [edx+tPoolDesc.ChunksFree]
		
		; Return number of chunks in ECX if the pool is marked
		; for "bucket alloc"
		test	byte [esi+tMasterPool.Flags],POOLFL_BUCKETALLOC
		jz	.Finish
		mov	ecx,[edx+tPoolDesc.ChunksFree]
		inc	ecx
		
.Finish:	mov	edx,ebx
		lea	eax,[esi+tMasterPool.SemLock]	; Unlock master pool
		call	K_SemV

		mov	esi,edx				; Return chunk addr
		xor	eax,eax
		mov	[esi],eax			; Clean fields we used
		mov	[esi+4],eax

.Done		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; K_PoolFreeChunk - free chunk.
		; Input: ESI=chunk address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_PoolFreeChunk
		mpush	ebx,edx,edi
		mov	edi,esi

		; Find the start of page, which is our pool descriptor
		mov	edx,esi		
		and	edx,PGENTRY_ADDRMASK		; EDX=pooldesc address
		mov	esi,[edx+tPoolDesc.Master]	; ESI=master pool addr

		lea	eax,[esi+tMasterPool.SemLock]	; Lock master pool
		call	K_SemP

		; Free this chunk
		mov	eax,[edx+tPoolDesc.FreeHead]
		mov	[edi],eax
		mov	eax,[esi+tMasterPool.Signature]
		mov	[edi+4],eax
		mov	[edx+tPoolDesc.FreeHead],edi
		inc	dword [edx+tPoolDesc.ChunksFree]

		; Check reference count and free the whole pool if needed
		dec	dword [edx+tPoolDesc.RefCount]
		jnz	.Unlock
		
		; If this pool is a hint, update hint
		; since this one is about to cease to exist
		cmp	[esi+tMasterPool.Hint],edx
		jne	.NotHint
		mov	eax,[edx+tPoolDesc.Next]
		mov	[esi+tMasterPool.Hint],eax
		
		; Find this pool in master pool linked list and unlink it.
		; First check out the head of the list.
		; If not sucessful, go through the whole list.
.NotHint:	cmp	[esi+tMasterPool.Pools],edx
		jne	.NotHead
		mov	eax,[edx+tPoolDesc.Next]
		mov	[esi+tMasterPool.Pools],eax
		jmp	.FreePage
		
.NotHead:	mov	ebx,[esi+tMasterPool.Pools]
.FindHeadLoop:	or	ebx,ebx
		jz	.Err
		cmp	[ebx+tPoolDesc.Next],edx
		je	.Unlink
		mov	ebx,[ebx+tPoolDesc.Next]
		jmp	.FindHeadLoop

.Unlink:	mov	eax,[edx+tPoolDesc.Next]
		mov	[ebx+tPoolDesc.Next],eax
		xor	edi,edi				; No errors

		; Decrease the count and free memory of this pool.
.FreePage:	dec	dword [esi+tMasterPool.Count]
		mov	eax,edx
		call	PG_Dealloc
		dec	dword [?PoolPageCount]

.Unlock:	lea	eax,[esi+tMasterPool.SemLock]	; Unlock master pool
		call	K_SemV

		mov	ax,di				; Error code
		shl	edi,1				; and carry flag
		
.Done:		mpop	edi,edx,ebx
		ret

.Err:		mov	edi,(1<<16)+ERR_PoolFreeNoHead	; Carry flag + errcode
		jmp	.FreePage
endp		;---------------------------------------------------------------


		; K_PoolChunkNumber - get a chunk number by its address.
		; Input: ESI=chunk address.
		; Output: CF=0 - OK, EAX=chunk number;
		;	  CF=1 - error, AX=error code.
proc K_PoolChunkNumber
		mpush	ebx,ecx,edx,edi

		; Find the start of page, which is our pool descriptor
		mov	ebx,esi		
		and	ebx,PGENTRY_ADDRMASK
		mov	edx,ebx				; EDX=pool desc. address
		mov	ebx,[edx+tPoolDesc.Master]	; EBX=master pool addr.

		; Find out what is a pool number for requested chunk
		mov	edi,[ebx+tMasterPool.Pools]
		or	edi,edi
		jz	.Err1
		xor	ecx,ecx
.Loop:		cmp	edi,edx				; Is is our pool?
		je	.Found
		inc	ecx
		mov	edi,[edi+tPoolDesc.Next]
		or	edi,edi
		jnz	.Loop

		; Error: the chunk doesn't belong to any pool
		mov	eax,ERR_PoolNotFound
		stc
		jmp	.Exit

		; We have found the pool number (it's in ECX).
		; Chunk number is:
		;  (pool_number * chunks_per_pool) + chunk_num_inside_pool
.Found:		mov	eax,[edi+tPoolDesc.ChunksTotal]
		mul	ecx
		mov	ecx,eax
		mov	eax,esi
		sub	eax,edi
		sub	eax,byte tPoolDesc_size
		div	dword [edi+tPoolDesc.ChunkSize]
		add	eax,ecx
		clc

.Exit:		mpop	edi,edx,ecx,ebx
		ret

.Err1:		mov	ax,ERR_PoolFreeNoHead
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; K_PoolChunkAddr - get a chunk address by its number.
		; Input: EBX=master pool address,
		;	 EAX=chunk number.
		; Output: CF=0 - OK, ESI=chunk address;
		;	  CF=1 - error, AX=error code.
proc K_PoolChunkAddr
		mpush	ecx,edx
		mov	esi,[ebx+tMasterPool.Pools]
		or	esi,esi
		jz	.Err1

		; Calculate pool number (and chunk number inside its pool)
		xor	edx,edx
		div	dword [esi+tPoolDesc.ChunksTotal]
		cmp	eax,[ebx+tMasterPool.Count]
		jae	.Err2

		; Find our pool walking through the pool list
		xor	ecx,ecx
.Loop:		cmp	eax,ecx
		je	.Found
		inc	ecx
		mov	esi,[esi+tPoolDesc.Next]
		or	esi,esi
		jnz	.Loop

		; Error: the chunk doesn't belong to any pool (weird case)
		mov	eax,ERR_PoolNotFound
		stc
		jmp	.Exit

		; Pool is found. Calculate chunk address
.Found:		mov	eax,edx
		mul	dword [ebx+tMasterPool.Size]
		lea	esi,[esi+eax+tPoolDesc_size]

		; If this chunk is marked with signature - error
		mov	eax,[ebx+tMasterPool.Signature]
		cmp	eax,[esi+4]
		je	.Err2
		clc

.Exit:		mpop	edx,ecx
		ret
		
.Err1:		mov	ax,ERR_PoolFreeNoHead
		stc
		jmp	.Exit

.Err2:		mov	ax,ERR_PoolBadChunkNum
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------
