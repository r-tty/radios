;-------------------------------------------------------------------------------
;  drvhlp.as - driver helper functions.
;-------------------------------------------------------------------------------

module $syscall.drvhlp

global DHlp_Suspend:export proc
global DHlp_Resume:export proc

section .text

		; DHlp_Suspend - suspend driver thread.
proc DHlp_Suspend
		retf
endp		;---------------------------------------------------------------


		; DHlp_Resume - resume driver thread.
proc DHlp_Resume
		retf
endp		;---------------------------------------------------------------
