;-------------------------------------------------------------------------------
;  parport.asm - Parallel port control module.
;-------------------------------------------------------------------------------

; --- Publics ---
		public DrvParallel

; --- Data ---

; Parallel driver main structure
DrvParallel	tDriver <"%parallel       ",offset DrvParallelET,0>

; Driver entry points table
DrvParallelET	tDrvEntries < PAR_Init,\
			      PAR_HandleEvent,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL >

; --- Procedures ---

		; PAR_Init
proc PAR_Init near
		ret
endp		;---------------------------------------------------------------


		; PAR_HandleEvent
proc PAR_HandleEvent near
		ret
endp		;---------------------------------------------------------------