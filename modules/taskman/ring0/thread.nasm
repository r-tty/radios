;-------------------------------------------------------------------------------
; thread.nasm - thread system calls.
;-------------------------------------------------------------------------------

module tm.kern.thread

%include "sys.ah"
%include "thread.ah"
%include "perm.ah"
%include "tm/kern.ah"

publicdata ThreadSyscallTable

externdata ?ProcessPool

library $rmk
importproc K_PoolChunkAddr, MT_CreateThread

section .data

ThreadSyscallTable:
mSyscallTabEnt ThreadCreate, 4
mSyscallTabEnt SchedGet, 3
mSyscallTabEnt SchedSet, 4
mSyscallTabEnt SchedInfo, 3
mSyscallTabEnt 0


section .text

		; int ThreadCreate(pid_t pid, void *(func)(void), void *arg, \
		;			const struct _thread_attr *attr);
proc sys_ThreadCreate
		arg	pid, func, targ, attr
		prologue

		; Get a current thread and its PCB address
		mCurrThread ebx
		mov	esi,[ebx+tTCB.PCB]

		; Only "root" can create threads in other processes
		mov	eax,[%$pid]
		or	eax,eax
		jz	.Create
		mIsRoot esi
		jc	.Exit
		push	ebx
		mov	ebx,?ProcessPool
		call	K_PoolChunkAddr
		pop	ebx
		jc	.Exit

		; Fast and lazy.
.Create:	mov	ebx,[%$func]
		xor	ecx,ecx
		call	MT_CreateThread

.Exit:		mCheckNeg
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_SchedGet
		ret
endp		;---------------------------------------------------------------


proc sys_SchedSet
		ret
endp		;---------------------------------------------------------------


proc sys_SchedInfo
		ret
endp		;---------------------------------------------------------------
