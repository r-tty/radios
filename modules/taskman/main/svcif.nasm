;-------------------------------------------------------------------------------
; svcif.nasm - ring0 syscall routines.
;-------------------------------------------------------------------------------

module tm.svcif

%include "pool.ah"
%include "tm/svcif.ah"

publicproc PoolInit, PoolAllocChunk, PoolFreeChunk
publicproc PoolChunkNumber, PoolChunkAddr
publicproc PageAlloc, PageDealloc

section .text

		; Initialize a pool.
		; Input: EBX=master pool address,
		;	 ECX=chunk size.
		; Output: none.
proc PoolInit
		mov	dl,POOLFL_HIMEM
		mRing0call R0_PoolInit
		ret
endp		;---------------------------------------------------------------


		; Allocate a chunk from the pool.
		; Input: EBX=master pool address,
		; Output: CF=0 - OK, ESI=chunk address;
		;	  CF=1 - error, AX=error code.
proc PoolAllocChunk
		mRing0call R0_PoolAllocChunk
		ret
endp		;---------------------------------------------------------------


		; Deallocate a chunk from the pool.
		; Input: ESI=chunk address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PoolFreeChunk
		mRing0call R0_PoolFreeChunk
		ret
endp		;---------------------------------------------------------------


		; Get a chunk number by its address
proc PoolChunkNumber
		mRing0call R0_PoolChunkNumber
		ret
endp		;---------------------------------------------------------------


		; Get a chunk address by its number
proc PoolChunkAddr
		mRing0call R0_PoolChunkAddr
		ret
endp		;---------------------------------------------------------------


		; Allocate a page of physical memory.
proc PageAlloc
		mRing0call R0_PageAlloc
		ret
endp		;---------------------------------------------------------------


		; Deallocate a page of physical memory.
proc PageDealloc
		mRing0call R0_PageDealloc
		ret
endp		;---------------------------------------------------------------
