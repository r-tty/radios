;-------------------------------------------------------------------------------
; event.nasm - event delivery functions.
;-------------------------------------------------------------------------------

module kernel.ipc.event

%include "sys.ah"
%include "errors.ah"

publicproc sys_MsgDeliverEvent, sys_MsgVerifyEvent

section .text

proc sys_MsgDeliverEvent
		ret
endp		;---------------------------------------------------------------


proc sys_MsgVerifyEvent
		ret
endp		;---------------------------------------------------------------
