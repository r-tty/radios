;*******************************************************************************
;  rmod.asm - COFF modules driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

; --- Data ---
segment KDATA
DrvCOFF		tDriver <"%BINFMT_COFF    ",DrvCOFF_ET,DRVFL_BinFmt>

DrvCOFF_ET	tDrvEntries < COFF_Init, \
			      NULL, \
			      COFF_Load, \
			      COFF_Unload, \
			      NULL, \
			      NULL, \
			      COFF_Done, \
			      DrvCOFF_Ctrl >

DrvCOFF_Ctrl	DD	NULL
ends


; --- Interface procedures ---
segment KCODE

		; COFF_Init - initialize driver.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc COFF_Init near
		ret
endp		;---------------------------------------------------------------


		; COFF_Done - release driver memory blocks.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc COFF_Done near
		ret
endp		;---------------------------------------------------------------


		; COFF_Load - load COFF module.
		; Input:
		; Output:
proc COFF_Load near
		ret
endp		;---------------------------------------------------------------


		; COFF_Unload - unload COFF module.
		; Input: EDI=pointer to kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc COFF_Unload near
		ret
endp		;---------------------------------------------------------------

ends
