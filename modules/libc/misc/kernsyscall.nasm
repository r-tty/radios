;
; kernsyscall.nasm - kernel system calls, accessible from C.
;

module libc.kernsyscall

publicproc libc_init_syscall

%include "syscall.ah"

		; Initialization
proc libc_init_syscall
		ret
endp		;---------------------------------------------------------------
