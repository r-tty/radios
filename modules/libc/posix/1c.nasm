;-------------------------------------------------------------------------------
; posix/1c.nasm - POSIX thread routines (1003.1c).
;-------------------------------------------------------------------------------

module libc.posix1c

%include "errors.ah"
%include "thread.ah"
%include "locstor.ah"
%include "sync.ah"
%include "time.ah"

exportproc _pthread_mutex_init, _pthread_mutex_destroy
exportproc _pthread_mutex_lock, _pthread_mutex_trylock, _pthread_mutex_unlock
exportproc _pthread_cond_init, _pthread_cond_destroy
exportproc _pthread_cond_wait, _pthread_cond_timedwait
exportproc _pthread_cond_signal, _pthread_cond_broadcast

externproc _SyncTypeCreate_r, _SyncDestroy_r
externproc _SyncMutexLock_r, _SyncMutexUnlock_r
externproc _SyncCondvarWait_r, _SyncCondvarSignal_r
externproc _TimerTimeout_r

section .text

		; Convert time specification into the number of nanoseconds.
		; Input: EBX=pointer to tTimeSpec structure.
		; Output: EDX:EAX=number of nanoseconds.
proc Timespec2nsec
		mov	eax,[ebx+tTimeSpec.Seconds]
		mov	edx,1000000000
		mul	edx
		add	eax,[ebx+tTimeSpec.Nanoseconds]
		adc	edx,byte 0
		ret
endp		;---------------------------------------------------------------


		;int pthread_mutex_init(pthread_mutex_t *mutex, 
		;			const pthread_mutexattr_t *attr);
proc _pthread_mutex_init
		arg	mutex, attr
		prologue
		Ccall	_SyncTypeCreate_r, SYNC_MUTEX_FREE, \
			dword [%$mutex], dword [%$attr]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_mutex_destroy(pthread_mutex_t * mutex);
proc _pthread_mutex_destroy
		jmp	_SyncDestroy_r
endp		;---------------------------------------------------------------


		; int pthread_mutex_lock(pthread_mutex_t *mutex);
proc _pthread_mutex_lock
		arg	mutex
		prologue
		savereg	ebx,edx,esi

		mov	esi,[%$mutex]
		test	dword [esi+tSync.Count],SYNC_PRIOCEILING
		jnz	.CheckOwner
		tlsptr(edx)
		mov	ebx,[edx+tTLS.Owner]
		xor	eax,eax
	lock	cmpxchg	dword [esi+tSync.Owner],ebx
		jz	.BumpCount

.CheckOwner:	mov	eax,[esi+tSync.Owner]
		and	eax,~SYNC_WAITING
		cmp	eax,ebx
		jne	.Wait
		mov	eax,[esi+tSync.Count]
		test	eax,SYNC_NONRECURSIVE
		jnz	.CheckDeadlock
		and	eax,SYNC_COUNTMASK
		cmp	eax,SYNC_COUNTMASK
		jne	.BumpCount
		mov	eax,EAGAIN
		jmp	.Exit

.CheckDeadlock:	test	eax,SYNC_NOERRORCHECK
		jnz	.Wait
		mov	eax,EDEADLK
		jmp	.Exit

.Wait:		Ccall	_SyncMutexLock_r, esi
		test	eax,eax
		jnz	.Exit

.BumpCount:	inc	dword [esi+tSync.Count]
		xor	eax,eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_mutex_trylock(pthread_mutex_t *mutex);
proc _pthread_mutex_trylock
		arg	mutex
		prologue
		savereg	ebx,ecx,edx,esi

		; Is the mutex unlocked?
		mov	esi,[%$mutex]
		tlsptr(edx)
		mov	ebx,[edx+tTLS.Owner]
		xor	eax,eax
	lock	cmpxchg	dword [esi+tSync.Owner],ebx
		jz	.BumpCount

		; Is the mutex recursive and locked by us?
		mov	edx,eax
		mov	ecx,[esi+tSync.Count]
		test	ecx,SYNC_NONRECURSIVE
		jnz	.ChkStatic
		and	eax,~SYNC_WAITING
		cmp	eax,ebx
		je	.BumpCount

.ChkStatic:	cmp	edx,SYNC_INITIALIZER
		jne	.ChkDestroy
		; Statically initialized mutex. Request an immediate timeout.
		Ccall	_TimerTimeout_r, CLOCK_REALTIME, byte 0, 0, 0, 0
		Ccall	_SyncMutexLock_r, esi
		test	eax,eax
		jnz	.Exit
.BumpCount:	inc	dword [esi+tSync.Count]
		xor	eax,eax

.Exit:		epilogue
		ret

.ChkDestroy:	cmp	dword [esi+tSync.Owner],SYNC_DESTROYED
		mov	eax,EINVAL
		je	.Exit
		mov	eax,EBUSY
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int pthread_mutex_unlock(pthread_mutex_t *mutex);
proc _pthread_mutex_unlock
		arg	mutex
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_init(pthread_cond_t *cond,
		;			 pthread_condattr_t *attr);
proc _pthread_cond_init
		arg	cond, attr
		prologue
		Ccall	_SyncTypeCreate_r, SYNC_COND, dword [%$cond], \
			dword [%$attr]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_destroy(pthread_cond_t *cond);
proc _pthread_cond_destroy
		jmp	_SyncDestroy_r
endp		;---------------------------------------------------------------


		; int pthread_cond_wait(pthread_cond_t *cond,
		;			pthread_mutex_t *mutex);
proc _pthread_cond_wait
		arg	cond, mutex
		prologue
		savereg	ebx,esi

		mov	esi,[%$mutex]
		tlsptr(ebx)
		mov	ebx,[ebx+tTLS.Owner]
		mov	eax,[esi+tSync.Owner]
		and	eax,~SYNC_WAITING
		cmp	eax,ebx
		mov	eax,EINVAL
		je	.Exit

		Ccall	_SyncCondvarWait_r, dword [%$cond], esi
		cmp	eax,EINTR
		jne	.Exit
		xor	eax,eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_timedwait(pthread_cond_t *cond,
		;				pthread_mutex_t *mutex,
		;				const struct timespec* abstime);
proc _pthread_cond_timedwait
		arg	cond, mutex, abstime
		locauto	nsec, Qword_size
		prologue
		savereg	ebx,edx,esi,edi

		tlsptr(ebx)
		mov	ebx,[ebx+tTLS.Owner]
		mov	esi,[%$mutex]
		mov	eax,[esi+tSync.Owner]
		and	eax,~SYNC_WAITING
		cmp	eax,ebx
		jne	.Inval

		mov	ebx,[%$abstime]
		call	Timespec2nsec
		lea	edi,[%$nsec]
		mov	[edi],eax
		mov	[edi+4],edx

		; Passing a NULL for event is the same as notify = SIGEV_UNBLOCK
		mov	ebx,[%$cond]
		mov	eax,CLOCK_REALTIME
		cmp	dword [ebx+tSync.Owner],SYNC_INITIALIZER
		je	.1
		mov	eax,[ebx+tSync.Count]
.1:		Ccall	_TimerTimeout_r, eax, TIMER_ABSTIME | TIMEOUT_CONDVAR, \
			byte 0, edi, byte 0
		test	eax,eax
		jnz	.Exit

		Ccall	_SyncCondvarWait_r, ebx, esi
		cmp	eax,EINTR
		jne	.Exit
		xor	eax,eax

.Exit:		epilogue
		ret

.Inval:		mov	eax,EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int pthread_cond_signal(pthread_cond_t *cond);
proc _pthread_cond_signal
		arg	cond
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_broadcast(pthread_cond_t *cond);
proc _pthread_cond_broadcast
		arg	cond
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
