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

KEY_NONE	EQU	-1

section .data

@key_count	DD	0
@key_destructor	DD	0
@key_mutex	DD	MUTEX_INITIALIZER


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


		; int pthread_mutex_init(pthread_mutex_t *mutex, 
		;			 const pthread_mutexattr_t *attr);
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
		savereg	ebx,edx,esi

		mov	esi,[%$mutex]
		mov	ebx,[esi+tSync.Owner]
		and	ebx,~SYNC_WAITING
		tlsptr(edx)
		cmp	ebx,[edx+tTLS.Owner]
		mov	eax,EPERM
		jne	.Exit

		xor	eax,eax
		dec	dword [esi+tSync.Count]
		jle	.1
		test	dword [esi+tSync.Count],SYNC_COUNTMASK
		jnz	.Exit
.1:		xchg	eax,[esi+tSync.Owner]
		test	eax,SYNC_WAITING
		jnz	.Unlock
		test	dword [esi+tSync.Count],SYNC_PRIOCEILING
		jz	.OK
.Unlock:	Ccall	_SyncMutexUnlock_r, esi

.OK:		xor	eax,eax
.Exit:		epilogue
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
		; XXX
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_broadcast(pthread_cond_t *cond);
proc _pthread_cond_broadcast
		arg	cond
		prologue
		; XXX
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_key_create(pthread_key_t *key,
		;				void (*destructor)(void *));
proc _pthread_key_create
		arg	key, destr
		prologue
		savereg	edx

		Ccall	_pthread_mutex_lock, dword @key_mutex
		or	eax,eax
		jnz	.Exit

		; Allocate destructor table
		mov	eax,[@key_destructor]
		or	eax,eax
		jnz	.ChkDestructor
		Ccall	_malloc, Dword
	if(!_key_destructor) {
		if(!(_key_destructor = malloc(sizeof *_key_destructor * PTHREAD_KEYS_MAX))) {
			pthread_mutex_unlock(&_key_mutex);
			return ENOMEM;
		}
		memset(_key_destructor, (int)_KEY_NONE, sizeof *_key_destructor * PTHREAD_KEYS_MAX);
	}

	// is destructor valid?
.ChkDestructor:	cmp	dword [%$destr],KEY_NONE
	if(destructor == _KEY_NONE ) {
		pthread_mutex_unlock(&_key_mutex);
		return EINVAL;
	}

	// are there enough keys?
	if(_key_count >= PTHREAD_KEYS_MAX) {
		pthread_mutex_unlock(&_key_mutex);
		return EAGAIN;
	}

	// find first free key
	for(k = 0; k < PTHREAD_KEYS_MAX; k++) {
		if(_key_destructor[k] == _KEY_NONE) {
			break;
		}
	}

	// this should never happen!
	if(k >= PTHREAD_KEYS_MAX) {
		pthread_mutex_unlock(&_key_mutex);
		return EAGAIN;
	}

	_key_destructor[k] = destructor;
	*key = k;
	_key_count++;

	pthread_mutex_unlock(&_key_mutex);
	return EOK;
}
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_key_delete(pthread_key_t key);
proc _pthread_key_delete
		arg	key
		prologue
		savereg	ebx,edx

		Ccall	_pthread_mutex_lock, dword @key_mutex
		or	eax,eax
		jnz	.Exit

		mov	edx,[%$key]
		test	edx,edx
		jc	.Invalid
		mov	ebx,[@key_destructor]
		or	ebx,ebx
		jz	.Invalid
		cmp	dword [ebx+edx*4],KEY_NONE
		je	.Invalid

		; Destructor functions are called in pthread_exit
		mov	dword [ebx+edx*4],KEY_NONE
		dec	@key_count
		Ccall	_pthread_mutex_unlock, dword @key_mutex

		xor	eax,eax

.Exit:		epilogue
		ret

.Invalid:	Ccall	_pthread_mutex_unlock, dword @key_mutex
		mov	eax,EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int pthread_once(pthread_once_t *once_control,
		;			void (*init_routine)(void));
proc _pthread_once
		arg	ctrl, initfunc
		prologue
		savereg	edx,esi

		mov	edx,[%$ctrl]
		cmp	dword [edx+tPthreadOnce.Once],0
		jne	.OK

		lea	esi,[edx+tPthreadOnce.Mutex]
		Ccall	_pthread_mutex_lock, esi
		or	eax,eax
		jz	.CheckFirst
		cmp	dword [edx+tPthreadOnce.Once],0
		jne	.OK
		jmp	.Exit

.CheckFirst:	cmp	dword [edx+tPthreadOnce.Once],0
		jne	.Unlock
		Ccall	_pthread_cleanup_push, .CancelFunc, esi
		call	dword [%$initfunc]
		Ccall	_pthread_cleanup_pop, 0
		inc	dword [edx+tPthreadOnce.Once]

.Unlock:	lea	esi,[edx+tPthreadOnce.Mutex]
		Ccall	_pthread_mutex_unlock, esi
		or	eax,eax
		jnz	.OK
		Ccall	_pthread_mutex_destroy, esi

.OK:		xor	eax,eax
.Exit:		epilogue
		ret

		; Cancellation sub-routine
.CancelFunc:	Ccall	_pthread_mutex_unlock, dword [esp+4]
		ret
endp		;---------------------------------------------------------------
