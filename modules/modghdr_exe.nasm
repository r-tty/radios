;-------------------------------------------------------------------------------
; modghdr_exe.nasm - generic module header for executables.
;-------------------------------------------------------------------------------

%include "module.ah"

		DD	RBM_SIGNATURE		; Signature
		DD	1			; Module version
		DW	MODTYPE_EXECUTABLE	; Module type
		DW	0			; Flags
		DW	1			; OS type
		DW	0			; OS version
		TIMES 112 DB 0			; Command line buffer