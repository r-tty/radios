;*******************************************************************************
;  console.as - RadiOS console driver.
;  Copyright (c) 1999 RET & COM research.
;*******************************************************************************

module console

%define	extcall near

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "asciictl.ah"


; --- Definitions ---

%define	NUMVIRTCONS	8			; Number of virtual consoles

; Video parameters structure
struc tConVidParm
.VidMode	RESB	1			; Video mode
.CursorShape	RESB	1			; Cursor shape
.CursorPos	RESW	1			; Cursor position
.FontPtr	RESD	1			; Font table pointer
.PrintAttr	RESB	1			; Screen attributes
.Reserved	RESB	3
endstruc

; Keyboard parameters structure
struc tConKbdParm
.Mode		RESB	1			; Mode flags (binary, etc.)
.RateDelay	RESB	1			; Keyboard rate and delay
.Switches	RESB	1			; Switches status
.Reserved	RESB	1
.Layout		RESD	1			; Keyboard layout pointer
endstruc

struc tConParm
.KbdParms	RESB	tConKbdParm_size
.VidParms	RESB	tConVidParm_size
endstruc


; --- Exports ---

global DrvConsole


; --- Imports ---

library kernel.driver
extern DRV_CallDriver:extcall

library kernel.misc
extern StrEnd:extcall, StrCopy:extcall

library kernel.onboard
extern SPK_Beep

; --- Data ---

section .data

DrvConsole	DB	"%console"
		TIMES	16-$+DrvConsole DB 0
		DD	DrvConET
		DW	DRVFL_Char

; Console driver entry points table
DrvConET	DD	CON_Init
		DD      CON_HandleEvents
		DD      CON_Open
		DD      CON_Close
		DD      CON_Read
		DD      CON_Write
		DD      NULL
		DD      CON_Control

CON_Control	DD	CON_GetInitStatStr	; Control routines
		DD	CON_GetParameters
		DD	NULL
		DD	NULL
		DD	CON_WrCharNoCtrl
		DD	NULL
		DD	NULL
		DD	NULL
		DD	CON_WrString
		DD	CON_SetActive

; Initialization string
CON_InitString	DB	NL,"Console devices initialized:",NL," ",0


; --- Variables ---

section .bss

MaxColNum	RESB	1			; Max. column number
MaxRowNum	RESB	1			; Max. row number
KBDID		RESW	1			; Keyboard internal ID
ConActive	RESB	1			; Active console number

ConParmTable	RESB	tConParm_size*NUMVIRTCONS



; --- Interface procedures ---

section .text

		; CON_Init - initialize console devices
		;	     (video text device and keyboard).
		; Input: none.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - detecting failure, AX=error code.
proc CON_Init
		mpush	edx,esi
		mov	byte [ConParmTable+tConParm.VidParms+tConVidParm.PrintAttr],7

		mCallDriver byte DRVID_VideoTx, byte DRVF_Init	; Initialize
		jc	.Exit					; video text
		dec	dl					; device
		dec	dh
		mov	[MaxColNum],dl
		mov	[MaxRowNum],dh

		mCallDriver byte DRVID_Keyboard, byte DRVF_Init	; Initialize
		jc	short .Exit				; keyboard
		mov	[KBDID],ax
		xor	eax,eax

.Exit:		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------


		; CON_HandleEvents - handle driver messages.
		; Input: EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_HandleEvents
		ret
endp		;---------------------------------------------------------------


		; CON_Open - "open" console.
		; Input: EDX (high word) = console number (0 for system).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_Open
		ret
endp		;---------------------------------------------------------------


		; CON_Close - "close" console.
		; Input: EDX (high word) = console number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_Close
		ret
endp		;---------------------------------------------------------------


		; CON_SetActive - set active console.
		; Input: AL=console number.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_SetActive
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_SetActPage
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; CON_HandleCTRL - handle ASCII control characters.
		; Input: AL=character code.
		; Output: CF=0 - not CTRL code,
		;	  CF=1 - CTRL code (has been handled).
proc CON_HandleCTRL
		mpush	ebx,edx
		cmp	al,ASC_BEL
		je	short .BEL
		cmp	al,ASC_BS
		je	short .BS
		cmp	al,ASC_HT
		je	near .HT
		cmp	al,ASC_VT
		je	near .HT
		cmp	al,ASC_LF
		je	near .LF
		cmp	al,ASC_CR
		je	near .CR
		clc
		jmp	.Exit

.BEL:		call	SPK_Beep
		jmp	.Done

.BS:		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_GetCurPos
		or	dl,dl
		jz      short .BS_Up
		dec	dl
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCursor
		jmp	.BS_Delete
.BS_Up:		or	dh,dh
		jz	near .Done
		dec	dh
		mov	dl,[MaxColNum]
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCursor
.BS_Delete:	push	eax
		mov	al,' '
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_WrChar
		pop	eax
		jmp	.Done

.HT:		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_GetCurPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,[MaxColNum]
		jbe	.HT_Next
		mov	dl,[MaxColNum]
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCursor
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCurNext
		jmp	.Done
.HT_Next:	mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCursor
		jmp	.Done

.VT:		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_GetCurPos
		jmp	short .Done

.LF:		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_GetCurPos
		cmp	dh,[MaxRowNum]
		jae	.LF_Scroll
		inc	dh
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCursor
		jmp	short .Done

.LF_Scroll:	mov	dl,1
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_Scroll
		push	eax
		xor	al,al
		mov	ebx,ConParmTable
		mov	ah,[ebx+tConParm.VidParms+tConVidParm.PrintAttr]
		stc
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_ClrLine
		pop	eax
		jmp	short .Done

.CR:		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_GetCurPos
		xor	dl,dl
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_MoveCursor

.Done:		stc
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; CON_Read - read one character from input device.
		; Input: none.
		; Output: AL=read character ASCII code,
		;	  AH=key scan code.
proc CON_Read
		mCallDriver byte DRVID_Keyboard, byte DRVF_Read
		ret
endp		;---------------------------------------------------------------


		; CON_Write - write character with CTRL handling.
		; Input: EDX (high word) = minor (console) number,
		;	 AL=character code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_Write
		call	CON_HandleCTRL
		jnc	short .NoCtrl
		cmp	al,ASC_LF
		jne	short .OK
		push	eax
		mov	al,ASC_CR
		call	CON_HandleCTRL
		pop	eax
		jmp	short .OK
.NoCtrl:	mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_VTX_WrCharTTY
.OK:		clc
		ret
endp		;---------------------------------------------------------------


		; CON_WrString - write null-terminated string.
		; Input: ESI=pointer to ASCIIZ-string.
		; Output: none.
proc CON_WrString
		mpush	eax,esi
.Loop:		mov	al,[esi]
		or	al,al
		jz	short .Exit
		call	CON_Write
                inc	esi
		jmp	.Loop
.Exit:		mpop	esi,eax
		ret
endp		;---------------------------------------------------------------


		; CON_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc CON_GetInitStatStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,CON_InitString
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mCallDriverCtrl byte DRVID_VideoTx, DRVCTL_GetInitStatStr
		call	StrEnd
		mov	word [edi],200Ah
		lea	esi,[edi+2]
		mCallDriverCtrl byte DRVID_Keyboard, DRVCTL_GetInitStatStr
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; CON_GetParameters - get console parameters.
		; Input: EDX (high word) = minor (console) number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_GetParameters
		ret
endp		;---------------------------------------------------------------


		; CON_WrCharNoCtrl - write a character without CTRL handling.
		; Input: AL=character code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_WrCharNoCtrl
		mCallDriverCtrl byte DRVID_VideoTx,DRVCTL_VTX_WrCharTTY
		ret
endp		;---------------------------------------------------------------
