;*******************************************************************************
;  process.asm - RadiOS process and threads management module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Publics ---


; --- Procedures ---

		; KSwitchTask - switch to next thread.
		; Input: none.
		; Output: none.
		; Note: called by timer interrupt handler.
proc KSwitchTask near
		ret
endp		;---------------------------------------------------------------


