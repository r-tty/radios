;-------------------------------------------------------------------------------
; posix1.nasm - POSIX routines.
;-------------------------------------------------------------------------------

module libc.posix1

%include "rmk.ah"
%include "errors.ah"
%include "locstor.ah"
%include "rm/iomsg.ah"

exportproc _open, _close, _read, _write

externproc __vopen, _MsgSend, _MsgSendv, _ConnectDetach_r

section .text

		; int open(const char *path, int oflag, ...);
proc _open
		arg	path, oflag, vararg
		prologue
		lea	ebx,[%$vararg]
		Ccall	__vopen, dword [%$path], dword [%$oflag], \
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
