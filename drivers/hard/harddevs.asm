;*******************************************************************************
;  hardctl.asm - RadiOS internal hardware drivers.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
Ideal

;DEBUG=1

include "segments.ah"
include "errdefs.ah"
include "sysdata.ah"
include "biosdata.ah"
include "drvctrl.ah"
include "drivers.ah"
include "hardware.ah"
include "kernel.ah"
include "strings.ah"
include "portsdef.ah"

IFDEF DEBUG
include "macros.ah"
include "misc.ah"
ENDIF


segment KCODE
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
include "hd.asm"
include "parport.asm"
include "serport.asm"
ends

end
