;-------------------------------------------------------------------------------
; event.nasm - event delivery functions.
;-------------------------------------------------------------------------------

module kernel.ipc.event

%include "sys.ah"
%include "errors.ah"

publicproc sys_MsgDeliverEvent, sys_MsgVerifyEvent

section .text

		; int MsgDeliverEvent(int rcvid, const struct sigevent* event);
proc sys_MsgDeliverEvent
		arg	rcvid, event
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int MsgVerifyEvent(int rcvid, const struct sigevent *event);
proc sys_MsgVerifyEvent
		arg	rcvid, event
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
