;*******************************************************************************
;  pool.as - routines for manipulations with the memory "pools".
;  Copyright (c) 2000 RET & COM Research.
;  This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.pool

%include "errors.ah"
%include "sema.ah"
%include "pool.ah"
%include "x86/paging.ah"


; --- Exports ---

global K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk


; --- Imports ---

library kernel.paging
extern PG_Alloc:near, PG_Dealloc:near

library kernel.semaphore
extern K_SemP:near, K_SemV:near


; --- Variables ---

section .bss

?PoolCount	RESD	1
?PoolPageCount	RESD	1		; Count total pages used by pools


; --- Code ---

section .text

		; K_PoolInit - initialize the master pool.
		; Input: EBX=address of the master pool,
		;	 ECX=chunk size,
		;	 EDX=flags.
		; Output: none.
proc K_PoolInit
		xor	eax,eax
		mov	[ebx+tMasterPool.Pools],eax
		mov	[ebx+tMasterPool.Hint],eax
		mov	[ebx+tMasterPool.Count],eax
		mov	[ebx+tMasterPool.Size],ecx
		mov	[ebx+tMasterPool.Flags],edx
		push	ebx
		lea	ebx,[ebx+tMasterPool.SemLock]
		mSemInit ebx
		pop	ebx
		inc	dword [?PoolCount]
		clc
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
		jc	short .Done
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
		; trailing with null.
		pop	esi				; ESI=free list head
		dec	ecx				; ECX=chunks-1
		jz	short .TrailNULL
.Loop:		lea	ebx,[esi+edx]
		mov	[esi],ebx
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

		lea	ebx,[esi+tMasterPool.SemLock]	; Lock master pool
		call	K_SemP
		
		; First check if "bucket alloc" flag is set. If so - 
		; immediately allocate new pool.
		test	dword [esi+tMasterPool.Flags],POOLFL_BUCKETALLOC
		jnz	short .AllocPool

		; Now check if hint is valid. If not, go through pool list
		; to find one containing some free chunks
		; If no pools with free space, get a new one.
		; Always update hint for future use
		mov	edx,[esi+tMasterPool.Hint]
		or	edx,edx
		jz	short .FindHint
		cmp	dword [edx+tPoolDesc.FreeHead],0
		jnz	short .HintOK

.FindHint:	mov	ebx,[esi+tMasterPool.Pools]
.FindHintLoop:	or	ebx,ebx
		jz	short .AllocPool
		cmp	dword [ebx+tPoolDesc.FreeHead],0
		jne	short .GotHint
		mov	ebx,[ebx+tPoolDesc.Next]
		jmp	short .FindHintLoop
.GotHint:	mov	[esi+tMasterPool.Hint],ebx
		mov	edx,ebx
		jmp	short .HintOK

.AllocPool:	mov	ebx,esi
		mov	edx,esi				; Save master pool addr
		call	K_PoolNew
		jc	short .Done
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
		test	dword [esi+tMasterPool.Flags],POOLFL_BUCKETALLOC
		jz	short .Finish
		mov	ecx,[edx+tPoolDesc.ChunksFree]
		inc	ecx
		
.Finish:	mov	edx,ebx
		lea	ebx,[esi+tMasterPool.SemLock]	; Unlock master pool
		call	K_SemV

		mov	esi,edx				; Return chunk addr
		xor	eax,eax				; All OK

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

		lea	ebx,[esi+tMasterPool.SemLock]	; Lock master pool
		call	K_SemP

		; Free this chunk
		mov	eax,[edx+tPoolDesc.FreeHead]
		mov	[edi],eax
		mov	[edx+tPoolDesc.FreeHead],edi
		dec	dword [edx+tPoolDesc.ChunksFree]

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
		jmp	short .FindHeadLoop

.Unlink:	mov	eax,[edx+tPoolDesc.Next]
		mov	[ebx+tPoolDesc.Next],eax
		xor	edi,edi				; No errors

		; Decrease the count and free memory of this pool.
.FreePage:	dec	dword [esi+tMasterPool.Count]
		mov	eax,edx
		call	PG_Dealloc
		dec	dword [?PoolPageCount]

.Unlock:	lea	ebx,[esi+tMasterPool.SemLock]	; Unlock master pool
		call	K_SemV

		mov	ax,di				; Error code
		shl	edi,1				; and carry flag
		
.Done:		mpop	edi,edx,ebx
		ret

.Err:		mov	edi,(1<<16)+ERR_KPoolFreeNoHead	; Carry flag + errcode
		jmp	short .FreePage
endp		;---------------------------------------------------------------

