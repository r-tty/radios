;-------------------------------------------------------------------------------
; rtexit.nasm - must be linked last.
;-------------------------------------------------------------------------------

module libc.rtexit

global text_end, data_end, bss_end
publicproc _fini

section .text

proc _fini
		ret
endp		;---------------------------------------------------------------

text_end:

section .data
data_end:

section .bss
bss_end:
