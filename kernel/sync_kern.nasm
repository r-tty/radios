;*******************************************************************************
; sync_kern.nasm - kernel synchronization primitives.
; Copyright (c) 2003 RET & COM Research.
; Portions are based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.sync.kern

%include "sys.ah"
%include "errors.ah"
%include "sync.ah"
%include "pool.ah"
%include "hash.ah"
%include "thread.ah"

exportproc K_SemP, K_SemV

externproc MT_ThreadSleep, MT_ThreadWakeup, MT_Schedule
externproc K_PoolAllocChunk, K_PoolFreeChunk
externproc BZero
externdata ?CurrThread


section .text

		; K_SemP - the "P" operation (decrement and sleep if negative).
		; Input: EAX=address of semaphore structure.
		; Output: none.
proc K_SemP
		pushfd
		cli

		; Check the optimistic case first
		dec	dword [eax+tSemaphore.Count]
		js	.Sleep
		popfd
		ret

		; Enqueue current thread under the semaphore and suspend it
.Sleep:		push	ebx
		mov	ebx,[?CurrThread]
		mSemEnq eax,ebx
		mov	al,THRSTATE_SEM
		call	MT_ThreadSleep
		inc	dword [ebx+tTCB.SemWait]
		pop	ebx
		popfd
		call	MT_Schedule
		ret
endp		;---------------------------------------------------------------


		; K_SemV - the "V" operation (increase and wake up waiting thread).
		; Input: EAX=address of semaphore structure.
		; Output: none.
proc K_SemV
		pushfd
		cli

		; If no threads kept, quickly bail out
		inc	dword [eax+tSemaphore.Count]
		cmp	dword [eax+tSemaphore.WaitQ],0
		je	.Done

		; Dequeue thread from under the semaphore
		; and let it be woken up next timeslice
		push	ebx
		mov	ebx,[eax+tSemaphore.WaitQ]
		mSemDeq eax,ebx
		call	MT_ThreadWakeup
		pop	ebx
		
.Done:		popfd
		ret
endp		;---------------------------------------------------------------


		; K_MutexEnter - acquire a mutex.
		; Input: EAX=address of mutex structure.
		; Output:
proc K_MutexEnter
		ret
endp		;---------------------------------------------------------------


		; K_MutexExit - release a mutex.
		; Input: EAX=address of mutex structure.
		; Output:
proc K_MutexExit
		ret
endp		;---------------------------------------------------------------


		; K_MutexTryEnter - try to acuqire a mutex.
		; Input: EAX=address of mutex structure.
		; Output:
proc K_MutexTryEnter
		ret
endp		;---------------------------------------------------------------


		; K_MutexOwned - check if a mutex is owned by the current thread.
		; Input: EAX=address of mutex structure.
		; Output:
proc K_MutexOwned
		ret
endp		;---------------------------------------------------------------


		; K_RWenter - acquire a R/W lock.
		; Input: EAX=address of lock structure,
		;	 DL=lock type.
		; Output:
proc K_RWenter
		ret
endp		;---------------------------------------------------------------


		; K_RWexit - release a R/W lock.
		; Input: EAX=address of lock structure.
		; Output:
proc K_RWexit
		ret
endp		;---------------------------------------------------------------


		; K_RWtryEnter - try to acquire a R/W lock.
		; Input: EAX=address of lock structure,
		;	 DL=lock type.
		; Output:
proc K_RWtryEnter
		ret
endp		;---------------------------------------------------------------


		; K_RWdowngrade - downgrade a R/W lock to read-only.
		; Input: EAX=address of lock structure.
		; Output:
proc K_RWdowngrade
		ret
endp		;---------------------------------------------------------------


		; K_RWtryUpgrade - try to upgrade a R/W lock to read-write.
		; Input: EAX=address of lock structure.
		; Output:
proc K_RWtryUpgrade
		ret
endp		;---------------------------------------------------------------
