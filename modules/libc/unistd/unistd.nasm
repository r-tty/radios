
module libc.unistd

%include "rm/memmsg.ah"

exportproc _mmap64
publicproc libc_init_unistd

extern _MsgSendnc

		; Initialization
proc libc_init_unistd
		ret
endp		;---------------------------------------------------------------


		; void *mmap64(void *addr, size_t len, int prot, 
		;		int flags, int fd, off64_t off);
proc _mmap64
		arg	addr, len, prot, flags, fd, off
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
		mov	ebx,[%$off]
		mov	[%$msg+tMemMapRequest.Offset],ebx
		mov	ebx,[%$off+4]
		mov	[%$msg+tMemMapRequest.Offset+4],ebx

		lea	ebx,[%$msg]
		Ccall	_MsgSendnc, dword MEMMGR_COID, ebx, \
			dword tMemMapRequest_size, ebx, \
			dword tMemMapReply_size
		test	eax,eax
		pop	ebx
		epilogue
		ret
endp		;---------------------------------------------------------------
