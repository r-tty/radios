;-------------------------------------------------------------------------------
; svcif.nasm - ring0 syscall routines.
;-------------------------------------------------------------------------------

module tm.svcif

%include "pool.ah"
%include "tm/svcif.ah"

publicproc HashAdd, HashLookup, HashRelease
publicproc PoolInit, PoolAllocChunk, PoolFreeChunk
publicproc PoolChunkNumber, PoolChunkAddr
publicproc PageAlloc, PageDealloc
publicproc CopyToAct, CopyFromAct
publicproc RegisterLDT, UnregisterLDT
publicproc CloneConnections

section .text

		; Hash something.
		; Input: EAX=identifier,
		;	 EBX=key,
		;	 ESI=hash table address,
		;	 EDI=data pointer.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc HashAdd
		mRing0call SVCF_HashAdd
		ret
endp		;---------------------------------------------------------------


		; Search in the hash table.
		; Input: EAX=identifier,
		;	 EBX=key,
		;	 ESI=table address.
		; Output: CF=0 - element found:
		;		  EDX=table slot address,
		;		  EDI=element address;
		;	  CF=1 - element not found.
proc HashLookup
		mRing0call SVCF_HashLookup
		ret
endp		;---------------------------------------------------------------


		; Release the hash element.
		; Input: EDX=table slot address,
		;	 EDI=element address.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error.
proc HashRelease
		mRing0call SVCF_HashRelease
		ret
endp		;---------------------------------------------------------------


		; Initialize a pool.
		; Input: EBX=master pool address,
		;	 ECX=chunk size.
		; Output: none.
proc PoolInit
		mov	dl,POOLFL_HIMEM
		mRing0call SVCF_PoolInit
		ret
endp		;---------------------------------------------------------------


		; Allocate a chunk from the pool.
		; Input: EBX=master pool address,
		; Output: CF=0 - OK, ESI=chunk address;
		;	  CF=1 - error, AX=error code.
proc PoolAllocChunk
		mRing0call SVCF_PoolAllocChunk
		ret
endp		;---------------------------------------------------------------


		; Deallocate a chunk from the pool.
		; Input: ESI=chunk address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PoolFreeChunk
		mRing0call SVCF_PoolFreeChunk
		ret
endp		;---------------------------------------------------------------


		; Get a chunk number by its address
proc PoolChunkNumber
		mRing0call SVCF_PoolChunkNumber
		ret
endp		;---------------------------------------------------------------


		; Get a chunk address by its number
proc PoolChunkAddr
		mRing0call SVCF_PoolChunkAddr
		ret
endp		;---------------------------------------------------------------


		; Allocate a page of physical memory.
proc PageAlloc
		mRing0call SVCF_PageAlloc
		ret
endp		;---------------------------------------------------------------


		; Deallocate a page of physical memory.
proc PageDealloc
		mRing0call SVCF_PageDealloc
		ret
endp		;---------------------------------------------------------------


		; Copy from active address space.
proc CopyFromAct
		mRing0call SVCF_CopyFromAct
		ret
endp		;---------------------------------------------------------------


		; Copy to active address space.
proc CopyToAct
		mRing0call SVCF_CopyToAct
		ret
endp		;---------------------------------------------------------------


		; Register a LDT.
proc RegisterLDT
		mRing0call SVCF_RegisterLDT
		ret
endp		;---------------------------------------------------------------


		; Unregister a LDT.
proc UnregisterLDT
		mRing0call SVCF_UnregisterLDT
		ret
endp		;---------------------------------------------------------------


		; Clone the connection descriptors.
proc CloneConnections
		mRing0call SVCF_CloneConnections
		ret
endp		;---------------------------------------------------------------
