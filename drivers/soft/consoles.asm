;*******************************************************************************
;  consoles.asm - RadiOS consoles driver.
;  Copyright (c) 1998,99 RET & COM research.
;*******************************************************************************

include "hardware.ah"
include "asciictl.ah"

; --- Definitions ---

; Misc
NUMVIRTCONS		EQU	8		; Number of virtual consoles

; Video parameters structure
struc tConVidParm
 VidMode	DB	?			; Video mode
 CursorShape	DB	?			; Cursor shape
 CursorPos	DW	?			; Cursor position
 FontPtr	DD	?			; Font table pointer
ends

; Keyboard parameters structure
struc tConKbdParm
 Mode		DB	?			; Mode flags (binary, etc.)
 RateDelay	DB	?			; Keyboard rate and delay
 Switches	DB	?			; Switches status
 Reserved	DB	?
 Layout		DD	?			; Keyboard layout pointer
ends

; Console settings structure
struc	tConParm
 VidParm	tConVidParm <>			; Video parameters
 KbdParm	tConKbdParm <>			; Keyboard parameters
ends


; --- Data ---
segment KDATA
DrvConsole	tDriver	<"%console        ",DrvConET,DRVFL_Char>

; Console driver entry points table
DrvConET	tDrvEntries < CON_Init, \
			      CON_HandleEvents, \
			      CON_Open, \
			      CON_Close, \
			      CON_Read, \
			      CON_Write, \
			      NULL, \
			      CON_Control>

CON_Control	DD	CON_GetInitStatStr	; Control routines
		DD	CON_GetParameters
		DD	NULL
		DD	NULL
		DD	CON_WrCharNoCtrl
		DD	NULL
		DD	NULL
		DD	NULL
		DD	CON_WrString
ends


; --- Variables ---
segment KVARS
MaxColNum	DB	79			; Max. column number
MaxRowNum	DB	24			; Max. row number
KBDID		DW	?			; Keyboard internal ID
ConActive	DB	0			; Active console number

; Console parameters table handle and address
ConParmTblHnd	DW	?
ConParmTblAddr	DD	?

; Initialization string
CON_InitString	DB	NL,"Console devices initialized:",NL," "
CON_DevInitStr	DB	160 dup (?)
ends


; --- Interface procedures ---
segment KCODE

		; CON_Init - initialize console devices
		;	     (video text device and keyboard).
		; Input: ESI=buffer for initialization status string.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - detecting failure, AX=error code.
proc CON_Init near
		push	ebx edx esi edi

		mov	eax,NUMVIRTCONS			; Allocate memory
		mov	ecx,size tConParm		; for console parameters
		mul	ecx				; table
		mov	ecx,eax
		call	KH_Alloc
		jc	short @@Exit
		mov	[ConParmTblHnd],ax
		mov	[ConParmTblAddr],ebx

		mov	ebx,esi
		mov	esi,offset CON_DevInitStr
		mCallDriver DRVID_VideoTx,DRVF_Init	; Initialize
		jc	short @@Exit			; video text device
		dec	dl
		dec	dh
		mov	[MaxColNum],dl
		mov	[MaxRowNum],dh

		mov	edi,esi
		call	StrEnd
		mov	ax,NL+2000h
		stosw

		mov	esi,edi
		mCallDriver DRVID_Keyboard,DRVF_Init	; Initialize
		jc	short @@Exit			; keyboard
		mov	[KBDID],ax

		mov	esi,ebx
		call	CON_GetInitStatStr
		xor	eax,eax

@@Exit:		pop	edi esi edx ebx
		ret
endp		;---------------------------------------------------------------


		; CON_HandleEvents - handle driver messages.
		; Input: EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_HandleEvents near
		ret
endp		;---------------------------------------------------------------


		; CON_Open - "open" console.
		; Input: EDX (high word) = console number (0 for system).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_Open near
		ret
endp		;---------------------------------------------------------------


		; CON_Close - "close" console.
		; Input: EDX (high word) = console number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_Close near
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; CON_SetActive - set active console.
		; Input: AL=console number.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_SetActive near

		ret
endp		;---------------------------------------------------------------


		; CON_HandleCTRL - handle ASCII control characters.
		; Input: AL=character code.
		; Output: CF=0 - not CTRL code,
		;	  CF=1 - CTRL code (has been handled).
proc CON_HandleCTRL near
		push	ebx edx
		cmp	al,ASC_BEL
		je	short @@BEL
		cmp	al,ASC_BS
		je	short @@BS
		cmp	al,ASC_HT
		je	short @@HT
		cmp	al,ASC_VT
		je	short @@HT
		cmp	al,ASC_LF
		je	@@LF
		cmp	al,ASC_CR
		je	@@CR
		clc
		jmp	@@Exit

@@BEL:		call	SPK_Beep
		jmp	@@Done

@@BS:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_GetCurPos
		or	dl,dl
		jz      short @@BS_Up
		dec	dl
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCursor
		jmp	@@BS_Delete
@@BS_Up:	or	dh,dh
		jz	@@Done
		dec	dh
		mov	dl,[MaxColNum]
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCursor
@@BS_Delete:    push	eax
		mov	al,' '
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_WrChar
		pop	eax
		jmp	@@Done

@@HT:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_GetCurPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,[MaxColNum]
		jbe	@@HT_Next
		mov	dl,[MaxColNum]
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCursor
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCurNext
		jmp	short @@Done
@@HT_Next:	mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCursor
		jmp	short @@Done

@@VT:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_GetCurPos
		jmp	short @@Done

@@LF:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_GetCurPos
		cmp	dh,[MaxRowNum]
		jae	@@LF_Scroll
		inc	dh
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCursor
		jmp	short @@Done

@@LF_Scroll:	mov	dl,1
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_Scroll
		push	eax
		xor	al,al
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_ClrLine
		pop	eax
		jmp	short @@Done

@@CR:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_GetCurPos
		xor	dl,dl
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_MoveCursor

@@Done:		stc
@@Exit: 	pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; CON_Read - read one character from input device.
		; Input: none.
		; Output: AL=read character ASCII code,
		;	  AH=key scan code.
proc CON_Read near
		mCallDriver DRVID_Keyboard,DRVF_Read
		ret
endp		;---------------------------------------------------------------


		; CON_Write - write character with CTRL handling.
		; Input: EDX (high word) = minor (console) number,
		;	 AL=character code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_Write near
		call	CON_HandleCTRL
		jnc	short @@NoCtrl
		cmp	al,ASC_LF
		jne	short @@OK
		push	eax
		mov	al,ASC_CR
		call	CON_HandleCTRL
		pop	eax
		jmp	short @@OK
@@NoCtrl:	mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_WrCharTTY
@@OK:		clc
		ret
endp		;---------------------------------------------------------------


		; CON_WrString - write null-terminated string.
		; Input: ESI=pointer to ASCIIZ-string.
		; Output: none.
proc CON_WrString near
		push	eax esi
@@Loop:		mov	al,[esi]
		or	al,al
		jz	short @@Exit
		call	CON_Write
                inc	esi
		jmp	@@Loop
@@Exit:		pop	esi eax
		ret
endp		;---------------------------------------------------------------


		; CON_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc CON_GetInitStatStr near
		push	esi edi
		mov	edi,esi
		mov	esi,offset CON_InitString
		call	StrCopy
		pop	edi esi
		ret
endp		;---------------------------------------------------------------


		; CON_GetParameters - get console parameters.
		; Input: EDX (high word) = minor (console) number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_GetParameters near
		ret
endp		;---------------------------------------------------------------


		; CON_WrCharNoCtrl - write a character without CTRL handling.
		; Input: AL=character code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_WrCharNoCtrl near
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VTX_WrCharTTY
		ret
endp		;---------------------------------------------------------------


ends
