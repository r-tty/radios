;*******************************************************************************
; pathman.nasm - head code of the path manager.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module tm.pathman

%include "errors.ah"
%include "parameters.ah"
%include "rm/iomsg.ah"

publicproc TM_InitPathman

externproc RD_Init, RFS_InitOCBpool

section .text

		; PTM_Init - initialize path manager.
		; Input:
		; Output:
proc TM_InitPathman
		call	RD_Init
		jc	.Exit
		mov	eax,MAXOCBS
		call	RFS_InitOCBpool
.Exit:		ret
endp		;---------------------------------------------------------------
