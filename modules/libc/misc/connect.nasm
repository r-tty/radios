;-------------------------------------------------------------------------------
; connect.nasm - ConnectControl and friends.
;-------------------------------------------------------------------------------

module libc.connect

%include "rm/iomsg.ah"
%include "connect.ah"

publicproc ConnectControl

section .text

		; int ConnectControl(struct connect_ctrl *ctrl, const char *path,
		;			uint response_len, void *response);
proc ConnectControl
		arg	ctrl, path, resplen, resp
		locals	serrno, sftype, sioflag, oflag, freebuf
		locauto	buffer, tIOMconnectEntry_size*SYMLOOP_MAX + PATH_MAX + 1
		prologue

		; If path is empty - just return
		mov	esi,[$%path]
		mov	al,[esi]
		or	al,al
		je	.InvPath

		mov	eax,[%$ctrl]
		mov	ebx,[edx+tConnectCtrl.Msg]

		; If we have a valid entry, do we want to test ourselves
		; against it?
		mov	edx,[ebx+tIOMconnect.FileType]
		cmp	edx,FTYPE_MATCHED
		jne	.SaveFtype

.SaveFtype:	mov	[$%sftype],edx
		mov	eax,[ebx+tIOMconnect.IOflag]
		mov	[%$sioflag],eax
		
.Exit:		epilogue
		ret

.InvPath:	mSetErrno EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------



int _connect_ctrl(struct _connect_ctrl *ctrl, const char *path, unsigned response_len, void *response) {
	struct _io_connect	*msg = ctrl->msg;
	int			fd;
	int			save_errno;
	int			save_ftype, save_ioflag;
#define MIN_FILLER_SIZE (sizeof(struct _io_connect_entry) * SYMLOOP_MAX + PATH_MAX + 1)
	struct {
	  struct _io_connect_link_reply	reply;	
	  char				filler[MIN_FILLER_SIZE];
	} *buffer;
	int			oflag, freebuffer;

	if(*path == '\0') {
		errno = ENOENT;
		return -1;
	}

	/* If we have a valid entry, do we want to test ourselves against it? */
	if(msg->file_type == _FTYPE_MATCHED) {
		msg->file_type = _FTYPE_ANY;
		if(ctrl->entry) {
			ctrl->flags |= FLAG_TEST_ENTRY;
		}
	}
	save_ftype = msg->file_type;
	save_ioflag = msg->ioflag;

onemoretime:
	msg->file_type = save_ftype;
	msg->ioflag = save_ioflag;

	/* 
	 This is where the first response will go from the client. In the
	 case of multiple fd's only the first reply is permanently recorded, 
	 all others are ignored 
	*/
	response_len = (response) ? response_len : 0;
	ctrl->response_len = response_len;
	ctrl->response = response;

	/* TODO: Make the allocation, re-use and buffer sizes 
	         all user configurable somehow. */

	/* 
	 Decide which type of allocation policy we want to
	 use: malloc/free on the heap, alloc/xxx on the stack

	 If we think that we have space on the stack (guesstimate
	 32 symlinks with 32 servers with 1K path == 32 * 2K == 64K) 
	 then go with stack allocation?
	*/
	ctrl->flags |= FLAG_STACK_ALLOC;
	if(_connect_malloc && __stackavail() < MIN_STACK_FOR_GROWTH) {
		ctrl->flags &= ~FLAG_STACK_ALLOC;
	}

	/* 
	 Decide if we are going to re-use the allocated
	 buffer or if we are just going to allocate new
	 buffers as we go along.
	*/
	ctrl->flags |= FLAG_REUSE_BUFFER;
	
	/* 
	 We only need to allocate a copy if we are going to  be iterating
	 over multiple fds, otherwise just make response the same as the
	 reply buffer (unless the reply buffer won't hold our minimum size) 
	 This saves us from double allocating when we don't have to. 
	*/
	if (ctrl->fds || (ctrl->flags & FLAG_MALLOC_FDS) || response_len < sizeof(*buffer)) {
		freebuffer = 1;
		if (!(buffer = CTRL_ALLOC(ctrl->flags, max(response_len, sizeof(*buffer))))) {
			errno = ENOMEM;
			return(-1);
		}
	}
	else {
		freebuffer = 0;
		buffer = response;
	}
	ctrl->reply = (void*)buffer;
	msg->reply_max = max(response_len, sizeof(*buffer));

	ctrl->reply->link.eflag = 0;

	/*
	 Always send a connect message.  When we allow a user 
	 configurable buffer, set the entry_max accordingly.
	*/
	msg->type = _IO_CONNECT;
	msg->entry_max = SYMLOOP_MAX;
	msg->path_len = strlen(path) + 1;
	oflag = msg->ioflag;
	msg->ioflag = (oflag & ~(O_ACCMODE | O_CLOEXEC)) | ((oflag + 1) & msg->access & O_ACCMODE);

	save_errno = errno;
	errno = EOK;
	if((fd = _connect_request(ctrl, 0, 0, path, 0, &_connect_proc_entry, buffer->filler, 0)) != -1) {
		errno = save_errno;

		// If not close on exec, then turn off the close on exec bit
		if(!(ctrl->base & _NTO_SIDE_CHANNEL) && !(oflag & O_CLOEXEC)) {
			ConnectFlags_r(0, fd, FD_CLOEXEC, 0);
		}
		if((ctrl->flags & FLAG_NOCTTY) && !(oflag & O_NOCTTY) && isatty(fd)) {
			procmgr_session(ND_LOCAL_NODE, getpid(), fd, PROCMGR_SESSION_TCSETSID);
		}

		//Unfortunately path = "" is both a valid return (internally) but an 
		//error condition (externally) so we resort to munging the path here
		if (ctrl->pathsize > 1 && ctrl->path[0] == '\0') {
			ctrl->path[0] = '/';
			ctrl->path[1] = '\0';
		}
	} else if(save_ftype == _FTYPE_ANY && (errno == ENOSYS || errno == ENOENT) &&
	          msg->file_type != save_ftype && msg->file_type != _FTYPE_MATCHED) {
		/* If the filetype change, but we still failed, then try sending the
		   request again but with the new filetype.  This is for servers who
		   have mounted on top of filesystems using their services. */
		if (freebuffer) {
			CTRL_FREE(ctrl->flags, buffer);
		}
		save_ftype = msg->file_type;
		goto onemoretime;
	}

	if (freebuffer) {
		CTRL_FREE(ctrl->flags, buffer);
	}	
	return fd;
}
