;-------------------------------------------------------------------------------
;  serport.asm - Serial ports control module.
;-------------------------------------------------------------------------------

		public DrvSerial

                ; Drvserial - serial device driver.
		; Action: calls serial port function number EAX.
proc DrvSerial near
		ret
endp		;---------------------------------------------------------------
