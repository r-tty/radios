;*******************************************************************************
;  consoles.asm - RadiOS consoles driver.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "consoles.ah"
include "asciictl.ah"

; --- Definitions ---
MAXCONNUM	EQU	7			; Maximun console number

; Console settings structure
struc	tConStruct
 VidFont	DB	?			; Console video font
 KBlayout	DB	?			; Console keyboard layout
ends



; --- Data ---


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
		; Kernel procedures
		extrn DRV_InstallNew:	 near

		; Keyboard procedures
		extrn KB_DetectMFIIKB:	 near

		; VGA text mode procedures
		extrn VGATX_Detect:	 near
		extrn VGATX_MoveCursor:	 near
		extrn VGATX_GetCurPos:	 near
		extrn VGATX_MoveCurNext: near
		extrn VGATX_Scroll:	 near
		extrn VGATX_ClrLine:	 near
		extrn VGATX_ClrVidPage:	 near
		extrn VGATX_WrChar:	 near

		; Speaker "beep"
		extrn SPK_Beep:		 near


; --- Driver procedures ---

		; CON_DetectDevs - detect and check consoles devices
		;		   (video controller and keyboard).
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - detecting failure, AX=error code.
proc CON_DetectDevs near
		push	edx
		call	VGATX_Detect
		jc	DetDv_Err1
		dec	dl
		dec	dh
		mov	[MaxColNum],dl
		mov	[MaxRowNum],dh
		call	KB_DetectMFIIKB
		jc	DetDv_Err2
		mov	[KBDID],ax
		jmp	DetDv_Exit

DetDv_Err1:	mov	ax,ERR_CON_VidDetFail
		jmp	DetDv_Exit
DetDv_Err2:	mov	ax,ERR_CON_KBDetFail
DetDv_Exit:	pop	edx
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
		je	HnCTL_BEL
		cmp	al,ASC_BS
		je	HnCTL_BS
		cmp	al,ASC_HT
		je	HnCTL_HT
		cmp	al,ASC_VT
		je	HnCTL_HT
		cmp	al,ASC_LF
		je	HnCTL_LF
		cmp	al,ASC_CR
		je	HnCTL_CR
		clc
		jmp	HnCTL_Exit

HnCTL_BEL:	call	SPK_Beep
		jmp	HnCTL_Done

HnCTL_BS:	call	VGATX_GetCurPos
		or	dl,dl
		jz      HnCTL_BS_Up
		dec	dl
		call	VGATX_MoveCursor
		jmp	HnCTL_Done
HnCTL_BS_Up:	or	dh,dh
		jz	HnCTL_Done
		dec	dh
		mov	dl,[MaxColNum]
		call	VGATX_MoveCursor
		jmp	HnCTL_Done

HnCTL_HT:	call	VGATX_GetCurPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,[MaxColNum]
		jbe	HnCTL_HTn
		mov	dl,[MaxColNum]
		call	VGATX_MoveCursor
		call	VGATX_MoveCurNext
		jmp	HnCTL_Done
HnCTL_HTn:	call	VGATX_MoveCursor
		jmp	HnCTL_Done

HnCTL_VT:	call	VGATX_GetCurPos
		jmp	HnCTL_Done

HnCTL_LF:	call	VGATX_GetCurPos
		cmp	dh,[MaxRowNum]
		jae	HnCTL_LFS
		inc	dh
		call	VGATX_MoveCursor
		jmp	HnCTL_Done
HnCTL_LFS:	mov	dl,1
		call	VGATX_Scroll
		push	eax
		xor	al,al
		call	VGATX_ClrLine
		pop	eax
		jmp	HnCTL_Done

HnCTL_CR:	call	VGATX_GetCurPos
		xor	dl,dl
		call	VGATX_MoveCursor
		jmp	HnCTL_Done

HnCTL_Done:	stc
HnCTL_Exit:	pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CON_WrCharTTY - write character in TTY mode.
		; Input: AL=character code,
		;	 BH=video page (0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; Notes: Writes at current cursor position, then move cursor.
		;	 Uses existing attributes.
		;	 Handle ASCII control codes.
		; (Date: 21.11.98)
proc CON_WrCharTTY near
		call	CON_HandleCTRL
		jc	WCTTY_Exit
		call	VGATX_WrChar
		call	VGATX_MoveCurNext
WCTTY_Exit:	ret
endp		;---------------------------------------------------------------


CON_MoveCursor:	jmp	VGATX_MoveCursor
CON_ClrScr:	jmp	VGATX_ClrVidPage