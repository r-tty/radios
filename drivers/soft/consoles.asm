;*******************************************************************************
;  consoles.asm - RadiOS consoles driver.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "asciictl.ah"

; --- Definitions ---

; Console driver main structure
DrvConsole	tDriver	<"%console        ",DrvConET,0>

; Console driver entry points table
DrvConET	tDrvEntries < CON_Init,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      CON_Read,\
			      CON_Write,\
			      DrvNULL,\
			      CON_Control>

CON_Control	DD	DrvNULL
		DD	DrvNULL
		DD	DrvNULL
		DD	DrvNULL
		DD	DrvNULL
		DD	CON_WrCharNoCtrl
		DD	DrvNULL
		DD	DrvNULL
		DD	CON_WrString


MAXCONNUM	EQU	7			; Maximal console number

; Console settings structure
struc	tConStruct
 VidFont	DB	?			; Console video font
 KBlayout	DB	?			; Console keyboard layout
ends



; --- Data ---
CON_InitString	DB	NL,"Console devices initialized:",NL," ",0
		DB	80 dup (?)
		DB	81 dup (?)

; --- Variables ---

MaxColNum	DB	79			; Max. column number
MaxRowNum	DB	24			; Max. row number
KBDID		DW	?			; Keyboard internal ID
ConActive	DB	0			; Active console number

; Console parameters tables
;CON_VidFntTbl	DD 256 dup (DefaultFont8x16)	; Table of offsets to fonts
;CON_KBltTbl	DD 256 dup (DefaultKBlayout)	; Table of offsets to layouts

; Console settings structures
VirtCons	tConStruct MAXCONNUM+1 dup (<0,0>)


; --- Externals ---

		; Speaker "beep"
		extrn SPK_Beep:		 near

; --- Publics ---
		public DrvConsole


; --- Driver procedures ---

		; CON_Init - initialize console devices
		;	     (video text device and keyboard).
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - detecting failure, AX=error code.
proc CON_Init near
		push	edx
		push	edi
		mCallDriver DRVID_VideoTx,DRVF_Init	; Initialize
		jc	@@Err1				; video text device
		dec	dl
		dec	dh
		mov	[MaxColNum],dl
		mov	[MaxRowNum],dh

		mov	edi,offset CON_InitString
		call	StrAppend
		mov	esi,edi
		call	StrEnd
		mov	[word edi],NL+2000h
		mov	[byte edi+2],0

		mCallDriver DRVID_Keyboard,DRVF_Init	; Initialize
		jc	@@Err2				; keyboard
		mov	[KBDID],ax

		mov	edi,offset CON_InitString
		call	StrAppend

		mov	esi,edi
		call	StrEnd
		mov	[word edi],NL
		clc
		jmp	@@Exit

@@Err1:		mov	ax,ERR_CON_VidDetFail
		jmp	@@Exit
@@Err2:		mov	ax,ERR_CON_KBDetFail
@@Exit:		pop	edi
		pop	edx
		ret
endp		;---------------------------------------------------------------


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
		;	  CF=1 - CTRL code (have been handled).
proc CON_HandleCTRL near
		push	ebx
		push	edx
		cmp	al,ASC_BEL
		je	@@BEL
		cmp	al,ASC_BS
		je	@@BS
		cmp	al,ASC_HT
		je	@@HT
		cmp	al,ASC_VT
		je	@@HT
		cmp	al,ASC_LF
		je	@@LF
		cmp	al,ASC_CR
		je	@@CR
		clc
		jmp	@@Exit

@@BEL:		call	SPK_Beep
		jmp	@@Done

@@BS:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_GetCurPos
		or	dl,dl
		jz      @@BS_Up
		dec	dl
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCursor
		jmp	@@BS_Delete
@@BS_Up:	or	dh,dh
		jz	@@Done
		dec	dh
		mov	dl,[MaxColNum]
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCursor
@@BS_Delete:    push	eax
		mov	al,' '
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_WrChar
		pop	eax
		jmp	@@Done

@@HT:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_GetCurPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,[MaxColNum]
		jbe	@@HT_Next
		mov	dl,[MaxColNum]
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCursor
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCurNext
		jmp	@@Done
@@HT_Next:	mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCursor
		jmp	@@Done

@@VT:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_GetCurPos
		jmp	@@Done

@@LF:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_GetCurPos
		cmp	dh,[MaxRowNum]
		jae	@@LF_Scroll
		inc	dh
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCursor
		jmp	@@Done

@@LF_Scroll:	mov	dl,1
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_Scroll
		push	eax
		xor	al,al
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_ClrLine
		pop	eax
		jmp	@@Done

@@CR:		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_GetCurPos
		xor	dl,dl
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCursor
		jmp	@@Done

@@Done:		stc
@@Exit: 	pop	edx
		pop	ebx
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
		; Input: AL=character code,
		;	 BH=console number (0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_Write near
		cmp	al,ASC_CR
		je	@@Exit
		call	CON_HandleCTRL
		jnc	@@NoCtrl
		cmp	al,ASC_LF
		jne	@@Exit
		push	eax
		mov	al,ASC_CR
		call	CON_HandleCTRL
		pop	eax
		jmp	short @@Exit
@@NoCtrl:	mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_WrChar
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCurNext
@@Exit:		ret
endp		;---------------------------------------------------------------


		; CON_WrString - write string.
		; Input: ESI=pointer to ASCIIZ-string.
		; Output: none.
		; Note: use only ASC_LF (0Ah) instead CRLF.
proc CON_WrString near
		push	esi
		push	eax
@@Loop:		mov	al,[esi]
		or	al,al
		jz	@@Exit
		call	CON_Write
                inc	esi
		jmp	@@Loop
@@Exit:		pop	eax
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; CON_WrCharNoCtrl - write character without CTRL handling.
		; Input: AL=character code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_WrCharNoCtrl near
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_WrChar
		mCallDriverCtrl DRVID_VideoTx,DRVCTL_VGATX_MoveCurNext
		ret
endp		;---------------------------------------------------------------

