;-------------------------------------------------------------------------------
; thread.nasm - thread system calls.
;-------------------------------------------------------------------------------

module tm.kern.thread

%include "sys.ah"
%include "errors.ah"
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
		jc	.Perm
		push	ebx
		mov	ebx,?ProcessPool
		call	K_PoolChunkAddr
		pop	ebx
		jc	.ChkNeg

		; Fast and lazy.
.Create:	mov	ebx,[%$func]
		xor	ecx,ecx
		call	MT_CreateThread
		jc	.ChkNeg

		; Return TID
		mov	eax,[esi+tTCB.TID]
		jmp	.Exit

.ChkNeg:	mCheckNeg
.Exit:		epilogue
		ret

.Perm:		mov	eax,-EPERM
		jmp	.Exit
endp		;---------------------------------------------------------------


proc sys_SchedGet
		prologue
		push	edx
		pop	edx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_SchedSet
		prologue
		push	edx
		pop	edx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_SchedInfo
		prologue
		push	edx
		pop	edx
		epilogue
		ret
endp		;---------------------------------------------------------------
