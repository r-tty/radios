;-------------------------------------------------------------------------------
; signal.nasm - signal system calls.
;-------------------------------------------------------------------------------

module tm.kern.signal

%include "tm/kern.ah"

publicdata SignalSyscallTable

; --- System call table ---

section .data

SignalSyscallTable:

mSyscallTabEnt SignalKill, 6
mSyscallTabEnt SignalReturn, 1	
mSyscallTabEnt SignalFault, 3	
mSyscallTabEnt SignalAction, 5	
mSyscallTabEnt SignalProcmask, 5	
mSyscallTabEnt SignalSuspend, 1	
mSyscallTabEnt SignalWaitinfo, 2
mSyscallTabEnt 0

; --- Procedures ---

section .text

proc sys_SignalKill
		ret
endp		;---------------------------------------------------------------


proc sys_SignalReturn
		ret
endp		;---------------------------------------------------------------


proc sys_SignalFault
		ret
endp		;---------------------------------------------------------------


proc sys_SignalAction
		ret
endp		;---------------------------------------------------------------


proc sys_SignalProcmask
		ret
endp		;---------------------------------------------------------------


proc sys_SignalSuspend
		ret
endp		;---------------------------------------------------------------


proc sys_SignalWaitinfo
		ret
endp		;---------------------------------------------------------------
