;*******************************************************************************
;  keyboard.asm - AT MFII keyboard control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "asciictl.ah"

; --- Definitions ---

; Keyboard commands
KB_CMD_Reset		EQU	0FFh
KB_CMD_Resend		EQU	0FEh
KB_CMD_SetDefault	EQU	0F6h
KB_CMD_DfltDisable	EQU	0F5h
KB_CMD_Enable		EQU	0F4h
KB_CMD_SetRateDelay	EQU	0F3h
KB_CMD_ReadID		EQU	0F2h
KB_CMD_Echo		EQU	0EEh
KB_CMD_IndCtrl		EQU	0EDh
KB_CMD_ScanDisable	EQU	0ADh
KB_CMD_ScanEnable	EQU	0AEh

; Pressed keys masks
KB_Prs_LShift		EQU	1
KB_Prs_LCtrl		EQU	2
KB_Prs_LAlt		EQU	4
KB_Prs_RShift		EQU	8
KB_Prs_RCtrl		EQU	16
KB_Prs_CapsLock		EQU	32
KB_Prs_NumLock		EQU	64
KB_Prs_ScrollLock	EQU	128

; On/off switches
KB_Sw_CapsLock		EQU	1
KB_Sw_NumLock		EQU	2
KB_Sw_ScrollLock	EQU	4
KB_Sw_Insert		EQU	8

; Functional keys definitions


; --- Keyboard data ---

; Default keyboard layout table
label DefaultKBlayout near
KB_DfltTbl1		DB ASC_NUL,ASC_ESC,"1234567890-=",ASC_BS,ASC_HT
			DB "qwertyuiop[]",ASC_CR,0,"asdfghjkl;'`",0
			DB "\zxcvbnm,./",0,0," ",0


; --- Keyboard variables ---
KB_PrsFlags		DB	?		; Keypressing flags
KB_SwFlags		DB	?		; Switches status


; --- Routines ---

		; KBC_Reset - reset keyboard controller.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc KBC_Reset near
		push	eax
		push	edx

		pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------

		; AnalyseKBcode - convert keyboard codes into ASCII and
		;		  BIOS-compatible scan-codes.
		; Input: AL=keyboard code.
		; Output: AL=ASCII code or 0,
		;	  AH=scan code,
		;	  EDX=control keys status.
proc AnalyseKBcode near
		test	al,80h
		jnz	AKC00
		mov	ebx,offset KB_DfltTbl1
		xlat
	extrn CON_WrCharTTY
		call	CON_WrCharTTY
	AKC00:	ret
endp		;---------------------------------------------------------------


		; DrvKeyboard - keyboard driver.
		; Action: calls keyboard function number EAX.
proc DrvKeyboard near
		ret
endp