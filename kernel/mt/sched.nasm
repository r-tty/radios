;-------------------------------------------------------------------------------
; sched.nasm - RadiOS scheduler.
; Copyright (c) 2000 RET & COM Research.
; This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;-------------------------------------------------------------------------------

%include "timeout.ah"

%define	CNT_SHIFT	1		; CPU usage aging factor

publicproc K_SwitchTask, MT_Schedule
publicproc MT_SuspendCurr, MT_SuspendCurr1ms
publicdata ?CurrThread, ?TicksCounter

externproc K_SetJmp, K_LongJmp
externproc K_SemP, K_SemV
externproc K_LDelayMs
externdata KernTSS


section .bss

?SchedInClock	RESD	1	; Effectively solve nested clock interrupts
?TicksCounter	RESD	1	; Ticks counter

?CurrThread	RESD	1	; Pointer to the current running thread

?KernTicks	RESD	1	; Statistics
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


section .text

		; MT_ContextSwitch - switch context from current thread to
		;		     the one specified. Also switch address
		;		     space if needed.
		; Input: EBX=address of new TCB.
		; Output: none.
proc MT_ContextSwitch
		cmp	ebx,[?CurrThread]
		jne	.SetKstack
		ret
		
		; Set new kernel stack
.SetKstack:	mov	eax,[ebx+tTCB.KStack]
		mov	[KernTSS+tTSS.ESP0],eax

		; If new thread belongs to another process - switch
		; to its page directory and reload LDTR.
		; There may be kernel threads with PCB == 0. We don't
		; switch PD and don't touch LDTR for them.
		mov	eax,[?CurrThread]
		mov	esi,[ebx+tTCB.PCB]
		cmp	esi,[eax+tTCB.PCB]
		je	.UpdateFS
		or	esi,esi
		je	.NewContext
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax
		lldt	[esi+tProcDesc.LDTdesc]

		; Always keep FS pointing at thread info page segment
.UpdateFS:	mov	eax,[ebx+tTCB.TID]
		shl	eax,3
		or	al,SELECTOR_LDT | SELECTOR_RPL3
		mov	fs,eax

		; Warp out to a new context
.NewContext:	mov	[?CurrThread],ebx
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
		inc	dword [?SchedTick]
		inc	dword [?SchedRecalcs]

		; Go through the list of ready threads.
		; Age current CPU usage and recalculate new priority.
		mpush	ebx,ecx
		mov	ebx,[?ReadyThrList]
		pushfd
		cli

.Walk:		mov	ebx,[ebx+tTCB.Next]
		cmp	ebx,[?ReadyThrList]
		je	.Done
		shr	dword [ebx+tTCB.Count],CNT_SHIFT

		; Calculate new priority if thread priority class is NORMAL
		cmp	byte [ebx+tTCB.PrioClass],THRPRCL_NORMAL
		jne	.Walk
		mov	eax,[ebx+tTCB.Priority]
		mov	ecx,[ebx+tTCB.Count]
		shr	ecx,1
		sub	eax,ecx
		jge	.SetPrio
		xor	eax,eax
.SetPrio:	mov	[ebx+tTCB.CurrPriority],eax
		jmp	.Walk

		; Periodically, we should check for starving threads.
		; tTCB.Stamp gets updated with current ?SchTicksCnt every
		; time scheduler chooses this TCB to run. It's easy to
 		; check then whether the thread is almost dead - its stamp
 		; differs substantially from current ?SchTicksCnt.

.Done:		popfd
		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_Schedule - main scheduler routine.
		; Input: none.
		; Output: none.
proc MT_Schedule
		mpush	ecx,edx,edi
		pushfd
		cli

		mov	ebx,[?CurrThread]

		; Calculate new priority if thread priority class is NORMAL
		cmp	byte [ebx+tTCB.PrioClass],THRPRCL_NORMAL
		jne	.Sched
		mov	eax,[ebx+tTCB.Priority]
		mov	ecx,[ebx+tTCB.Count]
		shr	ecx,1
		sub	eax,ecx
		jge	.SetPrio
		xor	eax,eax
.SetPrio:	mov	[ebx+tTCB.CurrPriority],eax

.Sched:		xor	eax,eax
		not	eax
		mov	ebx,[?ReadyThrList]
		mov	edx,ebx

.Walk:		mov	ebx,[ebx+tTCB.ReadyNext]
		cmp	ebx,[?ReadyThrList]
		je	.ChkQuantum
		cmp	[ebx+tTCB.CurrPriority],eax
		jle	.Walk
		mov	eax,[ebx+tTCB.CurrPriority]
		mov	edx,ebx
		jmp	.Walk

.ChkQuantum:	mov	eax,[?SchedTick]
		mov	[edx+tTCB.Stamp],eax

		cmp	dword [edx+tTCB.Quant],0
		jg	.SaveCtx
		; Quantum decreases when the number of
		; running threads increases treshold is 8 (2^3)
		mov	eax,THRQUANT_DEFAULT
		mov	ecx,[?ReadyThrCnt]
		shr	ecx,3
		sub	eax,ecx
		add	[edx+tTCB.Quant],eax
		cmp	dword [edx+tTCB.Quant],THRQUANT_MIN
		jge	.SaveCtx
		mov	dword [edx+tTCB.Quant],THRQUANT_MIN

.SaveCtx:	cmp	edx,[?CurrThread]
		je	.IncReturns
		mov	dword [?SchedInClock],0
		
		; Save context of current thread
		mov	ebx,[?CurrThread]
		lea	edi,[ebx+tTCB.Context]
		call	K_SetJmp
		or	eax,eax
		jnz	.Done

		; Switch to next
		mov	ebx,edx
		call	MT_ContextSwitch

.IncReturns:	inc	dword [?CurReturns]

.Done:		popfd
		mpop	edi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; MT_BumpTime - record some time related statistics.
		; Input: EBX=address of stack frame.
		; Output: none.
proc MT_BumpTime
		inc	dword [?SchedTimer]
		add	dword [?SchedMicroSec],10000
		cmp	dword [?SchedMicroSec],1000000
		jb	.1
		sub	dword [?SchedMicroSec],1000000
		inc	dword [?SchedSeconds]

.1:		mov	eax,[?CurrThread]
		inc	dword [eax+tTCB.Ticks]
		mov	al,[ebx+tStackFrame.ECS]
		and	al,SELECTOR_RPL3
		jz	.Kernel
		inc	dword [?UserTicks]
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
		arg	frame
		prologue

		; If multitasking isn't yet initialized - just leave
		cmp	dword [?CurrThread],0
		je	near .Exit
		
		; Bail out if reentered
		cmp	dword [?SchedInClock],0
		je	.CntTicks
		inc	dword [?NestedClocks]
		jmp	.Exit

		; Count the ticks
.CntTicks:	inc	dword [?TicksCounter]
		mov	dword [?SchedInClock],1
		sti
		lea	ebx,[%$frame]			; EBX=address of frame
		call	MT_BumpTime

		; Increase CPU usage and decrease quantum
		mov	ebx,[?CurrThread]
		cmp	ebx,[?ReadyThrList]
		je	.DecQuantum
		inc	dword [ebx+tTCB.Count]
.DecQuantum:	dec	dword [ebx+tTCB.Quant]

		; Need to age CPU usage?
		cmp	dword [?SchedTimer],100
		jb	.ChkTimeout
		call	MT_SchedAging
		mov	dword [?SchedTimer],0

.ChkTimeout:	call	MT_CheckTimeout

		cmp	dword [ebx+tTCB.Quant],0
		jle	.Schedule
		dec	dword [?SchedPreempt]
		jz	.Done
.Schedule:	call	MT_Schedule

.Done:		cli
		mov	dword [?SchedInClock],0
.Exit:		epilogue
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
		mEnqueue dword [?TimeoutQue], Next, Prev, ebx, tTimeout, ecx
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
		je	.Init
		add	ebx,tTimeout_size
		loop	.HuntLoop
		jmp	.NoSpace

		; Initialize this timeout.
		; Set its ticks value to current system ticks plus
		; the amount of ticks it wants to wait; makes searching
		; the timeout queue easier.
.Init:		mov	byte [ebx+tTimeout.State],TM_ST_ALLOC
		add	eax,[?TicksCounter]
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
		ja	.Insert
		mov	edx,[edx+tTimeout.Next]
		jmp	.SearchLoop

		; Insert this one before the one found above.
.Insert:	mov	[ebx+tTimeout.Next],edx
		mov	eax,[edx+tTimeout.Prev]
		mov	[ebx+tTimeout.Prev],eax
		mov	[eax+tTimeout.Next],ebx
		mov	[edx+tTimeout.Prev],ebx
		cmp	edx,[?TimeoutQue]
		jne	.1
		mov	[edx+tTimeout.Prev],ebx

.1:		popfd
		; Now actually wait for the timeout to elapse
		; we have previously initialized the semaphore
		; to non-singnaled state, so we block here
		lea	eax,[ebx+tTimeout.Sem]
		call	K_SemP
		ret

.NoSpace:	popfd
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
.ChkLoop:	mov	eax,[?TicksCounter]
		cmp	eax,[edx+tTimeout.Ticks]
		jb	.Done
		lea	eax,[edx+tTimeout.Sem]
		call	K_SemV
		mDequeue dword [?TimeoutQue], Next, Prev, edx, tTimeout, ebx
		mov	edx,[edx+tTimeout.Next]
		jmp	.ChkLoop
		
.Done:		popfd
		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_SuspendCurr - suspend current thread on given interval.
		; Input: ECX=interval in ms.
		; Output:none.
proc MT_SuspendCurr
		push	ecx
		call	K_LDelayMs
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; MT_SuspendCurr1ms - suspend current thread on 1 millisecond.
		; Input: none.
		; Output:none.
proc MT_SuspendCurr1ms
		push	ecx
		mov	ecx,1
		call	K_LDelayMs
		pop	ecx
		ret
endp		;---------------------------------------------------------------


;--- Debugging stuff -----------------------------------------------------------

%ifdef MTDEBUG

publicproc MT_PrintSchedStat

section .data
TxtNested	DB	NL,"Nested clocks: ",0
TxtAdjusts	DB	NL,"Sched adjusts: ",0
TxtRecalcs	DB	NL,"Sched recalcs: ",0
TxtCurrRets	DB	NL,"Current returns: ",0
TxtKernTicks	DB	NL,"Kernel ticks: ",0
TxtDrvTicks	DB	NL,"Driver ticks: ",0
TxtUserTicks	DB	NL,"User ticks: ",0
TxtTicksCnt	DB	NL,"Ticks counter: ",0
TxtSysUptime	DB	NL,NL,"System uptime: ",0
TxtSeconds	DB	" seconds",0

section .text

		; MT_PrintSchedStat - print scheduler statistics.
		; Input: none.
		; Output: none.
proc MT_PrintSchedStat
		mPrintString TxtNested
		mov	eax,[?NestedClocks]
		call	PrintDwordDec
		mPrintString TxtAdjusts
		mov	eax,[?SchedAdjusts]
		call	PrintDwordDec
		mPrintString TxtRecalcs
		mov	eax,[?SchedRecalcs]
		call	PrintDwordDec
		mPrintString TxtCurrRets
		mov	eax,[?CurReturns]
		call	PrintDwordDec
		mPrintString TxtKernTicks
		mov	eax,[?KernTicks]
		call	PrintDwordDec
		mPrintString TxtDrvTicks
		mov	eax,[?DrvTicks]
		call	PrintDwordDec
		mPrintString TxtUserTicks
		mov	eax,[?UserTicks]
		call	PrintDwordDec
		mPrintString TxtTicksCnt
		mov	eax,[?TicksCounter]
		call	PrintDwordDec

		mPrintString TxtSysUptime
		mov	eax,[?SchedSeconds]
		call	PrintDwordDec
		mPrintString TxtSeconds
		ret
endp		;---------------------------------------------------------------

%endif

