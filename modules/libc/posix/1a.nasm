;-------------------------------------------------------------------------------
; posix/1a.nasm - POSIX 1003.1a routines.
;-------------------------------------------------------------------------------

module libc.posix1a

exportproc _getenv

section .text

		; char *getenv(const char *name);
proc _getenv
		arg	name
		prologue
		; XXX
		epilogue
		ret
endp		;---------------------------------------------------------------