;*******************************************************************************
; sync.nasm - synchronization primitives (semaphores, mutexes, condvars, etc).
; Copyright (c) 2003 RET & COM Research.
; Portions are based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.sync

%include "sys.ah"
%include "errors.ah"
%include "sync.ah"
%include "pool.ah"
%include "thread.ah"
%include "tm/process.ah"

exportproc K_SemP, K_SemV
publicproc K_SyncInit
publicproc sys_SyncTypeCreate, sys_SyncDestroy, sys_SyncCtl
publicproc sys_SyncMutexLock, sys_SyncMutexUnlock, sys_SyncMutexRevive
publicproc sys_SyncCondvarWait, sys_SyncCondvarSignal
publicproc sys_SyncSemPost, sys_SyncSemWait

externproc MT_ThreadSleep, MT_ThreadWakeup
externproc MT_Schedule
externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc BZero
externdata ?CurrThread


section .bss

?MaxSyncObjs	RESD	1
?SyncObjCount	RESD	1
?SyncPool	RESB	tMasterPool_size


section .text

		; K_SyncInit - initialize synchronization object pool.
		; Input: EAX=maximum number of synchronization objects.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_SyncInit
		mov	[?MaxSyncObjs],eax
		mov	ebx,?SyncPool
		xor	ecx,ecx
		mov	[?SyncObjCount],ecx
		mov	cl,tSyncDesc_size
		xor	dl,dl
		call	K_PoolInit
		ret
endp		;---------------------------------------------------------------


		; K_SemP - the "P" operation (decrement and sleep if negative).
		; Input: EAX=address of semaphore structure.
		; Output: none.
proc K_SemP
		pushfd
		cli

		; Check the optimistic case first
		dec	dword [eax+tSemaphore.Count]
		js	.Sleep
		popfd
		ret

		; Enqueue current thread under the semaphore and suspend it
.Sleep:		push	ebx
		mov	ebx,[?CurrThread]
		mSemEnq eax,ebx
		mov	al,THRSTATE_SEM
		call	MT_ThreadSleep
		inc	dword [ebx+tTCB.SemWait]
		pop	ebx
		popfd
		call	MT_Schedule
		ret
endp		;---------------------------------------------------------------


		; K_SemV - the "V" operation (increase and wake up waiting thread).
		; Input: EAX=address of semaphore structure.
		; Output: none.
proc K_SemV
		pushfd
		cli

		; If no threads kept, quickly bail out
		inc	dword [eax+tSemaphore.Count]
		cmp	dword [eax+tSemaphore.WaitQ],0
		je	.Done

		; Dequeue thread from under the semaphore
		; and let it be woken up next timeslice
		push	ebx
		mov	ebx,[eax+tSemaphore.WaitQ]
		mSemDeq eax,ebx
		call	MT_ThreadWakeup
		pop	ebx
		
.Done:		popfd
		ret
endp		;---------------------------------------------------------------


		; Find a sync descriptor by user address of sync object.
		; Input: EBX=user address of sync object,
		;	 ESI=PCB address.
		; Output: CF=0 - OK, EAX=address of sync descriptor;
		;	  CF=1 - error, EAX=errno.
		; Note: linear search.
proc FindSyncDesc
		mov	eax,[esi+tProcDesc.SyncList]
.Loop:		or	eax,eax
		jz	.NotFound
		cmp	[eax+tSyncDesc.Usync],ebx
		je	.Exit
		mov	eax,[eax+tSyncDesc.Next]
		jmp	.Loop
.NotFound:	mov	eax,-EINVAL
.Exit:		ret
endp		;---------------------------------------------------------------



; --- Synchronizaton system calls ----------------------------------------------


		; int SyncTypeCreate(uint type, sync_t *sync,
		;			const struct _sync_attr_t *attr);
proc sys_SyncTypeCreate
		arg	type, sync, attr
		prologue

		; Check if sync and attr are okay
		mov	edi,[%$sync]
		add	edi,USERAREASTART
		jc	near .Fault
		mov	edx,[%$attr]
		or	edx,edx
		jz	.CheckOwner
		add	edx,USERAREASTART
		jc	near .Fault

		; Fill the "Owner" field
.CheckOwner:	xor	ecx,ecx
		mov	eax,[%$type]
		cmp	eax,SYNC_MUTEX_FREE
		je	.TypeMutex
		cmp	eax,SYNC_SEM
		je	.TypeSem
		cmp	eax,SYNC_COND
		jne	near .Invalid

		; This is condvar.
		or	edx,edx
		jz	.AllocDesc
		mov	edx,[edx+tSyncAttr.ClockID]
		jmp	.AllocDesc

		; For a mutex, check the protocol (if attr is NULL, use default)
.TypeMutex:	or	edx,edx
		jnz	.CheckProto
		mov	edx,MUTEX_PRIO_INHERIT
		jmp	.AllocDesc

.CheckProto:	mov	edx,[edx+tSyncAttr.Protocol]
		cmp	edx,MUTEX_PRIO_INHERIT
		jne	near .Invalid
		jmp	.AllocDesc

		; Check semafore value and initialize owner
.TypeSem:	cmp	dword [edi+tSync.Count],SEM_VALUE_MAX
		jae	.Invalid
		mov	[edi+tSync.Count],ecx
		mov	[edi+tSync.Owner],eax

		; Allocate a syncobj descriptor and zero it
.AllocDesc:	mov	ebx,?SyncPool
		call	K_PoolAllocChunk
		jc	.Again
		mov	ebx,esi
		mov	ecx,tSyncDesc_size
		call	BZero

		; Syncobj is considered to be owned by a calling process
		mCurrThread
		mov	eax,[eax+tTCB.PCB]
		mov	[esi+tSyncDesc.PCB],eax
		mov	ebx,[%$sync]
		mov	[esi+tSyncDesc.Usync],ebx
		mEnqueue dword [eax+tProcDesc.SyncList], Next, Prev, esi, tSyncDesc, ecx

		; Return success
		xor	eax,eax

.Exit:		epilogue
		ret

.Again:		mov	eax,-EAGAIN
		jmp	.Exit
.Fault:		mov	eax,-EFAULT
		jmp	.Exit
.Invalid:	mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int SyncDestroy(sync_t *sync);
proc sys_SyncDestroy
		arg	sync
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncMutexLock(sync_t *sync);
proc sys_SyncMutexLock
		arg	sync
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncMutexUnlock(sync_t *sync);
proc sys_SyncMutexUnlock
		arg	sync
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncMutexRevive(sync_t *sync);
proc sys_SyncMutexRevive
		arg	sync
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncCondvarWait(sync_t *sync, sync_t *mutex);
proc sys_SyncCondvarWait
		arg	sync, mutex
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncCondvarSignal(sync_t *sync, int broadcast);
proc sys_SyncCondvarSignal
		arg	sync, broadcast
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncSemPost(sync_t *sync);
proc sys_SyncSemPost
		arg	sync
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncSemWait(sync_t *sync, int try);
proc sys_SyncSemWait
		arg	sync, try
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SyncCtl(int cmd, sync_t *sync, void *data);
proc sys_SyncCtl
		arg	cmd, sync, data
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------
