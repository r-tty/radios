;------------------------------------------------------------------------------
; resmgr.nasm - resource manager functions.
;------------------------------------------------------------------------------

module librm.resmgr

%include "errors.ah"
%include "locstor.ah"
%include "rm/resmgr.ah"
%include "rm/iomsg.ah"
%include "rm/dispatch.ah"
%include "lib/defs.ah"
%include "private.ah"

exportproc _resmgr_attach, _resmgr_block, _resmgr_unblock, _resmgr_handler
exportproc _resmgr_context_alloc, _resmgr_context_free

importproc _malloc, _calloc, _free
importproc _pthread_mutex_init, _pthread_mutex_lock, _pthread_mutex_unlock
importproc _MsgReceive, _MsgRead_r, _MsgReplyv, _MsgError
importproc _pathmgr_link
externproc DISP_Attach, DISP_SetContextSize
externproc _message_attach
externproc _dispatch_context_alloc

MSG_MAX_SIZE	EQU	tIOMconnectLinkReply_size + \
			tIOMconnectEntry*SYMLOOP_MAX + PATH_MAX + 1

section .text

		; int resmgr_attach(dispatch_t *dpp, resmgr_attr_t *attr,
		;		const char *path, enum _file_type file_type,
		;		uint flags, const resmgr_connect_funcs_t *connect_funcs,
		;		const resmgr_io_funcs_t *io_funcs, void *handle);
proc _resmgr_attach
		arg	dpp, attr, path, ftype, flags, connf, iof, handle
		locauto	nullattr, tResMgrAttr_size
		locauto	msgattr, tMessageAttr_size
		prologue
		savereg	ebx,edx,ecx,esi,edi

		mov	edx,[%$attr]
		test	edx,edx
		jnz	.ChkCtrlFun
		lea	edi,[%$nullattr]
		mov	edx,edi
		mov	[%$attr],edx
		mov	ecx,tResMgrAttr_size
		xor	eax,eax
		cld
		rep	stosb

.ChkCtrlFun:	mov	ebx,[%$dpp]
		mov	esi,[ebx+tDispatch.ResmgrCtrl]
		test	esi,esi
		jnz	near .CtrlAllocated

		; Initialize resmgr control structure
		Ccall	_calloc, byte 1, tResMgrControl_size
		test	eax,eax
		jz	near .NoMem
		mov	esi,eax
		lea	edi,[%$msgattr]
		xor	eax,eax
		mov	ecx,tMessageAttr_size
		rep	stosb

		xor	ecx,ecx
		inc	cl
		mov	eax,[edx+tResMgrAttr.NpartsMax]
		cmp	eax,ecx
		jae	.1
		mov	eax,ecx
.1:		mov	[esi+tResMgrControl.NpartsMax],eax

	%if MSG_MAX_SIZE > tIOMunion_size
		mov	ecx,MSG_MAX_SIZE
	%else
		mov	ecx,tIOMunion_size
	%endif
		mov	eax,[edx+tResMgrAttr.MsgMaxSize]
		cmp	ecx,eax
		jae	.2
		mov	ecx,eax
.2:		mov	[esi+tResMgrControl.MsgMaxSize],ecx

		mov	eax,[edx+tResMgrAttr.NpartsMax]
		shl	eax,3				; log2(tIOV_size)
		add	eax,tResMgrContext_size
		add	eax,ecx
		mov	[esi+tResMgrControl.ContextSize],eax

		mov	ebx,[%$dpp]
		mov	dl,DISPATCH_RESMGR
		call	DISP_Attach
		jnc	.AttachMsg
		Ccall	_free, esi
		jmp	.Failed

		; Attach message types
.AttachMsg:	lea	edi,[%$msgattr]
		mov	dword [edi+tMessageAttr.Flags],MSG_FLAG_TYPE_RESMGR
		Ccall	_message_attach, ebx, edi, IOMSG_BASE, IOMSG_MAX, \
			RM_MsgHandler, byte 0
		test	eax,eax
		js	near .Exit

		; Attach pulse types
		or	dword [edi+tMessageAttr.Flags],MSG_FLAG_TYPE_PULSE
		mov	eax,PULSE_CODE_DISCONNECT
		Ccall	_message_attach, ebx, edi, eax, eax, byte 0
		test	eax,eax
		js	near .Exit
		mov	eax,PULSE_CODE_UNBLOCK
		Ccall	_message_attach, ebx, edi, eax, eax, byte 0
		test	eax,eax
		js	near .Exit
		lea	eax,[esi+tResMgrControl.Mutex]
		Ccall	_pthread_mutex_init, eax, byte 0
		jmp	.DoAttach

		; Control structure is already allocated
.CtrlAllocated:	mov	edi,[edx+tResMgrAttr.NpartsMax]
		mov	eax,[esi+tResMgrControl.NpartsMax]
		cmp	edi,eax
		jae	.3
		mov	edi,eax
.3:		lea	ecx,[eax*tIOV_size+tResMgrContext_size]
		mov	eax,[esi+tResMgrControl.MsgMaxSize]
		add	ecx,eax
		push	eax
		mov	edx,[edx+tResMgrAttr.MsgMaxSize]
	%if MSG_MAX_SIZE > tIOMunion_size
		mov	eax,MSG_MAX_SIZE
	%else
		mov	eax,tIOMunion_size
	%endif
		cmp	edx,eax
		jae	.4
		mov	edx,eax
.4:		pop	eax
		cmp	edx,eax
		jae	.5
		mov	edx,eax

.5:		test	dword [ebx+tDispatch.Flags],DISPATCH_CONTEXT_ALLOCED
		jz	.Fill
		cmp	ecx,[esi+tResMgrControl.ContextSize]
		ja	near .Invalid
		cmp	edx,[esi+tResMgrControl.MsgMaxSize]
		ja	near .Invalid

.Fill:		mov	[esi+tResMgrControl.NpartsMax],edi
		mov	[esi+tResMgrControl.ContextSize],ecx
		mov	[esi+tResMgrControl.MsgMaxSize],edx

		mov	dl,DISPATCH_RESMGR
		call	DISP_SetContextSize
		jc	near .Invalid

		; NULL path is allowed to set up the internals
.DoAttach:	mov	edx,[%$attr]
		mov	eax,[%$path]
		or	eax,eax
		jnz	.LinkAlloc
		test	dword [edx+tResMgrAttr.Flags],RESMGR_FLAG_ATTACH_LOCAL
		jnz	.LinkAlloc
		test	dword [%$flags],RESMGR_FLAG_FTYPEONLY
		jnz	near .Exit

.LinkAlloc:	call	RM_LinkAlloc
		jc	near .NoMem
		mov	eax,[edx+tResMgrAttr.Flags]
		or	eax,eax
		jz	.PrepareLink
		cmp	dword [esi+tResMgrControl.OtherFunc],0
		jz	.PrepareLink
		or	dword [edi+tRMlink.Flags],RESMGR_LINK_OTHERFUNC
		mov	[esi+tResMgrControl.OtherFunc],eax
		mov	[ebx+tDispatch.OtherFunc],eax

.PrepareLink:	Mov32	edi+tRMlink.ConnectFuncs,%$connf
		Mov32	edi+tRMlink.IOfuncs,%$iof
		Mov32	edi+tRMlink.Handle,%$handle
		test	dword [edx+tResMgrAttr],RESMGR_FLAG_ATTACH_LOCAL
		jz	.NotLocal
		xor	eax,eax
		not	eax
		mov	[edi+tRMlink.LinkId],eax
		jmp	.DoneOK

.NotLocal:	mov	eax,[%$flags]
		and	eax,RESMGR_FLAG_MASK
		Ccall	_pathmgr_link, dword [%$path], byte 0, byte 0, \
			dword [ebx+tDispatch.ChID], dword [edi+tRMlink.Id], \
			dword [%$ftype], eax
		test	eax,eax
		jns	.DoneOK
		test	dword [edi+tRMlink.Flags],RESMGR_LINK_OTHERFUNC
		jz	.FreeLink
		xor	eax,eax
		mov	[ebx+tDispatch.OtherFunc],eax
.FreeLink:	mov	eax,RESMGR_DETACH_ALL
		call	RM_LinkFree
		xor	eax,eax
		dec	eax
		jmp	.Exit

.DoneOK:	and	dword [edi+tRMlink.Flags],~RESMGR_LINK_HALFOPEN

.Exit:		epilogue
		ret

.NoMem:		mSetErrno ENOMEM, eax
.Failed:	xor	eax,eax
		dec	eax
		jmp	.Exit

.Invalid:	mSetErrno EINVAL, eax
		jmp	.Failed
endp		;---------------------------------------------------------------


		; resmgr_context_t *resmgr_context_alloc(dispatch_t *dpp);
proc _resmgr_context_alloc
		jmp	_dispatch_context_alloc
endp		;---------------------------------------------------------------


		; void resmgr_context_free(resmgr_context_t *ctp);
proc _resmgr_context_free
		jmp	_free
endp		;---------------------------------------------------------------


		; resmgr_context_t *resmgr_block(resmgr_context_t *ctp);
proc _resmgr_block
		arg	ctp
		prologue
		savereg	ebx,ecx,edx,esi,edi

		xor	eax,eax
		mov	ebx,[%$ctp]
		lea	esi,[ebx+tResMgrContext.Info]
		mov	[esi+tMsgInfo.MsgLen],eax
		not	eax
		mov	[ebx+tResMgrContext.Id],eax

.Again:		mov	edx,[ebx+tResMgrContext.DPP]
		mov	edi,[ebx+tResMgrContext.Msg]
		Ccall	_MsgReceive, dword [edx+tDispatch.ChID], edi, \
			dword [ebx+tResMgrContext.MsgMaxSize], esi
		mov	[ebx+tResMgrContext.RcvId],eax

		; While doing a network transaction the message may not be
		; sent completely, so get the rest
		test	eax,eax
		js	.OK
		mov	edx,eax
		mov	ecx,[esi+tMsgInfo.MsgLen]
		cmp	ecx,[esi+tMsgInfo.SrcMsgLen]
		jae	.OK
		mov	eax,[ebx+tResMgrContext.MsgMaxSize]
		cmp	ecx,eax
		jae	.OK
		add	edi,ecx
		sub	eax,ecx
		Ccall	_MsgRead_r, edx, edi, eax, ecx
		test	eax,eax
		jns	.GotRest
		neg	eax
		Ccall	_MsgError, edx, eax
		jmp	.Again

.GotRest:	add	[esi+tMsgInfo.MsgLen],eax
.OK:		mov	eax,ebx

		epilogue
		ret
endp		;---------------------------------------------------------------


		; void resmgr_handler(resmgr_context_t *ctp);
proc _resmgr_handler
		arg	ctp
		prologue
		savereg	ebx,edx,esi,edi

		mov	esi,[%$ctp]
		mov	edi,[esi+tResMgrContext.Msg]
		mov	ebx,[esi+tResMgrContext.DPP]
		xor	eax,eax
		mov	[esi+tResMgrContext.Status],eax
		mov	eax,RESMGR_DEFAULT
		mov	edx,[esi+tResMgrContext.RcvId]
		inc	edx
		jz	.ChkOtherFunc
		dec	edx
		jz	.Pulse

		; Check the message type
		mov	ax,[edi]
		push	.ChkOtherFunc
		cmp	ax,IOM_CONNECT
		je	near RM_ConnectHandler
		cmp	ax,IOM_DUP
		je	RM_DupHandler
		cmp	ax,IOM_MMAP
		je	RM_MmapHandler
		cmp	ax,IOM_OPENFD
		je	RM_OpenFDhandler
		add	esp,byte 4


		; Check the pulse code
.Pulse:		mov	eax,[edi+tPulse]
		cmp	ax,PULSE_TYPE
		jne	.ChkOtherFunc
		shr	eax,byte 16
		cmp	ax,PULSE_SUBTYPE
		jne	.ChkOtherFunc

		push	.ChkOtherFunc
		mov	ax,[edi+tPulse.Code]
		mov	edx,[edi+tPulse.SCoID]
		cmp	ax,PULSE_CODE_DISCONNECT
		je	RM_DisconnectHandler
		mov	edx,[edi+tPulse.SigValue]
		cmp	ax,PULSE_CODE_UNBLOCK
		je	RM_UnblockHandler
		add	esp,byte 4

.ChkOtherFunc:	cmp	eax,RESMGR_NOREPLY
		je	.Exit
		cmp	eax,RESMGR_DEFAULT
		jne	.ReplyOrErr

.ReplyOrErr:	test	eax,eax
		jle	.Reply
		Ccall	_MsgError, edx, eax
		jmp	.Exit
.Reply:		neg	eax
		lea	ebx,[esi+tResMgrContext.IOV]
		Ccall	_MsgReplyv, edx, dword [esi+tResMgrContext.Status], \
			ebx, eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; Input: none.
		; Output: CF=0 - OK, EDI=address of allocated structure;
		;	  CF=1 - error.
proc RM_LinkAlloc
		ret
endp		;---------------------------------------------------------------


		; Input: EDI=link structure address,
		;	 EAX=flags.
proc RM_LinkFree
		ret
endp		;---------------------------------------------------------------


proc RM_ConnectHandler
		ret
endp		;---------------------------------------------------------------


proc RM_DisconnectHandler
		ret
endp		;---------------------------------------------------------------


proc RM_DupHandler
		ret
endp		;---------------------------------------------------------------


proc RM_MmapHandler
		ret
endp		;---------------------------------------------------------------


proc RM_OpenFDhandler
		ret
endp		;---------------------------------------------------------------


proc RM_UnblockHandler
		ret
endp		;---------------------------------------------------------------

proc RM_MsgHandler
		ret
endp		;---------------------------------------------------------------
