;*******************************************************************************
;  ne2000.asm - NE2000 compatible Ethernet card driver.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Publics ---
		public DrvEthernet

; --- Data ---

; Ethernet driver main structure
DrvEthernet	tDriver <"%ethernet       ",offset DrvEthernetET,0>

; Driver entry points table
DrvEthernetET	tDrvEntries < NE2_Init,\
			      NE2_HandleEvent,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL >

; --- Procedures ---

		; NE2_Init
proc NE2_Init near
		ret
endp		;---------------------------------------------------------------


		; NE2_HandleEvent
proc NE2_HandleEvent near
		ret
endp		;---------------------------------------------------------------