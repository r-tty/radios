Monitor (debugger) sources.  Not well documented, but very similar to
DOS DEBUG.  Put an INT 3 in your program to invoke it.  Note that @r and @w
have been added to inspect and change disk blocks; they overwrite the memory at
DS:1000.  Don't use if DS is currently the system data seg!!!! Or if you
plan to continue single stepping

Debugger commands:

@r #		; Read a disk block
@w #		; write a disk block
b-# 		;clear a breakpoint (# from 1 - 7)
b# addr 	;set a breakpoint
d addr, [addr]	; dump
e addr		; Examine address
g [addr],[addr1]; Run from address to address 1 ( sets special breakpoint 0)
p		; like DEBUG p, only runs calls though
q		; quit
r [reg]		; Show registers, modify registers
t		; Single step
u [addr]	; Dissassemble