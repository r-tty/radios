;-------------------------------------------------------------------------------
;  sysdata.asm - miscelaneous system data.
;-------------------------------------------------------------------------------

include "KERNEL\sysdata.ah"
include "KERNEL\sysmsgs.asm"

; --- Hardware analysis data ---


; --- Console parameters tables ---
CON_VidFntTbl	DD 256 dup (DefaultFont8x16)	; Table of offsets to fonts
CON_KBltTbl	DD 256 dup (DefaultKBlayout)	; Table of offsets to layouts


; --- Virtual consoles settings table ---
VirtCons	tVirtCon 8 dup (<0,0>)



label DefaultKBlayout near