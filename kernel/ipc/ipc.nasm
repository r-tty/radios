;-------------------------------------------------------------------------------
; ipc.nasm - IPC initialization.
;-------------------------------------------------------------------------------

module kernel.ipc

%include "parameters.ah"

publicproc IPC_Init

extern IPC_MsgInit, IPC_ChanInit

section .text

		; IPC_Init - IPC initialization.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IPC_Init
		mov	eax,MAXCHANNELS
		call	IPC_ChanInit
		jc	.Exit
		call	IPC_MsgInit
.Exit:		ret
endp		;---------------------------------------------------------------
