;-------------------------------------------------------------------------------
;  sysmsgs.asm - RadiOS system messages.
;-------------------------------------------------------------------------------

include "asciictl.ah"

; --- CPU exceptions ---

INFO_EXC00	DB "divide error",0
INFO_EXC01	DB "debugging",0
INFO_EXC02	DB "non-maskable interrupt",0
INFO_EXC03	DB "breakpoint",0
INFO_EXC04	DB "INTO overflow",0
INFO_EXC05	DB "bound range exceed",0
INFO_EXC06	DB "invalid operation code",0
INFO_EXC07	DB "processor extension not available",0
INFO_EXC08	DB "double exception",0
INFO_EXC09	DB "processor extension protection error (80386/387)",0
INFO_EXC10	DB "invalid task state segment",0
INFO_EXC11	DB "segment not present",0
INFO_EXC12	DB "stack fault",0
INFO_EXC13	DB "general protection violation",0
INFO_EXC14	DB "page fault",0
INFO_EXC15	DB "reserved",0
INFO_EXC16	DB "coprocessor error",0
INFO_EXC17	DB "alignment check",0


; --- Startup messages ---

INFO_MainCPU	DB "Main processor: ",0
INFO_CPU386	DB "i80386 compatible",0
INFO_CPU486	DB "i486 compatible",0
INFO_CPUPENT	DB "Intel Pentium",0
INFO_CPUPMMX	DB "Intel Pentium MMX"
INFO_CPUK5	DB "AMD K5 (5k86)",0
INFO_CPUK6	DB "AMD K6",0
INFO_CPUK62	DB "AMD K6-2",0
INFO_CPUM1	DB "Cyrix/IBM 6x86",0
INFO_CPUM2	DB "Cyrix/IBM 6x86-MX",0
INFO_CPUIDT	DB "IDT C6",0

INFO_RadiOS	DB NL,NL
		DB "ษออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป",NL
		DB "บ RET & COM RadiOS, developer version 0.01                   บ",NL
		DB "บ Copyright (c) 1998 RET & COM reseach. All rights reserved. บ",NL
		DB "ศออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ",NL,NL,0
