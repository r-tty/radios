;*******************************************************************************
;  event.as - RadiOS IPC "events" primitives.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

module kernel.ipc.event

%include "sys.ah"
%include "errors.ah"


; --- Exports ---
global K_HandleEvent


; --- Imports ---
extern KernelEventHandler:near
extern SysReboot:near

; --- Code ---
section .text

		; K_HandleEvent - immediate event handling.
		; Input: EDX=PID,
		;	 EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - return.
proc K_HandleEvent
	;XXX
	jmp SysReboot
		or	edx,edx				; Kernel process?
		jz	short .Kernel
		
.Kernel:	xchg	eax,edx
		call	KernelEventHandler

.Exit		ret
endp		;---------------------------------------------------------------
