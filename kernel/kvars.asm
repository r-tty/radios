;-------------------------------------------------------------------------------
;  kvars.asm - kernel variables.
;-------------------------------------------------------------------------------

segment KVARS

; CPU and FPU type & CPU speed index
CPUtype		DB	0
FPUtype		DB	0
CPUspeed	DD	0

; Memory sizes (in kilobytes)
BaseMemSz	DD	0
ExtMemSz	DD	0

; Number of extended memory pages
ExtMemPages	DD	0			; Number of ext. mem. pages
VirtMemPages	DD	0			; Virtual memory pages
TotalMemPages	DD	0			; Total number of pages (Ext+VM)

; Heap (user segment) begin and end address
HeapBegin	DD	0
HeapEnd		DD	0

; Timer ticks counter
TimerTicksLo	DD	0			; Low dword
TimerTicksHi	DD	0			; High dword

; Installed drivers IDs
DrvId_Con	DD	0
DrvId_BIOS32	DD	0
DrvId_RD	DD	0
DrvId_RFS	DD	0

; Kernel heap variables
KH_Bottom	DD	?
KH_Top		DD	?
KH_FstBlAddr	DD	?

ends
