;*******************************************************************************
;  kernel.asm - RadiOS head kernel module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- External procedures and data, used by kernel ---
extrn PIC_EOI1:	near
extrn PIC_EOI2:	near

extrn KBC_ReadKBPort:	near	; debug
extrn KB_AnalyseKCode:	near	; debug

; --- Kernel modules ---

include "errdefs.ah"
include "sysdata.ah"

include "KERNEL\pmdata.asm"

include "KERNEL\int00-1f.asm"
include "KERNEL\int30-4f.asm"
include "KERNEL\int50-6f.asm"
include "KERNEL\int70-7f.asm"

include "KERNEL\MEMMAN\memman.asm"
include "KERNEL\PROCESS\process.asm"
include "KERNEL\UTILS\utils.asm"
include "KERNEL\drivers.asm"

include "KERNEL\sysdata.asm"

include "KERNEL\debugger.asm"


; --- Additional kernel procedures ---

