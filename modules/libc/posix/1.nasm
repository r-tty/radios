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

exportproc _open, _close, _read, _write, _fcntl
exportproc _getpid

externproc vopen, _MsgSend, _MsgSendnc, _MsgSendv
externproc _ConnectAttach, _ConnectDetach_r, _ConnectServerInfo
externproc _netmgr_remote_nd


section .text

		; int open(const char *path, int oflag, ...);
proc _open
		arg	path, oflag, vararg
		prologue
		lea	ebx,[%$vararg]
		Ccall	vopen, dword [%$path], dword [%$oflag], \
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


		; int vfcntl(int fd, int cmd, va_list ap);
proc vfcntl
		arg	fd, cmd, ap
		locunion msg, tIOMdup, tIOMspace, tIOMlock
		locauto	iov, 4*tIOV_size
		locauto info, tMsgInfo_size
		locals	arg, pid, fd2
		prologue
		savereg	ebx,edx,esi,edi

		mov	eax,[%$cmd]
		cmp	eax,256
		jae	near .ErrBadFun
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
		cmp	al,F_ALLOCSP64
		je	near .AllocSp64
		cmp	al,F_FREESP64
		je	near .FreeSp64
		cmp	al,F_ALLOCSP
		je	near .AllocSp
		cmp	al,F_FREESP
		je	near .FreeSp
		cmp	al,F_GETLK
		je	near .Locking
		cmp	al,F_SETLK
		je	near .Locking
		cmp	al,F_SETLKW
		je	near .Locking
		cmp	al,F_GETLK64
		je	near .Locking		
		cmp	al,F_SETLK64
		je	near .Locking		
		cmp	al,F_SETLKW64
		je	near .Locking
.ErrBadFun:	mSetErrno ENOSYS, eax
		xor	eax,eax
		not	eax
		jmp	.Exit

		; Duplicate a file descriptor
.DupFD:		mov	edx,[%$fd]
		cmp	edx,-1
		je	near .ErrBadFile
		lea	ebx,[%$info]
		Ccall	_ConnectServerInfo, 0, edx, ebx
		cmp	edx,eax
		jne	.ErrBadFile

		GetArg	%$ap, Dword
		Ccall	_ConnectAttach, dword [ebx+tMsgInfo.ND], \
			dword [ebx+tMsgInfo.PID], dword [ebx+tMsgInfo.ChID], \
			eax, byte COF_CLOEXEC
		cmp	eax,-1
		je	.FailRet
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
		Ccall	_MsgSendnc, dword [%$fd2], edi, 0, 0,


.ErrBadFile:	mSetErrno EBADF, eax
.FailRet:	xor	eax,eax
		dec	eax
		jmp	.Exit

		; Get file descriptor flags
.GetFD:

		; Set file descriptor flags
.SetFD:

		; Get file status / access modes flags
.GetFl:

		; Get file status / access modes flags
.SetFl:

		; DCMD_ALL_GETOWN devctl
.GetOwn:

		; DCMD_ALL_SETOWN devctl
.SetOwn:

		; Extend the file with zeros
.AllocSp:
.AllocSp64:

		; Truncate the file
.FreeSp:
.FreeSp64:

		; Locking functions
.Locking:

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
