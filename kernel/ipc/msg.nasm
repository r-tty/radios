;*******************************************************************************
; msg.nasm - core message routines.
; Copyright (c) 2000-2002 RET & COM Research.
; This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.ipc.msg

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "pool.ah"
%include "msg.ah"

; --- Exports ---
publicproc IPC_MsgInit
publicproc IPC_MsgAlloc, IPC_MsgPutFreeList
exportproc sys_MsgSend, sys_MsgSendnc, sys_MsgReply, sys_MsgReceive
exportproc sys_MsgWrite, sys_MsgRead, sys_MsgReadiov
exportproc sys_MsgSendPulse, sys_MsgReceivePulse
exportproc sys_MsgInfo, sys_MsgError, sys_MsgKeyData

; --- Imports ---

externproc K_PoolInit, K_PoolAllocChunk
externproc K_SemP, K_SemV
externproc IPC_ChanDescAddr, IPC_ConnDescAddr
externproc MT_ThreadSleep
externproc BZero

; --- Data ---

section .data

TxtCantAllocMsg	DB	":IPC:IPC_PortAlloc: warning: cannot allocate message",0


; --- Variables ---

section .bss

?MsgPool	RESB	tMasterPool_size
?MaxMessages	RESD	1


; --- Code ---

section .text

		; IPC_Init - initialize messaging memory structures.
		; Input: EAX=maximum number of messages present in kernel.
		; Output: none.
proc IPC_MsgInit
		mov	[?MaxMessages],eax
		mov	ebx,?MsgPool
		mov	ecx,tMsgDesc_size
		xor	edx,edx
		call	K_PoolInit
		ret
endp		;---------------------------------------------------------------


		; IPC_MsgAlloc - allocate a memory slot for message.
		; Input: none.
		; Output: CF=0 - OK, ESI=message structure address;
		;	  CF=1 - error, AX=error code.
proc IPC_MsgAlloc
		mpush	ebx,ecx
		mov	ebx,?MsgPool
		call	K_PoolAllocChunk
		jc	short .Exit
		
		mov	ebx,esi
		mov	ecx,tMsgDesc_size
		call	BZero

		lea	ebx,[esi+tMsgDesc.Lock]
		xor	eax,eax
		mSemInit ebx
		mSemSetVal ebx
		clc

.Exit:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------



		; IPC_PutMsgFreeList - put a message in the free list.
		; Input: ESI=message structure address,
		;	 EDI=port structure address.
		; Output: none.
proc IPC_MsgPutFreeList
		pushfd
		cli
		mov	eax,[edi+tChanDesc.FreeList]
		mov	[esi+tMsgDesc.NextFree],eax
		mov	[edi+tChanDesc.FreeList],esi
		popfd
		ret
endp		;---------------------------------------------------------------


		; IPC_GetFree - get a message from the free list.
		; Input: EDI=port structure address.
		; Output: ESI=message structure address.
proc IPC_GetFree
		pushfd
		cli
		mov	esi,[edi+tChanDesc.FreeList]
		or	esi,esi
		jz	short .Exit
		mov	eax,[esi+tMsgDesc.NextFree]
		mov	[edi+tChanDesc.FreeList],eax
		mov	dword [esi+tMsgDesc.NextFree],0
.Exit:		popfd
		ret
endp		;---------------------------------------------------------------


		; IPC_MsgEnqueue - enqueue a message in a port queue.
		; Input: ESI=message structure address,
		;	 EDI=port structure address.
		; Output: none.
proc IPC_MsgEnqueue
		mov	eax,[edi+tChanDesc.Tail]
		or	eax,eax
		jz	short .NoTail
		mov	[eax+tMsgDesc.Next],esi

.NoTail:	mov	dword [esi+tMsgDesc.Next],0
		mov	[edi+tChanDesc.Tail],esi
		cmp	dword [edi+tChanDesc.Head],0
		jnz	short .Exit
		mov	[edi+tChanDesc.Head],esi

.Exit:		ret
endp		;---------------------------------------------------------------


		; IPC_MsgDequeue - remove a message from port queue.
		; Input: ESI=message structure address,
		;	 EDI=port structure address.
		; Output: none.
proc IPC_MsgDequeue
		cmp	[edi+tChanDesc.Head],esi
		jne	short .1
		mov	eax,[esi+tMsgDesc.Next]
		mov	[edi+tChanDesc.Head],eax
		ret

.1:		push	ebx
		mov	ebx,[edi+tChanDesc.Head]

.Loop:		or	ebx,ebx
		jz	short .Exit
		cmp	esi,[ebx+tMsgDesc.Next]
		je	short .2
		mov	ebx,[ebx+tMsgDesc.Next]
		jmp	.Loop

.2:		mov	eax,[esi+tMsgDesc.Next]
		mov	[ebx+tMsgDesc.Next],eax
		cmp	[edi+tChanDesc.Tail],esi
		jne	short .Exit
		mov	[edi+tChanDesc.Tail],ebx

.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


; --- System call routines -----------------------------------------------------

		; int MsgSend(int coid, const void *smsg, int sbytes,
		;		void *rmsg, int rbytes);
proc sys_MsgSend
		arg	coid, smsg, sbytes, rmsg, rbytes
		prologue

		; Get a current thread and set its state
		mCurrThread ebx
;		mov	dword [ebx+tTCB.State],THRSTATE_SEND
		mov	edx,ebx

		; Get connection descriptor address
		mov	eax,[%$coid]
		call	IPC_ConnDescAddr
		jc	.Exit

		; Wake up a thread that's waiting for a message
		mov	edi,[esi+tConnDesc.ChanDesc]
		push	ebx
		lea	ebx,[edi+tChanDesc.RecvSem]
		call	K_SemV
		pop	ebx

.Exit:		mCheckNeg
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_MsgSendnc
		ret
endp		;---------------------------------------------------------------


proc sys_MsgError
		ret
endp		;---------------------------------------------------------------


		; int MsgReceive(int chid, void *msg, int bytes, 
		;		 struct _msg_info *info);
proc sys_MsgReceive
		arg	chid, msg, bytes, info
		prologue

		; Get a current thread and set its state
		mCurrThread ebx
;		mov	dword [ebx+tTCB.State],THRSTATE_RECEIVE
		mov	edx,ebx
	
		; If there are no connections to the channel - fall asleep
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	.Exit
		mov	eax,[esi+tChanDesc.NumConn]
		or	eax,eax
		jz	.Sleep

		; Check channel semaphore, if no messages for us - sleep
		push	ebx
		lea	ebx,[esi+tChanDesc.RecvSem]
		call	K_SemP
		pop	ebx
		jmp	.Exit

		; OK, there are some. Check if somebody sent a message
		mov	edi,[esi+tChanDesc.ConnList]
.ConnLoop:	or	edi,edi
		jz	.Sleep
		mov	eax,[edi+tConnDesc.SendWaitQ]
		or	eax,eax
		jnz	.SendWaitFound
		mov	edi,[edi+tConnDesc.Next]
		jmp	.ConnLoop

.Sleep:

.SendWaitFound:	clc

.Exit:		mCheckNeg
		epilogue
		ret
endp		;---------------------------------------------------------------

proc sys_MsgReply
		ret
endp		;---------------------------------------------------------------


proc sys_MsgRead
		ret
endp		;---------------------------------------------------------------


proc sys_MsgWrite
		ret
endp		;---------------------------------------------------------------


proc sys_MsgInfo
		ret
endp		;---------------------------------------------------------------


proc sys_MsgSendPulse
		ret
endp		;---------------------------------------------------------------


proc sys_MsgKeyData
		ret
endp		;---------------------------------------------------------------


proc sys_MsgReadiov
		ret
endp		;---------------------------------------------------------------


proc sys_MsgReceivePulse
		ret
endp		;---------------------------------------------------------------
