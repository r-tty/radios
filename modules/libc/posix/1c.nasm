;-------------------------------------------------------------------------------
; posix/1c.nasm - POSIX thread routines (1003.1c).
;-------------------------------------------------------------------------------

module libc.posix1c

%include "errors.ah"
%include "locstor.ah"
%include "sync.ah"

exportproc _pthread_mutex_init, _pthread_mutex_destroy
exportproc _pthread_mutex_lock, _pthread_mutex_trylock, _pthread_mutex_unlock
exportproc _pthread_cond_init, _pthread_cond_destroy
exportproc _pthread_cond_wait, _pthread_cond_timedwait
exportproc _pthread_cond_signal, _pthread_cond_broadcast
exportproc _sem_init, _sem_destroy, _sem_post, _sem_wait, _sem_trywait

externproc _SyncTypeCreate_r, _SyncDestroy_r
externproc _SyncMutexLock_r, _SyncMutexUnlock_r
externproc _SyncCondvarWait_r, _SyncCondvarSignal_r

section .text

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
		epilogue
		ret
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
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_destroy(pthread_cond_t *cond);
proc _pthread_cond_destroy
		arg	cond
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_wait(pthread_cond_t *cond,
		;			pthread_mutex_t *mutex);
proc _pthread_cond_wait
		arg	cond, mutex
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pthread_cond_timedwait(pthread_cond_t *cond,
		;				pthread_mutex_t *mutex,
		;				const struct timespec* abstime);
proc _pthread_cond_timedwait
		arg	cond, mutex, abstime
		prologue
		epilogue
		ret
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


		; int sem_init(sem_t *sem, int pshared, uint value);
proc _sem_init
		arg	sem, pshared, value
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_destroy(sem_t *sem);
proc _sem_destroy
		arg	sem
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_post(sem_t *sem);
proc _sem_post
		arg	sem
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_wait(sem_t *sem);
proc _sem_wait
		arg	sem
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sem_trywait(sem_t *sem);
proc _sem_trywait
		arg	sem
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
