;-------------------------------------------------------------------------------
; channel.nasm - channel handling functions.
;-------------------------------------------------------------------------------

module kernel.ipc.channel

%include "sys.ah"
%include "pool.ah"
%include "msg.ah"

publicproc IPC_ChanInit
publicproc IPC_ChanDescAddr, IPC_ConnDescAddr
exportproc sys_ChannelCreate, sys_ChannelDestroy
exportproc sys_ConnectAttach, sys_ConnectDetach
exportproc sys_ConnectServerInfo, sys_ConnectClientInfo
exportproc sys_ConnectFlags

externproc BZero, K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber,K_PoolChunkAddr
externproc IPC_MsgAlloc, IPC_MsgPutFreeList

section .data

?MaxChannels	RESD	1
?MaxConnections	RESD	1
?ChanPool	RESB	tMasterPool_size
?ConnPool	RESB	tMasterPool_size


section .text

		; Initialize channels memory structures.
		; Input: EAX=maximum number of channels,
		;	 ECX=maximum number of channel connections.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IPC_ChanInit
		mov	[?MaxChannels],eax
		mov	[?MaxConnections],ecx
		mov	ebx,?ChanPool
		mov	ecx,tChanDesc_size
		xor	edx,edx
		call	K_PoolInit
		jc	.Exit
		mov	ebx,?ConnPool
		mov	ecx,tConnDesc_size
		call	K_PoolInit
.Exit:		ret
endp		;---------------------------------------------------------------


		; IPC_ChanDescAddr - get a channel descriptor address.
		; Input: EAX=channel number.
		; Output: CF=0 - OK, ESI=descriptor address;
		;	  CF=1 - error, AX=error code.
proc IPC_ChanDescAddr
		push	ebx
		mov	ebx,?ChanPool
		call	K_PoolChunkAddr
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; IPC_ConnDescAddr - get a connection descriptor address.
		; Input: EAX=connection number.
		; Output: CF=0 - OK, ESI=descriptor address;
		;	  CF=1 - error, AX=error code.
proc IPC_ConnDescAddr
		push	ebx
		sub	eax,40000000h				; XXX - kluge
		mov	ebx,?ConnPool
		call	K_PoolChunkAddr
		pop	ebx
		ret
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------

		; int ChannelCreate(uint flags);
proc sys_ChannelCreate
		arg	fl
		prologue

		mpush	ebx,esi

		mov	ebx,?ChanPool
		call	K_PoolAllocChunk
		jc	short .Exit

		; Initialize message queue pointers
		xor	eax,eax
		mov	[esi+tChanDesc.Head],eax
		mov	[esi+tChanDesc.Tail],eax

		; Channel semaphore
		lea	ebx,[esi+tChanDesc.Lock]
		mSemInit ebx

		; Receive semaphore
		mov	[esi+tChanDesc.RecvSem+tSemaphore.Count],eax
		mov	[esi+tChanDesc.RecvSem+tSemaphore.WaitQ],eax
		
		; Connection list is empty
		mov	[esi+tChanDesc.NumConn],eax
		mov	[esi+tChanDesc.ConnList],eax

		; Initialize free list
		mov	edi,esi
		mov	ecx,8
		mov	dword [edi+tChanDesc.FreeList],0
.Loop:		call	IPC_MsgAlloc
		jc	short .Warning
		call	IPC_MsgPutFreeList
		loop	.Loop

		mov	esi,edi
		call	K_PoolChunkNumber

.Exit:		mCheckNeg
		mpop	esi,ebx
		epilogue
		ret

.Warning:
	%ifdef KPOPUPS
		push	esi
		mov	esi,MsgCantAllocMsg
		call	K_PopUp
		pop	esi
	%endif
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ChannelDestroy(int chid);
proc sys_ChannelDestroy
		arg	chid
		prologue
		mov	eax,[%$chid]
		call	K_PoolChunkAddr
		jz	.Exit

		; Wake up all sleeping thread waiting for the messages in
		; this channel and indicate that channel is being destroyed.

		; Free the channel descriptor
		call	K_PoolFreeChunk
		xor	eax,eax

.Exit:		mCheckNeg
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectAttach(uint nd, pid_t pid, int chid,
		;			uint index, int flags);
proc sys_ConnectAttach
		arg	nd, pid, chid, index, flags
		prologue
		mpush	ebx,esi

		; Get the address of channel descriptor
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	.Exit
		mov	edi,esi

		mov	ebx,?ConnPool
		call	K_PoolAllocChunk
		jc	.Exit

		inc	dword [edi+tChanDesc.NumConn]
		mov	[esi+tConnDesc.ChanDesc],edi
		mEnqueue dword [edi+tChanDesc.ConnList], Next, Prev, esi, tConnDesc
		clc

.Exit:		mCheckNeg
		mpop	esi,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectDetach(int coid);
proc sys_ConnectDetach
		arg	coid
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectServerInfo(pid_t pid, int coid,
		;			struct _server_info *info);
proc sys_ConnectServerInfo
		arg	pid, coid, info
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectClientInfo(int scoid, struct _client_info *info,
		;			int ngroups);
proc sys_ConnectClientInfo
		arg	scoid, info, ngroups
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_ConnectFlags
		ret
endp		;---------------------------------------------------------------
