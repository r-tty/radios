;*******************************************************************************
;  msg.as - RadiOS IPC "message" primitives.
;  Copyright (c) 2000 RET & COM Research.
;  This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.ipc.msg

%include "sys.ah"
%include "errors.ah"
%include "sema.ah"
%include "pool.ah"
%include "msg.ah"


; --- Imports ---

library kernel.pool
extern K_PoolInit


; --- Data ---

section .data


; --- Variables ---

section .bss

?PortPool	RESB	tMasterPool_size
?MsgPool	RESB	tMasterPool_size


; --- Code ---

section .text

		; IPC_MsgInit - initialize messaging structures.
		; Input: none.
		; Output: none.
proc IPC_MsgInit
		mov	ebx,?PortPool
		mov	ecx,tIPCport_size
		call	K_PoolInit
		jc	short .Done
		mov	ebx,?MsgPool
		mov	ecx,tMessage_size
		call	K_PoolInit		
.Done:		ret
endp		;---------------------------------------------------------------

