;-------------------------------------------------------------------------------
; channel.nasm - channel handling functions.
;-------------------------------------------------------------------------------

module kernel.ipc.channel

%include "sys.ah"
%include "errors.ah"
%include "pool.ah"
%include "msg.ah"
%include "thread.ah"
%include "tm/process.ah"

publicproc IPC_ChanInit
exportproc IPC_ChanDescAddr, IPC_ConnDescAddr
publicproc sys_ChannelCreate, sys_ChannelDestroy
publicproc sys_ConnectDetach
publicproc sys_ConnectClientInfo

externproc BZero, K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber,K_PoolChunkAddr

section .data

?MaxChannels	RESD	1
?MaxConnections	RESD	1
?ChanPool	RESB	tMasterPool_size


section .text

		; Initialize channels memory structures.
		; Input: EAX=maximum number of channels,
		;	 ECX=maximum number of connections (per-process).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IPC_ChanInit
		mov	[?MaxChannels],eax
		mov	[?MaxConnections],ecx
		mov	ebx,?ChanPool
		xor	ecx,ecx
		mov	cl,tChanDesc_size
		xor	dl,dl
		call	K_PoolInit
		ret
endp		;---------------------------------------------------------------


		; IPC_ChanDescAddr - get a channel descriptor address.
		; Input: EAX=channel ID.
		; Output: CF=0 - OK, ESI=descriptor address;
		;	  CF=1 - error, AX=error code.
proc IPC_ChanDescAddr
		push	ebx
		mov	ebx,?ChanPool
		call	K_PoolChunkAddr
		jc	.BadID
.Exit		pop	ebx
		ret

.BadID:		mov	eax,-ESRCH
		jmp	.Exit
endp		;---------------------------------------------------------------


		; IPC_ConnDescAddr - get a connection descriptor address.
		; Input: EAX=connection ID,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK, EDI=descriptor address;
		;	  CF=1 - error, AX=error code.
		; Note: linear search. Probably should be replaced with hash.
proc IPC_ConnDescAddr
		push	ebx
		mov	edi,[esi+tProcDesc.ConnList]
.Loop:		or	edi,edi
		jz	.InvCoID
		cmp	eax,[edi+tConnDesc.ID]
		je	.Exit
		mov	ebx,edi
		mov	edi,[edi+tConnDesc.Next]
		cmp	edi,ebx
		jne	.Loop
.Exit:		pop	ebx
		ret

.InvCoID:	mov	ax,EBADF
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------

		; int ChannelCreate(uint flags);
proc sys_ChannelCreate
		arg	fl
		prologue

		; Allocate a channel descriptor and zero it
		mov	ebx,?ChanPool
		call	K_PoolAllocChunk
		jc	.Exit
		mov	ebx,esi
		mov	ecx,tChanDesc_size
		call	BZero

		; Channel semaphore
		lea	eax,[esi+tChanDesc.Lock]
		mSemInit eax

		; Channel is considered to be owned by a calling process
		mCurrThread
		mov	eax,[eax+tTCB.PCB]
		mov	[esi+tChanDesc.PCB],eax
		mEnqueue dword [eax+tProcDesc.ChanList], Next, Prev, esi, tChanDesc, ecx

		; Return the channel ID
		call	K_PoolChunkNumber

.Exit:		mCheckNeg
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ChannelDestroy(int chid);
proc sys_ChannelDestroy
		arg	chid
		prologue

		mov	eax,[%$chid]
		call	K_PoolChunkAddr
		jz	.Exit

		; Remove this channel descriptor from the list
		mov	eax,[esi+tChanDesc.PCB]
		mDequeue dword [eax+tProcDesc.ChanList], Next, Prev, esi, tChanDesc, ecx
		
		; Wake up all sleeping thread waiting for the messages in
		; this channel and indicate that channel is being destroyed.

		; Free the channel descriptor
		call	K_PoolFreeChunk
		xor	eax,eax

.Exit:		mCheckNeg
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


		; int ConnectClientInfo(int scoid, struct _client_info *info,
		;			int ngroups);
proc sys_ConnectClientInfo
		arg	scoid, info, ngroups
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
