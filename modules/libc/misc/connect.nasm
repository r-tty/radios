;-------------------------------------------------------------------------------
; connect.nasm - ConnectControl and friends.
;-------------------------------------------------------------------------------

module libc.connect

%include "errors.ah"
%include "locstor.ah"
%include "rm/iomsg.ah"
%include "rm/fcntl.ah"
%include "connect.ah"

publicproc ConnectEntry, ConnectControl, Vopen

externproc _memset
externproc _MsgSendv, _MsgSendvnc


section .text

		; int ConnectIO(struct _connect_ctrl const *ctrl, int fd,
		;		const char *prefix, uint prefix_len,
		;		const char *path, void *buffer,
		;		const struct _io_connect_entry *entry);
proc ConnectIO
		arg	ctrl, fd, prefix, prefixlen, path, buffer, entry
		locauto	siov, 5*tIOV_size
		locauto	riov, 2*tIOV_size
		locals	retval, tryagain
		prologue
		savereg	ebx,edx

		mov	edi,[%$ctrl]
		mov	ebx,[edi+tConnectCtrl.Msg]
		lea	edx,[edi+tConnectCtrl.Link]

		; If our entries don't match, then try and resolve it to a link
		; to find a match by sending an COMBINE_CLOSE message to the
		; handler to see if it will resolve into a bigger link.
		; If we do find a match (later on as we recursed through the
		; entries in the process) then actually sent the message that
		; we originally were supposed to send. See rename() to see
		; how this is used.
		; This functionality is also used to resolve links "magically"
		; by switching the message type to be an open if the intial
		; request fails. This means that we don't have to fill proc
		; with all the resolution.

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectEntry(int base, const char *path, mode_t mode,
		;		uint oflag, uint sflag, uint subtype,
		;		int testcancel, uint access, uint file_type,
		;		uint extra_type, uint extra_len,
		;		const void *extra, uint response_len,
		;		void *response, int *status,
		;		struct _io_connect_entry *entry, int enoretry);
proc ConnectEntry
		arg	base, path, mode, oflag, sflag, subtype, testcancel
		arg	access, filetype, extratype, extralen, extra
		arg	resplen, response, status, entry, enoretry
		locauto	ctrl, tConnectCtrl_size
		locauto	msg, tIOMconnect_size
		locals	fd
		prologue

		lea	edi,[%$ctrl]
		Ccall	_memset, edi, dword 0, tConnectCtrl_size
		mov	eax,[%$base]
		mov	[edi+tConnectCtrl.Base],eax
		mov	eax,[%$extra]
		mov	[edi+tConnectCtrl.Extra],eax
		cmp	dword [%$testcancel],0
		jz	.Sendvnc
		mov	dword [edi+tConnectCtrl.SendFunc],_MsgSendv
		jmp	.1
.Sendvnc:	mov	dword [edi+tConnectCtrl.SendFunc],_MsgSendvnc
.1:		lea	ebx,[%$msg]
		mov	[edi+tConnectCtrl.Msg],ebx
		mov	eax,[%$entry]
		cmp	[edi+tConnectCtrl.Entry],eax
		jne	.3
		mov	eax,FLAG_TEST_ENTRY
		cmp	dword [%$enoretry],0
		jz	.2
		or	eax,FLAG_NO_RETRY
.2:		or	[edi+tConnectCtrl.Flags],eax

.3:		Ccall	_memset, ebx, 0, tIOMconnect_size
		mov	eax,[%$subtype]
		mov	[ebx+tIOMconnect.Subtype],eax
		mov	eax,[%$sflag]
		mov	[ebx+tIOMconnect.Sflag],eax
		mov	eax,[%$oflag]
		mov	[ebx+tIOMconnect.IOflag],eax
		mov	eax,[%$mode]
		mov	[ebx+tIOMconnect.Mode],eax
		mov	eax,[%$filetype]
		mov	[ebx+tIOMconnect.FileType],eax
		mov	eax,[%$access]
		mov	[ebx+tIOMconnect.Access],eax
		mov	eax,[%$extratype]
		mov	[ebx+tIOMconnect.ExtraType],eax
		mov	eax,[%$extralen]
		mov	[ebx+tIOMconnect.ExtraLen],eax

		Ccall	ConnectControl, edi, dword [%$path], \
			dword [%$resplen], dword [%$response]
		mov	edx, [%$status]
		or	edx,edx
		jz	.Exit
		mov	ebx,[edi+tConnectCtrl.Status]
		mov	[edx],ebx

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectControl(struct connect_ctrl *ctrl, const char *path,
		;			uint response_len, void *response);
proc ConnectControl
		arg	ctrl, path, resplen, resp
		locals	serrno, sftype, sioflag, oflag, freebuf
		locauto	buffer, tIOMconnectEntry_size*SYMLOOP_MAX + PATH_MAX + 1
		prologue

		; If path is empty - just return
		mov	esi,[%$path]
		mov	al,[esi]
		or	al,al
		je	.InvPath

		mov	edi,[%$ctrl]
		mov	ebx,[edi+tConnectCtrl.Msg]

		; If we have a valid entry, do we want to test ourselves
		; against it?
		mov	edx,[ebx+tIOMconnect.FileType]
		cmp	edx,FTYPE_MATCHED
		jne	.SaveFtype
		mov	dword [ebx+tIOMconnect.FileType],FTYPE_ANY
		cmp	dword [edi+tConnectCtrl.Entry],0
		jne	.SaveFtype
		or	dword [edi+tConnectCtrl.Flags],FLAG_TEST_ENTRY

.SaveFtype:	mov	[%$sftype],edx
		mov	eax,[ebx+tIOMconnect.IOflag]
		mov	[%$sioflag],eax

.Loop:		mov	[ebx+tIOMconnect.FileType],edx
		mov	[ebx+tIOMconnect.IOflag],eax

		; This is where the first response will go from the client.
		; In the case of multiple fd's only the first reply is
		; permanently recorded, all others are ignored.
		
.Exit:		epilogue
		ret

.InvPath:	mSetErrno EINVAL, edx
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int Vopen(const char *path, int oflag, int sflag, va_list ap);
proc Vopen
		arg	path, oflag, sflag, ap
		prologue

		test	dword [%$oflag], O_CREAT
		jz	.1
		GetArg	%$ap, Dword
		and	eax,~ST_MODE_IFMT
.1:		Ccall	ConnectEntry, 0, dword [%$path], eax, dword [%$oflag], \
			dword [%$sflag], IOM_CONNECT_OPEN, 1, \
			IOM_FLAG_RD | IOM_FLAG_WR, 0, 0, 0, 0, 0, 0, 0, 0, 0
		epilogue
		ret
endp		;---------------------------------------------------------------
