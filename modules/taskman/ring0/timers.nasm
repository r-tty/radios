;-------------------------------------------------------------------------------
; timers.nasm - timer system calls.
;-------------------------------------------------------------------------------

module tm.kern.timers

%include "sys.ah"
%include "pool.ah"
%include "time.ah"
%include "tm/kern.ah"

publicproc TM_InitTimerPool
publicdata TimerSyscallTable

importproc K_PoolInit, K_SemV, K_SemP
importdata ?TicksCounter

struc tTimeout
.State		RESD	1
.Ticks		RESD	1
.Sem		RESB	tSemaphore
.Next		RESD	1
.Prev		RESD	1
endstruc

MAX_TIMEOUTS	EQU	10

TM_ST_FREE 	EQU	0
TM_ST_ALLOC	EQU	1


section .data

TimerSyscallTable:
mSyscallTabEnt TimerCreate, 2
mSyscallTabEnt TimerDestroy, 1
mSyscallTabEnt TimerSettime, 4
mSyscallTabEnt TimerInfo, 4
mSyscallTabEnt TimerAlarm, 3
mSyscallTabEnt TimerTimeout, 5
mSyscallTabEnt 0


section .bss

?MaxTimers	RESD	1
?TimerPool	RESB	tMasterPool_size
?TimerListHead	RESD	1

?TimeoutQue	RESD	1	; Address of timeout queue
?TimeoutTrailer	RESB	tTimeout_size
?TimeoutPool	RESB	tTimeout_size*MAX_TIMEOUTS


section .text

		; Initialize timer pool.
		; Input: EAX=maximum number of timers.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_InitTimerPool
		mpush	ebx,ecx,edx
		mov	[?MaxTimers],eax
		xor	edx,edx
		mov	[?TimerListHead],edx
		mov	ebx,?TimerPool
		mov	ecx,tITimer_size
		call	K_PoolInit
.Done:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------


		; int TimerCreate(clockid_t id, const struct sigevent *event);
proc sys_TimerCreate
		arg	id, event
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerDestroy(timer_t id);
proc sys_TimerDestroy
		arg	id
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerSetTime(timer_id id, int flags,
		;	 const struct itimer *itime, struct itimer *otime);
proc sys_TimerSettime
		arg	id, flags, itime, otime
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerInfo(pid_t pid, timer_t id, int flags,
		;		struct timer_info *info);
proc sys_TimerInfo
		arg	pid, id flags, info
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerAlarm(clockid_t id, const struct itimer *itime,
		;		 struct itimer *otime);
proc sys_TimerAlarm
		arg	id, itime, otime
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerTimeout(clockid_t id, int flags,
		;		   const struct sigevent *notify,
		;		   const uint64 *ntime, uint64 *otime)
proc sys_TimerTimeout
		arg	id, flags, notify, ntime, otime
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


;------ Old timeout stuff-------------------------------------------------------

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
