;*******************************************************************************
; sync_user.nasm - synchronization system calls implementation.
; Copyright (c) 2003 RET & COM Research.
;*******************************************************************************

module kernel.sync.user

%include "sys.ah"
%include "errors.ah"
%include "pool.ah"
%include "hash.ah"
%include "thread.ah"
%include "tm/process.ah"

publicproc K_SyncInit
publicproc sys_SyncTypeCreate, sys_SyncDestroy, sys_SyncCtl
publicproc sys_SyncMutexLock, sys_SyncMutexUnlock, sys_SyncMutexRevive
publicproc sys_SyncCondvarWait, sys_SyncCondvarSignal
publicproc sys_SyncSemPost, sys_SyncSemWait

externproc K_PoolInit, K_PoolAllocChunk
externproc K_CreateHashTab, K_HashAdd, K_HashLookup, K_HashRelease
externproc BZero

section .bss

?SyncHashPtr	RESD	1
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
		jc	.Ret
		call	K_CreateHashTab
		jc	.Ret
		mov	[?SyncHashPtr],esi
.Ret:		ret
endp		;---------------------------------------------------------------


		; int SyncTypeCreate(uint type, sync_t *sync,
		;			const struct _sync_attr_t *attr);
proc sys_SyncTypeCreate
		arg	type, sync, attr
		prologue

		; Check if sync and attr are okay
		mov	edi,[%$sync]
		add	edi,USERAREASTART
		jc	near .Fault
		cmp	edi,-tSync_size
		ja	near .Fault
		mov	edx,[%$attr]
		or	edx,edx
		jz	.CheckOwner
		add	edx,USERAREASTART
		jc	near .Fault
		cmp	edx,-tSyncAttr_size
		ja	near .Fault

		; Fill the "Owner" field
.CheckOwner:	mov	eax,[%$type]
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
		jnz	.ChkMutexProto
		mov	edx,MUTEX_PRIO_INHERIT
		jmp	.AllocDesc

.ChkMutexProto:	mov	edx,[edx+tSyncAttr.Protocol]
		cmp	edx,MUTEX_PRIO_INHERIT
		jne	near .Invalid
		jmp	.AllocDesc

		; For a semaphore - protocol contains its initial value
.TypeSem:	or	edx,edx
		jnz	.ChkSemProto
		inc	edx					; Default count
		jmp	.SemSet
.ChkSemProto:	mov	edx,[edx+tSyncAttr.Protocol]
		cmp	edx,SEM_VALUE_MAX
		jae	near .Invalid
.SemSet:	mov	[edi+tSync.Count],edx
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

		; Fill in another fields and enqueue it
		mov	[esi+tSyncDesc.Type],ecx
		mov	ebx,[%$sync]
		mov	[esi+tSyncDesc.Usync],ebx
		mEnqueue dword [eax+tProcDesc.SyncList], Next, Prev, esi, tSyncDesc, ecx

		; We use PCB address as the identifier and user address of
		; synchronization object as the key for hashing.
		mov	edi,esi
		mov	esi,[?SyncHashPtr]
		call	K_HashAdd

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

		; Find a descriptor in the hash table
		mCurrThread
		mov	eax,[eax+tTCB.PCB]
		mov	ebx,[%$sync]
		mov	esi,[?SyncHashPtr]
		call	K_HashLookup
		jc	.Invalid

		; If this object is in use (busy) - exit with error
		
.Exit:		epilogue
		ret

.Invalid:	mov	eax,-EINVAL
		jmp	.Exit
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
