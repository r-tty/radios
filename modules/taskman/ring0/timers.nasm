;-------------------------------------------------------------------------------
; timers.nasm - timer system calls.
;-------------------------------------------------------------------------------

module tm.kern.timers

%include "pool.ah"
%include "time.ah"
%include "tm/kern.ah"

publicproc TM_InitTimerPool
publicdata TimerSyscallTable

importproc K_PoolInit

; --- System call table ---

section .data

TimerSyscallTable:
mSyscallTabEnt TimerCreate, 2
mSyscallTabEnt TimerDestroy, 1
mSyscallTabEnt TimerSettime, 4
mSyscallTabEnt TimerInfo, 4
mSyscallTabEnt TimerAlarm, 3
mSyscallTabEnt TimerTimeout, 5
mSyscallTabEnt 0

; --- Variables ---

section .bss

?MaxTimers	RESD	1
?TimerPool	RESB	tMasterPool_size
?TimerListHead	RESD	1


; --- Code ---

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
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerDestroy(timer_t id);
proc sys_TimerDestroy
		arg	id
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerSetTime(timer_id id, int flags,
		;	 const struct itimer *itime, struct itimer *otime);
proc sys_TimerSettime
		arg	id, flags, itime, otime
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerInfo(pid_t pid, timer_t id, int flags,
		;		struct timer_info *info);
proc sys_TimerInfo
		arg	pid, id flags, info
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerAlarm(clockid_t id, const struct itimer *itime,
		;		 struct itimer *otime);
proc sys_TimerAlarm
		arg	id, itime, otime
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerTimeout(clockid_t id, int flags,
		;		   const struct sigevent *notify,
		;		   const uint64 *ntime, uint64 *otime)
proc sys_TimerTimeout
		arg	id, flags, notify, ntime, otime
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
