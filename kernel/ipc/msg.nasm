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

publicproc IPC_MsgInit
publicproc sys_MsgSendv, sys_MsgSendvnc, sys_MsgReplyv, sys_MsgReceivev
publicproc sys_MsgWritev, sys_MsgReadv, sys_MsgReadIOV
publicproc sys_MsgSendPulse, sys_MsgReceivePulsev
publicproc sys_MsgInfo, sys_MsgError, sys_MsgKeyData


externproc IPC_ChanDescAddr, IPC_ConnDescAddr
externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber, K_PoolChunkAddr
externproc K_SemP, K_SemV
externproc K_CopyFromAct, K_CopyToAct, K_CopyOut, BZero
externproc SLin2Phys, DLin2Phys
externproc MT_ThreadSleep, MT_ThreadWakeup, MT_Schedule


section .bss

?MaxMessages	RESD	1			; Maximum number of messages
?MsgCount	RESD	1			; Number of allocated messages
?MsgPool	RESB	tMasterPool_size
?SpareMsg	RESD	1


section .text

		; IPC_MsgInit - initialize message pool.
		; Input: EAX=maximum number of messages.
		; Output: none.
proc IPC_MsgInit
		mov	[?MaxMessages],eax
		mov	ebx,?MsgPool
		xor	ecx,ecx
		mov	[?MsgCount],ecx
		mov	cl,tMsgDesc_size
		xor	dl,dl
		call	K_PoolInit

		; Allocate one spare message descriptor, so we will never have
		; rcvid 0 (it is reserved for pulses).
		call	AllocMsgDesc
		jc	.Exit
		mov	[?SpareMsg],ebx

.Exit:		ret
endp		;---------------------------------------------------------------


		; Allocate a message descriptor.
		; Input: none.
		; Output: CF=0 - OK, EBX=message descriptor address;
		;	  CF=1 - error, AX=error code.
proc AllocMsgDesc
		mpush	ecx,esi

		mov	eax,[?MsgCount]
		cmp	eax,[?MaxMessages]
		jae	.Err

		mov	ebx,?MsgPool
		call	K_PoolAllocChunk
		jc	.Exit
		mov	ebx,esi
		mov	ecx,tMsgDesc_size
		call	BZero

		mSemInit esi+tMsgDesc.Lock
		inc	dword [?MsgCount]
		clc

.Exit:		mpop	esi,ecx
		ret

.Err:		mov	ax,EAGAIN
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Free a message descriptor.
		; Input: EBX=message descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FreeMsgDesc
		push	esi
		mov	esi,ebx
		call	K_PoolFreeChunk
		jc	.Exit
		dec	dword [?MsgCount]
.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; Fill in the message information structure.
		; Input: EBX=message descriptor address,
		;	 EDI=information structure address (user).
		; Output: CF=0 - OK, EDI=info structure address (kernel);
		;	  CF=1 - error, AX=error code.
		; Note:	modifies ESI.
proc FillMessageInfo
		; Check if a user buffer is OK
		add	edi,USERAREASTART
		jc	.Fault
		mov	eax,edi
		add	eax,tMsgInfo_size-1
		jc	.Fault

		; Fill in the buffer
		mov	esi,[ebx+tMsgDesc.TCB]
		mov	eax,[esi+tTCB.TID]
		mov	[edi+tMsgInfo.TID],eax
		mov	eax,[esi+tTCB.PCB]
		mov	eax,[eax+tProcDesc.PID]
		mov	[edi+tMsgInfo.PID],eax
		mov	esi,[ebx+tMsgDesc.ConnDesc]
		mov	eax,[esi+tConnDesc.ID]
		mov	[edi+tMsgInfo.CoID],eax
		call	K_PoolChunkNumber
		jc	.Exit
		mov	[edi+tMsgInfo.ScoID],eax

.Exit		ret

.Fault:		mov	eax,-EFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Calculate an offset address in source IOV.
		; Input: ESI=address of IOV (user),
		;	 ECX=number of parts in IOV,
		;	 EDX=page directory address,
		;	 EAX=offset.
		; Output: CF=0 - OK:
		;		     EAX=offset inside IOV (in bytes),
		;		     EBX=physical address of target IOV,
		;		     ECX=number of IOVs remaining,
		;		     ESI=linear address of target IOV;
		;	  CF=1 - error.
		; Note: assumes that ECX is always positive.
proc CalcSIOVoffs
		jecxz	.Ret
		push	ebp
.Loop:		call	SLin2Phys
		jc	.Exit
		cmp	eax,[ebx+tIOV.Len]
		jl	.OK
		sub	eax,[ebx+tIOV.Len]
		add	esi,byte tIOV_size
		cmp	esi,USERAREACHECK
		cmc
		jc	.Exit
		loop	.Loop
.OK:		clc
.Exit:		pop	ebp
.Ret:		ret
endp		;---------------------------------------------------------------


		; Calculate an offset address in destination IOV.
		; Input: EDI=address of IOV (user),
		;	 ECX=number of parts in IOV,
		;	 EDX=page directory address,
		;	 EAX=offset.
		; Output: CF=0 - OK:
		;		     EAX=offset inside IOV (in bytes),
		;		     EBX=physical address of target IOV,
		;		     ECX=number of IOVs remaining,
		;		     EDI=linear address of target IOV;
		;	  CF=1 - error.
		; Note: assumes that ECX is always positive.
proc CalcDIOVoffs
		jecxz	.Ret
		push	ebp
.Loop:		call	DLin2Phys
		jc	.Exit
		cmp	eax,[ebx+tIOV.Len]
		jl	.OK
		sub	eax,[ebx+tIOV.Len]
		add	edi,byte tIOV_size
		cmp	edi,USERAREACHECK
		cmc
		jc	.Exit
		loop	.Loop
.OK:		clc
.Exit:		pop	ebp
.Ret:		ret
endp		;---------------------------------------------------------------


		; Multipart copy from send-source to receive buffers.
		; Input: EBX=address of message descriptor,
		;	 ECX=number of parts (or negated size in bytes),
		;	 EDX=offset in source (in bytes),
		;	 EDI=address of destination IOV or buffer.
		; Output: CF=0 - OK, EAX=number of bytes copied;
		;	  CF=1 - error, EAX=errno.
proc CopyVtoAct
		arg	sparts, dparts, sladdr, dladdr, offs
		arg	sbytes, dbytes
		prologue
		push	edi

		; Prepare EDX - set it to source process page directory address
		mov	[%$offs],edx
		mov	eax,[ebx+tMsgDesc.TCB]
		mov	eax,[eax+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]

		; Destination or source size/nparts may be zero.
		; In this case just do nothing.
		xor	eax,eax
		test	ecx,ecx
		jz	near .Exit
		mov	eax,[ebx+tMsgDesc.SendSize]
		test	eax,eax
		jz	near .Exit
		
		; If ECX is negative - destination is linear buffer, not IOV
		mov	esi,[ebx+tMsgDesc.SendBuf]
		mov	[%$dparts],ecx
		test	ecx,ecx
		jns	near .Dvector
		neg	ecx
		mov	[%$dbytes],ecx
		mov	[%$dladdr],edi

		; If the source is also scalar - we have a simplest case
		test	eax,eax
		jns	.Vect2scal
		neg	eax
		sub	eax,[%$offs]
		jc	near .BadOffset
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mpush	ebx,ecx,esi,edi
		add	esi,[%$offs]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	near .CopyErr

		; Return number of bytes copied
		mov	eax,ecx
		jmp	.Exit

		; Vector-to-scalar copy. Take care about offset too..
.Vect2scal:	mov	ecx,eax
		mov	eax,[%$offs]
		call	CalcSIOVoffs
		jc	near .BadOffset
		
.V2Sloop:	mpush	ebx,ecx,esi,edi
		mov	esi,[ebx+tIOV.Base]
		add	esi,eax
		mov	ecx,[ebx+tIOV.Len]
		sub	ecx,eax
		jz	.V2Snext
		mov	eax,[%$dbytes]
		cmp	eax,ecx
		jge	.2
		mov	ecx,eax
.2:		sub	[%$dbytes],ecx
		add	[%$dladdr],ecx
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	near .CopyErr
.V2Snext:	cmp	dword [%$dbytes],0
		jle	.V2Sdone
		add	esi,byte tIOV_size
		call	SLin2Phys
		jc	near .Exit
		mov	edi,[%$dladdr]
		loop	.V2Sloop

		; Return number of bytes copied
.V2Sdone:	mov	eax,[%$dparts]
		neg	eax
		sub	eax,[%$dbytes]
		jmp	.Exit

		; Destination is a vector. Check the source as well.
.Dvector:	test	eax,eax
		jns	.Vect2vect

		; Scalar-to-vector copy - a bit simpler than previous.
		neg	eax
		sub	eax,[%$offs]
		jc	near .BadOffset
		add	esi,[%$offs]
		mov	[%$sladdr],esi
		mov	[%$sbytes],eax
		mov	[%$sparts],eax

.S2Vloop:	mpush	ebx,ecx,esi,edi
		mov	ecx,[edi+tIOV.Len]
		mov	eax,[%$sbytes]
		cmp	eax,ecx
		jge	.3
		mov	ecx,eax
.3:		sub	[%$sbytes],ecx
		add	[%$sladdr],ecx
		mov	edi,[edi+tIOV.Base]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	.CopyErr
		cmp	dword [%$sbytes],0
		jle	.S2Vdone
		add	edi,byte tIOV_size
		mov	esi,[%$sladdr]
		loop	.S2Vloop

		; Return number of bytes copied
.S2Vdone:	mov	eax,[%$sparts]
		sub	eax,[%$sbytes]
		jmp	.Exit

		; Vector-to-vector copy. Complicated.
.Vect2vect:	mov	[%$dparts],ecx
		mov	ecx,eax
		mov	eax,[%$offs]
		call	CalcSIOVoffs
		jc	.BadOffset
		mov	dword [%$sbytes],0

.V2Vloop:	mpush	ebx,ecx,esi,edi
		mov	esi,[ebx+tIOV.Base]
		add	esi,eax
		mov	ecx,[ebx+tIOV.Len]
		sub	ecx,eax
		jz	.V2Vnext
		mov	eax,[edi+tIOV.Len]
		cmp	eax,ecx
		jge	.4
		mov	ecx,eax
.4:		add	[%$sbytes],ecx
		mov	edi,[edi+tIOV.Base]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	.CopyErr
.V2Vnext:	dec	dword [%$dparts]
		jz	.V2Vdone
		add	esi,byte tIOV_size
		add	edi,byte tIOV_size
		loop	.V2Vloop

		; Return number of bytes copied
.V2Vdone:	mov	eax,[%$sbytes]
		clc

.Exit:		pop	edi
		epilogue
		ret

.BadOffset:	mov	eax,-EFAULT
		jmp	.Exit

.CopyErr:	mov	eax,-EFAULT
		jmp	.Exit

.SrvFault:	mov	eax,-ESRVRFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Multipart copy from reply to send-reply buffers.
		; Input:
		; Output:
proc CopyVfromAct
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
		mCurrThread edx

		; Get connection descriptor address
		mov	eax,[%$coid]
		mov	esi,[edx+tTCB.PCB]
		call	IPC_ConnDescAddr
		jc	near .MkErrno

		; Get a message descriptor and fill it
		call	AllocMsgDesc
		jc	near .MkErrno
		lea	eax,[ebx+tMsgDesc.Lock]
		call	K_SemP
		mov	[ebx+tMsgDesc.TCB],edx
		mov	[ebx+tMsgDesc.ConnDesc],edi
		mov	eax,[%$smsg]
		mov	[ebx+tMsgDesc.SendBuf],eax
		mov	eax,[%$sparts]
		mov	[ebx+tMsgDesc.SendSize],eax
		mov	eax,[%$rmsg]
		mov	[ebx+tMsgDesc.ReplyBuf],eax
		mov	eax,[%$rparts]
		mov	[ebx+tMsgDesc.ReplySize],eax

		; Put the message into the send queue
		mov	esi,[edi+tConnDesc.ChanDesc]
		mEnqueue dword [esi+tChanDesc.SendWaitQ], Next, Prev, ebx, tMsgDesc, edx

		lea	eax,[ebx+tMsgDesc.Lock]
		call	K_SemV

		; If there is somebody in the receive queue, wake it up
		mov	edx,ebx
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
		mov	ebx,edx
		mov	edx,[ebx+tMsgDesc.Status]
		call	FreeMsgDesc
		jc	.MkErrno
		mov	eax,edx

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit
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
		arg	chid, msg, bytes, info
		prologue
		
		; Get an address of channel descriptor
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	near .MkErrno

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

		; Change sender status to REPLY-blocked and calculate data size
.GotMsg:	mov	eax,[ebx+tMsgDesc.TCB]
		mov	byte [eax+tTCB.State],THRSTATE_REPLY
		mov	eax,[eax+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]
		mov	ecx,[%$bytes]

		mov	eax,[ebx+tMsgDesc.SendSize]
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mpush	ebx,ecx,esi,edi
		mov	esi,[ebx+tMsgDesc.SendBuf]
		mov	edi,[%$msg]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	near .CopyErr

		; Delete message descriptor from the send queue and put it
		; into reply queue
		lea	eax,[ebx+tMsgDesc.Lock]
		call	K_SemP
		mDequeue dword [esi+tChanDesc.SendWaitQ], Next, Prev, ebx, tMsgDesc, edx
		mEnqueue dword [esi+tChanDesc.ReplyWaitQ], Next, Prev, ebx, tMsgDesc, edx
		lea	eax,[ebx+tMsgDesc.Lock]
		call	K_SemV

		; Get a message ID
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

.CopyErr:	mov	eax,-EFAULT
		jmp	.Exit

.BadBuf:	mov	eax,-EFAULT
		jmp	.Exit

		; We got a pulse. First check if a receive buffer is valid.
.GotPulse:	mov	ecx,[%$bytes]
		cmp	ecx,tPulse_size
		jl	.BadBuf
		mov	edi,[%$msg]
		add	edi,USERAREASTART
		jc	.BadBuf
		add	ecx,edi
		jc	.BadBuf
		
		; Copy the pulse data
		mov	edx,esi
		mov	esi,ebx
		mov	ecx,tPulse_size / 4
		cld
		rep	movsd
		
		; Delete the descriptor from pulse queue and free it
		lea	eax,[ebx+tPulseDesc.Lock]
		call	K_SemP
		mDequeue dword [edx+tChanDesc.PulseQueue], Next, Prev, ebx, tMsgDesc, ecx
		lea	eax,[ebx+tPulseDesc.Lock]
		call	K_SemV
		call	FreeMsgDesc
		jc	.MkErrno

		; Return 0, which means "pulse is received"
		xor	eax,eax	
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgReplyv(int rcvid, int status, const iov_t *riov, int rparts);
		; int MsgReply(int rcvid, int status, const void *msg, int size);
proc sys_MsgReplyv
		arg	rcvid, status, msg, size
		prologue
		
		; Get the message descriptor address
		mov	eax,[%$rcvid]
		mov	ebx,?MsgPool
		call	K_PoolChunkAddr
		jc	.MkErrno
		mov	ebx,esi

		; Prepare to copy
		mov	eax,[ebx+tMsgDesc.TCB]
		mov	eax,[eax+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]
		mov	ecx,[ebx+tMsgDesc.ReplySize]
		mov	eax,[%$size]
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mov	esi,[%$msg]
		mov	edi,[ebx+tMsgDesc.ReplyBuf]
		push	ebx
		call	K_CopyFromAct
		pop	ebx
		jc	.CopyErr

		; Fill the status and remove the message from reply queue
		mov	edi,[ebx+tMsgDesc.ConnDesc]
		mov	esi,[edi+tConnDesc.ChanDesc]
		mov	eax,[%$status]
		mov	[ebx+tMsgDesc.Status],eax
		lea	eax,[ebx+tMsgDesc.Lock]
		call	K_SemP
		mDequeue dword [esi+tChanDesc.ReplyWaitQ], Next, Prev, ebx, tMsgDesc, ecx
		lea	eax,[ebx+tMsgDesc.Lock]
		call	K_SemV

		; Unblock a thread that sent this message
		mov	ebx,[ebx+tMsgDesc.TCB]
		call	MT_ThreadWakeup

		; All OK
		xor	eax,eax

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit

.CopyErr:	mov	eax,-EFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgError(int rcvid, int error);
proc sys_MsgError
		arg	rcvid, errno
		prologue

		; Get the message descriptor address
		mov	eax,[%$rcvid]
		mov	ebx,?MsgPool
		call	K_PoolChunkAddr
		jc	.MkErrno
		mov	edx,esi

		; Set the status and thread's errno, then remove a message from
		; the channel's reply wait queue
		mov	edi,[edx+tMsgDesc.ConnDesc]
		mov	esi,[edi+tConnDesc.ChanDesc]
		xor	eax,eax
		dec	eax
		mov	[edx+tMsgDesc.Status],eax
		mov	ebx,[edx+tMsgDesc.TCB]
		mov	eax,[%$errno]
		mov	[ebx+tTCB.LastErrno],eax
		mDequeue dword [esi+tChanDesc.ReplyWaitQ], Next, Prev, edx, tMsgDesc, edi

		; Unblock a thread that sent this message
		call	MT_ThreadWakeup

		; All OK
		xor	eax,eax

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgReadv(int rcvid, const iov_t *riov, int rparts, int offset);
		; int MsgRead(int rcvid, void *msg, int bytes, int offset);
proc sys_MsgReadv
		arg	rcvid, msg, bytes, offs
		prologue

		; Get the message descriptor address
		mov	eax,[%$rcvid]
		mov	ebx,?MsgPool
		call	K_PoolChunkAddr
		jc	.MkErrno
		mov	ebx,esi

		; Check whether the size and offset are OK
		mov	ecx,[%$bytes]
		mov	eax,[ebx+tMsgDesc.SendSize]
		sub	eax,[%$offs]
		jc	.BadOffset
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mov	eax,[ebx+tMsgDesc.TCB]
		mov	eax,[eax+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]
		mov	esi,[ebx+tMsgDesc.SendBuf]
		add	esi,[%$offs]
		mov	edi,[%$msg]
		push	ecx
		call	K_CopyToAct
		pop	ecx
		jc	.CopyErr

		; Return number of bytes read
		mov	eax,ecx

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit

.BadOffset:	mov	eax,-EFAULT
		jmp	.Exit

.CopyErr:	mov	eax,-EFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgWritev(int rcvid, const iov_t *iov, int parts, int offset);
		; int MsgWrite(int rcvid, const void *msg, int size, int offset);
proc sys_MsgWritev
		arg	rcvid, msg, size, offs
		prologue

		; Get the message descriptor address
		mov	eax,[%$rcvid]
		mov	ebx,?MsgPool
		call	K_PoolChunkAddr
		jc	.MkErrno
		mov	ebx,esi

		; Check whether the size and offset are OK
		mov	ecx,[%$size]
		mov	eax,[ebx+tMsgDesc.ReplySize]
		sub	eax,[%$offs]
		jc	.BadOffset
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mov	eax,[ebx+tMsgDesc.TCB]
		mov	eax,[eax+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]
		mov	esi,[%$msg]
		mov	edi,[ebx+tMsgDesc.ReplyBuf]
		add	edi,[%$offs]
		push	ecx
		call	K_CopyFromAct
		pop	ecx
		jc	.CopyErr

		; Return number of bytes written
		mov	eax,ecx

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit

.BadOffset:	mov	eax,-EFAULT
		jmp	.Exit

.CopyErr:	mov	eax,-EFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgReadIOV(int rcvid, const struct iovec *iov, int parts,
		;		 int offset, int flags);
proc sys_MsgReadIOV
		arg	rcvid, iov, parts, offset, flags
		prologue
		
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgSendPulse(int coid, int priority, int code, int value);
proc sys_MsgSendPulse
		arg	coid, priority, code, value
		prologue

		; Get an address of current TCB
		mCurrThread edx

		; Get connection descriptor address
		mov	eax,[%$coid]
		mov	esi,[edx+tTCB.PCB]
		call	IPC_ConnDescAddr
		jc	near .MkErrno

		; Get a message descriptor and fill it
		call	AllocMsgDesc
		jc	near .MkErrno
		lea	eax,[ebx+tPulseDesc.Lock]
		call	K_SemP
		mov	[ebx+tPulseDesc.TCB],edx
		mov	[ebx+tPulseDesc.ConnDesc],edi
		mov	al,[%$code]
		mov	[ebx+tPulse.Code],al
		mov	eax,[%$value]
		mov	[ebx+tPulse.SigValue],eax

		; Put the pulse into the queue
		mov	esi,[edi+tConnDesc.ChanDesc]
		mEnqueue dword [esi+tChanDesc.PulseQueue], Next, Prev, ebx, tMsgDesc, edx

		lea	eax,[ebx+tPulseDesc.Lock]
		call	K_SemV

		; If there is somebody in the receive queue, wake it up
		mov	ebx,[esi+tChanDesc.ReceiveWaitQ]
		or	ebx,ebx
		jz	.OK
		mDequeue dword [esi+tChanDesc.ReceiveWaitQ], RcvNext, RcvPrev, ebx, tTCB, edx
		call	MT_ThreadWakeup

		; No error
.OK:		xor	eax,eax

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgReceivePulsev(int chid, const iov_t *piov, int parts,
		;			struct _msg_info *info);
		; int MsgReceivePulse(int chid, void *pulse, int bytes,
		;			struct _msg_info *info);
proc sys_MsgReceivePulsev
		arg	chid, pulse, bytes, info
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

		; Check if receive buffer is valid
.GotPulse:	mov	ecx,[%$bytes]
		cmp	ecx,tPulse_size
		jl	.BadBuf
		mov	edi,[%$pulse]
		add	edi,USERAREASTART
		jc	.BadBuf
		add	ecx,edi
		jc	.BadBuf

		; Copy the pulse code and value; fill scoid
		mov	al,[ebx+tPulse.Code]
		mov	[edi+tPulse.Code],al
		mov	eax,[ebx+tPulse.SigValue]
		mov	[edi+tPulse.SigValue],eax
		push	esi
		mov	esi,[ebx+tPulseDesc.ConnDesc]
		call	K_PoolChunkNumber
		pop	esi
		mov	[edi+tPulse.SCoID],eax
		
		; Delete the descriptor from pulse queue and free it
		lea	eax,[ebx+tPulseDesc.Lock]
		call	K_SemP
		mDequeue dword [esi+tChanDesc.PulseQueue], Next, Prev, ebx, tMsgDesc, ecx
		lea	eax,[ebx+tPulseDesc.Lock]
		call	K_SemV
		call	FreeMsgDesc
		jc	.MkErrno

		; Return 0, that means "pulse is received"
		xor	eax,eax

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit

.BadBuf:	mov	eax,-EFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgKeyData(int rcvid, int oper, uint32 key, uint32 *newkey,
		;		 const struct iovec *iov, int parts);
proc sys_MsgKeyData
		arg	rcvid, oper, key, newkey, iov, parts
		prologue
		
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgInfo(int rcvid, struct _msg_info *info);
proc sys_MsgInfo
		arg	rcvid, info
		prologue

		; Get the message descriptor address
		mov	eax,[%$rcvid]
		mov	ebx,?MsgPool
		call	K_PoolChunkAddr
		jc	.NotFound
		mov	ebx,esi

		; Fill in the buffer
		mov	edi,[%$info]
		call	FillMessageInfo
		jc	.MkErrno

		; All OK
		xor	eax,eax

.Exit:		epilogue
		ret

.MkErrno:	mErrno
		jmp	.Exit

.NotFound:	mov	eax,-ESRCH
		jmp	.Exit
endp		;---------------------------------------------------------------
