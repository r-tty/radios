;-------------------------------------------------------------------------------
;  kmsgs.asm - kernel messages.
;-------------------------------------------------------------------------------

include "asciictl.ah"

; --- Startup messages ---

INFO_CPU386	DB "i80386 compatible",0
INFO_CPU486	DB "i486 compatible",0
INFO_CPUPENT	DB "Intel Pentium",0
INFO_CPUPPRO	DB "Intel Pentium Pro",0
INFO_CPUPMMX	DB "Intel Pentium MMX",0
INFO_CPUP2	DB "Intel Pentium II",0
INFO_CPUK5	DB "AMD K5 (5k86)",0
INFO_CPUK6	DB "AMD K6",0
INFO_CPUK62	DB "AMD K6-2",0
INFO_CPUM1	DB "Cyrix/IBM 6x86",0
INFO_CPUM2	DB "Cyrix/IBM 6x86MX",0
INFO_CPUIDT	DB "IDT C6",0
INFO_Unknown	DB "Unknown",0

INFO_SpdInd	DB ", speed index=",0

INFO_NotInst	DB "not installed",0

INFO_Reboot	DB NL,NL,"CTRL_ALT_DEL signal received.",NL,0
