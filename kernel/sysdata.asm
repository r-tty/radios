;-------------------------------------------------------------------------------
;  sysdata.asm - miscellaneous system data.
;-------------------------------------------------------------------------------

include "KERNEL\sysmsgs.asm"

; --- CPU and FPU type & CPU speed index ---
CPUtype		DB	0
FPUtype		DB	0 
CPUspeed	DD	0

; --- Timer ticks counter ---
TimerTicksLo	DD	0			; Low dword
TimerTicksHi	DD	0			; High dword

; Installed drivers IDs
DrvId_Con	DD	0

; --- Hardware analysis data ---

