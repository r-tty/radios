;*******************************************************************************
;  v86bios.asm - V8086 BIOS routines module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386
ideal

segment		V86SEG 'code' use16
		assume CS:V86SEG

include "bvideo.asm"
include "bdiskio.asm"


ends

end