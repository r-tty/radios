;-------------------------------------------------------------------------------
; version.nasm - only contains a microkernel version and copyright message.
;-------------------------------------------------------------------------------

module kernel.version

publicdata RadiOS_Version, TxtRVersion, TxtRCopyright

section .data

TxtRVersion	DB	10,"RadiOS ", 0xE6, "kernel, version ",0
TxtRCopyright	DB	" (C) 1998-2002 RET & COM Research.",10,10,0
RadiOS_Version	DB	"0.0.1-mk5"
		DB	0			; Must be here (separate line)
