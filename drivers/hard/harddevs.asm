;*******************************************************************************
;  hardctl.asm - RadiOS internal hardware drivers.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
ideal

segment RADIOSKRNLSEG public 'code' use32
assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG

include "errdefs.ah"
include "sysdata.ah"
include "drvctrl.ah"

include "portsdef.ah"

include "misc.asm"
include "timer.asm"
include "cmosrtc.asm"
include "pic.asm"
include "dma.asm"
include "8042.asm"
include "bios32.asm"
include "pnp.asm"
include "keyboard.asm"
include "video.asm"
include "audio.asm"
include "ethernet.asm"
include "fd.asm"
include "hd.asm"
include "parport.asm"
include "serport.asm"

ends
end
