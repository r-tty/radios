;*******************************************************************************
;  kernel.asm - ZealOS head kernel module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "KERNEL\pmdata.asm"

include "KERNEL\int00-1f.asm"
include "KERNEL\int30-4f.asm"
include "KERNEL\int50-6f.asm"
include "KERNEL\int70-7f.asm"

;include "KERNEL\MEMMAN\memman.asm"
;include "KERNEL\PROCESS\process.asm"
include "KERNEL\HARDCTL\hardctl.asm"
;include "KERNEL\UTILS\utils.asm"

include "KERNEL\sysdata.asm"