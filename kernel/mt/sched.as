;-------------------------------------------------------------------------------
;  sched.as - RadiOS scheduler.
;  This code is based on the TINOS Operating System (c) 1998 Bart Sekura.
;-------------------------------------------------------------------------------

%include "timeout.ah"

; --- Exports ---

global K_SwitchTask
global MT_Schedule
global ?CurrThread


; --- Constants ---

%define	CNT_SHIFT	1		; CPU usage aging factor


; --- Imports ---

library kernel
extern KernTSS
extern K_PopUp:near

library kernel.setjmp
extern K_SetJmp:near, K_LongJmp:near

library kernel.semaphore
extern K_SemP:near, K_SemV: near

; --- Data ---

section .data

MsgSwToCurr	DB	":SCHEDULER:MT_ContextSwitch: switching to current thread",0
MsgNoMoreTmQ	DB	":SCHEDULER:MT_SetTimeout: no more space in the queue",0


; --- Variables ---

section .bss

?SchedInClock	RESD	1	; Effectively solve nested clock interrupts
?SchedTicksCnt	RESD	1	; Ticks counter

?CurrThread	RESD	1	; Pointer to the current running thread

?KernTicks	RESD	1	; Statistics
?DrvTicks	RESD	1
?UserTicks	RESD	1
?NestedClocks	RESD	1
?CurReturns	RESD	1
?SchedAdjusts	RESD	1
?SchedRecalcs	RESD	1

?SchedTimer	RESD	1	; Used to determine if a second passed
				; since we last ran CPU aging routine

?SchedTick	RESD	1	; How many times we ran the abovementioned
				; routine (also used to stamp threads when
 				; they're awarded a timeslice from scheduler
 				; to determine possible starvation)

?SchedMicroSec	RESD	1	; Time recording (microseconds, seconds)
?SchedSeconds	RESD	1

?SchedPreempt	RESD	1	; This may be set outside scheduler to indicate
				; that the current thread should be preempted,
				; even though its timeslice hasn't expired.
				; Because there are potentially more important
 				; threads hanging around waiting to be activated

?TimeoutQue	RESD	1	; Address of timeout queue
?TimeoutTrailer	RESB	tTimeout_size
?TimeoutPool	RESB	tTimeout_size*MAX_TIMEOUTS

; --- Code ---

section .text

		; MT_ContextSwitch - switch context from current thread to
		;		     the one specified. Also switch address
		;		     space if needed.
		; Input: EBX=address of new TCB.
		; Output: none.
proc MT_ContextSwitch
		cmp	ebx,[?CurrThread]
		jne	short .Switch
	%ifdef KPOPUPS
		push	esi
		mov	esi,MsgSwToCurr
		call	K_PopUp
		pop	esi
	%endif
		ret
		
.Switch:	mov	[?CurrThread],ebx		; New thread pointer
		mov	eax,[ebx+tTCB.KStack]		; Set new kernel stack
		mov	[KernTSS+tTSS.ESP0],eax
inc byte [0xb8000+158]
		inc	dword [ebx+tTCB.Preempt]
		lea	edi,[ebx+tTCB.Context]
		xor	eax,eax
		inc	al
		call	K_LongJmp
		ret
endp		;---------------------------------------------------------------


		; MT_SchedAging - age CPU usage periodically.
		;		  Currently called once per second
 		;		  from clock interrupt.
		; Input: none.
		; Output: none.
proc MT_SchedAging
		; Simple statistics
		inc	dword [?SchedTicksCnt]
		inc	dword [?SchedRecalcs]

		; Go through the list of ready threads.
		; Age current CPU usage and recalculate new priority.
		push	ebx
		mov	ebx,[?ReadyThrList]
		pushfd
		cli

.Walk:		mov	ebx,[ebx+tTCB.Next]
		cmp	ebx,[?ReadyThrList]
		je	.Done
		shr	byte [ebx+tTCB.Count],CNT_SHIFT

		; Calculate new priority if thread priority class is NORMAL
		cmp	byte [ebx+tTCB.PrioClass],THRPRCL_NORMAL
		jne	.Walk
		mov	al,[ebx+tTCB.Priority]
		mov	ah,[ebx+tTCB.Count]
		shr	ah,1
		sub	al,ah
		jge	short .SetPrio
		xor	al,al
.SetPrio:	mov	[ebx+tTCB.CurrPriority],al
		jmp	short .Walk

		; Periodically, we should check for starving threads.
		; tTCB.Stamp gets updated with current ?SchedTick every
		; time scheduler chooses this TCB to run. It's easy to
 		; check then whether the thread is almost dead - its stamp
 		; differs substantially from current ?SchedTick.

.Done:		popfd
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; MT_Schedule - main scheduler routine.
		; Input: none.
		; Output: none.
proc MT_Schedule
		mpush	edx,edi
		pushfd
		cli

		mov	ebx,[?CurrThread]

		; Calculate new priority if thread priority class is NORMAL
		cmp	byte [ebx+tTCB.PrioClass],THRPRCL_NORMAL
		jne	.Sched
		mov	al,[ebx+tTCB.Priority]
		mov	ah,[ebx+tTCB.Count]
		shr	ah,1
		sub	al,ah
		jge	.SetPrio
		xor	al,al
.SetPrio:	mov	[ebx+tTCB.CurrPriority],al

.Sched:		xor	al,al
		not	al
		mov	ebx,[?ReadyThrList]
		mov	edx,ebx

.Walk:		mov	ebx,[ebx+tTCB.Next]
		cmp	ebx,[?ReadyThrList]
		je	.ChkQuantum
		cmp	[ebx+tTCB.CurrPriority],al
		jbe	.Walk
		mov	al,[ebx+tTCB.CurrPriority]
		mov	edx,ebx
		jmp	short .Walk

.ChkQuantum:	mov	eax,[?SchedTick]
		mov	[edx+tTCB.Stamp],eax

		cmp	dword [edx+tTCB.Quant],0
		ja	.SaveCtx
		; Quantum decreases when the number of
		; running threads increases treshold is 8 (2^3)
		mov	eax,[?ReadyThrCnt]
		shr	eax,3
		mov	ebx,eax
		mov	eax,THRQUANT_DEFAULT
		sub	eax,ebx
		add	[edx+tTCB.Quant],eax
		cmp	dword [edx+tTCB.Quant],THRQUANT_MIN
		jae	.SaveCtx
		mov	dword [edx+tTCB.Quant],THRQUANT_MIN

.SaveCtx:	cmp	edx,[?CurrThread]
		je	.IncReturns
		mov	dword [?SchedInClock],0
		
		; Save context of current thread
		mov	ebx,[?CurrThread]
		push	dword [ebx+tTCB.Context]
		call	K_SetJmp
		or	al,al
		jnz	.Done

		; Switch to next
		mov	ebx,edx
		call	MT_ContextSwitch

.IncReturns:	inc	dword [?CurReturns]

.Done:		popfd
		mpop	edi,edx
		ret
endp		;---------------------------------------------------------------


		; MT_BumpTime - record some time related statistics.
		; Input: EBX=address of stack frame.
		; Output: none.
proc MT_BumpTime
		inc	dword [?SchedTimer]
		add	dword [?SchedMicroSec],10000
		cmp	dword [?SchedMicroSec],1000000
		jb	short .1
		sub	dword [?SchedMicroSec],1000000
		inc	dword [?SchedSeconds]

.1:		mov	eax,[?CurrThread]
		inc	dword [eax+tTCB.Ticks]
		mov	al,[ebx+tStackFrame.ECS]
		and	al,3
		jz	short .Kernel
		cmp	al,1
		je	short .Driver
		inc	dword [?UserTicks]
		ret

.Driver:	inc	dword [?DrvTicks]
		ret

.Kernel:	inc	dword [?KernTicks]
		ret
endp		;---------------------------------------------------------------


		; K_SwitchTask - task switching routine (called from timer
		;		 interrupt handler).
		; Input: thread frame must be on the stack.
		; Output: none.
		; Note:  Interrupts are disabled until we enable them
 		;	 explicitly.
proc K_SwitchTask
%define	.frame		ebp+8
		push	ebp
		mov	ebp,esp
		
		; Bail out if reentered
		cmp	dword [?SchedInClock],0
		je	short .CntTicks
		inc	dword [?NestedClocks]
		ret

		; Count the ticks
.CntTicks:	inc	dword [?SchedTicksCnt]
		mov	byte [?SchedInClock],1
		sti
		lea	ebx,[.frame]			; EBX=address of frame
		call	MT_BumpTime

		; Increase CPU usage and decrease quantum
		mov	ebx,[?CurrThread]
		cmp	ebx,[?ReadyThrList]
		je	short .DecQuantum
		inc	dword [ebx+tTCB.Count]
.DecQuantum:	dec	dword [ebx+tTCB.Quant]

		; Need to age CPU usage?
		cmp	dword [?SchedTimer],100
		jb	short .ChkTimeout
		call	MT_SchedAging
		mov	dword [?SchedTimer],0

.ChkTimeout:	call	MT_CheckTimeout

		cmp	dword [ebx+tTCB.Quant],0
		jle	short .Schedule
		dec	dword [?SchedPreempt]
		jz	short .Done
.Schedule:	call	MT_Schedule

.Done		cli
		mov	dword [?SchedInClock],0
		leave
		ret
endp		;---------------------------------------------------------------


		; MT_InitTimeout - initialize timeout pool.
		; Input: none.
		; Output: none.
proc MT_InitTimeout
		mov	ecx,MAX_TIMEOUTS
		mov	ebx,?TimeoutPool
.InitQLoop:	mov	byte [ebx+tTimeout.State],TM_ST_FREE
		add	ebx,tTimeout_size
		loop	.InitQLoop

		mov	ebx,?TimeoutTrailer
		mov	dword [ebx+tTimeout.Ticks],-1
		mov	byte [ebx+tTimeout.State],TM_ST_ALLOC

		; Enqueue trailer
		mEnqueue dword [?TimeoutQue], Next, Prev, ebx, tTimeout
		ret
endp		;---------------------------------------------------------------


		; MT_SetTimeout - set timeout.
		; Input: ECX=number of ticks.
		; Output: none.
proc MT_SetTimeout
		; We just hunt for free timeout slot.
		; Goin' do it when interrupts are disabled.
		pushfd
		cli
		mov	eax,ecx
		mov	ecx,MAX_TIMEOUTS
		mov	ebx,?TimeoutPool
.HuntLoop:	cmp	byte [ebx+tTimeout.State],TM_ST_FREE
		je	short .Init
		add	ebx,tTimeout_size
		loop	.HuntLoop
		jmp	short .NoSpace

		; Initialize this timeout.
		; Set its ticks value to current system ticks plus
		; the amount of ticks it wants to wait; makes searching
		; the timeout queue easier.
.Init:		mov	byte [ebx+tTimeout.State],TM_ST_ALLOC
		add	eax,[?SchedTicksCnt]
		mov	[ebx+tTimeout.Ticks],eax
		push	ebx
		lea	ebx,[ebx+tTimeout.Sem]
		mSemInit ebx
		xor	eax,eax
		mSemSetVal ebx
		pop	ebx

		; Go through the timeout queue until we reach
		; the one with higher timeout ticks than this one.
		; This results in having timeout queue sorted
		; by timeout ticks in ascending order.
		mov	edx,[?TimeoutQue]
.SearchLoop:	mov	eax,[ebx+tTimeout.Ticks]
		cmp	[edx+tTimeout.Ticks],eax
		ja	short .Insert
		mov	edx,[edx+tTimeout.Next]
		jmp	short .SearchLoop

		; Insert this one before the one found above.
.Insert:	mov	[ebx+tTimeout.Next],edx
		mov	eax,[edx+tTimeout.Prev]
		mov	[ebx+tTimeout.Prev],eax
		mov	[eax+tTimeout.Next],ebx
		mov	[edx+tTimeout.Prev],ebx
		cmp	edx,[?TimeoutQue]
		jne	short .1
		mov	[edx+tTimeout.Prev],ebx

.1:		popfd
		; Now actually wait for the timeout to elapse
		; we have previously initialized the semaphore
		; to non-singnaled state, so we block here
		lea	ebx,[ebx+tTimeout.Sem]
		call	K_SemP
		ret

.NoSpace:	push	esi
		mov	esi,MsgNoMoreTmQ
		call	K_PopUp
		pop	esi
		popfd
		ret
endp		;---------------------------------------------------------------


		; MT_CheckTimeout - go through timeouts queue and release
 		;		    those that expired.
		; Input: none.
		; Output: none.
proc MT_CheckTimeout
		mpush	ebx,edx
		pushfd
		cli
		
		mov	edx,[?TimeoutQue]
.ChkLoop:	mov	eax,[?SchedTicksCnt]
		cmp	eax,[edx+tTimeout.Ticks]
		jb	.Done
		lea	ebx,[edx+tTimeout.Sem]
		call	K_SemV
		mDequeue dword [?TimeoutQue], Next, Prev, edx, tTimeout
		mov	edx,[edx+tTimeout.Next]
		jmp	.ChkLoop
		
.Done:		popfd
		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------

