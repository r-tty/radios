;*******************************************************************************
;  coff.as - COFF modules driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module binfmt.coff

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"

; --- Exports ---

global DrvCOFF


; --- Imports ---


; --- Data ---

section .data

DrvCOFF		DB	"%BINFMT_COFF"
		TIMES	16-$+DrvCOFF DB 0
		DD	DrvCOFF_ET
		DW	DRVFL_BinFmt

DrvCOFF_ET	DD	COFF_Init
		DD	NULL
		DD	COFF_Load
		DD	COFF_Unload
		DD	NULL
		DD	NULL
		DD	COFF_Done
		DD	DrvCOFF_Ctrl

DrvCOFF_Ctrl	DD	NULL


; --- Interface procedures ---

section .text

		; COFF_Init - initialize driver.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc COFF_Init
		ret
endp		;---------------------------------------------------------------


		; COFF_Done - release driver memory blocks.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc COFF_Done
		ret
endp		;---------------------------------------------------------------


		; COFF_Load - load COFF module.
		; Input:
		; Output:
proc COFF_Load
		ret
endp		;---------------------------------------------------------------


		; COFF_Unload - unload COFF module.
		; Input: EDI=pointer to kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc COFF_Unload
		ret
endp		;---------------------------------------------------------------

