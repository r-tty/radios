;*******************************************************************************
;  vgagr.as - VGA graphics mode driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module vgagr

%define extcall near

%include "sys.ah"


; --- Exports ---

global DrvVGAGR


; --- Imports ---



; --- Data ---

section .data

; Video graphics driver main structure
DrvVGAGR	DB	"%videogr"
		TIMES	16-$+DrvVGAGR DB 0
		DD	DrvVGAGRET
		DW	0

; Driver entry points table
DrvVGAGRET	DD	VGR_Init
		DD	NULL
		DD	VGR_Open
		DD	VGR_Close
		DD	NULL
		DD	NULL
		DD	NULL
		DD	VGAGR_Control

VGAGR_Control	DD	VGR_GetISS
		DD	VGR_GetParms
		DD	VGR_SetParms

; Video controller parameters for various modes
VGAPARM_Mode3	DB	63h,0,70h,5,3,1,3,0,2
%ifdef NOTEBOOK
		DB	5Fh,4Fh,50h,82h,55h,81h,0BFh,1Fh,0,04Fh,0Eh,0Fh,0,0,7
		DB	80h,9Ch,0AEh,8Fh,28h,1Fh,96h,0B9h,0A3h,0FFh
%else
		DB	5Fh,4Fh,50h,82h,55h,81h,0BFh,1Fh,0,0C7h,06,7,0,0,0
		DB	59h,9Ch,8Eh,8Fh,28h,1Fh,96h,0B9h,0A3h,0FFh
%endif
		DB	0,0,0,0,0,10h,0Eh,0,0FFh
		DB	0,1,2,3,4,5,6,7,10h,11h,12h,13h,14h,15h,16h,17h
		DB	8,0,0Fh,0,0

VGAPARM_Mode12	DB	0E3h,0,70h,4,3,1,0Fh,0,6
%ifdef NOTEBOOK
		DB	5fh,4fh,50h,82h,54h,80h,0bfh,3eh,0,40h,0eh,0fh,0,0,3
		DB	070h,0EAh,0ACh,0DFh,28h,0,0E7h,4,0E3h,0FFh
%else
		DB	5fh,4fh,50h,82h,54h,80h,0bfh,3eh,0,40h,0,0,0,0,0
		DB	059h,0eah,8ch,0dfh,28h,0,0e7h,4,0e3h,0ffh
%endif
		DB	0,0,0,0,0,40,5,0Fh,0FFh
		DB	0,1,2,3,4,5,14h,7,38h,39h,3Ah,3Bh,3Ch,3Dh,3Eh,3Fh
		DB	1,0,0Fh,0,0

; Default palette
Palette		DB	000h, 000h, 000h,  000h, 000h, 02Ah
		DB	000h, 02Ah, 000h,  000h, 02Ah, 02Ah
		DB	02Ah, 000h, 000h,  02Ah, 000h, 02Ah
		DB	02Ah, 02Ah, 000h,  02Ah, 02Ah, 02Ah
		DB	000h, 000h, 015h,  000h, 000h, 03Fh
		DB	000h, 02Ah, 015h,  000h, 02Ah, 03Fh
		DB	02Ah, 000h, 015h,  02Ah, 000h, 03Fh
		DB	02Ah, 02Ah, 015h,  02Ah, 02Ah, 03Fh
		DB	000h, 015h, 000h,  000h, 015h, 02Ah
		DB	000h, 03Fh, 000h,  000h, 03Fh, 02Ah
		DB	02Ah, 015h, 000h,  02Ah, 015h, 02Ah
		DB	02Ah, 03fh, 000h,  02Ah, 03Fh, 02Ah
		DB	000h, 015h, 015h,  000h, 015h, 03Fh
		DB	000h, 03fh, 015h,  000h, 03Fh, 03Fh
		DB	02Ah, 015h, 015h,  02Ah, 015h, 03Fh
		DB	02Ah, 03Fh, 015h,  02Ah, 03fh, 03Fh
		DB	015h, 000h, 000h,  015h, 000h, 02Ah
		DB	015h, 02Ah, 000h,  015h, 02Ah, 02Ah
		DB	03Fh, 000h, 000h,  03fh, 000h, 02Ah
		DB	03Fh, 02Ah, 000h,  03fh, 02Ah, 02Ah
		DB	015h, 000h, 015h,  015h, 000h, 03Fh
		DB	015h, 02Ah, 015h,  015h, 02Ah, 03Fh
		DB	03Fh, 000h, 015h,  03Fh, 000h, 03Fh
		DB	03Fh, 02Ah, 015h,  03Fh, 02Ah, 03Fh
		DB	015h, 015h, 000h,  015h, 015h, 02Ah
		DB	015h, 03Fh, 000h,  015h, 03Fh, 02Ah
		DB	03Fh, 015h, 000h,  03Fh, 015h, 02Ah
		DB	03Fh, 03fh, 000h,  03Fh, 03Fh, 02Ah
		DB	015h, 015h, 015h,  015h, 015h, 03Fh
		DB	015h, 03Fh, 015h,  015h, 03Fh, 03Fh
		DB	03Fh, 015h, 015h,  03Fh, 015h, 03Fh
		DB	03Fh, 03Fh, 015h,  03Fh, 03Fh, 03Fh


; --- Interface procedures ---

section .text

		; VGR_Init - initialize driver.
		; Input: ESI=buffer for init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc VGR_Init
		ret
endp		;---------------------------------------------------------------


		; VGR_Open - "open" graphics device.
		; Input: AL=video mode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc VGR_Open
		ret
endp		;---------------------------------------------------------------


		; VGR_Close - "close" graphics device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc VGR_Close
		ret
endp		;---------------------------------------------------------------


		; VGR_GetISS - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc VGR_GetISS
		ret
endp		;---------------------------------------------------------------


		; VGR_GetParms - get device parameters.
		; Input:
		; Output:
proc VGR_GetParms
		ret
endp		;---------------------------------------------------------------


		; VGR_SetParms - set device parameters.
		; Input:
		; Output:
proc VGR_SetParms
		ret
endp		;---------------------------------------------------------------

