;-------------------------------------------------------------------------------
; xopen.nasm - various routines described by X/Open specification.
;-------------------------------------------------------------------------------

module libc.xopen

%include "time.ah"

; Exports

exportproc _usleep
publicproc libc_init_xopen

; Imports

extern _clock_nanosleep

; Code

section .text

		; int usleep(ulong usec);
proc _usleep
		arg	usec
		locauto	ts, tTimeSpec_size
		prologue
		mpush	ecx,edx
		mov	eax,[%$usec]
		mov	ecx,1000000
		xor	edx,edx
		div	ecx
		mov	[%$ts+tTimeSpec.Seconds],eax
		mov	eax,edx
		mov	ecx,1000
		mul	ecx
		mov	[%$ts+tTimeSpec.Nanoseconds],eax
		lea	edx,[%$ts]
		Ccall	_clock_nanosleep, CLOCK_REALTIME, 0, edx, 0
		mpop	edx,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; Initialization
proc libc_init_xopen
		ret
endp		;---------------------------------------------------------------
