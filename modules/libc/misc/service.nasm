;-------------------------------------------------------------------------------
; service.nasm - support routines (non-POSIX).
;-------------------------------------------------------------------------------

module libc.service

exportproc _netmgr_remote_nd

section .text

		; int netmgr_remote_nd(int remote_nd, int local_nd);
proc _netmgr_remote_nd
		arg	remnd, locnd
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
