;*******************************************************************************
; channel.nasm - channel handling functions.
; Copyright (c) 2003 RET & COM Research.
;*******************************************************************************

module kernel.ipc.channel

%include "sys.ah"
%include "errors.ah"
%include "pool.ah"
%include "hash.ah"
%include "msg.ah"
%include "thread.ah"
%include "tm/process.ah"

publicproc IPC_ChanInit
exportproc IPC_ChanDescAddr, IPC_ConnDescAddr
exportdata ?ConnPool, ?ConnHash
publicproc sys_ChannelCreate, sys_ChannelDestroy
publicproc sys_ConnectDetach
publicproc sys_ConnectClientInfo

externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber, K_PoolChunkAddr
externproc K_CreateHashTab, K_HashLookup, K_HashAdd, K_HashRelease
externproc K_SemP, K_SemV
externproc MT_ThreadWakeup
externproc K_AllocateID, BZero

section .data

?ChanPool	RESB	tMasterPool_size
?ConnPool	RESB	tMasterPool_size
?ChanHash	RESD	1
?ConnHash	RESD	1


section .text

		; Initialize channel and connection memory structures.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IPC_ChanInit
		mov	ebx,?ChanPool
		xor	ecx,ecx
		mov	cl,tChanDesc_size
		xor	dl,dl
		call	K_PoolInit
		jc	.Ret
		call	K_CreateHashTab
		jc	.Ret
		mov	[?ChanHash],esi
		mov	ebx,?ConnPool
		xor	ecx,ecx
		mov	cl,tConnDesc_size
		mov	dl,POOLFL_HIMEM
		call	K_PoolInit
		jc	.Ret
		call	K_CreateHashTab
		jc	.Ret
		mov	[?ConnHash],esi
.Ret:		ret
endp		;---------------------------------------------------------------


		; IPC_ChanDescAddr - get a channel descriptor address.
		; Input: EAX=channel ID,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK:
		;		     EDX=hash table slot address,
		;		     ESI=channel descriptor address,
		;		     EDI=hash element address;
		;	  CF=1 - error, EAX=errno.
proc IPC_ChanDescAddr
		push	ebx
		mov	ebx,esi
		mov	esi,[?ChanHash]
		call	K_HashLookup
		jc	.BadID
		mov	esi,[edi+tHashElem.Data]
.Exit		pop	ebx
		ret

.BadID:		mov	eax,-ESRCH
		jmp	.Exit
endp		;---------------------------------------------------------------


		; IPC_ConnDescAddr - get a connection descriptor address.
		; Input: EAX=connection ID,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK:
		;		     EDX=hash table slot address,
		;		     EDI=descriptor address;
		;	  CF=1 - error, EAX=errno.
proc IPC_ConnDescAddr
		mpush	ebx,esi
		mov	ebx,esi
		mov	esi,[?ConnHash]
		call	K_HashLookup
		jc	.Invalid
		mov	edi,[edi+tHashElem.Data]
.Exit:		mpop	esi,ebx
		ret

.Invalid:	mov	eax,-EBADF
		jmp	.Exit
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------

		; int ChannelCreate(uint flags);
proc sys_ChannelCreate
		arg	flags
		prologue

		; Allocate a channel descriptor and zero it
		mov	ebx,?ChanPool
		call	K_PoolAllocChunk
		jc	near .Again
		mov	ebx,esi
		mov	ecx,tChanDesc_size
		call	BZero

		; Channel semaphore
		lea	eax,[esi+tChanDesc.Lock]
		mSemInit eax

		; Channel is considered to be owned by a calling process
		mCurrThread
		mov	edi,[eax+tTCB.PCB]
		mov	[esi+tChanDesc.PCB],edi
		mEnqueue dword [edi+tProcDesc.ChanList], Next, Prev, esi, tChanDesc, ecx

		; Update flags and the channel ID
		Mov32	%$flags,esi+tChanDesc.Flags
		lea	ebx,[edi+tProcDesc.MaxChan]
		call	K_AllocateID
		jc	.Again
		mov	[esi+tChanDesc.ID],eax

		; PCB address will be a hash key
		mov	ebx,edi
		mov	edi,esi
		mov	esi,[?ChanHash]
		call	K_HashAdd
		jc	.Again
		mov	eax,[edi+tChanDesc.ID]

.Exit:		epilogue
		ret

.Again:		mov	eax,-EAGAIN
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ChannelDestroy(int chid);
proc sys_ChannelDestroy
		arg	chid
		prologue

		; Get a channel descriptor address
		mCurrThread ebx
		mov	esi,[ebx+tTCB.PCB]
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	.Invalid

		; Free the hash element
		call	K_HashRelease

		; Remove this channel descriptor from the list
		mLockCB edx, tProcDesc
		mDequeue dword [edx+tProcDesc.ChanList], Next, Prev, esi, tChanDesc, ecx
		mUnlockCB edx, tProcDesc
		
		; Wake up all sleeping threads waiting for the messages in
		; this channel and indicate that channel is being destroyed.

		; Free the channel descriptor
		call	K_PoolFreeChunk
		xor	eax,eax

.Exit:		epilogue
		ret

.Invalid:	mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ConnectDetach(int coid);
proc sys_ConnectDetach
		arg	coid
		locals	head
		prologue

		; Get the connection and channel descriptor addresses
		mCurrThread
		mov	ebx,[eax+tTCB.PCB]
		mov	eax,[%$coid]
		call	IPC_ConnDescAddr
		jc	.Invalid
		mov	esi,[edi+tConnDesc.ChanDesc]

		; Walk through the list of threads blocked on our connection
		; and unblock them with EBADF error
		mov	ebx,[esi+tChanDesc.SendWaitQ]
		mov	[%$head],ebx
.Loop:		or	ebx,ebx
		jz	.OK
		mov	edx,[ebx+tTCB.SendReplyNext]
		cmp	[ebx+tTCB.ConnDesc],edi
		jne	.Next
		mDequeue dword [%$head], SendReplyNext, SendReplyPrev, ebx, tTCB, ecx

		; Was the send wait queue head pointing to this thread?
		cmp	[esi+tChanDesc.SendWaitQ],ebx
		jne	.ChkReplyQhead
		Mov32	esi+tChanDesc.SendWaitQ,%$head
		jmp	.SetStatus

		; Was the reply wait queue head pointing to this thread?
.ChkReplyQhead:	cmp	[esi+tChanDesc.ReplyWaitQ],ebx
		jne	.SetStatus
		Mov32	esi+tChanDesc.SendWaitQ,%$head

		; Set the status and unblock the thread
.SetStatus:	mov	dword [ebx+tTCB.MsgStatus],-EBADF
		call	MT_ThreadWakeup

.Next:		xchg	ebx,edx
		cmp	ebx,edx
		jne	.Loop

		; Remove this connection from the channel's list and free
		; the connection descriptor. Also check if it's a last
		; connection to the channel; if so - depending on the
		; presence of CHF_DISCONNECT flag either send a pulse
		; to the channel or silently free the scoid.

.OK:		xor	eax,eax
.Exit:		epilogue
		ret

.Invalid:	mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ConnectClientInfo(int scoid, struct _client_info *info,
		;			int ngroups);
proc sys_ConnectClientInfo
		arg	scoid, info, ngroups
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------
