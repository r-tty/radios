;*******************************************************************************
; sync.nasm - synchronization primitives (semaphores, mutexes, condvars, etc).
; Copyright (c) 2000-2002 RET & COM Research.
; Portions are based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.sync

; --- Exports ---

publicproc K_SemP, K_SemV
publicproc sys_SyncTypeCreate
publicproc sys_SyncDestroy
publicproc sys_SyncMutexLock
publicproc sys_SyncMutexUnlock
publicproc sys_SyncCondvarWait
publicproc sys_SyncCondvarSignal
publicproc sys_SyncSemPost
publicproc sys_SyncSemWait
publicproc sys_SyncCtl
publicproc sys_SyncMutexRevive


; --- Imports ---

library kernel.mt
externdata ?CurrThread
externproc MT_ThreadSleep, MT_ThreadWakeup
externproc MT_Schedule

%include "thread.ah"
%include "sync.ah"

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


; --- Synchronizaton system calls ----------------------------------------------


proc sys_SyncTypeCreate
		ret
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


proc sys_SyncMutexRevive
		ret
endp		;---------------------------------------------------------------
