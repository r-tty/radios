;-------------------------------------------------------------------------------
;  sysdata.asm - miscelaneous system data.
;-------------------------------------------------------------------------------

include "KERNEL\sysmsgs.asm"

; --- CPU type speed index ---
CPUtype		DB ?
CPUspeed	DD ?

; --- Timer ticks counter ---
TimerTicksLo	DD 0				; Low dword
TimerTicksHi	DD 0				; High dword

; --- Hardware analysis data ---


