;-------------------------------------------------------------------------------
; posix/1_proc.nasm - POSIX process routines.
;-------------------------------------------------------------------------------

module libc.proc

%include "rmk.ah"
%include "locstor.ah"
%include "tm/procmsg.ah"

exportproc _getpid, _getppid, _getpgrp, _waitpid, _wait
exportproc _execl, _execle, _execlp, _execlpe
exportproc _execv, _execve, _execvp, _execvpe
exportproc _fork

externproc _MsgSendnc
externproc _spawn, _spawnp
externproc _wait4

section .text

		; pid_t getpid(void);
proc _getpid
		tlsptr(eax)
		mov	eax,[eax+tTLS.PID]
		ret
endp		;---------------------------------------------------------------


		; pid_t getppid(void);
proc _getppid
		locauto	msg, tMsg_ProcGetSetID_size
		prologue
		savereg	ebx,edx

		lea	ebx,[%$msg]
		mov	word [ebx+tProcGetSetIDrequest.Type],PROC_GETSETID
		mov	word [ebx+tProcGetSetIDrequest.Subtype],PROC_ID_GETID
		xor	eax,eax
		mov	[ebx+tProcGetSetIDrequest.PID],eax
		Ccall	_MsgSendnc, dword PROCMGR_COID, ebx, \
			byte tProcGetSetIDrequest_size, ebx, \
			byte tProcGetSetIDreply_size
		cmp	eax,-1
		je	.Exit
		mov	eax,[ebx+tProcGetSetIDreply.Ppid]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; pid_t getpgrp(void)
proc _getpgrp
		locauto	msg, tMsg_ProcGetSetID_size
		prologue
		savereg	ebx,edx

		lea	ebx,[%$msg]
		mov	word [ebx+tProcGetSetIDrequest.Type],PROC_GETSETID
		mov	word [ebx+tProcGetSetIDrequest.Subtype],PROC_ID_GETID
		xor	eax,eax
		mov	[ebx+tProcGetSetIDrequest.PID],eax
		Ccall	_MsgSendnc, dword PROCMGR_COID, ebx, \
			byte tProcGetSetIDrequest_size, ebx, \
			byte tProcGetSetIDreply_size
		cmp	eax,-1
		je	.Exit
		mov	eax,[ebx+tProcGetSetIDreply.Pgrp]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execl(const char *path, const char *arg0, ...);
proc _execl
		arg	path, arg0
		prologue
		lea	eax,[%$arg0]
		Ccall	_execve, dword [%$path], eax, byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execle(const char *path, const char *arg0, ...);
proc _execle
		arg	path, arg0
		prologue
		savereg	ebx,esi
		lea	ebx,[%$arg0]
		mov	esi,ebx
		xor	eax,eax				; Find a pointer to envp
		cld
		repne	scasd
		lodsd
		Ccall	_execve, dword [%$path], ebx, eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		 ; int execlp(const char *path, const char *arg0, ...);
proc _execlp
		arg	path, arg0
		prologue
		lea	eax,[%$arg0]
		Ccall	_execvpe, dword [%$path], eax, byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execlpe(const char *path, const char *arg0, ...);
proc _execlpe
		arg	path, arg0
		prologue
		savereg	ebx,esi
		lea	ebx,[%$arg0]
		mov	esi,ebx
		xor	eax,eax				; Find a pointer to envp
		cld
		repne	scasd
		lodsd
		Ccall	_execvpe, dword [%$path], ebx, eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execve(const char *path, char * const *argv, 
		;		char * const *envp);
proc _execve
		arg	path, argv, envp
		locauto	attr, tSpawnInheritance
		prologue
		lea	eax,[%$attr]
		mov	dword [eax+tSpawnInheritance.Flags],SPAWN_EXEC
		Ccall	_spawn, dword [%$path], byte 0, byte 0, eax, \
			dword [%$argv], dword [%$envp]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execv(const char *path, char * const *argv)
proc _execv
		arg	path, argv
		prologue
		Ccall	_execve, dword [%$path], dword [%$argv], byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execvpe(const char *file, char * const *argv,
		;		char * const *envp);
proc _execvpe
		arg	file, argv, envp
		locauto	attr, tSpawnInheritance
		prologue
		lea	eax,[%$attr]
		mov	dword [eax+tSpawnInheritance.Flags],SPAWN_EXEC
		Ccall	_spawnp, dword [%$file], byte 0, byte 0, eax, \
			dword [%$argv], dword [%$envp]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int execvp(const char *file, char * const *argv);
proc _execvp
		arg	file, argv
		prologue
		Ccall	_execvpe, dword [%$file], dword [%$argv], byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; pid_t Fork(unsigned flags, uintptr_t frame);
proc Fork
		arg	flags, frame
		locauto	msg, tMsg_ProcFork_size
		prologue
		savereg	ebx,edx

		; We don't support any pthread_atfork() stuff yet..
		lea	ebx,[%$msg]
		mov	word [ebx+tMsg_ProcFork.Type],PROC_FORK
		mov	word [ebx+tMsg_ProcFork.Zero],0
		Mov32	ebx+tMsg_ProcFork.Flags,%$flags
		Mov32	ebx+tMsg_ProcFork.Frame,%$frame
		Ccall	_MsgSendnc, PROCMGR_COID, ebx, tMsg_ProcFork, 0, 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; pid_t fork(void);
proc _fork
		Ccall	Fork, byte FORK_ASPACE, byte 0
		ret
endp		;---------------------------------------------------------------


		; pid_t waitpid(pid_t pid, int *stat_loc, int options);
proc _waitpid
		arg	pid, sloc, opts
		prologue
		mov	eax,[%$pid]
		test	eax,eax
		js	.Zero
		jnz	.Wait4
		call	_getpgrp
		neg	eax
		jmp	.Wait4

.Zero:		xor	eax,eax
.Wait4:		Ccall	_wait4, eax, dword [%$sloc], dword [%$opts], byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; pid_t wait(int *stat_loc)
proc _wait
		arg	statloc
		prologue
		Ccall	_wait4, dword [%$statloc], byte 0, byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------
