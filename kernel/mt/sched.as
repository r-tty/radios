;-------------------------------------------------------------------------------
;  sched.as - RadiOS scheduler.
;  This code is based on the TINOS Operating System (c) 1998 Bart Sekura.
;-------------------------------------------------------------------------------

; --- Exports ---

global K_SwitchTask
global MT_Schedule


; --- Constants ---

%define	CNT_SHIFT	1		; CPU usage aging factor


; --- Imports ---

extern KernTSS
extern K_PopUp:near

library kernel.setjmp
extern K_SetJmp:near, K_LongJmp:near

; --- Data ---

MsgSwToCurr	DB	":SCHEDULER:MT_ContextSwitch: switching to current thread",0


; --- Variables ---

section .data

K_SchInClock	RESD	1	; Effectively solve nested clock interrupts
K_SchTicksCnt	RESD	1	; Ticks counter

K_CurrThrPtr	RESD	1	; Pointer to the current running thread

K_KernTicks	RESD	1	; Statistics
K_DrvTicks	RESD	1
K_UserTicks	RESD	1
K_NestedClocks	RESD	1
K_CurReturns	RESD	1
K_SchedAdjusts	RESD	1
K_SchedRecalcs	RESD	1

K_SchedTimer	RESD	1	; Used to determine if a second passed
				; since we last ran cpu aging routine

K_SchedTick	RESD	1	; How many times we ran the abovementioned
				; routine (also used to stamp threads when
 				; they're awarded a timeslice from scheduler
 				; to determine possible starvation)

K_SchMicroSec	RESD	1	; Time recording (microseconds, seconds)
K_SchSeconds	RESD	1

K_SchedPreempt	RESD	1	; This may be set outside scheduler to indicate
				; that the current thread should be preempted,
				; even though its timeslice hasn't expired.
				; Because there are potentially more important
 				; threads hanging around waiting to be activated


; --- Code ---

section .text

		; MT_ContextSwitch - switch context from current thread to
		;		     the one specified. Also switch address
		;		     space if needed.
		; Input: EBX=address of new TCB.
		; Output: none.
proc MT_ContextSwitch
		cmp	ebx,K_CurrThrPtr
		jne	.Switch
		push	esi
		mov	esi,MsgSwToCurr
		call	K_PopUp
		pop	esi
		ret
		
.Switch:	mov	[K_CurrThrPtr],ebx		; New thread pointer
		mov	eax,[ebx+tTCB.KStack]		; Set new kernel stack
		mov	[KernTSS+tTSS.ESP0],eax

		inc	dword [ebx+tTCB.Preempt]
		lea	ebx,[ebx+tTCB.Context]
		mov	al,1
		call	K_LongJmp
		ret
endp		;---------------------------------------------------------------


		; MT_SchedAging - age cpu usage periodically.
		;		  Currently called once per second
 		;		  from clock interrupt.
		; Input: none.
		; Output: none.
proc MT_SchedAging
		; Simple statistics
		inc	dword [K_SchTicksCnt]
		inc	dword [K_SchedRecalcs]

		; Go through the list of ready threads.
		; Age current cpu usage and recalculate new priority.
		mov	ebx,[MT_ReadyThrLst]
		pushfd
		cli

.Walk:		mov	ebx,[ebx+tTCB.Next]
		cmp	ebx,[MT_ReadyThrLst]
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
		; tTCB.Stamp gets updated with current K_SchedTick every
		; time scheduler chooses this TCB to run. It's easy to
 		; check then whether the thread is almost dead - its stamp
 		; differs substantially from current K_SchedTick.

.Done:		popfd
		ret
endp		;---------------------------------------------------------------


		; MT_Schedule - main scheduler routine.
		; Input: none.
		; Output: none.
proc MT_Schedule
		push	edx
		pushfd
		cli

		mov	ebx,[K_CurrThrPtr]

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
		mov	ebx,[MT_ReadyThrLst]
		mov	edx,ebx

.Walk:		mov	ebx,[ebx+tTCB.Next]
		cmp	ebx,[MT_ReadyThrLst]
		je	.ChkQuantum
		cmp	[ebx+tTCB.CurrPriority],al
		jbe	.Walk
		mov	al,[ebx+tTCB.CurrPriority]
		mov	edx,ebx
		jmp	short .Walk

.ChkQuantum:	mov	eax,[K_SchedTick]
		mov	[edx+tTCB.Stamp],eax

		cmp	dword [edx+tTCB.Quant],0
		ja	.SaveCtx
		; Quantum decreases when the number of
		; running threads increases treshold is 8 (2^3)
		mov	eax,[MT_ReadyThrCnt]
		shr	eax,3
		mov	ebx,eax
		mov	eax,THRQUANT_DEFAULT
		sub	eax,ebx
		add	[edx+tTCB.Quant],eax
		cmp	dword [edx+tTCB.Quant],THRQUANT_MIN
		jae	.SaveCtx
		mov	dword [edx+tTCB.Quant],THRQUANT_MIN

.SaveCtx:	cmp	edx,[K_CurrThrPtr]
		je	.IncReturns
		mov	dword [K_SchInClock],0
		
		; Save context of current thread
		mov	ebx,[K_CurrThrPtr]
		lea	ebx,[ebx+tTCB.Context]
		call	K_SetJmp
		or	al,al
		jnz	.Done

		; Switch to next
		mov	ebx,edx
		call	MT_ContextSwitch

.IncReturns:	inc	dword [K_CurReturns]

.Done:		popfd
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; K_SwitchTask - task switching routine (called from timer
		;		 interrupt handler).
		; Input: none.
		; Output: none.
proc K_SwitchTask
		ret
endp		;---------------------------------------------------------------

