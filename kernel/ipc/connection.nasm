;*******************************************************************************
; connection.nasm - connection functions and system calls.
; Copyright (c) 2003 RET & COM Research.
;*******************************************************************************

module kernel.ipc.connection

%include "sys.ah"
%include "errors.ah"
%include "pool.ah"
%include "hash.ah"
%include "msg.ah"
%include "thread.ah"
%include "tm/process.ah"

publicproc IPC_ConnInit
publicproc K_CloneConnections
exportproc K_ConnDescAddr, K_CreateSConnDesc
exportdata ?ConnPool, ?ConnHash
publicproc sys_ConnectDetach, sys_ConnectClientInfo

externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber, K_PoolChunkAddr
externproc K_CreateHashTab, K_HashLookup, K_HashAdd, K_HashRelease
externproc K_SemP, K_SemV
externproc MT_ThreadWakeup
externproc K_AllocateID, BZero


section .bss

?ConnPool	RESB	tMasterPool_size
?ConnHash	RESD	1


section .text

		; Initialize connection memory structures.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IPC_ConnInit
		xor	ecx,ecx
		xor	edx,edx
		mov	ebx,?ConnPool
		mov	cl,tConnDesc_size
		mov	dl,POOLFL_HIMEM
		call	K_PoolInit
		jc	.Ret
		call	K_CreateHashTab
		jc	.Ret
		mov	[?ConnHash],esi
.Ret:		ret
endp		;---------------------------------------------------------------


		; Get a connection descriptor address.
		; Input: EAX=connection ID,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK:
		;		     EDX=hash table slot address,
		;		     EDI=descriptor address;
		;	  CF=1 - error, EAX=errno.
proc K_ConnDescAddr
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


		; Create a server connection descriptor.
		; Input: EDX=address of channel descriptor,
		;	 EDI=client PCB address,
		;	 ECX=ScoId index (base).
		; Output: CF=0 - OK, EAX=SCoID;
		;	  CF=1 - error, EAX=errno.
proc K_CreateSConnDesc
		mpush	ebx,esi,edi

		; Allocate a new descriptor and clear it
		mov	ebx,?ConnPool
		call	K_PoolAllocChunk
		jc	near .Again
		mov	ebx,esi
		push	ecx
		mov	ecx,tConnDesc_size
		call	BZero
		pop	ecx

		; Allocate an ID from the bitmap, check the index
		mov	esi,[edx+tChanDesc.PCB]
		push	ebx
		lea	ebx,[esi+tProcDesc.MaxConn]
		call	K_AllocateID
		pop	ebx
		jc	near .Again
		or	ecx,ecx
		jz	.ScoIndexOK
		cmp	ecx,SIDE_CHANNEL
		jne	near .BadIndex
.ScoIndexOK:	add	eax,ecx
		mov	[ebx+tConnDesc.ID],eax
		mov	[ebx+tConnDesc.ClientPCB],edi
		mov	[ebx+tConnDesc.ChanDesc],edx

		; Use connection ID as identifier and PCB address as hash key
		mov	edi,ebx
		mov	ebx,esi
		mov	esi,[?ConnHash]
		call	K_HashAdd
		jc	.Again

		; Put connection descriptor to the list
.ScoDescFound:	mov	esi,[edx+tChanDesc.PCB]
		inc	dword [esi+tProcDesc.ServConnCount]
		mLockCB esi, tProcDesc
		mEnqueue dword [esi+tProcDesc.ServConnList], Next, Prev, edi, tConnDesc, ebx
		mUnlockCB esi, tProcDesc

		; Return SCoID
		mov	eax,[edi+tConnDesc.ID]
		clc

.Exit:		mpop	edi,esi,ebx
		ret

.BadIndex:	mov	eax,-EBADF
		jmp	.Exit

.Again:		mov	eax,-EAGAIN
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Copy connection descriptors from one process to another and
		; create new server connection descriptors.
		; Input: ESI=source PCB address,
		;	 EDI=destination PCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: target connection pool must be already initialized,
		;	modifies EBX,ECX,EDX,ESI and EDI.
proc K_CloneConnections
		mov	edx,[esi+tProcDesc.ConnList]
		mov	ebx,edi

		; Allocate a descriptor and copy the data
.Loop:		or	edx,edx
		jz	near .Exit
		push	ebx
		mov	ebx,?ConnPool
		call	K_PoolAllocChunk
		pop	ebx
		jc	.Exit
		mov	edi,esi
		mov	esi,edx
		mov	ecx,tConnDesc_size
		push	edi
		rep	movsb
		; Create a corresponding server descriptor
		mov	ecx,[edx+tConnDesc.ScoID]
		and	ecx,SIDE_CHANNEL
		mov	edi,ebx
		push	edx
		mov	edx,[edx+tConnDesc.ChanDesc]
		call	K_CreateSConnDesc
		pop	edx
		pop	edi
		jc	.Exit
		mov	[edi+tConnDesc.ScoID],eax

		; Put it into the list and hash
		mEnqueue dword [ebx+tProcDesc.ConnList], Next, Prev, edi, tConnDesc, esi
		mov	eax,[edi+tConnDesc.ID]
		mov	esi,[?ConnHash]
		call	K_HashAdd
		jc	.Exit

		mov	eax,edx
		mov	edx,[edx+tConnDesc.Next]
		cmp	edx,eax
		jne	.Loop

.Exit:		ret
endp		;---------------------------------------------------------------

; --- System calls -------------------------------------------------------------

		; int ConnectDetach(int coid);
proc sys_ConnectDetach
		arg	coid
		locals	head
		prologue

		; Get the connection and channel descriptor addresses
		mCurrThread
		mov	ebx,[eax+tTCB.PCB]
		mov	eax,[%$coid]
		call	K_ConnDescAddr
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
