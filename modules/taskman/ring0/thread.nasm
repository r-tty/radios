;-------------------------------------------------------------------------------
; thread.nasm - thread system calls.
;-------------------------------------------------------------------------------

module tm.kern.thread

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "perm.ah"
%include "tm/kern.ah"
%include "tm/process.ah"

publicdata ThreadSyscallTable

externproc R0_Pid2PCBaddr

importproc K_PoolChunkAddr, MT_CreateThread
importproc K_SemV, K_SemP

section .data

ThreadSyscallTable:
mSyscallTabEnt ThreadCreate, 4
mSyscallTabEnt ThreadDestroy, 3
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
		call	R0_Pid2PCBaddr
		jc	.Exit

		; Create the thread and attach it to the process.
		; Take care about PCB locking too.
.Create:	mov	ebx,[%$func]
		xor	ecx,ecx
		call	MT_CreateThread
		jc	.Again
		mLockCB	esi, tProcDesc
		mEnqueue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB, ecx
		mUnlockCB esi, tProcDesc

		; Return TID
		mov	eax,[ebx+tTCB.TID]

.Exit:		epilogue
		ret

.Perm:		mov	eax,-EPERM
		jmp	.Exit
.Again:		mov	eax,-EAGAIN
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ThreadDestroy(int tid, int priority, void *status);
proc sys_ThreadDestroy
		arg	tid, prio, status
		prologue

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SchedGet(pid_t pid, int tid, struct sched_param *param);
proc sys_SchedGet
		arg	pid, tid, param
		prologue

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SchedGet(pid_t pid, int tid, int policy, 
		;		struct sched_param *param);
proc sys_SchedSet
		arg	pid, tid, policy, param
		prologue

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SchedInfo(pid_t pid, int policy, struct _sched_info *info);
proc sys_SchedInfo
		arg	pid, policy, info
		prologue

		epilogue
		ret
endp		;---------------------------------------------------------------
