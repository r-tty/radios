;-------------------------------------------------------------------------------
; posix/1b.nasm - routines described by "POSIX Realtime Extensions" (1003.1b).
;-------------------------------------------------------------------------------

module libc.posix1b

%include "errors.ah"
%include "locstor.ah"
%include "sync.ah"
%include "tm/memman.ah"
%include "tm/memmsg.ah"

exportproc _mmap64
exportproc _sem_init, _sem_destroy, _sem_post, _sem_wait, _sem_trywait
exportproc _sched_get_priority_max, _sched_get_priority_min

externproc _read, _write
externproc _MsgSendnc, _SchedInfo
externproc _SyncTypeCreate, _SyncDestroy
externproc _SyncSemPost, _SyncSemWait

section .text

		; void *mmap64(void *addr, size_t len, int prot, 
		;		int flags, int fd, off64_t off);
proc _mmap64
		arg	addr, len, prot, flags, fd, offl, offh
		locauto	msg, tMsg_MemMap_size
		prologue
		push	ebx
		
		xor	eax,eax
		mov	word [%$msg+tMemMapRequest.Type],MEM_MAP
		mov	[%$msg+tMemMapRequest.Zero],ax
		mov	[%$msg+tMemMapRequest.Reserved1],eax
		mov	[%$msg+tMemMapRequest.Reserved2],eax
		mov	[%$msg+tMemMapRequest.Align],eax
		mov	[%$msg+tMemMapRequest.Align+4],eax
		mov	ebx,[%$addr]
		mov	[%$msg+tMemMapRequest.Addr],ebx
		mov	ebx,[%$len]
		mov	[%$msg+tMemMapRequest.Len],ebx
		mov	[%$msg+tMemMapRequest.Len+4],eax
		mov	ebx,[%$prot]
		mov	[%$msg+tMemMapRequest.Prot],ebx
		mov	ebx,[%$flags]
		mov	[%$msg+tMemMapRequest.Flags],ebx
		mov	ebx,[%$fd]
		mov	[%$msg+tMemMapRequest.FD],ebx
		mov	ebx,[%$offl]
		mov	[%$msg+tMemMapRequest.Offset],ebx
		mov	ebx,[%$offh]
		mov	[%$msg+tMemMapRequest.Offset+4],ebx

		lea	ebx,[%$msg]
		Ccall	_MsgSendnc, MEMMGR_COID, ebx, tMemMapRequest_size, \
			ebx, tMemMapReply_size
		test	eax,eax
		jns	.Exit
		mov	eax,MAP_FAILED

.Exit		pop	ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_init(sem_t *sem, int pshared, uint value);
proc _sem_init
		arg	sem, pshared, value
		locauto	attr, tSyncAttr_size
		prologue
		savereg	ebx

		lea	ebx,[%$attr]
		Mov32	ebx+tSyncAttr.Protocol,%$value
		mov	eax,[%$pshared]
		or	eax,eax
		jnz	.Shared
		mov	dword [ebx+tSyncAttr.Flags],SEM_PROCESS_PRIVATE
		jmp	.1
.Shared:	mov	dword [ebx+tSyncAttr.Flags],SEM_PROCESS_SHARED
.1:		xor	eax,eax
		mov	[ebx+tSyncAttr.PrioCeiling],eax
		Ccall	_SyncTypeCreate, SYNC_SEM, dword [%$sem], ebx

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_destroy(sem_t *sem);
proc _sem_destroy
		arg	sem
		prologue

		; Force an EINVAL if the semaphore is "statically" initialized
		mov	eax,[%$sem]
		cmp	dword [eax+tSync.Owner],SYNC_INITIALIZER
		je	.Invalid
		Ccall	_SyncDestroy, eax

.Exit:		epilogue
		ret

.Invalid:	mSetErrno EINVAL, eax
		xor	eax,eax
		not	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int sem_post(sem_t *sem);
proc _sem_post
		arg	sem
		prologue

		mov	eax,[%$sem]
		cmp	dword [eax+tSync.Owner],SYNC_NAMED_SEM
		jne	.Normal

		; Named semaphore
		Ccall	_write, dword [eax+tSync.Count], 0, 0
		jmp	.Exit

		; Normal (unnamed) semaphore
.Normal:	Ccall	_SyncSemPost, eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_wait(sem_t *sem);
proc _sem_wait
		arg	sem
		prologue

		mov	eax,[%$sem]
		cmp	dword [eax+tSync.Owner],SYNC_NAMED_SEM
		jne	.Normal

		; Named semaphore
		Ccall	_read, dword [eax+tSync.Count], 0, 0
		jmp	.Exit

		; Normal (unnamed) semaphore
.Normal:	Ccall	_SyncSemWait, eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_trywait(sem_t *sem);
proc _sem_trywait
		arg	sem
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sched_get_priority_min(int alg);
proc _sched_get_priority_min
		arg	alg
		locauto	info, tSchedInfo_size
		prologue
		lea	eax,[%$info]
		Ccall	_SchedInfo, 0, dword [%$alg], eax
		test	eax,eax
		js	.Exit
		mov	eax,[%$info+tSchedInfo.PrioMin]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sched_get_priority_max(int alg);
proc _sched_get_priority_max
		arg	alg
		locauto	info, tSchedInfo_size
		prologue
		lea	eax,[%$info]
		Ccall	_SchedInfo, 0, dword [%$alg], eax
		test	eax,eax
		js	.Exit
		mov	eax,[%$info+tSchedInfo.PrioMax]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
