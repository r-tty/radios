;------------------------------------------------------------------------------
; resmgr.nasm - resource manager functions.
;------------------------------------------------------------------------------

module librm.resmgr

%include "rm/resmgr.ah"
%include "rm/iomsg.ah"
%include "rm/dispatch.ah"
%include "private.ah"

exportproc _resmgr_attach, _resmgr_block, _resmgr_unblock, _resmgr_handler
exportproc _resmgr_context_alloc, _resmgr_context_free

library $libc
importproc _malloc, _memset
importproc _MsgReceive, _MsgRead_r, _MsgError

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
		mov	ecx,tResMgrAttr_size
		xor	eax,eax
		cld
		rep	stosb

.ChkCtrlFun:	mov	ebx,[%$dpp]
		cmp	[ebx+tDispatch.ResmgrCtrl],eax
		jnz	.CtrlAllocated

		; Initialize resmgr control structure
		Ccall	_calloc, byte 1, tResMsgControl_size
		test	eax,eax
		jz	.NoMem
		mov	esi,eax
		lea	edi,[%$msgattr]
		xor	eax,eax
		mov	ecx,tMessageAttr_size
		rep	stosb
//-------------------------
	_resmgr_control 		*ctrl;
	resmgr_attr_t			null_attr;

	if(!attr) {
		memset(attr = &null_attr, 0, sizeof null_attr);
	}

	if(!_DPP(dpp)->resmgr_ctrl) {
		message_attr_t			msg_attr;

		if((ctrl = malloc(sizeof *ctrl)) == NULL) {
			errno = ENOMEM;
			return -1;
		}
		memset(ctrl, 0, sizeof *ctrl);
		memset(&msg_attr, 0, sizeof msg_attr);
//------------------------
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
		mov	eax,[edx+tResMsgAttr.MsgMaxSize]
		cmp	ecx,eax
		jae	.2
		mov	ecx,eax
.2:		mov	[esi+tResMgrControl.MsgMaxSize],ecx

		mov	eax,[edx+tResMgrAttr.NpartsMax]
		shl	eax,3				; log2(tIOV_size)
		add	eax,tResMsgContext_size
		add	eax,ecx
		mov	[esi+tResMgrControl.ContextSize],eax

		mov	ebx,[%$dpp]
		mov	dl,DISPATCH_RESMGR
		call	DISP_Attach
		jnc	.AttachMsg
		Ccall	_free, esi
		jmp	.Failed
//-----------------------
		ctrl->nparts_max = max(attr->nparts_max, 1);
		ctrl->msg_max_size = max(attr->msg_max_size, max(MSG_MAX_SIZE, sizeof(resmgr_iomsgs_t)));

		ctrl->context_size = sizeof(resmgr_context_t) +
		    attr->nparts_max * sizeof(((resmgr_context_t *)0)->iov[0]) +
		    ctrl->msg_max_size;

		if(_dispatch_attach(dpp, ctrl, DISPATCH_RESMGR) == -1) {
			free(ctrl);
			return -1;
		}
//------------------------
		; Attach message types
.AttachMsg:	lea	edi,[%$msgattr]
		mov	dword [edi+tMessageAttr.Flags],MSG_FLAG_TYPE_REMGR
		Ccall	_message_attach, ebx, edi, IOMSG_BASE, IOMSG_MAX, \
			RM_MsgHandler, byte 0
		test	eax,eax
		js	.Exit

		; Attach pulse types
		or	dword [edi+tMessageAttr.Flags],MSG_FLAG_TYPE_PULSE
		mov	eax,PULSE_CODE_DISCONNECT
		Ccall	_message_attach, ebx, edi, eax, eax, byte 0
		test	eax,eax
		js	.Exit
		mov	eax,PULSE_CODE_UNBLOCK
		Ccall	_message_attach, ebx, edi, eax, eax, byte 0
		test	eax,eax
		js	.Exit
		
		// Attach message type as well
		msg_attr.flags = MSG_FLAG_TYPE_RESMGR;
		if(message_attach(dpp, &msg_attr, _IO_BASE, _IO_MAX, _resmgr_msg_handler, (void *)NULL) == -1) {
			return -1;
		}

		msg_attr.flags |= MSG_FLAG_TYPE_PULSE | MSG_FLAG_CROSS_ENDIAN;

		// Attach resmgr pulse types.
		if(message_attach(dpp, &msg_attr, _PULSE_CODE_DISCONNECT, _PULSE_CODE_DISCONNECT, _resmgr_msg_handler, (void *)NULL) == -1) {
			return -1;
		}

		if(message_attach(dpp, &msg_attr, _PULSE_CODE_UNBLOCK, _PULSE_CODE_UNBLOCK, _resmgr_msg_handler, (void *)NULL) == -1) {
			return -1;
		}

		pthread_mutex_init(&ctrl->mutex, 0);

	} else {
//------------------------
.CtrlAllocated:	
		int		newsize, newcsize, newiov;

		ctrl = dpp->resmgr_ctrl;

		newiov = max(attr->nparts_max, ctrl->nparts_max);
		newsize = max(ctrl->msg_max_size, max(attr->msg_max_size, max(MSG_MAX_SIZE, sizeof(resmgr_iomsgs_t))));

		newcsize = sizeof(resmgr_context_t) + ctrl->nparts_max * sizeof(((resmgr_context_t *)0)->iov[0]) + ctrl->msg_max_size;

		if((dpp->flags & _DISPATCH_CONTEXT_ALLOCED) && (newcsize > ctrl->context_size || newsize > ctrl->msg_max_size)) {
			errno = EINVAL;
			return -1;
		} else {
			ctrl->nparts_max = newiov;
			ctrl->context_size = newcsize;
			ctrl->msg_max_size = newsize;
		}

		if(_dispatch_set_contextsize(dpp, DISPATCH_RESMGR) == -1) {
			errno = EINVAL;
			return -1;
		}
	}

	ctrl->flags = (attr->flags & RESMGR_FLAG_CROSS_ENDIAN) ? _RESMGR_CROSS_ENDIAN : 0;
//----------------------------------

		; NULL path is allowed to set up the internals
	if(path || (attr->flags & RESMGR_FLAG_ATTACH_LOCAL) || (flags & _RESMGR_FLAG_FTYPEONLY)) {
		struct link				*link;

		if(!(link = _resmgr_link_alloc())) {
			errno = ENOMEM;
			return -1;
		}

		if(attr->other_func && !ctrl->other_func) {
			link->flags |= _RESMGR_LINK_OTHERFUNC;
			ctrl->other_func = attr->other_func;
			_DPP(dpp)->other_func = (void *)attr->other_func;
		}

		link->connect_funcs = connect_funcs;
		link->io_funcs = io_funcs;
		link->handle = handle;
		if(attr->flags & RESMGR_FLAG_ATTACH_LOCAL) {
			link->link_id = -1;
		} else {
			if((link->link_id = pathmgr_link(path, 0, 0, _DPP(dpp)->chid, link->id, file_type, flags & _RESMGR_FLAG_MASK)) == -1) {
				if(link->flags & _RESMGR_LINK_OTHERFUNC) {
					dpp->other_func = NULL;
				}
				_resmgr_link_free(link->id, _RESMGR_DETACH_ALL);
				return -1;
			}
		}
		link->flags &= ~_RESMGR_LINK_HALFOPEN;
		return link->id;
	}
	return 0;
//-------------------------------
.Exit:		epilogue
		ret

.NoMem:		mSerErrno ENOMEM, eax
.Failed:	xor	eax,eax
		dec	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; resmgr_context_t *resmgr_context_alloc(dispatch_t *dpp);
proc _resmgr_context_alloc
		ret
endp		;---------------------------------------------------------------


		; void resmgr_context_free(resmgr_context_t *ctp);
proc _resmgr_context_free
		ret
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
		mov	edi,[ebx+tResMsgContext.Msg]
		Ccall	_MsgReceive, dword [edx+tDispatch.ChID], edi,
			dword [ebx+tResMsgContext.MsgMaxSize], esi
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


		; void _resmgr_handler(resmgr_context_t *ctp);
proc _resmgr_handler
		arg	ctp
		prologue
	int								n;
	resmgr_iomsgs_t					*msg;
	dispatch_t						*dpp;
	struct pulse_func				*p;
	
	msg = ctp->msg;
	dpp = ctp->dpp;
	n = _RESMGR_DEFAULT;
	ctp->status = 0;
	if(ctp->rcvid != -1) {
		if(ctp->rcvid == 0) {
			if(msg->type == _PULSE_TYPE && msg->pulse.subtype == _PULSE_SUBTYPE) {
				struct _pulse pulse;

				switch(msg->pulse.code) {
				case _PULSE_CODE_DISCONNECT:
					_resmgr_disconnect_handler(ctp, msg, msg->pulse.scoid);
					break;

				case _PULSE_CODE_UNBLOCK:
					pulse = msg->pulse;
					n = _resmgr_unblock_handler(ctp, msg, msg->pulse.value.sival_int);
					if(n == _RESMGR_DEFAULT) {
						msg->pulse = pulse;
						ctp->rcvid = 0;
						if(dpp->other_func) {
							n = dpp->other_func(ctp, msg);
						}
					}
					break;

				default:
					pthread_mutex_lock(&_resmgr_io_table.mutex);
					for(p = _resmgr_pulse_list; p; p = p->next) {
						if(p->code == msg->pulse.code) {
							pthread_mutex_unlock(&_resmgr_io_table.mutex);
							p->func(ctp, p->code, msg->pulse.value, p->handle);
							break;
						}
					}
					if(!p) {
						pthread_mutex_unlock(&_resmgr_io_table.mutex);
						if(dpp->other_func) {
							dpp->other_func(ctp, msg);
						}
					}
					break;
				}
				if(n == _RESMGR_DEFAULT) {
					return;
				}
			}
		} else {
			if(ctp->info.flags & _NTO_MI_ENDIAN_DIFF) {
				if(!(dpp->resmgr_ctrl->flags & _RESMGR_CROSS_ENDIAN)) {
					MsgError(ctp->rcvid, EENDIAN);
					return;
				}
				ENDIAN_SWAP16(&msg->type);
MsgError(ctp->rcvid, EENDIAN); return;		/* @@ Temp until endian supported in resmgr stuff */
			}
			switch(msg->type) {
			case _IO_CONNECT:
				n = _resmgr_connect_handler(ctp, msg);
				break;

			case _IO_DUP:
				n = _resmgr_dup_handler(ctp, msg);
				break;

			case _IO_MMAP:
				n = _resmgr_mmap_handler(ctp, msg);
				break;

			case _IO_OPENFD:
				n = _resmgr_openfd_handler(ctp, msg);
				break;

			default:
				if(msg->type >= _IO_BASE && msg->type <= _IO_MAX) {
					struct binding				*binding;

					if((binding = (struct binding *)_resmgr_handle(&ctp->info, 0, _RESMGR_HANDLE_FIND_LOCK)) == (void *)-1) {
						n = EBADF;
					} else {
						n = _resmgr_io_handler(ctp, msg, binding);
					}
				} else {
					n = _RESMGR_DEFAULT;
				}
				break;
			}
		}
	}

	if(n == _RESMGR_DEFAULT && dpp->other_func) {
		n = dpp->other_func(ctp, msg);
	}

	switch(n) {
	case _RESMGR_NOREPLY:
		break;

	case _RESMGR_DEFAULT:
		n = ENOSYS;
		/* Fall through */
	default:
		if(n <= 0) {
			MsgReplyv(ctp->rcvid, ctp->status, ctp->iov + 0, -n);
		} else {
			MsgError(ctp->rcvid,  n);
		}
	}
endp		;---------------------------------------------------------------
