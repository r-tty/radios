;------------------------------------------------------------------------------
; message.nasm - function for handling other messages by a resource manager.
;------------------------------------------------------------------------------

module librm.message

%include "rm/resmgr.ah"
%include "rm/dispatch.ah"
%include "private.ah"

exportproc _message_attach, _message_detach
exportproc _pulse_attach, _pulse_detach
exportproc _message_connect, _message_block, _message_unblock

importproc _ConnectAttach, _ConnectDetach
importproc _pthread_mutex_lock, _pthread_mutex_unlock
externproc _dispatch_block

section .text

		; int message_attach(dispatch_t *dpp, message_attr_t *attr,
		;		     int low, int high, int (*func)
		;			(message_context_t *ctp, int fd,
		;			 uint flags, void *handle),
		;		     void *handle);
proc _message_attach
		arg	dpp, attr, low, high, func, handle
		prologue
		epilogue
		ret
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
