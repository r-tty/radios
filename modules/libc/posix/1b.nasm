;-------------------------------------------------------------------------------
; posix/1b.nasm - routines described by "POSIX Realtime Extensions" (1003.1b).
;-------------------------------------------------------------------------------

module libc.posix1b

%include "tm/memman.ah"
%include "tm/memmsg.ah"

exportproc _mmap64, _exit

extern _MsgSendnc

section .text

		; void *mmap64(void *addr, size_t len, int prot, 
		;		int flags, int fd, off64_t off);
proc _mmap64
		arg	addr, len, prot, flags, fd, offl, offh
		locauto	msg, tMsg_MemMap_size
		prologue
		push	ebx
		
		xor	eax,eax
		mov	word [%$msg+tMemMapRequest.Type],MEM_MAP
		mov	[%$msg+tMemMapRequest.Zero],ax
		mov	[%$msg+tMemMapRequest.Reserved1],eax
		mov	[%$msg+tMemMapRequest.Reserved2],eax
		mov	[%$msg+tMemMapRequest.Align],eax
		mov	[%$msg+tMemMapRequest.Align+4],eax
		mov	ebx,[%$addr]
		mov	[%$msg+tMemMapRequest.Addr],ebx
		mov	ebx,[%$len]
		mov	[%$msg+tMemMapRequest.Len],ebx
		mov	[%$msg+tMemMapRequest.Len+4],eax
		mov	ebx,[%$prot]
		mov	[%$msg+tMemMapRequest.Prot],ebx
		mov	ebx,[%$flags]
		mov	[%$msg+tMemMapRequest.Flags],ebx
		mov	ebx,[%$fd]
		mov	[%$msg+tMemMapRequest.FD],ebx
		mov	ebx,[%$offl]
		mov	[%$msg+tMemMapRequest.Offset],ebx
		mov	ebx,[%$offh]
		mov	[%$msg+tMemMapRequest.Offset+4],ebx

		lea	ebx,[%$msg]
		Ccall	_MsgSendnc, MEMMGR_COID, ebx, tMemMapRequest_size, \
			ebx, tMemMapReply_size
		test	eax,eax
		jns	.Exit
		mov	eax,MAP_FAILED

.Exit		pop	ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc _exit
		jmp	$
endp		;---------------------------------------------------------------
