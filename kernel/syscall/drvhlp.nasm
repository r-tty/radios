;-------------------------------------------------------------------------------
;  drvhlp.nasm - driver helper functions.
;-------------------------------------------------------------------------------

module $syscall.drvhlp

exportproc dhr_Suspend
exportproc dhr_Resume

section .text

		; dhr_Suspend - suspend driver thread.
proc dhr_Suspend
		retf
endp		;---------------------------------------------------------------


		; dhr_Resume - resume driver thread.
proc dhr_Resume
		retf
endp		;---------------------------------------------------------------
