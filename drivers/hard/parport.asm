;-------------------------------------------------------------------------------
;  parport.asm - Parallel port control module.
;-------------------------------------------------------------------------------

		public DrvParallel

                ; DrvParallel - parallel device driver.
		; Action: calls parallel port function number EAX.
proc DrvParallel near
		ret
endp		;---------------------------------------------------------------
