;*******************************************************************************
;  ide.asm - IDE controller and drive control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

		public DrvHDD

                ; DrvHDD - HDD device driver entry.
		; Action: calls HDD function number EAX.
proc DrvHDD near
		ret
endp		;---------------------------------------------------------------
