;-------------------------------------------------------------------------------
;  sysdata.asm - miscelaneous system data.
;-------------------------------------------------------------------------------

include "KERNEL\sysmsgs.asm"

; --- Timer ticks counter ---
TimerTicksLo	DD 0				; Low dword
TimerTicksHi	DD 0				; High dword

; --- Hardware analysis data ---


; --- Console parameters tables ---
;CON_VidFntTbl	DD 256 dup (DefaultFont8x16)	; Table of offsets to fonts
;CON_KBltTbl	DD 256 dup (DefaultKBlayout)	; Table of offsets to layouts


; --- Virtual consoles settings ---
VirtCons	tVirtCon 8 dup (<0,0>)
CurrVirtCon	DB 0				; Current virtual console
