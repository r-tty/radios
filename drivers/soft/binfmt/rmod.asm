;*******************************************************************************
;  rmod.asm - RadiOS modules driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

; --- Data ---
segment KDATA
DrvRMod		tDriver <"%BINFMT_RMOD    ",DrvRModET,DRVFL_BinFmt>

DrvRModET	tDrvEntries < RMOD_Init, \
			      NULL, \
			      NULL, \
			      NULL, \
			      RMOD_Load, \
			      NULL, \
			      RMOD_Done, \
			      DrvRMod_Ctrl >

DrvRMod_Ctrl	DD	NULL
ends


; --- Interface procedures ---
segment KCODE

		; RMOD_Init - initialize driver.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RMOD_Init near
		ret
endp		;---------------------------------------------------------------


		; RMOD_Done - release driver memory blocks.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RMOD_Done near
		ret
endp		;---------------------------------------------------------------


		; RMOD_Load - load RadiOS module.
		; Input:
		; Output:
proc RMOD_Load near
		ret
endp		;---------------------------------------------------------------


ends
