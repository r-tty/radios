;*******************************************************************************
;  hardctl.asm - RadiOS internal hardware  .
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
ideal

segment RADIOSKRNLSEG public 'code' use16
assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG

include "errdefs.ah"
include "sysdata.ah"

include "portsdef.ah"
include "misc.asm"
include "timerrtc.asm"
include "pic.asm"
include "dma.asm"
include "8042.asm"
include "keyboard.asm"
include "video.asm"
include "audio.asm"
include "net.asm"
include "fdd.asm"
include "ide.asm"
include "parport.asm"
include "serport.asm"

ends
end