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

INFO_CPU386	DB "i80386 compatible",0
INFO_CPU486	DB "i486 compatible",0
INFO_CPUPENT	DB "Intel Pentium",0
INFO_CPUPMMX	DB "Intel Pentium MMX",0
INFO_CPUK5	DB "AMD K5 (5k86)",0
INFO_CPUK6	DB "AMD K6",0
INFO_CPUK62	DB "AMD K6-2",0
INFO_CPUM1	DB "Cyrix/IBM 6x86",0
INFO_CPUM2	DB "Cyrix/IBM 6x86-MX",0
INFO_CPUIDT	DB "IDT C6",0
INFO_Unknown	DB "Unknown",0

INFO_SpdInd	DB ", speed index=",0

INFO_NotInst	DB "not installed",0


INFO_FD360	DB '360 KB, 5.5"',0
INFO_FD720f	DB '720 KB, 5.5"',0
INFO_FD1200	DB '1.2 MB, 5.5"',0
INFO_FD720h	DB '720 KB, 3.5"',0
INFO_FD1440	DB '1.44 MB, 3.5"',0
INFO_FD2880	DB '2.88 MB, 3.5"',0


INFO_RadiOS	DB NL
		DB "ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป",NL
		DB "บ The Radiant Operating System (RadiOS), kernel version d0.01 บ",NL
		DB "บ Copyright (c) 1998,99 RET & COM research.                   บ",NL
		DB "ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ",NL,NL,0

INFO_InitDskDr	DB NL,"Initializing disk drivers...",NL,0
INFO_InitErr	DB ": init error ",0

INFO_Assembler	DB "Assembled with Turbo Assembler, version 3.2",NL
		DB "Copyright (C) 1988,1994 Borland International.",NL,0

INFO_Shutdown	DB ASC_BEL,NL,NL,"Main process completed. Press any key to reset...",0

; --- Error messages ---
ERRMSG_0100	DB "bad driver function number",0
ERRMSG_0101	DB "unknown event code",0
ERRMSG_0320	DB "drivers table full",0
ERRMSG_0321	DB "bad driver ID",0
ERRMSG_0322	DB "driver not initialized",0

ERRMSG_0340	DB "invalid base memory size",0
ERRMSG_0341	DB "exetended memory test not passed",0

ERRMSG_0800	DB "keyboard controller not ready",0

ERRMSG_0A00	DB "bad timer channel number",0

ERRMSG_0B00	DB "bad DMA channel number",0
ERRMSG_0B01	DB "invalid DMA memory block address",0
ERRMSG_0B02	DB "out of DMA page",0
ERRMSG_0B03	DB "odd address for slave DMA controller",0

ERRMSG_1100	DB "keyboard initialization failure",0

ERRMSG_1205	DB "bad video page number",0
ERRMSG_1206	DB "invalid cursor position",0

ERRMSG_1600	DB "bad floppy drive number",0

ERRMSG_2020	DB "console output device initialization failure",0
ERRMSG_2021	DB "console input device initialization failure",0
ERRMSG_2100	DB "invalid virtual console number",0
