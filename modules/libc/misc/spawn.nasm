;-------------------------------------------------------------------------------
; spawn.nasm - spawn() routines.
;-------------------------------------------------------------------------------

module libc.spawn

%include "rmk.ah"
%include "msg.ah"
%include "errors.ah"
%include "locstor.ah"
%include "rm/netmgr.ah"
%include "tm/procmsg.ah"

exportproc _spawn, _spawnl, _spawnle, _spawnlp, _spawnlpe
exportproc _spawnp, _spawnvp, _spawnve, _spawnvpe

externproc _MsgSendvnc, _ConnectAttach, _ConnectDetach
externproc _waitpid, _getenv
externproc _malloc, _free
externproc _strchr, _strlen
externdata _environ

section .data

TxtPath		DB	"PATH",0

section .text

		; pid_t spawn(const char *path, int fd_count, const int fd_map[],
		;		const struct inheritance *inherit, char **argv,
		;		char **envp);
proc _spawn
		arg	path, fdcnt, fdmap, inherit, argv, envp
		locauto	msg, tMsg_ProcSpawn_size
		locauto	iov, 6*tIOV_size
		locals	arg, src, search, data, coid, premote
		prologue
		savereg	ebx,ecx,edx,esi,edi

		lea	ebx,[%$msg]
		mov	word [ebx+tMsg_ProcSpawn.Type],PROC_SPAWN
		mov	word [ebx+tMsg_ProcSpawn.Subtype],PROC_SPAWN_START

		cld
		xor	eax,eax
		mov	[%$search],eax
		mov	ecx,tSpawnInheritance_size
		lea	edi,[ebx+tMsg_ProcSpawn.Parms]
		mov	esi,[%$inherit]
		mov	edx,esi
		cmp	esi,eax
		jz	.NoInherit
		rep	movsb

		test	dword [edx+tSpawnInheritance.Flags],SPAWN_SEARCH_PATH
		jz	.TestSetND
		Ccall	_getenv, TxtPath
		mov	[%$search],eax

.TestSetND:	test	dword [edx+tSpawnInheritance.Flags],SPAWN_SETND
		jz	.CountLen
		mov	eax,[edx+tSpawnInheritance.ND]
		and	eax,ND_NODE_MASK
		cmp	eax,ND_LOCAL_NODE		; Remote spawn?
		je	.CountLen
		mov	word [ebx+tMsg_ProcSpawn.Subtype],PROC_SPAWN_REMOTE
		jmp	.CountLen

.NoInherit:	rep	stosb

.CountLen:	xor	eax,eax
		mov	[ebx+tMsg_ProcSpawn.Nargv],eax
		mov	[ebx+tMsg_ProcSpawn.Narge],eax

		; ECX is a bytes counter
		xor	ecx,ecx
		mov	esi,[%$argv]
		or	esi,esi
		jz	.CountEnv
.LoopCntArgv:	lodsd
		or	eax,eax
		jz	.CountEnv
		Ccall	_strlen, eax
		inc	eax
		add	ecx,eax
		inc	dword [ebx+tMsg_ProcSpawn.Nargv]
		jmp	.LoopCntArgv

.CountEnv:	mov	esi,[%$envp]
		or	esi,esi
		jnz	.LoopCntEnvp
		mov	esi,[_environ]
.LoopCntEnvp:	lodsd
		or	eax,eax
		jz	.SetNFDs
		Ccall	_strlen, eax
		inc	eax
		add	ecx,eax
		inc	dword [ebx+tMsg_ProcSpawn.Narge]
		jmp	.LoopCntEnvp

.SetNFDs:	Mov32	ebx+tMsg_ProcSpawn.NFDs,%$fdcnt
		mov	dword [%$coid],PROCMGR_COID
		mov	[ebx+tMsg_ProcSpawn.Nbytes],ecx
		lea	edi,[%$iov]
		cmp	dword [ebx+tMsg_ProcSpawn.Subtype],PROC_SPAWN_REMOTE
		jne	near .Local

		; Remote spawn
		lea	eax,[ecx+SPAWN_REMOTE_MSGBUF_SIZE]
		Ccall	_malloc, eax
		test	eax,eax
		jz	near .ErrNoMem
		mov	[%$data],eax
		add	eax,ecx
		mov	[%$premote],eax
		mov	esi,eax
		mSetIOV	edi, 0, ebx, tMsg_ProcSpawn_size
		mSetIOV	edi, 2, ebx, tMsg_ProcSpawn_size
		mov	edx,[%$fdmap]
		mov	eax,[%$fdcnt]
		shl	eax,2					; *= Dword_size
		mSetIOV	edi, 1, edx, eax
		mSetIOV	edi, 3, esi, SPAWN_REMOTE_MSGBUF_SIZE
		lea	eax,[edi+2*tIOV_size]
		Ccall	_MsgSendvnc, edi, byte 2, eax, byte 2
		inc	eax
		jnz	.ConnAttach
.FreeAndRet:	Ccall	_free, dword [%$data]
		jmp	.Exit

.ConnAttach:	Ccall	_ConnectAttach, dword [esi+tSpawnRemote.ND], \
			dword [esi+tSpawnRemote.PID], \
			dword [esi+tSpawnRemote.ChID], SIDE_CHANNEL, byte 0
		mov	[%$coid],eax
		inc	eax
		jz	.FreeAndRet
		lea	eax,[esi+tSpawnRemote_size]
		mov	ecx,[esi+tSpawnRemote.Size]
		mSetIOV	edi, 5, eax, ecx
		mov	word [ebx+tMsg_ProcSpawn.Subtype],PROC_SPAWN_START
		jmp	.CopyArgv

		; Local spawn
.Local:		Ccall	_malloc, ecx
		test	eax,eax
		jz	near .ErrNoMem
		mov	[%$data],eax
		mSetIOV	edi, 5, eax, 0

		; Copy the arguments, one by one
.CopyArgv:	mov	edi,[%$data]
		mov	edx,[%$argv]
		or	edx,edx
		jz	.CopyEnvp
.LoopCpyArgv:	mov	esi,[edx]
		or	esi,esi
		jz	.CopyEnvp
.CopyArgStr:	lodsb
		stosb
		or	al,al
		jnz	.CopyArgStr
		add	edx,byte 4
		jmp	.LoopCpyArgv

		; Copy the environment strings, one by one
.CopyEnvp:	mov	edx,[%$envp]
		or	edx,edx
		jz	.Prepare
.LoopCpyEnvp:	mov	esi,[edx]
		or	esi,esi
		jz	.Prepare
.CopyEnvStr:	lodsb
		stosb
		or	al,al
		jnz	.CopyEnvStr
		add	edx,byte 4
		jmp	.LoopCpyArgv

		; Prepare the IOV and send the message
.Prepare:	lea	edi,[%$iov]
		mSetIOV	edi, 0, ebx, tMsg_ProcSpawn_size
		mov	edx,[%$fdmap]
		mov	eax,[%$fdcnt]
		shl	eax,2					; *= Dword_size
		mSetIOV	edi, 1, edx, eax
		xor	eax,eax
		mov	esi,[%$search]
		or	esi,esi
		jz	.SetSearchLen
		Ccall	_strlen, esi
		inc	eax
.SetSearchLen:	mov	[ebx+tMsg_ProcSpawn.SearchLen],ax
		mSetIOV	edi, 2, esi, eax
		xor	eax,eax
		mov	esi,[%$path]
		Ccall	_strlen, esi
		inc	eax
		mov	[ebx+tMsg_ProcSpawn.PathLen],ax
		mSetIOV	edi, 3, esi, eax
		mov	esi,[%$data]
		mov	ecx,[ebx+tMsg_ProcSpawn.Nbytes]
		mSetIOV	edi, 4, esi, ecx

		Ccall	_MsgSendvnc, dword [%$coid], edi, byte 6, 0, 0
		mov	ecx,eax

		mov	edx,[%$coid]
		cmp	edx,PROCMGR_COID
		je	.OK
		Ccall	_ConnectDetach, edx

.OK:		Ccall	_free, dword [%$data]
		mov	eax,ecx

.Exit:		epilogue
		ret

.ErrNoMem:	mSetErrno ENOMEM,eax
		xor	eax,eax
		dec	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int spawnl(int mode, const char *path, const char *arg0, ...);
proc _spawnl
		arg	mode, path, arg0
		prologue
		lea	eax,[%$arg0]
		Ccall	_spawnve, dword [%$mode], dword [%$path], eax, byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int spawnle(int mode, const char *path, const char *arg0, ...);
proc _spawnle
		arg	mode, path, arg0
		prologue
		savereg	ebx,esi

		lea	ebx,[%$arg0]
		mov	esi,ebx
		xor	eax,eax				; Find a pointer to envp
		cld
		repne	scasd
		lodsd
		Ccall	_spawnve, dword [%$mode], dword [%$path], ebx, eax

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int spawnlp(int mode, const char *file, const char *arg0, ...);
proc _spawnlp
		arg	mode, file, arg0
		prologue
		lea	eax,[%$arg0]
		Ccall	_spawnvpe, dword [%$mode], dword [%$file], eax, byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int spawnlpe(int mode, const char *file, const char *arg0, ...);
proc _spawnlpe
		arg	mode, file, arg0
		prologue
		savereg	ebx,esi

		lea	ebx,[%$arg0]
		mov	esi,ebx
		xor	eax,eax				; Find a pointer to envp
		cld
		repne	scasd
		lodsd
		Ccall	_spawnvpe, dword [%$mode], dword [%$file], ebx, eax

		epilogue
		ret
endp		;---------------------------------------------------------------


		; pid_t spawnp(const char *file, int fd_count, const int fd_map[],
		;		const struct inheritance *inherit,
		;		char * const argv[], char * const envp[]);
proc _spawnp
		arg	file, fdcnt, fdmap, inherit, argv, envp
		locauto	attr, tSpawnInheritance_size
		prologue
		savereg	ecx,esi,edi

		cld
		xor	ecx,ecx
		mov	cl,tSpawnInheritance_size
		lea	edi,[%$attr]
		mov	esi,[%$inherit]
		or	esi,esi
		jz	.ZeroAttr
		rep	movsb
		jmp	.1

.ZeroAttr:	xor	eax,eax
		rep	stosb

.1:		Ccall	_strchr, dword [%$file], byte '/'
		or	eax,eax
		jnz	.2
		or	dword [%$attr+tSpawnInheritance.Flags],SPAWN_SEARCH_PATH

.2:		lea	edi,[%$attr]
		or	dword [edi+tSpawnInheritance.Flags],SPAWN_CHECK_SCRIPT
		lea	edi,[%$attr]
		Ccall	_spawn, dword [%$file], dword [%$fdcnt], dword [%$fdmap], \
			edi, dword [%$argv], dword [%$envp]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int spawnve(int mode, const char *path, char * const argv[],
		;		char * const envp[]);
proc _spawnve
		arg	mode, path, argv, envp
		locauto	attr, tSpawnInheritance_size
		locals	pid
		prologue
		savereg	edx

		mov	eax,[%$mode]
		cmp	eax,P_NOWAITO
		ja	.ErrInval
		je	.NoZombie
		xor	edx,edx
		cmp	al,P_WAIT
		je	.1
		cmp	al,P_NOWAIT
		je	.1
		mov	edx,SPAWN_EXEC
		jmp	.1

.NoZombie:	mov	edx,SPAWN_NOZOMBIE
.1:		mov	[%$attr+tSpawnInheritance.Flags],edx
		lea	edx,[%$attr]
		Ccall	_spawn, dword [%$path], byte 0, byte 0, edx, \
			dword [%$argv], dword [%$envp]
		cmp	eax,-1
		je	.Exit
		cmp	dword [%$mode],P_WAIT
		jne	.Exit
		lea	ebx,[%$pid]
		Ccall	_waitpid, eax, ebx, 0
		cmp	eax,-1
		je	.Exit
		mov	eax,[%$pid]

.Exit:		epilogue
		ret

.ErrInval:	mSetErrno EINVAL, eax
		xor	eax,eax
		not	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int spawnv(int mode, const char *path, char * const *argv);
proc _spawnv
		arg	mode, path, argv
		prologue
		Ccall	_spawnve, dword [%$mode], dword [%$path], \
			dword [%$argv], byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int spawnvpe(int mode, const char *file, char * const argv[],
		;		char * const envp[]);
proc _spawnvpe
		arg	mode, file, argv, envp
		locauto	attr, tSpawnInheritance_size
		locals	pid
		prologue
		savereg	edx

		mov	eax,[%$mode]
		cmp	eax,P_NOWAITO
		ja	.ErrInval
		je	.NoZombie
		xor	edx,edx
		cmp	al,P_WAIT
		je	.1
		cmp	al,P_NOWAIT
		je	.1
		mov	edx,SPAWN_EXEC
		jmp	.1

.NoZombie:	mov	edx,SPAWN_NOZOMBIE
.1:		mov	[%$attr+tSpawnInheritance.Flags],edx
		lea	edx,[%$attr]
		Ccall	_spawnp, dword [%$file], byte 0, byte 0, edx, \
			dword [%$argv], dword [%$envp]
		cmp	eax,-1
		je	.Exit
		cmp	dword [%$mode],P_WAIT
		jne	.Exit
		lea	ebx,[%$pid]
		Ccall	_waitpid, eax, ebx, 0
		cmp	eax,-1
		je	.Exit
		mov	eax,[%$pid]

.Exit:		epilogue
		ret

.ErrInval:	mSetErrno EINVAL, eax
		xor	eax,eax
		not	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int spawnvp(int mode, const char *file, char * const *argv)
proc _spawnvp
		arg	mode, file, argv
		prologue
		Ccall	_spawnvpe, dword [%$mode], dword [%$file], \
			dword [%$argv], byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------
