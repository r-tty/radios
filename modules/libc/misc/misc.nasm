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
exportproc _tlsptr

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
		savereg	edi

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
		savereg	edi

		lea	edi,[%$msgbuf]
		mov	word [edi+tMsg_MemFreePages.Type],MEM_FREEPAGES
		mov	eax,[%$addr]
		mov	[edi+tMsg_MemFreePages.Addr],eax
		Ccall	_MsgSendnc, SYSMGR_COID, edi, tMsg_MemFreePages_size, \
			edi, 2

		epilogue
		ret
endp		;---------------------------------------------------------------


		; Get a pointer to Thread Local Storage in EAX
proc _tlsptr
		tlsptr(eax)
		ret
endp		;---------------------------------------------------------------
