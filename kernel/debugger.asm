;*******************************************************************************
;  debugger.asm - RadiOS internal debugger.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Definitions ---
DBG_StackSz		EQU	1000h			; Debugger stack size


; --- Variables ---

; --- Procedures ---

		; DebugEntry - debugger entry point.
		; Action: clears console 7 and call debugger.
proc DebugEntry near
		ret
endp		;---------------------------------------------------------------

