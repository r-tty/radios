;------------------------------------------------------------------------------
; rmhelper.nasm - resource manager helper functions.
;------------------------------------------------------------------------------

module librm.resmgr

%include "rm/resmgr.ah"
%include "rm/iomsg.ah"
%include "rm/dispatch.ah"
%include "disppriv.ah"

exportproc RM_AttachName, RM_HandleMsg
exportproc RM_AllocDesc, RM_FreeDesc
exportproc RM_AllocContext, RM_FreeContext
exportproc RM_WaitMsg, RM_Unblock, RM_Timeout

library $libc
importproc _malloc, _memset

section .text

		; int resmgr_attach(dispatch_t *dpp, resmgr_attr_t *attr,
		;		const char *path, enum _file_type file_type,
		;		uint flags, const resmgr_connect_funcs_t *connect_funcs,
		;		const resmgr_io_funcs_t *io_funcs, void *handle);
proc RM_AttachName
		ret
endp		;---------------------------------------------------------------


		; dispatch_t *dispatch_create(void);
proc RM_AllocDesc
		Ccall	_malloc, tDispatch_size
		test	eax,eax
		jz	.Exit
		mov	ebx,eax
		Ccall	_memset, ebx, 0, tDispatch_size
		mov	dword [ebx+tDispatch.ChID],-1
		mov	dword [ebx+tDispatch.Flags],0
		mov	eax,ebx
.Exit:		ret
endp		;---------------------------------------------------------------


proc RM_FreeDesc
		ret
endp		;---------------------------------------------------------------


proc RM_AllocContext
		ret
endp		;---------------------------------------------------------------


proc RM_FreeContext
		ret
endp		;---------------------------------------------------------------


proc RM_WaitMsg
		ret
endp		;---------------------------------------------------------------


proc RM_Unblock
		ret
endp		;---------------------------------------------------------------


proc RM_HandleMsg
		ret
endp		;---------------------------------------------------------------


proc RM_Timeout
		ret
endp		;---------------------------------------------------------------