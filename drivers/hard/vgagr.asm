;*******************************************************************************
;  vgagr.asm - VGA graphics mode driver.
;  Copyright (c) 1999 .....< your name ;-) >..... All rights reserved.
;*******************************************************************************

; --- Publics ---
		public DrvVGAGR


; --- Data ---

; Video graphics driver main structure
DrvVGAGR	tDriver <"%videogr        ",offset DrvVGAGRET,0>

; Driver entry points table
DrvVGAGRET	tDrvEntries < DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      VGAGR_Control >

VGAGR_Control	DD	?
