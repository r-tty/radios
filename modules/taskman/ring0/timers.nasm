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


proc sys_TimerCreate
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_TimerDestroy
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_TimerSettime
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_TimerInfo
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_TimerAlarm
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_TimerTimeout
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
