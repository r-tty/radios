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
exportproc K_ChanDescAddr
publicproc sys_ChannelCreate, sys_ChannelDestroy

externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber, K_PoolChunkAddr
externproc K_CreateHashTab, K_HashLookup, K_HashAdd, K_HashRelease
externproc K_SemP, K_SemV
externproc MT_ThreadWakeup
externproc K_AllocateID, BZero

section .bss

?ChanPool	RESB	tMasterPool_size
?ChanHash	RESD	1


section .text

		; Initialize channel memory structures.
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
.Ret:		ret
endp		;---------------------------------------------------------------


		; Get a channel descriptor address.
		; Input: EAX=channel ID,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK:
		;		     EDX=hash table slot address,
		;		     ESI=channel descriptor address,
		;		     EDI=hash element address;
		;	  CF=1 - error, EAX=errno.
proc K_ChanDescAddr
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
		call	K_ChanDescAddr
		jc	.Invalid

		; Free the hash element
		call	K_HashRelease

		; Remove this channel descriptor from the list
		mLockCB edx, tProcDesc
		mDequeue dword [edx+tProcDesc.ChanList], Next, Prev, esi, tChanDesc, ecx
		mUnlockCB edx, tProcDesc

		; Invalidate all scoids for this channel

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
