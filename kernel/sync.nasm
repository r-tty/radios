;*******************************************************************************
; sync.nasm - synchronization primitives (semaphores, mutexes, condvars, etc).
; Copyright (c) 2003 RET & COM Research.
; Portions are based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.sync

%include "errors.ah"
%include "sync.ah"
%include "pool.ah"
%include "thread.ah"
%include "tm/process.ah"

exportproc K_SemP, K_SemV
publicproc sys_SyncTypeCreate, sys_SyncDestroy, sys_SyncCtl
publicproc sys_SyncMutexLock, sys_SyncMutexUnlock, sys_SyncMutexRevive
publicproc sys_SyncCondvarWait, sys_SyncCondvarSignal
publicproc sys_SyncSemPost, sys_SyncSemWait

externproc MT_ThreadSleep, MT_ThreadWakeup
externproc MT_Schedule
externproc K_PoolAllocChunk, K_PoolFreeChunk
externproc BZero
externdata ?CurrThread


section .bss

?SyncPool	RESB	tMasterPool_size


section .text

		; K_SyncInit - initialize synchronization object pool.
		; Input: EAX=maximum number of synchronization objects.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_SyncInit
		ret
endp		;---------------------------------------------------------------


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


; --- Synchronizaton system calls ----------------------------------------------


		; int SyncTypeCreate(uint type, sync_t *sync,
		;			const struct _sync_attr_t *attr);
proc sys_SyncTypeCreate
		arg	type, sync, attr
		prologue

		; Allocate a syncobj descriptor and zero it
		mov	ebx,?SyncPool
		call	K_PoolAllocChunk
		jc	.Again
		mov	ebx,esi
		mov	ecx,tSyncDesc_size
		call	BZero

		; Syncobj is considered to be owned by a calling process
		mCurrThread
		mov	eax,[eax+tTCB.PCB]
		mov	[esi+tSyncDesc.PCB],eax
		mEnqueue dword [eax+tProcDesc.SyncList], Next, Prev, esi, tSyncDesc, ecx

		; Return success
		xor	eax,eax

.Exit:		epilogue
		ret

.Again:		mov	eax,-EAGAIN
		jmp	.Exit		
endp		;---------------------------------------------------------------


proc sys_SyncDestroy
		ret
endp		;---------------------------------------------------------------


proc sys_SyncMutexLock
		ret
endp		;---------------------------------------------------------------


proc sys_SyncMutexUnlock
		ret
endp		;---------------------------------------------------------------


proc sys_SyncMutexRevive
		ret
endp		;---------------------------------------------------------------


proc sys_SyncCondvarWait
		ret
endp		;---------------------------------------------------------------


proc sys_SyncCondvarSignal
		ret
endp		;---------------------------------------------------------------


proc sys_SyncSemPost
		ret
endp		;---------------------------------------------------------------


proc sys_SyncSemWait
		ret
endp		;---------------------------------------------------------------


proc sys_SyncCtl
		ret
endp		;---------------------------------------------------------------
