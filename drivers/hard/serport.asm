;-------------------------------------------------------------------------------
;  serport.asm - Serial ports control module.
;-------------------------------------------------------------------------------

; --- Publics ---
		public DrvSerial

; --- Data ---

; Serial driver main structure
DrvSerial	tDriver <"%serial         ",offset DrvSerialET,0>

; Driver entry points table
DrvSerialET	tDrvEntries < SER_Init,\
			      SER_HandleEvent,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL >

; --- Procedures ---

		; SER_Init
proc SER_Init near
		ret
endp		;---------------------------------------------------------------


		; SCSI_HandleEvent
proc SER_HandleEvent near
		ret
endp		;---------------------------------------------------------------