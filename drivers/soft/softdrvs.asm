;-------------------------------------------------------------------------------
;  softdrvs.asm - software drivers module.
;-------------------------------------------------------------------------------

.386
ideal

DEBUG=1

include "sysdata.ah"
include "errdefs.ah"
include "drvctrl.ah"
include "macros.ah"

segment RADIOSKRNLSEG public 'code' use32
assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG

include "consoles.asm"
include "dskcache.asm"

ends
end