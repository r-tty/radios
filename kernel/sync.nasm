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
extern ?CurrThread
extern MT_ThreadSleep, MT_ThreadWakeup
extern MT_Schedule

%include "thread.ah"
%include "sync.ah"

section .text

		; K_SemP - the "P" operation.
		; Input: EBX=address of semaphore structure.
		; Output: none.
proc K_SemP
		pushfd
		cli

		; Check the optimistic case first
		dec	dword [ebx+tSemaphore.Count]
		js	.Sleep
		popfd
		ret

		; Enqueue current thread under the semaphore
		; and put him to bed :)
.Sleep:		mov	eax,[?CurrThread]
		mSemEnq ebx,eax
		push	ebx
		mov	ebx,eax
		call	MT_ThreadSleep
		inc	dword [ebx+tTCB.SemWait]
		pop	ebx
		popfd
		call	MT_Schedule
		ret
endp		;---------------------------------------------------------------


		; K_SemV - the "V" operation.
		; Input: EBX=address of semaphore structure.
		; Output: none.
proc K_SemV
		pushfd
		cli

		; If no threads kept, quickly bail out
		inc	dword [ebx+tSemaphore.Count]
		cmp	dword [ebx+tSemaphore.WaitQ],0
		je	.Done

		; Dequeue thread from under the semaphore
		; and let it be woken up next timeslice
		mov	eax,[ebx+tSemaphore.WaitQ]
		mSemDeq ebx,eax
		push	ebx
		mov	ebx,eax
		call	MT_ThreadWakeup
		pop	ebx
		
.Done:		popfd
		ret
endp		;---------------------------------------------------------------


; --- Syncronizaton system calls -----------------------------------------------

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
