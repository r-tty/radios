;-------------------------------------------------------------------------------
;  softdrvs.asm - software drivers module.
;-------------------------------------------------------------------------------

.386
ideal

include "macros.ah"
include "sysdata.ah"
include "errdefs.ah"
include "segments.ah"
include "drvctrl.ah"
include "kernel.ah"
include "strings.ah"
include "drivers.ah"

IFDEF DEBUG
include "misc.ah"
ENDIF

include "consoles.asm"
include "ramdisk.asm"

include "BINFMT\rmod.asm"
include "BINFMT\coff.asm"
include "BINFMT\rdf.asm"

end
