;-------------------------------------------------------------------------------
; posix1j.nasm - POSIX advanced realtime extensions (1003.1j).
;-------------------------------------------------------------------------------

module libc.posix1j

%include "time.ah"
%include "thread.ah"

exportproc _clock_nanosleep
publicproc libc_init_posix1j

section .text


		; int clock_nanosleep(clockid_t clock_id, int flags, 
		;   const struct timespec *rqtp, struct timespec *rmtp)
proc _clock_nanosleep
		arg	clockid, flags, rqtp, rmtp
		prologue
		mpush	ecx,edx
		mov	ecx,[%$flags]
		and	ecx,TIMER_ABSTIME
		or	edx,TIMEOUT_NANOSLEEP
		mpop	edx,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; Initialization
proc libc_init_posix1j
		ret
endp		;---------------------------------------------------------------
