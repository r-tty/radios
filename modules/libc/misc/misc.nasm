;-------------------------------------------------------------------------------
; misc.nasm - miscellaneous non-POSIX routines.
;-------------------------------------------------------------------------------

module libc.misc

%include "rmk.ah"
%include "errors.ah"
%include "thread.ah"
%include "locstor.ah"
%include "tm/memman.ah"
%include "tm/memmsg.ah"
%include "rm/iomsg.ah"
%include "rm/devctl.ah"

exportproc _mmap_device_memory, _munmap_device_memory
exportproc _mmap_device_io, _munmap_device_io
exportproc _AllocPages, _FreePages
exportproc _tlsptr, Devctl

externproc _mmap64
externproc _MsgSendnc, _MsgSendv

section .text

		; void *mmap_device_memory(void *addr, size_t len, int prot,
		;			int flags, uint64_t physical);
proc _mmap_device_memory
		arg	addr, len, prot, flags, physl, physh
		prologue
		mov	eax,[%$flags]
		and	eax,~MAP_TYPE
		or	eax,MAP_PHYS | MAP_SHARED
		Ccall	_mmap64, dword [%$addr], dword [%$len], dword [%$prot], \
			eax, 0, dword [%$physl], dword [%$physh]
		epilogue
		ret
endp		;---------------------------------------------------------------


proc _munmap_device_memory
		ret
endp		;---------------------------------------------------------------


proc _mmap_device_io
		ret
endp		;---------------------------------------------------------------


proc _munmap_device_io
		ret
endp		;---------------------------------------------------------------


		; void *AllocPages(unsigned size);
proc _AllocPages
		arg	size
		locauto	msgbuf, tMsg_MemAllocPages_size
		prologue
		savereg	edx

		lea	edi,[%$msgbuf]
		mov	word [edi+tMemAllocPagesRequest.Type],MEM_ALLOCPAGES
		mov	eax,[%$size]
		mov	[edi+tMemAllocPagesRequest.Size],eax
		Ccall	_MsgSendnc, SYSMGR_COID, edi, tMemAllocPagesRequest_size, \
			edi, tMemAllocPagesReply_size
		test	eax,eax
		js	.Err
		mov	eax,[edi+tMemAllocPagesReply.Addr]

.Exit:		epilogue
		ret

.Err:		xor	eax,eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; void FreePages(void *addr);
proc _FreePages
		arg	addr
		locauto	msgbuf, tMsg_MemFreePages
		prologue
		savereg	edx

		lea	edi,[%$msgbuf]
		mov	word [edi+tMsg_MemFreePages.Type],MEM_FREEPAGES
		mov	eax,[%$addr]
		mov	[edi+tMsg_MemFreePages.Addr],eax
		Ccall	_MsgSendnc, SYSMGR_COID, edi, tMsg_MemFreePages_size, \
			edi, 2

		epilogue
		ret
endp		;---------------------------------------------------------------


		; Get a pointer to Thread Local Storage
proc _tlsptr
		mov	eax,[fs:0]
		ret
endp		;---------------------------------------------------------------


		; int Devctl(int fd, int dcmd, void *data_ptr, size_t nbytes,
		;	     uint flags);
proc Devctl
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
