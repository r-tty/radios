;-------------------------------------------------------------------------------
;  serport.asm - Serial ports control module.
;-------------------------------------------------------------------------------

                ; Drvserial - serial device driver.
		; Action: calls serial port function number EAX.
proc DrvSerial near
		ret
endp