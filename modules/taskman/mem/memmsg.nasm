;-------------------------------------------------------------------------------
; memmsg.nasm - memory manager message handlers.
;-------------------------------------------------------------------------------

module taskman.mm.memmsg

%include "sys.ah"
%include "rmk.ah"
%include "errors.ah"
%include "cpu/paging.ah"
%include "tm/process.ah"
%include "tm/memmsg.ah"

publicdata MemMsgHandlers

externproc PoolChunkAddr, MapArea
externproc MM_FindRegion, MM_AllocBlock, MM_FreeBlock
externdata ?ConnPool, ?ProcessPool

library $libc
externproc _MsgRead, _MsgReply, _MsgError

section .data

MemMsgHandlers:
mMHTabEnt MH_MemMap, MEM_MAP
mMHTabEnt MH_MemCtrl, MEM_CTRL
mMHTabEnt MH_MemInfo, MEM_INFO
mMHTabEnt MH_MemOffset, MEM_OFFSET
mMHTabEnt MH_MemDebugInfo, MEM_DEBUG_INFO
mMHTabEnt MH_MemSwap, MEM_SWAP
mMHTabEnt MH_MemAllocPages, MEM_ALLOCPAGES
mMHTabEnt MH_MemFreePages, MEM_FREEPAGES
mMHTabEnt 0


section .text

		; MEM_MAP handler
		; Input: ESI=message information address,
		;	 EBX=rcvid.
proc MH_MemMap
		locauto	msgbuf, tMsg_MemMap_size
		prologue

		; Read a message and check its length
		lea	edi,[%$msgbuf]
		mov	ecx,tMemMapRequest_size
		Ccall	_MsgRead, ebx, edi, ecx, 0
		test	eax,eax
		clc
		js	.ReplyErr
		cmp	eax,ecx
		jb	.ReplyErr

		; Find a linear memory region
		mov	edx,ebx
		mov	eax,[esi+tMsgInfo.PID]
		mov	ebx,?ProcessPool
		call	PoolChunkAddr
		mov	ecx,[edi+tMemMapRequest.Len]
		call	MM_FindRegion
		jc	.NoMem

		; Map area
		mpush	edx,edi
		mov	edx,[esi+tProcDesc.PageDir]
		mov	al,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		mov	ah,al
		mov	esi,[edi+tMemMapRequest.Offset]
		mov	edi,ebx
		call	MapArea
		mpop	edi,edx
		jc	.Exit

		; Fill in the fields in the reply and return linear address
		sub	ebx,USERAREASTART
		Ccall	_MsgReply, edx, ebx, edi, tMemMapReply_size

.Exit:		epilogue
		ret

.ReplyErr:	Ccall	_MsgError, ebx, -ENOMSG
		jmp	.Exit

.NoMem:		Ccall	_MsgError, edx, -ENOMEM
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MEM_CTRL handler
proc MH_MemCtrl
		ret
endp		;---------------------------------------------------------------


		; MEM_INFO handler
proc MH_MemInfo
		ret
endp		;---------------------------------------------------------------


		; MEM_OFFSET handler
proc MH_MemOffset
		ret
endp		;---------------------------------------------------------------


		; MEM_DEBUG_INFO handler
proc MH_MemDebugInfo
		ret
endp		;---------------------------------------------------------------


		; MEM_SWAP handler
proc MH_MemSwap
		ret
endp		;---------------------------------------------------------------


		; MEM_ALLOCPAGES handler.
		; Input: ESI=message information address,
		;	 EBX=rcvid.
proc MH_MemAllocPages
		locauto msgbuf, tMsg_MemAllocPages_size
		prologue

		; Read a message and check its length
		lea	edi,[%$msgbuf]
		mov	ecx,tMemAllocPagesRequest_size
		Ccall	_MsgRead, ebx, edi, ecx, 0
		test	eax,eax
		clc
		js	.ReplyErr
		cmp	eax,ecx
		jb	.ReplyErr

		; Get a PCB address
		mov	edx,ebx
		mov	eax,[esi+tMsgInfo.PID]
		mov	ebx,?ProcessPool
		call	PoolChunkAddr

		; Allocate block
		mov	ecx,[edi+tMemAllocPagesRequest.Size]
		mov	al,PG_WRITABLE
		call	MM_AllocBlock
		jc	.NoMem

		; Fill in the fields in the reply and return linear address
		mov	[edi+tMemAllocPagesReply.Addr],ebx
		Ccall	_MsgReply, edx, 0, edi, tMemAllocPagesReply_size

.Exit		epilogue
		ret

.ReplyErr:	Ccall	_MsgError, ebx, -ENOMSG
		jmp	.Exit

.NoMem:		Ccall	_MsgError, edx, -ENOMEM
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MEM_FREEPAGES handler.
		; Input: ESI=message information address,
		;	 EBX=rcvid.
proc MH_MemFreePages
		locauto msgbuf, tMsg_MemFreePages_size
		prologue

		; Read a message and check its length
		lea	edi,[%$msgbuf]
		mov	ecx,tMsg_MemFreePages_size
		Ccall	_MsgRead, ebx, edi, ecx, 0
		test	eax,eax
		clc
		js	.ReplyErr
		cmp	eax,ecx
		jb	.ReplyErr

		; Get a PCB address
		mov	edx,ebx
		mov	eax,[esi+tMsgInfo.PID]
		mov	ebx,?ProcessPool
		call	PoolChunkAddr

		; Free block
		mov	ebx,[edi+tMsg_MemFreePages.Addr]
		call	MM_FreeBlock
		jc	.NoMem

		; Echo-reply to unblock the sender
		Ccall	_MsgReply, edx, 0, edi, ecx

.Exit:		epilogue
		ret

.ReplyErr:	Ccall	_MsgError, ebx, -ENOMSG
		jmp	.Exit

.NoMem:		Ccall	_MsgError, edx, -ENOMEM
		jmp	.Exit
endp		;---------------------------------------------------------------
