;-------------------------------------------------------------------------------
; connect.nasm - ConnectControl and friends.
;-------------------------------------------------------------------------------

module libc.connect

%include "errors.ah"
%include "locstor.ah"
%include "rm/iomsg.ah"
%include "rm/fcntl.ah"
%include "connect.ah"

publicproc ConnectEntry, ConnectControl, Vopen

externproc _memset
externproc _MsgSendv, _MsgSendvnc


section .text

		; int ConnectIO(struct _connect_ctrl const *ctrl, int fd,
		;		const char *prefix, uint prefix_len,
		;		const char *path, void *buffer,
		;		const struct _io_connect_entry *entry);
proc ConnectIO
		arg	ctrl, fd, prefix, prefixlen, path, buffer, entry
		locauto	siov, 5*tIOV_size
		locauto	riov, 2*tIOV_size
		locals	retval, tryagain
		prologue
		savereg	ebx,edx

; register struct _io_connect *msg = ctrl->msg;
; register struct _io_connect_link_reply *reply = &(ctrl->reply->link);
; iov_t siov[5], riov[2];
; register unsigned sparts;
; static const char FIXCONST padding[_QNX_MSG_ALIGN - 1];
; int ret, tryagain;
; struct _io_connect_entry *ent = ctrl->entry;

		mov	edi,[%$ctrl]
		mov	ebx,[edi+tConnectCtrl.Msg]
		lea	edx,[edi+tConnectCtrl.Link]

;   SETIOV (siov + 0, msg, offsetof (struct _io_connect, path));
;
;    if (prefix_len) {
;	SETIOV (siov + 1, prefix, prefix_len);
;	sparts = 2;
;    } else {
;	sparts = 1;
;    }
;    SETIOV (siov + sparts, path, msg->path_len);
;    sparts++;
;    msg->path_len += prefix_len;
;    if (msg->extra_len) {
;	int align;
;
;	if (align =
;	    (_QNX_MSG_ALIGN -
;	     (offsetof (struct _io_connect, path) +
;	      msg->path_len)) & (_QNX_MSG_ALIGN - 1)) {
;	    SETIOV (siov + sparts, padding, align);
;	    sparts++;
;	}
;	SETIOV (siov + sparts, ctrl->extra, msg->extra_len);
;	sparts++;
;   }
;    SETIOV (riov + 0, reply, sizeof *reply);
;    SETIOV (riov + 1, buffer, msg->reply_max - sizeof *reply);

		; If our entries don't match, then try and resolve it to a link
		; to find a match by sending an COMBINE_CLOSE message to the
		; handler to see if it will resolve into a bigger link.
		; If we do find a match (later on as we recursed through the
		; entries in the process) then actually sent the message that
		; we originally were supposed to send. See rename() to see
		; how this is used.
		; This functionality is also used to resolve links "magically"
		; by switching the message type to be an open if the intial
		; request fails. This means that we don't have to fill proc
		; with all the resolution.

;   // We don't want to test the entries, or we have a matching entry ... send
;    // original message
;    if (!(ctrl->flags & FLAG_TEST_ENTRY)) {
;	ret = 1;
;    } else if (ent->pid == entry->pid &&
;	       ent->chid == entry->chid &&
;	       ND_NODE_CMP (ent->nd, entry->nd) == 0 &&
;	       ((ctrl->flags & FLAG_TEST_NPC_ONLY)
;		|| ent->handle == entry->handle)) {
;	ret = 1;
;   } else {
;	ret = 0;
;    }

;    if (ret
;	&& (!(ctrl->flags & FLAG_TEST_ND_ONLY)
;	    || ND_NODE_CMP (ctrl->nd, entry->nd) == 0)) {
;	if ((ret = ctrl->send (fd, siov, sparts, riov, 2)) != -1
;	    || (ctrl->flags & FLAG_TEST_ENTRY)) {
;	    return ret;
;	}
;    }
;    // We only try to resolve a link reply if we didn't send in the first place 
;    // or if
;    // the request went out and returned with ENOSYS indicating no callout.
;    if (ctrl->flags & FLAG_NO_RETRY) {
;	tryagain = 0;
;    } else {
;	tryagain = ((ret != -1) || (errno == ENOSYS));
;	switch (msg->subtype) {
;	    case _IO_CONNECT_OPEN:
;	    case _IO_CONNECT_COMBINE:
;	    case _IO_CONNECT_COMBINE_CLOSE:
;		break;
;
;		/* 
;		   These have specific resmgr helpers, that return specific
;		   errno's in the case of failure. */
;	    case _IO_CONNECT_LINK:
;		tryagain |= (errno == ENXIO) ? 1 : 0;
;		break;
;	}
;    }
;
;    // If we failed (or we didn't have a matching entry) stuff a msg to resolve 
;    // possible links
;    if (tryagain) {
;	int saved_errno, saved_ioflag, saved_type, saved_etype, saved_elen;
;
;	saved_ioflag = msg->ioflag;
;	saved_type = msg->subtype;
;	saved_etype = msg->extra_type;
;	saved_elen = msg->extra_len;

;	msg->ioflag = 0;
;	msg->extra_len = 0;
;	msg->extra_type = _IO_CONNECT_EXTRA_NONE;
;	msg->subtype = _IO_CONNECT_COMBINE_CLOSE;

;	saved_errno = errno;	// Meaningless errno for matching entry
;	ret = ctrl->send (fd, siov, sparts, riov, 2);
;	if (ret == -1) {
;	    errno = (ctrl->flags & FLAG_TEST_ENTRY) ? ENXIO : saved_errno;
;	}

;	msg->subtype = saved_type;
;	msg->extra_type = saved_etype;
;	msg->extra_len = saved_elen;
;	msg->ioflag = saved_ioflag;

;	// If we return anything other than a link here, it is an error 
;	// What to do if we return 0? For now I avoid the issue and return.
;	if ((ret != -1) &&
;	    (ret & (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_TYPE_MASK)) !=
;	    (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_LINK)) {
;	    errno = ENXIO;
;	    ret = -1;
;	}
;    } else {
;	errno = (errno == EOK) ? ENOENT : errno;
;	ret = -1;
;    }
;    return ret;

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectEntry(int base, const char *path, mode_t mode,
		;		uint oflag, uint sflag, uint subtype,
		;		int testcancel, uint access, uint file_type,
		;		uint extra_type, uint extra_len,
		;		const void *extra, uint response_len,
		;		void *response, int *status,
		;		struct _io_connect_entry *entry, int enoretry);
proc ConnectEntry
		arg	base, path, mode, oflag, sflag, subtype, testcancel
		arg	access, filetype, extratype, extralen, extra
		arg	resplen, response, status, entry, enoretry
		locauto	ctrl, tConnectCtrl_size
		locauto	msg, tIOMconnect_size
		locals	fd
		prologue

		lea	edi,[%$ctrl]
		Ccall	_memset, edi, dword 0, tConnectCtrl_size
		mov	eax,[%$base]
		mov	[edi+tConnectCtrl.Base],eax
		mov	eax,[%$extra]
		mov	[edi+tConnectCtrl.Extra],eax
		cmp	dword [%$testcancel],0
		jz	.Sendvnc
		mov	dword [edi+tConnectCtrl.SendFunc],_MsgSendv
		jmp	.1
.Sendvnc:	mov	dword [edi+tConnectCtrl.SendFunc],_MsgSendvnc
.1:		lea	ebx,[%$msg]
		mov	[edi+tConnectCtrl.Msg],ebx
		mov	eax,[%$entry]
		cmp	[edi+tConnectCtrl.Entry],eax
		jne	.3
		mov	eax,FLAG_TEST_ENTRY
		cmp	dword [%$enoretry],0
		jz	.2
		or	eax,FLAG_NO_RETRY
.2:		or	[edi+tConnectCtrl.Flags],eax

.3:		Ccall	_memset, ebx, 0, tIOMconnect_size
		mov	eax,[%$subtype]
		mov	[ebx+tIOMconnect.Subtype],eax
		mov	eax,[%$sflag]
		mov	[ebx+tIOMconnect.Sflag],eax
		mov	eax,[%$oflag]
		mov	[ebx+tIOMconnect.IOflag],eax
		mov	eax,[%$mode]
		mov	[ebx+tIOMconnect.Mode],eax
		mov	eax,[%$filetype]
		mov	[ebx+tIOMconnect.FileType],eax
		mov	eax,[%$access]
		mov	[ebx+tIOMconnect.Access],eax
		mov	eax,[%$extratype]
		mov	[ebx+tIOMconnect.ExtraType],eax
		mov	eax,[%$extralen]
		mov	[ebx+tIOMconnect.ExtraLen],eax

		Ccall	ConnectControl, edi, dword [%$path], \
			dword [%$resplen], dword [%$response]
		mov	edx, [%$status]
		or	edx,edx
		jz	.Exit
		mov	ebx,[edi+tConnectCtrl.Status]
		mov	[edx],ebx

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectRequest (struct _connect_ctrl *ctrl,
		;		const char *prefix, uint prefix_len,
		;		const char *path, uint path_skip,
		;		const struct _io_connect_entry *entry,
		;		void *buffer, int chrootlen)
proc ConnectRequest
		arg	ctrl, pfx, pfxlen, path, pathskip, entry, buffer, chrootlen
		prologue
;    register struct _io_connect *msg = ctrl->msg;
;    register struct _io_connect_link_reply *reply = &(ctrl->reply->link);
;    register int fd;
;    int ftype;

;    if ((fd =
;	 ConnectAttach (entry->nd, entry->pid, entry->chid, ctrl->base,
;			_NTO_COF_CLOEXEC)) != -1) {
;	msg->handle = entry->handle;
;	msg->eflag = reply->eflag;
;
	; Get the status of the node in question along with all of the node
	; entries associated with it
;	if ((ctrl->status =
;	     _connect_io (ctrl, fd, prefix, prefix_len, path + path_skip,
;			  buffer, entry)) == -1) {
;	    ConnectDetach_r (fd);
;	    return (-1);
;	}
	; Do we want any particular type of server connections, otherwise use
	; what we got
;	ftype = msg->file_type;
;	if (ctrl->status & _IO_CONNECT_RET_FLAG) {
;	    if ((ftype == _FTYPE_ANY) &&
;		(ctrl->status & _IO_CONNECT_RET_TYPE_MASK) ==
;		_IO_CONNECT_RET_FTYPE) {
;		ftype = msg->file_type = ctrl->reply->ftype.file_type;
;		ctrl->nd = entry->nd;
;		ctrl->flags |= FLAG_TEST_ND_ONLY;
;	    }
;	}

	 
	;  If a link was returned it means that there are other managers out
	;  there that might handle use.  We can cycle through each of the node
	;  entries querying them to see if they can do what we need them to do */
;	if ((ctrl->
;	     status & (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_TYPE_MASK)) ==
;	    (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_LINK)) {

;	    ConnectDetach_r (fd);

	; Nuke the chroot_len reply field if that flag not set
;	    if (!(ctrl->status & _IO_CONNECT_RET_CHROOT)) {
;		reply->chroot_len = 0;
;	    }
	; Check the mode flag against our umask
;	    if (entry->pid == PATHMGR_PID && entry->chid == PATHMGR_CHID
;		&& !prefix) {
;		if (ctrl->status & _IO_CONNECT_RET_UMASK) {
;		    msg->mode &= ~(reply->umask & ~S_IFMT);
;		}
;		if (ctrl->status & _IO_CONNECT_RET_NOCTTY) {
;		    ctrl->flags |= FLAG_NOCTTY;
;		}
;	    }

;	    if (msg->entry_max == 0) {
;		errno = ELOOP;
;		return -1;
;	    }
;	    if (reply->nentries * sizeof (*entry) + reply->path_len >=
;		msg->reply_max) {
;		errno = ENAMETOOLONG;
;		return -1;
;	    }
	; If we have multiple entries for this node, then look at each
	; entry/object/connection in turn to see if that connection can
	; give us the services we desire
;	    if (reply->nentries) {
;		char *save;
;		void *buff;
;		unsigned path_len;
;		uint8_t cnt, num;	/* 256 entries returned max */

;		path_len = reply->path_len;
;		cnt = num = reply->nentries;
;		chrootlen += reply->chroot_len;

;		buff = ((struct _io_connect_entry *) buffer + num);
;		if (path_skip > 1 && path[path_skip - 1] == '/') {
;		    path_skip--;
;		}
;		if (!(save = CTRL_ALLOC (ctrl->flags, path_len + path_skip))) {
;		    errno = ENOMEM;
;		    return -1;
;		}
;		memcpy (save, path, path_skip);
;		memcpy (save + path_skip, buff, path_len);

;		if (ctrl->flags & FLAG_REUSE_BUFFER) {
;		    msg->reply_max -= num * sizeof *entry;
;		    entry = buffer;
;		} else {
;		    if (!
;			(entry =
;			 CTRL_ALLOC (ctrl->flags, num * sizeof (*entry)))) {
;			CTRL_FREE (ctrl->flags, save);
;			errno = ENOMEM;
;			return -1;
;		    }
;		    memcpy ((void *) entry, buffer, num * sizeof (*entry));
;		    buff = buffer;
;		}

;		msg->entry_max--;
;		for (; cnt > 0; entry++, cnt--) {
		    ; 
		    ;   If this is a FTYPE_ALL/FTYPE_MATCHED, skip this entry,
		    ;   this is here since you might return an FTYPE_MATCHED at 
		    ;   one of the earlier iterations.  A better solution would 
		    ;   be to switch on msg->file_type below rather than ftype, 
		    ;   then remove this test.
;		    if (msg->file_type == _FTYPE_ALL) {
;			continue;
;		    }
		    ; Check to see if this entry/manager provides the type of
		    ; service we want
;		    if ((msg->file_type == _FTYPE_ANY) ||
;			(entry->file_type == _FTYPE_ALL)
;			|| (msg->file_type == entry->file_type)) {
;			int pad_len;
;			int save_errno;
;			int marker;
;
;			save_errno = errno;
;			msg->path_len = path_len - entry->prefix_len;

			 
			;   We stuff the path piecewise whenever we have a skip
			;   component. In order to do this we shift the path
			;   insert point forward before we recurse and then
			;   move it back and stuff the path after we recurse. We 
			;   expect that the component that we are stuffing will
			;   always begin with a / and doesn't terminate with a
			;   slash.
;			pad_len = entry->prefix_len;
;			pad_len -=
;			    (save[path_skip + pad_len - 1] == '/') ? 1 : 0;
;			if (ctrl->flags & FLAG_NO_PREFIX
;			    || (ctrl->pathsize - ctrl->pathlen) < pad_len) {
;			    pad_len = 0;
;			}
;			ctrl->pathlen += pad_len;
;			marker = ctrl->pathlen;	// We might be able to remove
;						// the marker
;
;			fd = _connect_request (ctrl, 0, 0, save,
;					       entry->prefix_len + path_skip,
;					       entry, buff, chrootlen);
;
;			if (pad_len && marker == ctrl->pathlen) {
;			    ctrl->pathlen -= pad_len;
;			    if (fd != -1 && ctrl->path && ctrl->pathsize) {
;				memcpy (&ctrl->path[ctrl->pathlen],
;					&save[path_skip], pad_len);
;			    }
;			}
			; We want to continue cycling if we have an array, and 
			; we have space 
			; in the array to store fd's, otherwise we break out
			; and return the fd
;			if (fd != -1 && ctrl->fds) {
;			    continue;
;			}
			; We had an error, try it again with another manager
			; or exit if the 
			; manager says they handle us but want to return an
			; error (ie ejected cdrom)
;			if (fd == -1 && msg->file_type != _FTYPE_MATCHED) {
;			    switch (errno) {
;				default:
;				    if (errno < ENETDOWN
;					|| errno > EHOSTUNREACH) {
;					break;
;				    }
;				    /* FALL THROUGH: ipc/network software --
;				       operational errors */
;				case EROFS:
;				case ENOSYS:
;				case ENOENT:
;				case ENXIO:
;				    if (save_errno != EOK
;					&& save_errno != ENOSYS) {
;					errno = save_errno;
;				    }
;				    continue;
;			    }
;			}
;
;			break;
;		    }
;		}
;		msg->entry_max++;

;		if (ctrl->flags & FLAG_REUSE_BUFFER) {
;		    msg->reply_max += num * sizeof *entry;
;		} else {
;		    CTRL_FREE (ctrl->flags, (void *) entry);
;		}
;		CTRL_FREE (ctrl->flags, save);
;
		 
		;   Otherwise we are a link to somewhere, but there are no
		;   specific entries (ie managers) for us to query, but we have
		;   a new path (ie symlink) for us to query and traverse,
		;   looking for handlers.

		;   Proc always receives a request which is relative to the
		;   chroot and returns a path which is absolute.  We do the
		;   translation as required when a symlink is involved. */
;	    } else {
;		char *savedpath, *buff = buffer;
;		int hold_pathlen;
;		uint16_t preoffset, postoffset;
;
;		msg->path_len = reply->path_len;
;		hold_pathlen = ctrl->pathlen;
;		ctrl->pathlen = 0;

;		/* Don't bother with the path work if we only want real path */
;		if (ctrl->path && (ctrl->flags & FLAG_NO_SYM)) {
;		    savedpath = ctrl->path;
;		    ctrl->path = NULL;
;		} else {
;		    savedpath = NULL;
;		}

;		if (*buff == '/') {	/* Don't mess with absolute links */
;		    preoffset = path_skip;
;		    postoffset = 0;
;		} else if (chrootlen < path_skip) {	/* chroot fits under
;							   mount point */
;		    preoffset = chrootlen;
;		    postoffset = 0;
;		} else {	/* chroot over mount point */
;		    preoffset = path_skip;
;		    postoffset = chrootlen - path_skip;
;		}

;		fd = _connect_request (ctrl, path + preoffset,
;				       path_skip - preoffset, buff + postoffset,
;				       0, &_connect_proc_entry, buff, 0);
;
;		if (savedpath && fd != -1) {
;		    ctrl->path = savedpath;
;		    ctrl->pathlen = hold_pathlen;
;		    goto copy_path;
;		}
;	    }

;	    /* File was matched but a request to change the file type was made */
;	} else
;	    if ((ctrl->
;		 status & (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_TYPE_MASK)) ==
;		(_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_FTYPE)) {
;	    ConnectDetach_r (fd);
;	    // Only if the file type is matched do we change it. Does it
;	    // matter?
;	    if (ctrl->reply->ftype.file_type == _FTYPE_MATCHED) {
;		msg->file_type = ctrl->reply->ftype.file_type;
;	    }
;	    errno = ctrl->reply->ftype.status;
;	    errno = (errno == EOK) ? ENOSYS : errno;
;	    fd = -1;
;
;	    // We have connected to the server, and the server returned some
;	    // stuff for us to re-send
;	} else if ((ctrl->status & (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_MSG))
;		   == (_IO_CONNECT_RET_FLAG | _IO_CONNECT_RET_MSG)) {
;
;	    msg->file_type = _FTYPE_MATCHED;
;	    ConnectDetach_r (fd);
;	    if ((msg->subtype == _IO_CONNECT_OPEN &&
;		 msg->extra_len == 0) ||
;		((msg->subtype == _IO_CONNECT_COMBINE ||
;		  msg->subtype == _IO_CONNECT_COMBINE_CLOSE) &&
;		 reply->path_len)) {
;		register struct _server_info *info = buffer;
;
;		if ((fd =
;		     ConnectAttach (info->nd, info->pid, info->chid, ctrl->base,
;				    _NTO_COF_CLOEXEC)) != -1) {
;		    if (reply->path_len) {
;			register struct _io_combine *next = (void *) (info + 1);
;			iov_t siov[2], riov[2];
;			int sparts = 1;
;
;			SETIOV (siov + 0, next, reply->path_len);
;			if (msg->extra_len) {
;			    next->combine_len |= _IO_COMBINE_FLAG;
;			    SETIOV (siov + 1, ctrl->extra, msg->extra_len);
;			    sparts++;
;			}
;			SETIOV (riov + 0, reply, sizeof *reply);
;			SETIOV (riov + 1, buffer,
;				msg->reply_max - sizeof *reply);
;			if ((ctrl->status =
;			     ctrl->send (fd, siov, sparts, riov, 2)) == -1
;			    || msg->subtype == _IO_CONNECT_COMBINE_CLOSE) {
;			    io_close_t msg;
;			    int save_errno;
;
;			    msg.i.type = _IO_CLOSE;
;			    msg.i.combine_len = sizeof msg.i;
;			    SETIOV (siov + 0, &msg.i, sizeof msg.i);
;			    save_errno = errno;
;			    ctrl->send (fd, siov, 1, 0, 0);
;			    errno = save_errno;
;			    if (ctrl->status == -1) {
;				ConnectDetach_r (fd);
;				fd = -1;
;			    }
;			}
;		    }
;		}
;	    } else {
;		fd = -1;
;		errno = ENOTSUP;
;	    }

	    ; We didn't get any return message from the server, end of
	    ; recursion on this tree?
;	} else {
	    ; Stick the discovered fd into an array of fds, resizing if
	    ; required/allowed
;	    if (ctrl->fds) {
;		if (ctrl->fds_index >= ctrl->fds_len - 1) {
;		    int *tmp;
;
;		    // If we are not ok with resizing, or we run out of memory
;		    // ... error out
;		    if (!(ctrl->flags & FLAG_MALLOC_FDS) ||
;			!(tmp =
;			  realloc (ctrl->fds,
;				   (ctrl->fds_len +
;				    FD_BUF_INCREMENT) * sizeof (*ctrl->fds)))) {
;			errno = ENOMEM;
;			return (-1);
;		    }
;		    ctrl->fds = tmp;
;		    ctrl->fds_len += FD_BUF_INCREMENT;
;		}

;		ctrl->fds[ctrl->fds_index++] = fd;
;	    }
;	    // This only gets done once, if the message has extra data ... copy 
;	    // it over
;	    // We use memmove since there may be overlapping areas involved
;	    // here.
;	    if (ctrl->response_len) {
;		int b;
;
;		b = min (sizeof (*ctrl->reply), ctrl->response_len);
;		memmove (ctrl->response, ctrl->reply, b);
;		if (ctrl->response_len > b) {
;		    memmove (((char *) ctrl->response) + b, buffer,
;			     ctrl->response_len - b);
;		}
;
;		ctrl->response_len = 0;
;	    }
;
;	    if (ctrl->flags & FLAG_SET_ENTRY) {
;		*ctrl->entry = *entry;
;		ctrl->entry->prefix_len = prefix_len + path_skip;
;	    }
;
;	  copy_path:
;	    if (ctrl->path) {
;		char *insert;
;		int cplen;
;
;		cplen = strlen (path + path_skip) + 1;
;
;		// path[path_skip] != '\0' && !(ctrl->flags & FLAG_NO_PREFIX)
;		if (cplen != 1 && !(ctrl->flags & FLAG_NO_PREFIX)) {
;		    insert = &ctrl->path[ctrl->pathlen];
;		    cplen++;	// For the extra slash we insert 
;		} else {
;		    insert = NULL;	// Marker for below
;		}
;
;		if ((ctrl->pathsize - ctrl->pathlen) < cplen) {
;		    ctrl->path[0] = '\0';
;		    ctrl->pathsize = 0;	// Indicate that the path was too small
;		} else {
;		    if (insert) {
;			*insert++ = '/';
;			cplen--;
;		    } else {
;			insert = &ctrl->path[ctrl->pathlen];
;		    }
;
;		    memcpy (insert, path + path_skip, cplen);
;		}
;	    }
;	}
;    }
;   // We don't want to return -1 if we actually manage to cache other managers
;    return ((fd == -1 && ctrl->fds && ctrl->fds_index) ? ctrl->fds[0] : fd);
		epilogue
    		ret
endp		;---------------------------------------------------------------


		; int ConnectControl(struct connect_ctrl *ctrl, const char *path,
		;			uint response_len, void *response);
proc ConnectControl
		arg	ctrl, path, resplen, resp
		locals	serrno, sftype, sioflag, oflag, freebuf
		locauto	buffer, tIOMconnectEntry_size*SYMLOOP_MAX + PATH_MAX + 1
		prologue

		; If path is empty - just return
		mov	esi,[%$path]
		mov	al,[esi]
		or	al,al
		je	.InvPath

		mov	edi,[%$ctrl]
		mov	ebx,[edi+tConnectCtrl.Msg]

		; If we have a valid entry, do we want to test ourselves
		; against it?
		mov	edx,[ebx+tIOMconnect.FileType]
		cmp	edx,FTYPE_MATCHED
		jne	.SaveFtype
		mov	dword [ebx+tIOMconnect.FileType],FTYPE_ANY
		cmp	dword [edi+tConnectCtrl.Entry],0
		jne	.SaveFtype
		or	dword [edi+tConnectCtrl.Flags],FLAG_TEST_ENTRY

.SaveFtype:	mov	[%$sftype],edx
		mov	eax,[ebx+tIOMconnect.IOflag]
		mov	[%$sioflag],eax

.Loop:		mov	[ebx+tIOMconnect.FileType],edx
		mov	[ebx+tIOMconnect.IOflag],eax

		; This is where the first response will go from the client.
		; In the case of multiple fd's only the first reply is
		; permanently recorded, all others are ignored.
		
.Exit:		epilogue
		ret

.InvPath:	mSetErrno EINVAL, edx
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int Vopen(const char *path, int oflag, int sflag, va_list ap);
proc Vopen
		arg	path, oflag, sflag, ap
		prologue

		test	dword [%$oflag], O_CREAT
		jz	.1
		GetArg	%$ap, Dword
		and	eax,~ST_MODE_IFMT
.1:		Ccall	ConnectEntry, 0, dword [%$path], eax, dword [%$oflag], \
			dword [%$sflag], IOM_CONNECT_OPEN, 1, \
			IOM_FLAG_RD | IOM_FLAG_WR, 0, 0, 0, 0, 0, 0, 0, 0, 0
		epilogue
		ret
endp		;---------------------------------------------------------------
