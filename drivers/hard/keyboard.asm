;*******************************************************************************
;  keyboard.asm - AT MFII keyboard control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "asciictl.ah"

; --- Definitions ---

; Child event handler structure

; Keyboard commands
KB_CmdReset		EQU	0FFh
KB_CmdResend		EQU	0FEh
KB_CmdSetDefault	EQU	0F6h
KB_CmdDfltDisable	EQU	0F5h
KB_CmdEnable		EQU	0F4h
KB_CmdSetRateDelay	EQU	0F3h
KB_CmdReadID		EQU	0F2h
KB_CmdEcho		EQU	0EEh
KB_CmdIndCtrl		EQU	0EDh
KB_CmdScanDisable	EQU	0ADh
KB_CmdScanEnable	EQU	0AEh

; Keyboard answers
KB_AnsACK		EQU	0FAh
KB_AnsTestOK		EQU	0AAh
KB_AnsKeyUp		EQU	0F0h
KB_AnsDiagFail		EQU	0FDh
KB_AnsEcho		EQU	0EEh
KB_AnsBufErr		EQU	0FFh

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


; --- Externals ---


; --- Publics ---
		public DrvKeyboard
;		public KB_DetectMFIIKB
;		public KB_AnalyseKCode


; --- Procedures ---

		; DrvKeyboard - keyboard driver entry.
		; Action: calls keyboard function number EAX.
		; Return: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc DrvKeyboard near
		cmp	eax,DRVF_Init	
		je	KB_Init
		cmp	eax,DRVF_HandleEv
		je	KB_HandleEv
		cmp	eax,DRVF_InstNextHn
		je	KB_InstNextHn
		mov	ax,ERR_BadFunNum
		stc
		ret
endp		;---------------------------------------------------------------


		; KB_Init - reset and initialize keyboard.
		; Input: none.
		; Output: CF=0 - OK, AX=keyboard internal ID;
		;	  CF=1 - error, AX=error code.
proc KB_Init near
		mov	al,KB_CmdReset
		clc
		call	KBC_SendKBCmd			; Internal KB test
		jc	DetKBD_Exit
;		call	KBC_WaitKBcode
;		call	KBC_ReadKBPort
;		cmp	al,KB_AnsTestOK
;		jne	DetKBD_Err

;		mov	al,KB_CmdReadID
;		clc
;		call	KBC_SendKBCmd
;		jc	DetKBD_Exit
;		call	KB_Delay
;		call	KBC_ReadKBPort
;		mov	ah,al
;		call	KB_Delay
;		call	KBC_ReadKBPort
;		xchg	al,ah
		clc
		jmp	short DetKBD_Exit

DetKBD_Err:	mov	ax,ERR_KB_DetFail
		stc
DetKBD_Exit:	ret
endp		;---------------------------------------------------------------


		; KB_HandleEv - handle keyboard events (from IRQ1 handler).
		; Input: EBX=pointer to event structure.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KB_HandleEv near
		ret
endp		;---------------------------------------------------------------


		; KB_InstChlHandler - install child keyboard events handler.
		; Input: EBX=handler address;
		;	 AL=0 - post-haldling,
		;	 AL=1 - pre-handling.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KB_InstChlHandler near
		ret
endp		;---------------------------------------------------------------


		; KB_AnalyseKCode - convert keyboard codes into ASCII and
		;		    BIOS-compatible scan-codes.
		; Input: AL=keyboard code.
		; Output: AL=ASCII code or 0,
		;	  AH=scan code,
		;	  EDX=control keys status.
proc KB_AnalyseKCode near
		push	ebx
		push	edx
		test	al,80h
		jnz	AKC_2
		mov	ebx,offset KB_DfltTbl1
		xlat
 IFDEF DEBUG
		extrn CON_WrCharTTY:near
		cmp	al,27
		jne	AKC00
		DB	0E9h
		DD	0FFFF0h
	AKC00:	cmp	al,13
		jne	AKC_1
		call	CON_WrCharTTY
		mov	al,10
	AKC_1:	call	CON_WrCharTTY
		jmp	AKC_Exit
	AKC_2:	mov	dx,79
		mov	ah,15
		xor	bh,bh
		stc
		call	VGATX_WrCharXY
 ENDIF
AKC_Exit:	pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------

