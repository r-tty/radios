;-------------------------------------------------------------------------------
; libcinit.nasm - initialize different libc components.
;-------------------------------------------------------------------------------

module $libc

extern libc_init_syscall
extern libc_init_signal
extern libc_init_stdio
extern libc_init_stdlib
extern libc_init_string
extern libc_init_termios
extern libc_init_unistd

section .text

proc libc_init
		call	libc_init_syscall
		call	libc_init_signal
		call	libc_init_stdio
		call	libc_init_stdlib
		call	libc_init_string
		call	libc_init_termios
		call	libc_init_unistd
		ret
endp		;---------------------------------------------------------------
