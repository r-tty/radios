;-------------------------------------------------------------------------------
; services.nasm - support routines (non-POSIX).
;-------------------------------------------------------------------------------

module libc.services

%include "errors.ah"
%include "rm/resmgr.ah"
%include "rm/iomsg.ah"
%include "rm/pathmgr.ah"

exportproc _netmgr_remote_nd
exportproc _pathmgr_symlink, _pathmgr_unlink, _pathmgr_link

externproc ConnectEntry
externproc _ConnectDetach
externproc _getpid

section .data

TxtRootPath	DB	"/",0

section .text

		; int netmgr_remote_nd(int remote_nd, int local_nd);
proc _netmgr_remote_nd
		arg	remnd, locnd
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int _pathmgr_link(const char *path, uint nd, pid_t pid,
		;		int chid, uint handle, enum file_type file_type,
		;		unsigned flags);
proc _pathmgr_link
		arg	path, nd, pid, chid, handle, ftype, flags
		locauto	link, tIOresmgrLinkExtra
		prologue
		savereg	ebx,esi

		mov	eax,[%$flags]
		test	eax,RESMGR_FLAG_FTYPEALL
		jz	.ChkFtype
		mov	dword [%$ftype],FTYPE_ALL
		jmp	.ChkPath
.ChkFtype:	cmp	dword [%$ftype],FTYPE_ANY
		jl	near .Invalid

.ChkPath:	mov	esi,[%$path]
		or	esi,esi
		je	.NullPath
		cmp	byte [esi],0
		je	.NullPath
		test	eax,RESMGR_FLAG_FTYPEONLY
		jz	near .Invalid
		jmp	.Prepare

.NullPath:	mov	esi,TxtRootPath
		or	dword [%$flags],RESMGR_FLAG_FTYPEONLY

.Prepare:	lea	ebx,[%$link]
		Mov32	ebx+tIOresmgrLinkExtra.ND,%$nd
		mov	eax,[%$pid]
		test	eax,eax
		jnz	.PidOK
		call	_getpid
.PidOK:		mov	[ebx+tIOresmgrLinkExtra.PID],eax
		Mov32	ebx+tIOresmgrLinkExtra.ChID,%$chid
		Mov32	ebx+tIOresmgrLinkExtra.Handle,%$handle
		Mov32	ebx+tIOresmgrLinkExtra.FileType,%$ftype
		Mov32	ebx+tIOresmgrLinkExtra.Flags,%$flags

		Ccall	ConnectEntry, PATHMGR_COID, esi, byte 0, byte 0, \
			SH_DENYNO, IOM_CONNECT_LINK, byte 0, byte 0, \
			FTYPE_LINK, IOM_CONNECT_EXTRA_RESMGR_LINK, \
			tIOresmgrLinkExtra_size, ebx, byte 0, byte 0, byte 0, \
			byte 0, byte 0
		test	eax,eax
		js	.Exit

		test	dword [%$flags],PATHMGR_FLAG_STICKY
		jz	.Exit
		Ccall	_ConnectDetach, eax
		xor	eax,eax

.Exit:		epilogue
		ret

.Invalid:	mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int pathmgr_symlink(const char *symlink, const char *path);
proc _pathmgr_symlink
		arg	symlink, path
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pathmgr_unlink(const char *path);
proc _pathmgr_unlink
		arg	symlink, path
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
