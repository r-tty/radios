;------------------------------------------------------------------------------
; message.nasm - function for handling other messages by a resource manager.
;------------------------------------------------------------------------------

module librm.message

%include "errors.ah"
%include "locstor.ah"
%include "rm/resmgr.ah"
%include "rm/dispatch.ah"
%include "private.ah"

exportproc _message_attach, _message_detach
exportproc _pulse_attach, _pulse_detach
exportproc _message_connect, _message_block, _message_unblock

importproc _ConnectAttach, _ConnectDetach
importproc _pthread_mutex_init, _pthread_mutex_lock, _pthread_mutex_unlock
importproc _calloc, _realloc, _free
externproc _dispatch_block, DISP_Attach, DISP_VectorFind

section .text

		; int message_attach(dispatch_t *dpp, message_attr_t *attr,
		;		     int low, int high, int (*func)
		;			(message_context_t *ctp, int fd,
		;			 uint flags, void *handle),
		;		     void *handle);
proc _message_attach
		arg	dpp, attr, low, high, func, handle
		prologue
		savereg	ebx,ecx,edx,esi,edi

		; Is the message control structure already initialized?
		mov	edx,[%$attr]
		mov	ebx,[%$dpp]
		mov	esi,[ebx+tDispatch.MessageCtrl]
		test	esi,esi
		jnz	near .CtrlAllocated

		; Initialize message control structure
		Ccall	_calloc, byte 1, byte tMessageControl_size
		test	eax,eax
		jz	near .NoMemory
		mov	esi,eax

		; Calculate number of parts
		xor	eax,eax
		inc	al
		test	edx,edx
		jz	.1
		mov	ecx,[edx+tMessageAttr.NpartsMax]
		cmp	eax,ecx
		jae	.1
		mov	eax,ecx
.1:		mov	[esi+tMessageControl.NpartsMax],eax

		; Calculate MsgMaxSize
	%if MSG_MAX_SIZE > tIOMunion_size
		mov	ecx,MSG_MAX_SIZE
	%else
		mov	ecx,tIOMunion_size
	%endif
		test	edx,edx
		jz	.2
		mov	eax,[edx+tMessageAttr.MsgMaxSize]
		cmp	ecx,eax
		jae	.2
		mov	ecx,eax
.2:		mov	[esi+tMessageControl.MsgMaxSize],ecx

		; Calculate ContextSize
		mov	eax,[esi+tMessageControl.NpartsMax]
		shl	eax,tIOV_shift
		add	eax,byte tMessageContext_size
		add	eax,ecx
		mov	[esi+tMessageControl.ContextSize],eax

		; Attach the message
		mov	ebx,[%$dpp]
		mov	dl,DISPATCH_MESSAGE
		call	DISP_Attach
		jnc	.InitMutex
		Ccall	_free, esi
		jmp	.Failed

.InitMutex:	lea	eax,[esi+tMessageControl.Mutex]
		Ccall	_pthread_mutex_init, eax, 0

.CtrlAllocated:	lea	eax,[esi+tMessageControl.Mutex]
		Ccall	_pthread_mutex_lock, eax

		; Attach message type to message vector
		mov	ecx,[esi+tMessageControl.NumElements]
		mov	edi,[esi+tMessageControl.MessageVec]
		or	edi,edi
		jz	.GrowVec
		cmp	ecx,[esi+tMessageControl.NumEntries]
		jne	.FindVec

		; Grow the vector array
.GrowVec:	add	ecx,GROW_VEC
		shl	ecx,tMessageVec_shift
		Ccall	_realloc, edi, ecx
		test	eax,eax
		jz	near .NoMemory
		mov	edi,eax
		mov	eax,[esi+tMessageControl.NumElements]
		shl	eax,tMessageVec_shift
		push	edi
		add	edi,eax
		mov	ecx,GROW_VEC*tMessageVec_size/4
		xor	eax,eax
		cld
		rep	stosd
		pop	edi
		mov	[esi+tMessageControl.MessageVec],edi
		mov	ecx,[esi+tMessageControl.NumElements]
		add	ecx,GROW_VEC
		mov	[esi+tMessageControl.NumElements],ecx

		; Find a vector
.FindVec:	call	DISP_VectorFind
		jc	near .NoMemory

		; Do we have to allocate a pulse code?
		mov	edx,[%$attr]
		test	edx,edx
		jz	near .FillVec
		mov	eax,[edx+tMessageAttr.Flags]
		test	eax,MSG_FLAG_TYPE_PULSE
		jz	near .FillVec
		test	eax,MSG_FLAG_ALLOC_PULSE
		jz	.ChkPcodeLoHi

		; Yes, we need to allocate a pulse code
		mov	edx,PULSE_CODE_MINAVAIL
.PulseCodeLoop:	cmp	edx,PULSE_CODE_MAXAVAIL
		jg	near .ErrAgain
		mov	ebx,edx
		mov	ecx,[esi+tMessageControl.NumElements]
		mov	edi,[esi+tMessageControl.MessageVec]
.FindPVecLoop:	mov	eax,[edi+tMessageVec.Flags]
		test	eax,VEC_VALID
		jz	.NextPVec
		test	eax,MSG_FLAG_TYPE_PULSE
		jz	.NextPVec
		cmp	edx,[edi+tMessageVec.Low]
		jl	.NextPVec
		cmp	edx,[edi+tMessageVec.High]
		jg	.NextPVec
		inc	edx
		jmp	.3
.NextPVec:	add	edi,byte tMessageVec_size
		loop	.FindPVecLoop
.3:		cmp	edx,ebx
		jne	.PulseCodeLoop
		cmp	edx,PULSE_CODE_MAXAVAIL
		jg	near .ErrAgain
		mov	[%$low],edx
		jmp	.FillVec

		; Check if %$low and %$high are in valid range
.ChkPcodeLoHi:	mov	edx,[%$low]
		mov	ebx,[%$high]
		cmp	edx,-128
		jge	.ChkCoidDeath
		cmp	ebx,127
		jg	near .Invalid

		; Check for coid death
.ChkCoidDeath:	cmp	edx,PULSE_CODE_COIDDEATH
		jl	.FillVec
		cmp	ebx,PULSE_CODE_COIDDEATH
		jg	.FillVec
		mov	eax,[%$dpp]
		test	dword [eax+tDispatch.Flags],DISPATCH_CHANNEL_COIDDEATH
		jz	near .Busy

		; Fill in the vector
.FillVec:	Mov32	edi+tMessageVec.Low,%$low
		Mov32	edi+tMessageVec.High,%$high
		mov	dword [edi+tMessageVec.Flags],VEC_VALID
		Mov32	edi+tMessageVec.Handle,%$handle
		Mov32	edi+tMessageVec.Func,%$func
		inc	dword [esi+tMessageControl.NumEntries]

		; Initialize vector flags, if necessary
		mov	edx,[%$attr]
		test	edx,edx
		jz	.OK
		mov	eax,[edx+tMessageAttr.Flags]
		test	eax,MSG_FLAG_TYPE_RESMGR
		jz	.ChkSelectFlag
		or	dword [edi+tMessageVec.Flags],MSG_FLAG_TYPE_RESMGR
		jmp	.ChkPulseFlag

.ChkSelectFlag:	test	eax,MSG_FLAG_TYPE_SELECT
		jz	.ChkPulseFlag
		or	dword [edi+tMessageVec.Flags],MSG_FLAG_TYPE_SELECT | MSG_FLAG_TYPE_PULSE

.ChkPulseFlag:	test	eax,MSG_FLAG_TYPE_PULSE
		jz	.ChkDefFnFlag
		or	dword [edi+tMessageVec.Flags],MSG_FLAG_TYPE_PULSE

.ChkDefFnFlag:	test	eax,MSG_FLAG_DEFAULT_FUNC
		jz	.OK
		or	dword [edi+tMessageVec.Flags],MSG_FLAG_DEFAULT_FUNC
		
.OK:		lea	eax,[esi+tMessageControl.Mutex]
		Ccall	_pthread_mutex_unlock, eax
		xor	eax,eax

.Exit:		epilogue
		ret

.ErrAgain:	mSetErrno EAGAIN,edi
		jmp	.UnlockAndErr

.NoMemory:	mSetErrno ENOMEM,edi
		jmp	.UnlockAndErr

.Invalid:	mSetErrno EINVAL,edi
		jmp	.UnlockAndErr

.Busy:		mSetErrno EBUSY,edi
		jmp	.UnlockAndErr

.Failed:	mSetErrno eax,edi
.UnlockAndErr:	lea	edi,[esi+tMessageControl.Mutex]
		Ccall	_pthread_mutex_unlock, edi
		xor	eax,eax
		dec	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int pulse_attach(dispatch_t *dpp, int flags, int code,
		;		int (*func)(message_context_t *ctp, int fd,
		;				uint flags, void *handle),
		;		void *handle);
proc _pulse_attach
		arg	dpp, flags, code, func, handle
		locauto	attr, tMessageAttr_size
		prologue
		savereg	ecx,edi

		xor	ecx,ecx
		mov	cl,tMessageAttr_size
		xor	eax,eax
		lea	edi,[%$attr]
		cld
		rep	stosb

		lea	edi,[%$attr]
		mov	eax,[%$flags]
		mov	dword [edi+tMessageAttr.Flags],MSG_FLAG_TYPE_PULSE
		test	eax,MSG_FLAG_ALLOC_PULSE
		jz	.Attach
		or	dword [edi+tMessageAttr.Flags],MSG_FLAG_ALLOC_PULSE

.Attach:	Ccall	_message_attach, dword [%$dpp], edi, dword [%$code], \
			dword [%$code], dword [%$func], dword [%$handle]

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int message_detach(dispatch_t *dpp, int low, int high, int flags);
proc _message_detach
		arg	dpp, low, high, flags
		prologue
		savereg	ebx,esi

		mov	ebx,[%$dpp]
		mov	esi,[ebx+tDispatch.MessageCtrl]
		or	esi,esi
		jz	.Err

		lea	edx,[esi+tMessageControl.Mutex]
		Ccall	_pthread_mutex_lock, edx

		; Search for a matching entry
		mov	ecx,[esi+tMessageControl.NumElements]
		jecxz	.Unlock
		mov	edi,[esi+tMessageControl.MessageVec]
.Loop:		test	dword [edi+tMessageVec.Flags],VEC_VALID
		jz	.Next
		Cmp32	%$low,edi+tMessageVec.Low
		jne	.1
		Cmp32	%$high,edi+tMessageVec.High
		jne	.1
		mov	ebx,[edi+tMessageVec.Flags]
		and	ebx,MSG_FLAG_TYPE_PULSE
		mov	eax,[%$flags]
		xor	eax,ebx
		jz	.2
.1:		mov	ebx,[edi+tMessageVec.Flags]
		and	ebx,MSG_FLAG_DEFAULT_FUNC
		mov	eax,[%$flags]
		and	eax,ebx
		jz	.Next
.2:		and	dword [edi+tMessageVec.Flags],~VEC_VALID
		dec	dword [esi+tMessageControl.NumElements]
		Ccall	_pthread_mutex_unlock, edx
		xor	eax,eax
		jmp	.Exit
.Next:		add	edi,byte 4 
		loop	.Loop

.Unlock:	Ccall	_pthread_mutex_unlock, edx

.Err:		xor	eax,eax
		not	eax
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int pulse_detach(dispatch_t *dpp, int code, int flags);
proc _pulse_detach
		mov	dword [esp+16],MSG_FLAG_TYPE_PULSE
		jmp	_message_detach
endp		;---------------------------------------------------------------


		; int message_connect(dispatch_t *dpp, int flags);
proc _message_connect
		arg	dpp, flags
		prologue
		savereg	ebx
		xor	eax,eax
		test	dword [%$flags],MSG_FLAG_SIDE_CHANNEL
		jz	.Connect
		mov	eax,SIDE_CHANNEL
.Connect:	mov	ebx,[%$dpp]
		Ccall	_ConnectAttach, byte 0, byte 0, \
			dword [ebx+tDispatch.ChID], eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; message_context_t *message_block(message_context_t *ctp);
proc _message_block
		arg	ctp
		prologue
		savereg	ebx,esi
		mov	esi,[%$ctp]
		xor	eax,eax
		not	eax
		mov	[esi+tMessageContext.ID],eax
		mov	ebx,[esi+tMessageContext.dpp]
		Mov32	esi+tMessageContext.Info+tMsgInfo.MsgLen,ebx+tDispatch.MsgMaxSize
		Ccall	_dispatch_block, esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void _message_unblock(dispatch_context_t *ctp);
proc _message_unblock
		arg	ctp
		prologue
		savereg	ebx,esi

		mov	esi,[%$ctp]
		mov	ebx,[esi+tMessageContext.dpp]
		Ccall	_ConnectAttach, byte 0, byte 0, dword [ebx+tDispatch.ChID], \
			SIDE_CHANNEL, byte 0
		test	eax,eax
		js	.Exit
		Ccall	_ConnectDetach

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
