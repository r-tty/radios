;*******************************************************************************
;  sbpro.asm - SB-Pro compatible audio card control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Publics ---

		public DrvAudio


                ; DrvAudio - audio device driver.
		; Action: calls audio function number EAX.
proc DrvAudio near
		ret
endp		;---------------------------------------------------------------
