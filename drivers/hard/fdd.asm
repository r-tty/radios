;-------------------------------------------------------------------------------
;  fdd.asm - Floppy disk controller (8272) control module.
;-------------------------------------------------------------------------------

		public DrvFDD

                ; DrvFDD - FDD device driver entry.
		; Action: calls FDD function number EAX.
proc DrvFDD near
		ret
endp		;---------------------------------------------------------------
