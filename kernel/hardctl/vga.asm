;*******************************************************************************
;  vga.asm - VGA direct control routines.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Definitions ---
CGA_MemAddr	EQU	0B8000h

CRTC_R0		EQU	0		; CRT controller registers
CRTC_R1		EQU	1
CRTC_R2		EQU	2
CRTC_R3		EQU	3
CRTC_R4		EQU	4
CRTC_R5		EQU	5
CRTC_R6		EQU	6
CRTC_R7		EQU	7
CRTC_R8		EQU	8
CRTC_R9		EQU	9
CRTC_R10	EQU	10
CRTC_R11	EQU	11
CRTC_R12	EQU	12
CRTC_R13	EQU	13
CRTC_R14	EQU	14
CRTC_R15	EQU	15

TxtNumVPages	EQU	8		; Number of video pages
TxtNumCols	EQU	80		; Number of columns
TxtNumRows	EQU	25              ; Number of rows


; --- Data ---
include "HARDCTL\vgafont.asm"			; Default 8x16 font table


; --- Variables ---
VGA_TxtMemAddr	DD	CGA_MemAddr
VGA_CursorPos	DW	0


; --- Routines ---

;-------------------------- Text mode routines ---------------------------------

		; VGATX_MoveCursor - move cursor to specified position.
		; Input: DL=column (0..79),
		;	 DH=row (0..24),
		;	 BH=video page(0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; Notes: always keeps cursor position in VGA_CursorPos;
		;	 physically sets cursor only if it is visible.
		; (Date: 19.11.98)
proc VGATX_MoveCursor near
		cmp	bh,TxtNumVPages
		jae	vMVCUR_Err2
		cmp	dl,TxtNumCols
		jae	vMVCUR_Err1
		cmp	dh,TxtNumRows
		jae	vMVCUR_Err1
		push	eax
		push	ebx
		push	ecx
		push	edx

		movzx	ebx,bh			; Count offset in video
		shl	ebx,11			; memory (CRTC format)
		movzx	eax,dh
		movzx	edx,dl			; Store column
		shl	eax,4
		lea	eax,[eax*4+eax]
		add	eax,edx			; Now EAX=row*80+column
		add	eax,ebx			; Add video page address
		mov	[VGA_CursorPos],ax
		mov	cx,ax

		mov	dx,PORT_CGA_CAddr
		pushfd				; Store interrupts state
		mov	al,CRTC_R14
		cli
		out	dx,al
		inc	dx
		in	al,dx
		test	al,40h
		jnz	vMVCUR_Hidd
		dec	dx
		mov	al,CRTC_R14
		out	dx,ax
		mov	ah,cl
		mov	al,CRTC_R15
		out	dx,ax
vMVCUR_Hidd:	popfd
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		clc
		jmp	short vMVCUR_Exit

vMVCUR_Err1:	mov	ax,ERR_VID_BadCurPos
		jmp	short vMVCUR_Err
vMVCUR_Err2:	mov	ax,ERR_VID_BadVPage
vMVCUR_Err:	stc
vMVCUR_Exit:	ret
endp		;---------------------------------------------------------------


		; VGATX_GetCurPos - get cursor position.
		; Input: none.
		; Output: DL=column (0..79),
		;	  DH=row (0..24),
		;	  BH=video page (0..7).
		;	  CF=1 - cursor is hidden,
		;	  CF=0 - cursor is visible:
		; Note: destroys high words of EBX and EDX
		; (Date: 19.11.98)
proc VGATX_GetCurPos near
		push	eax
		pushfd				; Store interrupts state
		mov	dx,PORT_CGA_CAddr
		mov	al,CRTC_R14
		cli
		out	dx,al
		inc	dx
		in	al,dx                   ; AL=HB of physical position
		popfd
		shl	al,2			; CF=0 if hidden
		lahf
		mov	bl,ah

		movzx	edx,[VGA_CursorPos]
		mov	eax,edx
		shr	dx,11
		mov	bh,dl			; Now BH=cursor video page.
		shl	dx,11
		sub	eax,edx			; Now EAX=row*80+column
		mov	dl,TxtNumCols
		div	dl
		mov	dh,al			; Row
		mov	dl,ah			; Column

		mov	ah,bl			; Restore status of cursor
		sahf				; (visible/hidden)
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; VGATX_HideCursor - hide cursor.
		; Input: none.
		; Output: none.
		; (Date: 19.11.98)
proc VGATX_HideCursor near
		push	eax
		push	edx
		pushfd
		mov	dx,PORT_CGA_CAddr
		mov	ax,CRTC_R14+4000h
		cli
		out	dx,ax
		mov	ax,CRTC_R15
		out	dx,ax
		popfd
		pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; VGATX_ShowCursor - show cursor.
		; Input: none.
		; Output: none.
		; Note: restores cursor position from VGA_CursorPos
		; (Date: 20.11.98)
proc VGATX_ShowCursor near
		push	eax
		push	edx
		pushfd
		mov	dx,PORT_CGA_CAddr
		mov	al,CRTC_R14
		mov	ah,[byte high VGA_CursorPos]
		cli
		out	dx,ax
		mov	al,CRTC_R15
		mov	ah,[byte low VGA_CursorPos]
		out	dx,ax
		popfd
		pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------



		; VGATX_SetActPage - set active video page.
		; Input: BH=page number (0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; (Date: 19.11.98)
proc VGATX_SetActPage near
		cmp	bh,TxtNumVPages
		jae	vSAP_Err
		push	eax
		push	edx
		movzx	eax,bh			; Count offset in video
		shl	eax,11			; memory (CRTC format)
		mov	dx,PORT_CGA_CAddr
		pushfd				; Store interrupts state
		push	eax
		mov	al,CRTC_R12
		cli
		out	dx,ax
		pop	eax
		mov	ah,al
		mov	al,CRTC_R13
		out	dx,ax
		popfd
		pop	edx
		pop	eax
		clc
		jmp	short vSAP_Exit
vSAP_Err:	mov	ax,ERR_VID_BadVPage
		stc
vSAP_Exit:	ret
endp		;---------------------------------------------------------------



		; VGATX_Scroll - scroll screen.
		; Input: DL=number of lines by which to scroll (signed),
		;	 BH=video page (0..7).
		; Output: CF=0 - OK,
		; 	  CF=1 - error, AX=error code.
		; Notes: DL=0..24 to scroll up, -24..0 to scroll down;
		;	 scroll with attributes.
		; (Date: 20.11.98)
proc VGATX_Scroll near
		cmp	bh,TxtNumVPages
		jae	vScroll_Err
		push	ecx
		push	esi
		push	edi
		test	dl,80h
		jnz     vScroll_Dwn
		cmp	dl,TxtNumRows
		jae	vScroll_OK
		movzx	edi,bh			; Begin preparing to scroll up
		shl	edi,12			; Set EDI to begin of video page
		add	edi,[VGA_TxtMemAddr]
		movzx	esi,dl
		shl	esi,5			; Set ESI to address of line
		lea	esi,[esi*4+esi]		; which must be moved up
		add	esi,edi
		mov	cl,TxtNumRows
		sub	cl,dl
		movzx	ecx,cl			; ECX=number of scrolled lines
		shl	ecx,3
		lea	ecx,[ecx*4+ecx]		; ECX=number of moved dwords
		cld
		rep	movs [dword edi],[dword esi]
		jmp     vScroll_OK

vScroll_Dwn:    cmp	dl,(not TxtNumRows)+2
		jb	vScroll_OK
		not	dl
		inc	dl
		movzx	edi,bh
		shl	edi,12			; Set EDI to end of video page
		add	edi,[VGA_TxtMemAddr]
		add	edi,TxtNumCols*TxtNumRows*2-4
		movzx	ecx,dl
		shl	ecx,5
		lea	ecx,[ecx*4+ecx]
		mov	esi,edi			; Set ESI to end of line
		sub	esi,ecx			; which must be moved down
		mov	cl,TxtNumRows
		sub	cl,dl
		movzx	ecx,cl			; ECX=number of scrolled lines
		shl	ecx,3
		lea	ecx,[ecx*4+ecx]		; ECX=number of moved dwords
		std
		rep	movs [dword edi],[dword esi]

vScroll_OK:	pop	edi
		pop	esi
		pop	ecx
		clc
		jmp	short vScroll_Exit
vScroll_Err:	mov	ax,ERR_VID_BadVPage
		stc
vScroll_Exit:	ret
endp		;---------------------------------------------------------------



		; VGATX_WrCharXY - write character at coordinates.
		; Input: AL=character code,
		;	 AH=attribute (when CF=1)
		;	 BH=video page,
		;	 DL=column,
		;	 DH=row,
		;	 CF=0 - doesn't change attributes,
		;	 CF=1 - change attributes (AH).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; Notes: doesn't move cursor;
		;	 doesn't handle CTRL chars.
		; (Date: 21.11.98)
proc VGATX_WrCharXY near
		pushfd
		cmp	bh,TxtNumVPages
		jae	vWCXY_Err2
		cmp	dl,TxtNumCols
		jae	vWCXY_Err1
		cmp	dh,TxtNumRows
		jae	vWCXY_Err1
		popfd
		push	eax
		push	ebx
		push	ecx
		push	edx
		pushfd
		pop	ecx			; Keep flags
		shl	ecx,16			; in high word of ECX
		mov	cx,ax
		movzx	ebx,bh			; Count offset in video memory
		shl	ebx,12
		add	ebx,[VGA_TxtMemAddr]
		movzx	eax,dl
		shl	eax,1
		movzx	edx,dh			; Store column
		shl	edx,5
		lea	edx,[edx*4+edx]
		add	edx,eax			; Now EAX=row*160+column
		add	edx,ebx			; Add video page address
		mov	[byte edx],cl		; Write char
		test	ecx,10000h
		jz	vWCXY_NoAttr
		mov	[byte edx+1],ch
vWCXY_NoAttr:	pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		clc
		jmp	short vWCXY_Exit

vWCXY_Err1:	mov	ax,ERR_VID_BadCurPos
		jmp	short vWCXY_Err
vWCXY_Err2:	mov	ax,ERR_VID_BadVPage
vWCXY_Err:	popfd
		stc
vWCXY_Exit:	ret
endp		;---------------------------------------------------------------


		; VGATX_WrChar - write character at cursor position.
		; Input: AL=character code.
		; Output: none.
		; Notes: doesn't move cursor;
		;	 uses existing attributes;
		;	 doesn't handle CTRL chars.
proc VGATX_WrChar near
		push	ebx
		push	edx
		call	VGATX_GetCurPos
		clc
		call	VGATX_WrCharXY
		pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; VGATX_WrCharA - write char at cursor position with attributes.
		; Input: AL=character code,
		;	 AH=attribute.
		; Output: none.
		; Notes: doesn't move cursor;
		;	 doesn't handle CTRL chars.
proc VGATX_WrCharA near
		push	ebx
		push	edx
		call	VGATX_GetCurPos
		stc
		call	VGATX_WrCharXY
		pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------



		; VGATX_MoveCurTTY - move cursor to next position.
		; Input: none.
		; Output: none.
		; Notes: if cursor in last column, moves it to new line;
		;	 if cursor in right down corner, scroll screen.
proc VGATX_MoveCurTTY near
		push	ebx
		push	edx
                call	VGATX_GetCurPos
		inc	dl

		call	VGATX_MoveCursor
		pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------



		; VGATX_HandleCTRL - handle ASCII control characters.
		; Input: AL=character code.
		; Output: CF=0 - not CTRL code,
		;	  CF=1 - CTRL code (have been handled).
proc VGATX_HandleCTRL near
		push	ebx
		push	edx
		cmp	al,ASC_BEL
		je	vHnCTL_BEL
		cmp	al,ASC_BS
		je	vHnCTL_BS
		cmp	al,ASC_HT
		je	vHnCTL_HT
		cmp	al,ASC_VT
		je	vHnCTL_HT
		cmp	al,ASC_LF
		je	vHnCTL_LF
		cmp	al,ASC_CR
		je	vHnCTL_CR
		clc
		jmp	vHnCTL_Exit

vHnCTL_BEL:	call	SPK_Beep
		jmp	vHnCTL_Done

vHnCTL_BS:	call	VGATX_GetCurPos
		jmp	vHnCTL_Done

vHnCTL_HT:	call	VGATX_GetCurPos
		jmp	vHnCTL_Done

vHnCTL_VT:	call	VGATX_GetCurPos
		jmp	vHnCTL_Done

vHnCTL_LF:	call	VGATX_GetCurPos
		cmp	dh,TxtNumRows-1
		jne	vHnCTL_LFS
		inc	dh
		call	VGATX_MoveCursor
		jmp	vHnCTL_Done
vHnCTL_LFS:	mov	dl,1
		call	VGATX_Scroll
		jmp	vHnCTL_Done

vHnCTL_CR:	call	VGATX_GetCurPos
		xor	dl,dl
		call	VGATX_MoveCursor
		jmp	vHnCTL_Done

vHnCTL_Done:	stc
vHnCTL_Exit:	pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------



		; VGATX_WrCharTTY - write character in TTY mode.
		; Input: AL=character code,
		;	 BH=video page (0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; Notes: Writes at current cursor position, then move cursor.
		;	 Uses existing attributes.
		;	 Handle ASCII control codes.
proc VGATX_WrCharTTY near
		call	VGATX_HandleCTRL
		jc	vWCTTY_Exit
		call	VGATX_WrChar
		call	VGATX_MoveCurTTY
vWCTTY_Exit:	ret
endp		;---------------------------------------------------------------
