;-------------------------------------------------------------------------------
; vsprintf.nasm - routines for printing formatted data.
;-------------------------------------------------------------------------------

module libc.stdio.vsprintf

exportproc _printf

section .text

		; int printf(const char *fmt, ...);
proc _printf
		arg	fmt
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
