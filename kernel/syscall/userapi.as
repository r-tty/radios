;-------------------------------------------------------------------------------
;  userapi.as - user APIs (system calls).
;-------------------------------------------------------------------------------

module syscall.user

global UAPI_Exit


section .text

		; UAPI_Exit - exit process.
proc UAPI_Exit
		retf
endp		;---------------------------------------------------------------
