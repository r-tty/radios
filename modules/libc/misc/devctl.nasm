;-------------------------------------------------------------------------------
; connect.nasm - DevControl and friends.
;-------------------------------------------------------------------------------

module libc.devctl

%include "errors.ah"
%include "locstor.ah"
%include "rm/iomsg.ah"
%include "rm/devctl.ah"

exportproc _devctl
publicproc DevControl

externproc _MsgSendv

section .text

		; int DevControl(int fd, int dcmd, void *data_ptr, size_t nbytes,
		;	     uint flags);
proc DevControl
		arg	fd, dcmd, dptr, nbytes, flags
		locauto	msg, tIOMdevctl_size
		locauto	iov, 4*tIOV_size
		prologue
		savereg	ebx,ecx,edx

		lea	ebx,[%$msg]
		mov	word [ebx+tIOMdevctl.Type],IOM_DEVCTL
		mov	word [ebx+tIOMdevctl.CombineLen],tIOMdevctl_size
		mov	eax,[%$dcmd]
		mov	[ebx+tIOMdevctl.Dcmd],eax
		mov	eax,[%$nbytes]
		mov	[ebx+tIOMdevctl.Nbytes],eax
		xor	eax,eax
		mov	[ebx+tIOMdevctl.Zero],eax

		lea	edx,[%$iov]
		mSetIOV	edx, 0, ebx, tIOMdevctl_size
		mov	eax,[%$dptr]
		xor	ecx,ecx
		test	dword [%$dcmd],DEVDIR_TO
		jz	.1
		mov	ecx,[%$nbytes]
.1:		mSetIOV	edx, 1, eax, ecx

		mSetIOV	edx, 2, ebx, tIOMdevctlReply_size
		xor	ecx,ecx
		test	dword [%$dcmd],DEVDIR_FROM
		jz	.2
		mov	ecx,[%$nbytes]
.2:		mSetIOV	edx, 3, eax, ecx

		lea	eax,[%$iov+2*tIOV_size]
		Ccall	_MsgSendv, dword [%$fd], edx, byte 2, eax, byte 2
		cmp	eax,-1
		jne	.OK
		test	dword [%$flags],DEVCTL_FLAG_NOTTY
		jz	.Fail
		mGetErrno eax
		cmp	eax,ENOSYS
		jne	.Fail
		mSetErrno ENOTTY, eax

.Fail:		xor	eax,eax
		dec	eax
		jmp	.Exit

.OK:		xor	eax,eax
		test	dword [%$flags],DEVCTL_FLAG_NORETVAL
		jnz	.Exit
		mov	eax,[%$msg+tIOMdevctlReply.RetVal]

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int devctl(int fd, int dcmd, void *data_ptr, size_t nbytes,
		;		int *info_ptr);
proc _devctl
		arg	fd, dcmd, dptr, nbytes, infop
		ret
endp		;---------------------------------------------------------------
