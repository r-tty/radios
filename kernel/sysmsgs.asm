;-------------------------------------------------------------------------------
;  sysmsgs.asm - ZealOS system messages.
;-------------------------------------------------------------------------------

; --- CPU exceptions ---

INFO_EXC00	DB 'divide error',0
INFO_EXC01	DB 'debugging',0
INFO_EXC02	DB 'non-maskable interrupt',0
INFO_EXC03	DB 'breakpoint',0
INFO_EXC04	DB 'INTO overflow',0
INFO_EXC05	DB 'bound range exceed',0
INFO_EXC06	DB 'invalid operation code',0
INFO_EXC07	DB 'processor extension not available',0
INFO_EXC08	DB 'double exception',0
INFO_EXC09	DB 'processor extension protection error (80386/387)',0
INFO_EXC10	DB 'invalid task state segment',0
INFO_EXC11	DB 'segment not present',0
INFO_EXC12	DB 'stack fault',0
INFO_EXC13	DB 'general protection violation',0
INFO_EXC14	DB 'page fault',0
INFO_EXC15	DB 'reserved',0
INFO_EXC16	DB 'coprocessor error',0
INFO_EXC17	DB 'alignment check',0

