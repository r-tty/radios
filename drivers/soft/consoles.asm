;*******************************************************************************
;  consoles.asm - RadiOS consoles driver.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "asciictl.ah"

; --- Definitions ---

; --- Externals ---

		; VGA text mode procedures
		extrn VGATX_MoveCursor:	 near
		extrn VGATX_GetCurPos:	 near
		extrn VGATX_MoveCurNext: near
		extrn VGATX_Scroll:	 near
		extrn VGATX_ClrLine:	 near
		extrn VGATX_WrChar:	 near

		; Speaker "beep"
		extrn SPK_Beep:		near

; --- Data ---
TxtNumCols	DB	?
TxtNumRows	DB	?

; --- Driver procedures ---

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
		mov	dl,TxtNumCols-1
		call	VGATX_MoveCursor
		jmp	HnCTL_Done

HnCTL_HT:	call	VGATX_GetCurPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,TxtNumCols
		jb	HnCTL_HTn
		mov	dl,TxtNumCols-1
		call	VGATX_MoveCursor
		call	VGATX_MoveCurNext
		jmp	HnCTL_Done
HnCTL_HTn:	call	VGATX_MoveCursor
		jmp	HnCTL_Done

HnCTL_VT:	call	VGATX_GetCurPos
		jmp	HnCTL_Done

HnCTL_LF:	call	VGATX_GetCurPos
		cmp	dh,TxtNumRows-1
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