;*******************************************************************************
;  ne2000.asm - NE2000 compatible Ethernet card driver.
;  Copyright (c) 1998 RET & COM research.
;*******************************************************************************

segment KDATA
; Ethernet driver main structure
DrvEthernet	tDriver <"%ethernet       ",offset DrvEthernetET,0>

; Driver entry points table
DrvEthernetET	tDrvEntries < ETH_Init,\
			      ETH_HandleEvent,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL >
ends

; --- Procedures ---

		; NE2_Init
proc ETH_Init near
		ret
endp		;---------------------------------------------------------------


		; NE2_HandleEvent
proc ETH_HandleEvent near
		ret
endp		;---------------------------------------------------------------
