;-------------------------------------------------------------------------------
; stdio.nasm - Unix stream I/O routines.
;-------------------------------------------------------------------------------

module libc.stdio

%include "asciictl.ah"

publicproc libc_init_stdio

exportdata _stdin, _stdout, _stderr

section .bss

_stdin		RESB	64
_stdout		RESB	64
_stderr		RESB	64


section .text

		; int fputc(int c, FILE *stream);
proc _fputc	
		arg	c, stream
		prologue
		epilogue
endp		;---------------------------------------------------------------
