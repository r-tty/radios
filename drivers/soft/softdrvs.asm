;-------------------------------------------------------------------------------
;  softdrvs.asm - software drivers module.
;-------------------------------------------------------------------------------

.386
ideal

include "segments.ah"
include "kernel.ah"
include "memman.ah"
include "drivers.ah"
include "drvctrl.ah"
include "strings.ah"
include "sysdata.ah"
include "macros.ah"
include "errdefs.ah"

IFDEF DEBUG
include "misc.ah"
ENDIF

include "consoles.asm"
include "ramdisk.asm"

include "BINFMT\rmod.asm"
include "BINFMT\coff.asm"
include "BINFMT\rdf.asm"

end
