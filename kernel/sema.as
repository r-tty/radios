;*******************************************************************************
;  sema.as - semaphore operations.
;  Based upon the TINOS Operating System (c) 1996-1998 Bart Sekura.
;  RadiOS porting by Yuri Zaporogets.
;*******************************************************************************

module kernel.semaphore

; --- Exports ---

global K_SemP, K_SemV


; --- Imports ---

library kernel.mt
extern ?CurrThread
extern MT_ThreadSleep:near, MT_ThreadWakeup:near
extern MT_Schedule:near

%include "i386/setjmp.ah"
%include "thread.ah"
%include "sema.ah"

section .text

		; K_SemP - the "P" operation.
		; Input: EBX=address of semaphore structure.
		; Output: none.
proc K_SemP
		pushfd
		cli

		; Check the optimistic case first
		dec	dword [ebx+tSemaphore.Count]
		jc	.Sleep
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


