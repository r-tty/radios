;-------------------------------------------------------------------------------
; posix/1.nasm - POSIX 1003.1 routines.
;-------------------------------------------------------------------------------

module libc.posix1

%include "rmk.ah"
%include "errors.ah"
%include "locstor.ah"
%include "tm/procmsg.ah"
%include "rm/netmgr.ah"
%include "rm/iomsg.ah"
%include "rm/fcntl.ah"
%include "rm/devctl.ah"

exportproc _creat, _open, _close, _read, _write, _dup, _fcntl
exportproc _umask

externproc _MsgSend, _MsgSendnc, _MsgSendv
externproc _ConnectAttach, _ConnectDetach_r
externproc _ConnectServerInfo, _ConnectFlags_r, _ConnectFlags
externproc _netmgr_remote_nd, _getpid
externproc Vopen, Devctl


section .text

		; int creat(const char *path, mode_t mode);
proc _creat
		arg	path, mode
		prologue
		Ccall	_open, dword [%$path], O_WRONLY | O_CREAT | O_TRUNC, \
			dword [%$mode]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int open(const char *path, int oflag, ...);
proc _open
		arg	path, oflag, vararg
		prologue
		lea	ebx,[%$vararg]
		Ccall	Vopen, dword [%$path], dword [%$oflag], \
			dword SH_DENYNO, ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int close(int fd);
proc _close
		arg	fd
		locauto	msg, tIOMclose_size
		prologue

		lea	ebx,[%$msg]
		mov	word [ebx+tIOMclose.Type],IOM_CLOSE
		mov	eax,tIOMclose_size
		mov	[ebx+tIOMclose.CombineLen],ax
		Ccall	_MsgSend, dword [%$fd], ebx, eax, 0, 0
		test	eax,eax
		jns	.Detach
		mGetErrno edx
		cmp	edx,EINTR
		je	.Err

.Detach:	push	eax
		Ccall	_ConnectDetach_r, dword [%$fd]
		mov	edx,eax
		or	eax,eax
		pop	eax
		jz	.Exit
		test	eax,eax
		js	.Err
		mSetErrno edx,eax

.Err:		xor	eax,eax
		neg	eax
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int read(int fd, void *buf, size_t count);
proc _read
		arg	fd, buf, count
		locauto	msg, tIOMread_size
		prologue

		lea	ebx,[%$msg]
		mov	word [ebx+tIOMread.Type],IOM_READ
		mov	eax,tIOMread_size
		mov	[ebx+tIOMread.CombineLen],ax
		mov	ecx,[%$count]
		mov	[ebx+tIOMread.Nbytes],ecx
		mov	dword [ebx+tIOMread.Xtype],IOM_XTYPE_NONE
		Ccall	_MsgSend, dword [%$fd], ebx, eax, dword [%$buf],ecx

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int write(int fd, const void *buf, size_t count);
proc _write
		arg	fd, buf, count
		locauto	msg, tIOMwrite_size
		locauto	iov, 2*tIOV_size
		prologue

		lea	ebx,[%$msg]
		mov	word [ebx+tIOMread.Type],IOM_WRITE
		mov	eax,tIOMread_size
		mov	[ebx+tIOMread.CombineLen],ax
		mov	ecx,[%$count]
		mov	[ebx+tIOMread.Nbytes],ecx
		mov	dword [ebx+tIOMread.Xtype],IOM_XTYPE_NONE
	
		lea	edx,[%$iov]
		mSetIOV edx, 0, ebx, eax
		mov	ebx,[%$buf]
		mSetIOV edx, 1, ebx, ecx
		Ccall	_MsgSendv, dword [%$fd], edx, 2, 0, 0

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int dup(int fd);
proc _dup
		arg	fd
		prologue
		Ccall	_fcntl, F_DUPFD, byte 0
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int vfcntl(int fd, int cmd, va_list ap);
proc vfcntl
		arg	fd, cmd, ap
		locunion msg, tIOMdup, tIOMspace, tIOMlock
		locauto	iov, 4*tIOV_size
		locauto info, tMsgInfo_size
		locals	arg, pid, fd2
		prologue
		savereg	ebx,edx,esi,edi

		mov	edx,[%$fd]
		mov	eax,[%$cmd]
		cmp	eax,256
		jae	near .ErrBadFun
		xor	ecx,ecx
		cmp	al,F_DUPFD
		je	near .DupFD
		cmp	al,F_GETFD
		je	near .GetFD
		cmp	al,F_SETFD
		je	near .SetFD
		cmp	al,F_GETFL
		je	near .GetFl
		cmp	al,F_SETFL
		je	near .SetFl
		cmp	al,F_GETOWN
		je	near .GetOwn
		cmp	al,F_SETOWN
		je	near .SetOwn
		mov	cl,al
		cmp	al,F_ALLOCSP64
		je	near .AllocFreeSp64
		cmp	al,F_FREESP64
		je	near .AllocFreeSp64
		cmp	al,F_ALLOCSP
		je	near .AllocSp
		cmp	al,F_FREESP
		je	near .FreeSp
		xor	ecx,ecx
		inc	cl
		cmp	al,F_SETLK
		je	near .Locking
		cmp	al,F_SETLKW
		je	near .Locking
		cmp	al,F_SETLK64
		je	near .Locking		
		cmp	al,F_SETLKW64
		je	near .Locking
		inc	cl
		cmp	al,F_GETLK
		je	near .Locking
		cmp	al,F_GETLK64
		je	near .Locking
.ErrBadFun:	mSetErrno ENOSYS, eax
		xor	eax,eax
		not	eax
		jmp	.Exit

		; Duplicate a file descriptor
.DupFD:		cmp	edx,-1
		je	near .ErrBadFile
		lea	ebx,[%$info]
		Ccall	_ConnectServerInfo, 0, edx, ebx
		cmp	edx,eax
		jne	near .ErrBadFile

		GetArg	%$ap, Dword
		Ccall	_ConnectAttach, dword [ebx+tMsgInfo.ND], \
			dword [ebx+tMsgInfo.PID], dword [ebx+tMsgInfo.ChID], \
			eax, byte COF_CLOEXEC
		cmp	eax,-1
		je	near .FailRet
		mov	[%$fd2],eax

		lea	edi,[%$msg]
		mov	word [edi+tIOMdup.Type],IOM_DUP
		mov	word [edi+tIOMdup.CombineLen],tIOMdup_size
		Ccall	_netmgr_remote_nd, dword [ebx+tMsgInfo.ND], byte ND_LOCAL_NODE
		mov	[edi+tIOMdup.Info+tMsgInfo.ND],eax
		call	_getpid
		mov	[edi+tIOMdup.Info+tMsgInfo.PID],eax
		mov	eax,[ebx+tMsgInfo.ChID]
		mov	[edi+tIOMdup.Info+tMsgInfo.ChID],eax
		mov	eax,[ebx+tMsgInfo.ScoID]
		mov	[edi+tIOMdup.Info+tMsgInfo.ScoID],eax
		mov	eax,[%$fd]
		mov	[edi+tIOMdup.Info+tMsgInfo.CoID],eax
		Ccall	_MsgSendnc, dword [%$fd2], edi, tIOMdup_size, 0, 0
		cmp	eax,-1
		je	.DetachErr
		Ccall	_ConnectFlags_r, dword [%$fd2]
		mov	eax,[%$fd2]
		jmp	.Exit

.DetachErr:	Ccall	_ConnectDetach_r, dword [%$fd2]
		jmp	.FailRet

.ErrBadFile:	mSetErrno EBADF, eax
.FailRet:	xor	eax,eax
		dec	eax
		jmp	.Exit

		; Get file descriptor flags
.GetFD:		Ccall	_ConnectFlags, 0, edx, 0, 0
		jmp	.Exit

		; Set file descriptor flags
.SetFD:		GetArg	%$ap, Dword
		Ccall	_ConnectFlags, 0, edx, -1, eax, 0
		jmp	.Exit

		; Get file status / access modes flags
.GetFl:		lea	eax,[%$arg]
		Ccall	Devctl, edx, DCMD_ALL_GETFLAGS, eax, Dword_size, 0
		cmp	eax,-1
		je	near .Exit
		mov	eax,[%$arg]
		jmp	near .Exit

		; Set file status / access modes flags
.SetFl:		mov	eax,[%$ap]
		Ccall	Devctl, edx, DCMD_ALL_SETFLAGS, eax, Dword_size, 0
		jmp	.Exit

		; DCMD_ALL_GETOWN devctl
.GetOwn:	lea	eax,[%$arg]
		Ccall	Devctl, edx, DCMD_ALL_GETOWN, eax, Dword_size, 0
		cmp	eax,-1
		je	near .Exit
		mov	eax,[%$arg]
		jmp	.Exit

		; DCMD_ALL_SETOWN devctl
.SetOwn:	mov	eax,[%$ap]
		Ccall	Devctl, edx, DCMD_ALL_SETOWN, eax, Dword_size, 0
		jmp	.Exit

		; Extend or truncate the file
.AllocFreeSp64:	lea	ebx,[%$msg]
		mov	esi,[%$ap]
		; Use 64-bit values
		Mov64	ebx+tIOMspace.Start,esi+tFlock.Start
		Mov64	ebx+tIOMspace.Len,esi+tFlock.Len
		jmp	.ExtTrCommon

.AllocSp:	mov	cl,F_ALLOCSP64
		jmp	.ExtTrunc32

.FreeSp:	mov	cl,F_FREESP64
.ExtTrunc32:	lea	ebx,[%$msg]
		mov	esi,[%$ap]
		; Use 32-bit values
		Mov64	ebx+tIOMspace.Start,esi+tFlock.Start
		Mov64	ebx+tIOMspace.Len,esi+tFlock.Len

.ExtTrCommon:	Mov16	ebx+tIOMspace.Whence,esi+tFlock.Whence
		mov	word [ebx+tIOMspace.Type],IOM_SPACE
		mov	word [ebx+tIOMspace.CombineLen],tIOMspace_size
		mov	[ebx+tIOMspace.Subtype],ecx
		Ccall	_MsgSend, edx, ebx, byte tIOMspace_size, 0, 0
		jmp	.Exit

		; Locking functions
.Locking:	lea	ebx,[%$msg]
		mov	word [ebx+tIOMlock.Type],IOM_LOCK
		mov	word [ebx+tIOMlock.CombineLen],tIOMlock_size
		mov	[ebx+tIOMlock.Subtype],eax
		lea	edi,[%$iov]
		mSetIOV	edi, 0, ebx, tIOMlock_size
		mSetIOV	edi, 2, ebx, tIOMlock_size
		mov	esi,[%$arg]
		mSetIOV	edi, 1, esi, tFlock_size
		mSetIOV	edi, 3, esi, tFlock_size
		lea	esi,[%$iov+2*tIOV_size]
		Ccall	_MsgSendv, edx, edi, 2, esi, ecx

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int fcntl(int fd, int cmd, ...);
proc _fcntl
		arg	fd, cmd, vararg
		prologue
		lea	ebx,[%$vararg]
		Ccall	vfcntl, dword [%$fd], dword [%$cmd], ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; mode_t Umask(pid_t pid, mode_t cmask);
proc Umask
		arg	pid, cmask
		locauto	msg, tMsg_ProcUmask_size
		prologue
		savereg	edx

		lea	edx,[%$msg]
		mov	dword [edx],PROC_UMASK + (PROC_UMASK_SET << 16)
		Mov32	edx+tProcUmaskRequest.Umask,%$cmask
		Mov32	edx+tProcUmaskRequest.PID,%$pid
		Ccall	_MsgSendnc, PROCMGR_COID, edx, tProcUmaskRequest_size, \
			edx, tProcUmaskReply_size
		cmp	eax,-1
		je	.Exit
		mov	eax,[%$msg+tProcUmaskReply.Umask]

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; mode_t umask(mode_t cmask);
proc _umask
		arg	cmask
		prologue
		Ccall	Umask, byte 0, dword [%$cmask]
		epilogue
		ret
endp		;---------------------------------------------------------------
