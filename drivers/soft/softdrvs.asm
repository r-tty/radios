;-------------------------------------------------------------------------------
;  softdrvs.asm - software drivers module.
;-------------------------------------------------------------------------------

.386
ideal

segment RADIOSKRNLSEG public 'code' use16
assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG

include "consoles.asm"
include "dskcache.asm"

ends
end