;-------------------------------------------------------------------------------
;  version.nasm - only contains a current version.
;-------------------------------------------------------------------------------

module kernel.version

global RadiOS_Version, Msg_RVersion, Msg_RCopyright

section .data

Msg_RVersion	DB	"RadiOS ", 0xE6, "kernel, version ",0
Msg_RCopyright	DB	" (C) 1998-2002 RET & COM Research.",10,10,0
RadiOS_Version	DB	"0.0.1-mk2"
		DB	0
