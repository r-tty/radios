;-------------------------------------------------------------------------------
; posix1j.nasm - POSIX advanced realtime extensions (1003.1j).
;-------------------------------------------------------------------------------

module libc.posix1j

%include "time.ah"
%include "thread.ah"

exportproc _clock_nanosleep

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

		;XXX

		mpop	edx,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------
