;*******************************************************************************
;  mouse.nasm - PS/2 mouse driver.
;  Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module hw.mouse

%define extcall far
%define return retf

%include "driver.ah"

; --- Exports ---

global DrvMouse


; --- Imports ---


; --- Data ---

section .data

DrvMouse	DB	"%mouse"
		TIMES	16-$+DrvMouse DB 0
		DD	M_Entries
		DW	DRVFL_Extern+DRVFL_Char		; Loadable driver
		
M_Entries	DD	M_Init				; Initialize
		DD	0
		DD	0
		DD	0
		DD	0
		DD	0
		DD	0
		DD	M_Control
		
M_Control	DD	0

; --- Code ---

section .text

		; M_Init - initialize a driver.
		; Input:
		; Output:
proc M_Init
		return
endp		;---------------------------------------------------------------
