;-------------------------------------------------------------------------------
;  version.nasm - only contains a current version.
;-------------------------------------------------------------------------------

global RadiOS_Version, Msg_RVersion, Msg_RCopyright

section .data

Msg_RVersion	DB	"RadiOS kernel, version ",0
Msg_RCopyright	DB	" (C) 1998-2002 RET & COM Research.",10,0
RadiOS_Version	DB	"0.0.1-mk"
		DB	0
