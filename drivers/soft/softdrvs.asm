;-------------------------------------------------------------------------------
;  softdrvs.asm - software drivers module.
;-------------------------------------------------------------------------------

.386
ideal

DEBUG=1

include "errdefs.ah"

segment RADIOSKRNLSEG public 'code' use32
assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG

include "consoles.asm"
include "dskcache.asm"

ends
end