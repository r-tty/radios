;------------------------------------------------------------------------------
; dispatch.nasm - dispatching routines.
;------------------------------------------------------------------------------

module librm.dispatch

importproc _ChannelCreate, _ChannelDestroy
importproc _malloc, _free

%include "errors.ah"
%include "locstor.ah"
%include "rm/resmgr.ah"
%include "rm/dispatch.ah"
%include "private.ah"

exportproc _dispatch_create, _dispatch_destroy
exportproc _dispatch_context_alloc, _dispatch_context_free
exportproc _dispatch_block, _dispatch_unblock
exportproc _dispatch_handler, _dispatch_timeout
publicproc DISP_Attach, DISP_SetContextSize

importproc _malloc, _calloc, _free

section .text

		; dispatch_t *dispatch_create(void);
proc _dispatch_create
		push	edx
		xor	edx,edx
		xor	eax,eax
		not	eax
		call	DISP_AllocDesc
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; int dispatch_destroy(dispatch_t *dpp);
proc _dispatch_destroy
		arg	dpp
		prologue
		mov	eax,[%$dpp]
		mov	eax,[eax+tDispatch.ChID]
		test	eax,eax
		js	.FreeDesc
		Ccall	_ChannelDestroy, eax
.FreeDesc:	Ccall	_free, dword [%$dpp]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; dispatch_context_t *dispatch_block(dispatch_context_t *ctp);
proc _dispatch_block
		arg	ctp
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void dispatch_unblock(dispatch_context_t *ctp);
proc _dispatch_unblock
		arg	ctp
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void dispatch_handler(dispatch_context_t *ctp);
proc _dispatch_handler
		arg	ctp
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int dispatch_timeout(dispatch_t *dpp, struc timespec *timeout);
proc _dispatch_timeout
		arg	dpp, timeout
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; dispatch_context_t *dispatch_context_alloc(dispatch_t *dpp);
proc _dispatch_context_alloc
		arg	dpp
		prologue
		savereg	ebx,ecx,esi

		mov	ebx,[%$dpp]
		mov	eax,[ebx+tDispatch.BlockType]
		cmp	eax,DISPATCH_BLOCK_RECEIVE
		jne	.ChkSigWait

		mov	eax,[ebx+tDispatch.MessageCtrl]
		test	eax,eax
		jz	.Invalid
		Ccall	_calloc, 1, dword [ebx+tDispatch.ContextSize]
		test	eax,eax
		jz	.NoMemory
		mov	esi,eax

		mov	[esi+tMessageContext.dpp],ebx
		mov	eax,[ebx+tDispatch.NpartsMax]
		lea	eax,[eax*tIOV_size+tMessageContext.IOV]
		mov	ecx,[ebx-tDispatch.ContextSize]
		sub	ecx,eax
		mov	[esi+tMessageContext.MsgMaxSize],ecx
		add	eax,esi
		mov	[esi+tMessageContext.Msg],eax

		or	dword [ebx+tDispatch.Flags],DISPATCH_CONTEXT_ALLOCED
		jmp	.Exit

.ChkSigWait:	cmp	eax,DISPATCH_BLOCK_SIGWAIT
		jne	.Invalid
		xor	eax,eax
.Exit:		epilogue
		ret

.Invalid:	mSetErrno EINVAL, eax
		xor	eax,eax
		jmp	.Exit

.NoMemory:	mSetErrno ENOMEM, eax
		xor	eax,eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; void dispatch_context_free(dispatch_context_t *ctp);
proc _dispatch_context_free
		jmp	_free
endp		;---------------------------------------------------------------


		; DISP_AllocDesc - create a dispatch descriptor.
		; Input: EAX=channel id,
		;	 EDX=flags.
		; Output: CF=0 - OK, EAX=descriptor address;
		;	  CF=1 - error.
proc DISP_AllocDesc
		mpush	ebx,ecx,edi
		mov	ebx,eax
int 20h
		Ccall	_malloc, tDispatch_size
		test	eax,eax
		stc
		jz	.Exit

		cld
		mov	ecx,tDispatch_size
		mov	edi,eax
		push	eax
		xor	al,al
		rep	stosb
		pop	eax
		mov	[eax+tDispatch.ChID],ebx
		mov	[eax+tDispatch.Flags],edx
		clc
.Exit:		mpop	edi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; Attach the control structure to dispatch handle.
		; Input: EBX=dispatch handle address,
		;	 DL=attach type,
		;	 ESI=control structure address,
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc DISP_Attach
		push	ecx

		mov	al,[ebx+tDispatch.BlockType]
		or	al,al
		jnz	.ChkBlockType

		; If called first time, just initialize block type
		cmp	dl,DISPATCH_SELECT
		je	.Select2
		cmp	dl,DISPATCH_RESMGR
		je	.Resmgr2
		cmp	dl,DISPATCH_MESSAGE
		je	.Message2
		cmp	dl,DISPATCH_SIGWAIT
		je	.Sigwait2
		stc
		jmp	.Exit

.Sigwait2:	mov	dword [ebx+tDispatch.BlockType],DISPATCH_BLOCK_SIGWAIT
		jmp	.SigWait

.Select2:	or	dword [ebx+tDispatch.Flags],DISPATCH_FLAG_SELECT
		mov	byte [ebx+tDispatch.BlockType],DISPATCH_BLOCK_RECEIVE
		jmp	.Select

.Resmgr2:	or	dword [ebx+tDispatch.Flags],DISPATCH_FLAG_RESMGR
		mov	byte [ebx+tDispatch.BlockType],DISPATCH_BLOCK_RECEIVE
		jmp	.Resmgr

.Message2:	mov	byte [ebx+tDispatch.BlockType],DISPATCH_BLOCK_RECEIVE
		jmp	.Message

		; If block type is already set, do some checks
.ChkBlockType:	cmp	dl,DISPATCH_SELECT
		je	near .Select
		cmp	dl,DISPATCH_RESMGR
		je	.Resmgr1
		cmp	dl,DISPATCH_MESSAGE
		je	.Message1
		cmp	dl,DISPATCH_SIGWAIT
		je	.Sigwait1
		stc
		jmp	.Exit

.Sigwait1:	cmp	al,DISPATCH_BLOCK_RECEIVE
		je	near .Invalid
		mov	byte [ebx+tDispatch.BlockType],DISPATCH_BLOCK_SIGWAIT
		jmp	.SigWait

.Message1:	and	dword [ebx+tDispatch.Flags],~DISPATCH_FLAG_RESMGR
.Resmgr1:	test	dword [ebx+tDispatch.Flags],DISPATCH_FLAG_SELECT
		jnz	.1
		cmp	al,DISPATCH_BLOCK_SIGWAIT
		je	near .Invalid
		jmp	.1_1
.1:		and	dword [ebx+tDispatch.Flags],~DISPATCH_FLAG_SELECT
.1_1:		mov	byte [ebx+tDispatch.BlockType],DISPATCH_BLOCK_RECEIVE
		cmp	dl,DISPATCH_MESSAGE
		je	.Message

.Resmgr:	mov	[ebx+tDispatch.ResmgrCtrl],esi
		mov	ecx,[esi+tResMgrControl.ContextSize]
		mov	edx,[esi+tResMgrControl.MsgMaxSize]
		jmp	.CheckChID

.Message:	mov	[ebx+tDispatch.MessageCtrl],esi
		mov	ecx,[esi+tMessageControl.ContextSize]
		mov	edx,[esi+tMessageControl.MsgMaxSize]
		jmp	.CheckChID

.SigWait:	mov	[ebx+tDispatch.SigwaitCtrl],esi
		mov	ecx,[esi+tSigwaitControl.ContextSize]
		xor	edx,edx
		jmp	.CheckChID

.Select:	mov	[ebx+tDispatch.SelectCtrl],esi
		mov	ecx,[esi+tSelectControl.ContextSize]
		xor	edx,edx

		; Create a channel if necessary
.CheckChID:	cmp	byte [ebx+tDispatch.BlockType],DISPATCH_BLOCK_RECEIVE
		jne	.CountMax
		cmp	dword [ebx+tDispatch.ChID],-1
		jne	.CountMax
		mov	eax,CHF_UNBLOCK | CHF_DISCONNECT | CHF_COID_DISCONNECT
		Ccall	_ChannelCreate, eax
		test	eax,eax
		stc
		js	.Exit

		; Re-calculate the sizes and store in the handle
.CountMax:	cmp	[ebx+tDispatch.ContextSize],ecx
		jae	.CountMax1
		mov	[ebx+tDispatch.ContextSize],ecx
.CountMax1:	cmp	[ebx+tDispatch.MsgMaxSize],edx
		jae	.CountMax2
		mov	[ebx+tDispatch.MsgMaxSize],edx
.CountMax2:	mov	eax,[esi+tResMgrControl.NpartsMax]
		cmp	[ebx+tDispatch.NpartsMax],eax
		jae	.OK
		mov	[ebx+tDispatch.NpartsMax],eax

.OK:		xor	eax,eax
.Exit:		pop	ecx
		ret

.Invalid:	mov	eax,EINVAL
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Set the dispatch context size based on the attach type.
		; Input: EBX=dispatch handle address,
		;	 DL=attach type.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc DISP_SetContextSize
		mpush	ecx,edx

		xor	eax,eax
		cmp	dl,DISPATCH_SELECT
		je	.Select
		cmp	dl,DISPATCH_RESMGR
		je	.Resmgr
		cmp	dl,DISPATCH_MESSAGE
		je	.Message
		cmp	dl,DISPATCH_SIGWAIT
		jne	.Error

		mov	eax,[ebx+tDispatch.SigwaitCtrl]
		mov	ecx,[eax+tSigwaitControl.ContextSize]
		jmp	.1

.Select:	mov	eax,[ebx+tDispatch.SelectCtrl]
		mov	ecx,[eax+tSelectControl.ContextSize]
		jmp	.1

.Resmgr:	mov	eax,[ebx+tDispatch.ResmgrCtrl]
		mov	ecx,[eax+tResMgrControl.ContextSize]
		mov	eax,[eax+tResMgrControl.MsgMaxSize]
		jmp	.1

.Message:	mov	eax,[ebx+tDispatch.MessageCtrl]
		mov	ecx,[eax+tMessageControl.ContextSize]
		mov	eax,[eax+tMessageControl.MsgMaxSize]

.1:		mov	edx,[ebx+tDispatch.ContextSize]
		test	dword [ebx+tDispatch.Flags],DISPATCH_CONTEXT_ALLOCED
		jz	.Set
		cmp	ecx,edx
		ja	.Error
		cmp	eax,[ebx+tDispatch.MsgMaxSize]
		ja	.Error

.Set:		cmp	ecx,edx
		jae	.2
		mov	ecx,edx
.2:		mov	[ebx+tDispatch.ContextSize],ecx
		mov	edx,[ebx+tDispatch.MsgMaxSize]
		cmp	eax,edx
		jae	.3
		mov	eax,edx
.3:		mov	[ebx+tDispatch.MsgMaxSize],eax
		xor	eax,eax

.Exit:		mpop	edx,ecx
		ret

.Error:		stc
		jmp	.Exit
endp		;---------------------------------------------------------------
