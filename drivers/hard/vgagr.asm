;*******************************************************************************
;  vgagr.asm - VGA graphics mode driver.
;  Copyright (c) 1999 .....< your name ;-) >..... All rights reserved.
;*******************************************************************************


segment KDATA
; Video graphics driver main structure
DrvVGAGR	tDriver <"%videogr        ",offset DrvVGAGRET,0>

; Driver entry points table
DrvVGAGRET	tDrvEntries < NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      VGAGR_Control >

VGAGR_Control	DD	NULL
ends
