;------------------------------------------------------------------------------
; dispatch.nasm - dispatching routines.
;------------------------------------------------------------------------------

module librm.dispatch

library $libc
importproc _ChannelCreate, _ChannelDestroy
importproc _malloc, _free

%include "errors.ah"
%include "rm/dispatch.ah"
%include "private.ah"

exportproc _dispatch_create, _dispatch_destroy
publicproc DISP_Attach

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
		mov	eax,[eax+tDispatch.ChID],
		test	eax,eax
		js	.FreeDesc
		Ccall	_ChannelDestroy, eax
.FreeDesc:	Ccall	_free, dword [%$dpp]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; DISP_AllocDesc - create a dispatch descriptor.
		; Input: EAX=channel id,
		;	 EDX=flags.
		; Output: CF=0 - OK, EAX=descriptor address;
		;	  CF=1 - error.
proc DISP_AllocDesc
		mpush	ebx,ecx,edi
		mov	ebx,eax
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
		je	.Select
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
		mov	ecx,[esi+tResmgrControl.ContextSize]
		mov	edx,[esi+tResmgrControl.MsgMaxSize]
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
.CountMax2:	mov	eax,[esi+tResmgrControl.NpartsMax]
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
