;*******************************************************************************
; msg.nasm - core message passing routines.
; Copyright (c) 2003 RET & COM Research.
;*******************************************************************************

module kernel.ipc.msg

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "pool.ah"
%include "msg.ah"
%include "tm/process.ah"
%include "cpu/paging.ah"

publicproc IPC_PulseInit
publicproc sys_MsgSendv, sys_MsgSendvnc, sys_MsgReplyv, sys_MsgReceivev
publicproc sys_MsgWritev, sys_MsgReadv, sys_MsgReadIOV
publicproc sys_MsgSendPulse, sys_MsgReceivePulsev
publicproc sys_MsgInfo, sys_MsgError, sys_MsgKeyData
exportproc K_DecodeRcvid, K_SendPulse, AllocPulseDesc, FreePulseDesc


externproc IPC_ChanDescAddr, IPC_ConnDescAddr
externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber, K_PoolChunkAddr
externproc K_SemP, K_SemV
externproc K_CopyFromAct, K_CopyToAct, K_CopyOut, BZero
externproc SLin2Phys, DLin2Phys
externproc MT_ThreadSleep, MT_ThreadWakeup, MT_Schedule, MT_FindTCBbyNum


section .bss

?MaxPulses	RESD	1			; Maximum number of pulses
?PulseCount	RESD	1			; Number of allocated pulses
?PulsePool	RESB	tMasterPool_size


section .text

%include "msgcopy.nasm"

		; IPC_PulseInit - initialize the pulse pool.
		; Input: EAX=maximum number of pulses.
		; Output: none.
proc IPC_PulseInit
		mov	[?MaxPulses],eax
		mov	ebx,?PulsePool
		xor	ecx,ecx
		mov	[?PulseCount],ecx
		mov	cl,tPulseDesc_size
		xor	dl,dl
		call	K_PoolInit
		ret
endp		;---------------------------------------------------------------


		; Allocate a pulse descriptor.
		; Input: none.
		; Output: CF=0 - OK, EBX=pulse descriptor address;
		;	  CF=1 - error, EAX=errno.
proc AllocPulseDesc
		mpush	ecx,esi

		mov	eax,[?PulseCount]
		cmp	eax,[?MaxPulses]
		jae	.Err

		mov	ebx,?PulsePool
		call	K_PoolAllocChunk
		jc	.Exit
		mov	ebx,esi
		mov	ecx,tPulseDesc_size
		call	BZero

		mSemInit esi+tPulseDesc.Lock
		inc	dword [?PulseCount]
		clc

.Exit:		mpop	esi,ecx
		ret

.Err:		mov	eax,-EAGAIN
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Free a pulse descriptor.
		; Input: EBX=pulse descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FreePulseDesc
		push	esi
		mov	esi,ebx
		call	K_PoolFreeChunk
		jc	.Exit
		dec	dword [?PulseCount]
.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; Find a TCB by a given rcvid.
		; Input: EAX=rcvid.
		; Output: CF=0 - OK, EBX=TCB address;
		;	  CF=1 - error, EAX=errno.
		; Note: currently rcvid consists of 16-bit TCB chunk number
		;	(system-wide, low word) and 16-bit ConnDesc chunk
		;	number (system-wide, high word). This will most
		;	probably change when the support of native networking
		;	will be added.
proc K_DecodeRcvid
		and	eax,0FFFFh
		call	MT_FindTCBbyNum
		jnc	.Ret
		mov	eax,-ESRCH
.Ret:		ret
endp		;---------------------------------------------------------------


		; Fill in the message information structure.
		; Input: EBX=address of sending TCB,
		;	 EDI=information structure address (user).
		; Output: CF=0 - OK:
		;		     EAX=0,
		;		     EDI=info structure address (kernel);
		;	  CF=1 - error, EAX=errno.
		; Note:	modifies ESI.
proc FillMessageInfo
		; Check if a user buffer is OK
		add	edi,USERAREASTART
		jc	.Fault
		mov	eax,edi
		add	eax,tMsgInfo_size-1
		jc	.Fault

		; Fill in the buffer
		mov	eax,[ebx+tTCB.TID]
		mov	[edi+tMsgInfo.TID],eax
		mov	eax,[ebx+tTCB.PCB]
		mov	eax,[eax+tProcDesc.PID]
		mov	[edi+tMsgInfo.PID],eax
		mov	esi,[ebx+tTCB.ConnDesc]
		mov	eax,[esi+tConnDesc.ID]
		mov	[edi+tMsgInfo.CoID],eax
		call	K_PoolChunkNumber
		jc	.NotFound
		mov	[edi+tMsgInfo.ScoID],eax
.Exit:		ret

.Fault:		mov	eax,-EFAULT
		jmp	.Exit
.NotFound:	mov	eax,-ESRCH
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Send a pulse to the channel. This routine is used
		; by MsgSendPulse and MsgDeliverEvent.
		; Input: AL=pulse code,
		;	 ECX=pulse value,
		;	 EBX=address of TCB,
		;	 EDI=address of connection descriptor.
		; Output: none.
proc K_SendPulse
		mpush	ebx,edx,esi,eax

		; Get a pulse descriptor and fill it in
		mov	edx,ebx
		call	AllocPulseDesc
		jc	near .Exit

		mLockCB ebx, tPulseDesc
		mov	al,[esp]
		mov	[ebx+tPulse.Code],al
		mov	[ebx+tPulse.SigValue],ecx
		mov	[ebx+tPulseDesc.TCB],edx
		mov	[ebx+tPulseDesc.ConnDesc],edi

		; Put the pulse into the queue
		mov	esi,[edi+tConnDesc.ChanDesc]
		mEnqueue dword [esi+tChanDesc.PulseQueue], Next, Prev, ebx, tPulseDesc, edx
		mUnlockCB ebx, tPulseDesc

		; If there is somebody in the receive queue, wake him up
		mov	ebx,[esi+tChanDesc.ReceiveWaitQ]
		or	ebx,ebx
		jz	.Exit
		mDequeue dword [esi+tChanDesc.ReceiveWaitQ], RcvNext, RcvPrev, ebx, tTCB, edx
		call	MT_ThreadWakeup

.Exit:		mpop	eax,esi,edx,ebx
		ret
endp		;---------------------------------------------------------------


; --- System call routines -----------------------------------------------------

		; int MsgSendvnc(int coid, const iov_t *siov, int sparts,
		;		const iov_t *riov, int rparts);
		; int MsgSendnc(int coid, const void *smsg, int sbytes,
		;		void *rmsg, int rbytes);
		; int MsgSendsvnc(int coid, const void *smsg, int sbytes,
		;		const iov_t *riov, int rparts);
		; int MsgSendvsnc(int coid, const iov_t *siov, int sparts,
		;		void *rmsg, int rbytes);
proc sys_MsgSendvnc
		arg	coid, smsg, sparts, rmsg, rparts
		prologue

		; Get current thread
		mCurrThread ebx

		; Get connection descriptor address
		mov	eax,[%$coid]
		mov	esi,[ebx+tTCB.PCB]
		call	IPC_ConnDescAddr
		jc	near .Exit

		; Fill in the fields in TCB
		mLockCB ebx, tTCB
		mov	[ebx+tTCB.ConnDesc],edi
		mov	eax,[%$smsg]
		mov	[ebx+tTCB.SendBuf],eax
		mov	eax,[%$sparts]
		mov	[ebx+tTCB.SendSize],eax
		mov	eax,[%$rmsg]
		mov	[ebx+tTCB.ReplyBuf],eax
		mov	eax,[%$rparts]
		mov	[ebx+tTCB.ReplySize],eax

		; Put the message into the send queue
		mov	esi,[edi+tConnDesc.ChanDesc]
		mEnqueue dword [esi+tChanDesc.SendWaitQ], SendReplyNext, SendReplyPrev, ebx, tTCB, edx
		mUnlockCB ebx, tTCB

		; If there is somebody in the receive queue, wake him up
		mov	ebx,[esi+tChanDesc.ReceiveWaitQ]
		or	ebx,ebx
		jz	.Sleep
		mDequeue dword [esi+tChanDesc.ReceiveWaitQ], RcvNext, RcvPrev, ebx, tTCB, edi
		call	MT_ThreadWakeup
		
		; Block ourselves until we get reply or error
.Sleep:		mCurrThread ebx
		mov	al,THRSTATE_SEND
		cli
		call	MT_ThreadSleep
		call	MT_Schedule

		; Get a status and free message descriptor
		mov	eax,[ebx+tTCB.MsgStatus]

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgSendv(int coid, const iov_t *siov, int sparts,
		;		const iov_t *riov, int rparts);
		; int MsgSend(int coid, const void *smsg, int sbytes,
		;		void *rmsg, int rbytes);
		; int MsgSendsv(int coid, const void *smsg, int sbytes,
		;		const iov_t *riov, int rparts);
		; int MsgSendvs(int coid, const iov_t *siov, int sparts,
		;		void *rmsg, int rbytes);
proc sys_MsgSendv
		jmp	sys_MsgSendvnc
endp		;---------------------------------------------------------------


		; int MsgReceivev(int chid, const iov_t *riov, int rparts,
		;		 struct _msg_info *info);
		; int MsgReceive(int chid, void *msg, int bytes, 
		;		 struct _msg_info *info);
proc sys_MsgReceivev
		arg	chid, msg, parts, info
		prologue

		; Get an address of channel descriptor
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	near .Exit

		; If there is a message or pulse pending, we won't block
.WaitLoop:	mov	ebx,[esi+tChanDesc.PulseQueue]
		or	ebx,ebx
		jnz	near .GotPulse
		mov	ebx,[esi+tChanDesc.SendWaitQ]
		or	ebx,ebx
		jnz	.GotMsg
		mCurrThread ebx
		mEnqueue dword [esi+tChanDesc.ReceiveWaitQ], RcvNext, RcvPrev, ebx, tTCB, edx
		mov	al,THRSTATE_RECEIVE
		cli
		call	MT_ThreadSleep
		call	MT_Schedule
		jmp	.WaitLoop

		; Change sender status to REPLY-blocked
.GotMsg:	mov	byte [ebx+tTCB.State],THRSTATE_REPLY

		; Copy the message
		mov	ecx,[%$parts]
		xor	edx,edx
		mov	edi,[%$msg]
		call	CopyVtoAct
		jc	near .Exit
		mov	ecx,eax

		; Delete the TCB from the send queue and put it into a
		; reply queue
		mLockCB ebx, tTCB
		mDequeue dword [esi+tChanDesc.SendWaitQ], SendReplyNext, SendReplyPrev, ebx, tTCB, edx
		mEnqueue dword [esi+tChanDesc.ReplyWaitQ], SendReplyNext, SendReplyPrev, ebx, tTCB, edx
		mUnlockCB ebx, tTCB

		; Get a rcvid
		mov	esi,ebx
		call	K_PoolChunkNumber
		jc	.MkErrno
		mov	edx,eax

		; Fill in the message information if it was requested
		mov	edi,[%$info]
		or	edi,edi
		jz	.OK
		call	FillMessageInfo
		jc	.Exit
		mov	[edi+tMsgInfo.MsgLen],ecx

.OK:		mov	eax,edx

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit

		; We got a pulse. Simply copy it.
.GotPulse:	mov	ecx,[%$parts]
		mov	edi,[%$msg]
		call	CopyPulseToAct
		jc	.Exit
		
		; Delete the descriptor from pulse queue and free it
		mLockCB ebx, tPulseDesc
		mDequeue dword [esi+tChanDesc.PulseQueue], Next, Prev, ebx, tPulseDesc, ecx
		mUnlockCB ebx, tPulseDesc
		call	FreePulseDesc
		jc	.MkErrno

		; Return 0, which means "pulse is received"
		xor	eax,eax	
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgReplyv(int rcvid, int status, const iov_t *riov, int rparts);
		; int MsgReply(int rcvid, int status, const void *msg, int size);
proc sys_MsgReplyv
		arg	rcvid, status, msg, parts
		prologue
		
		; Get the sending TCB address
		mov	eax,[%$rcvid]
		call	K_DecodeRcvid
		jc	.Exit

		; Copy the message
		mov	ecx,[%$parts]
		xor	edx,edx
		mov	esi,[%$msg]
		call	CopyVfromAct
		jc	.Exit

		; Fill the status and remove the TCB from reply queue
		mov	edi,[ebx+tTCB.ConnDesc]
		mov	esi,[edi+tConnDesc.ChanDesc]
		mov	eax,[%$status]
		mov	[ebx+tTCB.MsgStatus],eax
		mLockCB ebx, tTCB
		mDequeue dword [esi+tChanDesc.ReplyWaitQ], SendReplyNext, SendReplyPrev, ebx, tTCB, ecx
		mUnlockCB ebx, tTCB

		; Finally, unblock the sender and return success
		call	MT_ThreadWakeup
		xor	eax,eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgError(int rcvid, int error);
proc sys_MsgError
		arg	rcvid, errno
		prologue

		; Get the sending TCB address
		mov	eax,[%$rcvid]
		call	K_DecodeRcvid
		jc	.Exit

		; Set the status and thread's errno, then remove the TCB from
		; the channel's reply wait queue
		mov	edi,[ebx+tTCB.ConnDesc]
		mov	esi,[edi+tConnDesc.ChanDesc]
		mov	dword [ebx+tTCB.MsgStatus],-1
		mov	eax,[%$errno]
		mov	[ebx+tTCB.LastErrno],eax
		mLockCB ebx, tTCB
		mDequeue dword [esi+tChanDesc.ReplyWaitQ], SendReplyNext, SendReplyPrev, ebx, tTCB, edi
		mUnlockCB ebx, tTCB

		; Unblock the sender and return success
		call	MT_ThreadWakeup
		xor	eax,eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgReadv(int rcvid, const iov_t *riov, int rparts, int offset);
		; int MsgRead(int rcvid, void *msg, int bytes, int offset);
proc sys_MsgReadv
		arg	rcvid, msg, parts, offs
		prologue

		; Get the sending TCB address
		mov	eax,[%$rcvid]
		call	K_DecodeRcvid
		jc	.Exit

		; Copy the data
		mov	ecx,[%$parts]
		mov	edx,[%$offs]
		mov	edi,[%$msg]
		call	CopyVtoAct

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgWritev(int rcvid, const iov_t *iov, int parts, int offset);
		; int MsgWrite(int rcvid, const void *msg, int size, int offset);
proc sys_MsgWritev
		arg	rcvid, msg, parts, offs
		prologue

		; Get the sending TCB address
		mov	eax,[%$rcvid]
		call	K_DecodeRcvid
		jc	.Exit

		; Copy the data
		mov	ecx,[%$parts]
		mov	edx,[%$offs]
		mov	esi,[%$msg]
		call	CopyVfromAct

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgReadIOV(int rcvid, const struct iovec *iov, int parts,
		;		 int offset, int flags);
proc sys_MsgReadIOV
		arg	rcvid, iov, parts, offset, flags
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgSendPulse(int coid, int priority, int code, int value);
proc sys_MsgSendPulse
		arg	coid, priority, code, value
		prologue

		; Get an address of current TCB
		mCurrThread ebx

		; Get connection descriptor address
		mov	eax,[%$coid]
		mov	esi,[ebx+tTCB.PCB]
		call	IPC_ConnDescAddr
		jc	.Exit

		; Send the pulse
		mov	al,[%$code]
		mov	ecx,[%$value]
		call	K_SendPulse

		; No error
		xor	eax,eax
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgReceivePulsev(int chid, const iov_t *piov, int parts,
		;			struct _msg_info *info);
		; int MsgReceivePulse(int chid, void *pulse, int bytes,
		;			struct _msg_info *info);
proc sys_MsgReceivePulsev
		arg	chid, pulse, parts, info
		prologue

		; Get an address of channel descriptor
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	near .MkErrno

		; If pulse queue is empty - suspend ourselves
.WaitLoop:	mov	ebx,[esi+tChanDesc.PulseQueue]
		or	ebx,ebx
		jnz	.GotPulse
		mCurrThread ebx
		mEnqueue dword [esi+tChanDesc.ReceiveWaitQ], RcvNext, RcvPrev, ebx, tTCB, ecx
		mov	al,THRSTATE_RECEIVE
		cli
		call	MT_ThreadSleep
		call	MT_Schedule
		jmp	.WaitLoop

		; Copy the pulse
.GotPulse:	mov	ecx,[%$parts]
		mov	edi,[%$pulse]
		call	CopyPulseToAct
		jc	.Exit
		
		; Delete the descriptor from pulse queue and free it
		mLockCB ebx, tPulseDesc
		mDequeue dword [esi+tChanDesc.PulseQueue], Next, Prev, ebx, tPulseDesc, ecx
		mUnlockCB ebx, tPulseDesc
		call	FreePulseDesc
		jc	.MkErrno

		; Return 0, that means "pulse is received"
		xor	eax,eax

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgKeyData(int rcvid, int oper, uint32 key, uint32 *newkey,
		;		 const struct iovec *iov, int parts);
proc sys_MsgKeyData
		arg	rcvid, oper, key, newkey, iov, parts
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgInfo(int rcvid, struct _msg_info *info);
proc sys_MsgInfo
		arg	rcvid, info
		prologue

		; Get the sending TCB address
		mov	eax,[%$rcvid]
		call	K_DecodeRcvid
		jc	.Exit

		; Fill in the buffer
		mov	edi,[%$info]
		call	FillMessageInfo

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
