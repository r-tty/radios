;*******************************************************************************
;  vgatx.asm - VGA text mode control module.
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
include "vgafont.asm"			; Default 8x16 font table


; --- Variables ---
VGA_TxtMemAddr	DD	CGA_MemAddr
VGA_CursorPos	DW	0
VGAtx_TabSize	DB	8			; Unused


; --- Routines ---

;---------------------------- Module publics -----------------------------------

		public VGATX_Detect
		public VGATX_MoveCursor
		public VGATX_GetCurPos
		public VGATX_HideCursor
		public VGATX_ShowCursor
		public VGATX_SetActPage
		public VGATX_Scroll
		public VGATX_WrCharXY
		public VGATX_WrChar
		public VGATX_WrCharA
		public VGATX_MoveCurNext
		public VGATX_ClrLine
		public VGATX_ClrVidPage

;----------------------------- Routines bodies ---------------------------------

		; VGATX_Detect - check of presence text-mode VGA.
		; Input: none
		; Output: CF=0 - OK, EBX=pointer to VGA information.
		; 	  CF=1 - checking error.
		; Note: uses CRTC R15 to detect VGA port;
		;	moves cursor right on 1 position.
proc VGATX_Detect near
		push	eax
		push	edx
		mov	dx,PORT_CGA_CAddr		; Checking VGA ports
		mov	al,CRTC_R15
		out	dx,al
		PORTDELAY
		inc	dx
		in	al,dx
		dec	dx
		mov	ah,al
		inc	ah
		mov	al,CRTC_R15
		out	dx,ax
		PORTDELAY
		out	dx,al
		PORTDELAY
		inc	dx
		in	al,dx
		cmp	al,ah
		jne	vDETECT_Err
		mov	eax,0BFFFEh		; Checking VGA memory
		mov	dl,55h
		mov	[byte eax],dl
		mov	dh,[byte eax]
		cmp	dl,dh
		jne	vDETECT_Err
		mov	[byte eax],0
		clc
		jmp	short vDETECT_Exit
vDETECT_Err:	stc
vDETECT_Exit:	pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------




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
		xor	eax,eax
		mov	al,dh
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
		; Note: destroys BL, high words of EBX and EDX.
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
		; (Date: 21.11.98)
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
		; (Date: 21.11.98)
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



		; VGATX_MoveCurNext - move cursor to next position.
		; Input: none.
		; Output: none.
		; Notes: if cursor in last column, moves it to new line;
		;	 if cursor in right down corner, scroll screen.
proc VGATX_MoveCurNext near
		push	ebx
		push	edx
                call	VGATX_GetCurPos
		cmp	dl,TxtNumCols-1
		je	vMCurN_NL
		inc	dl
		call	VGATX_MoveCursor
		jmp	short vMCurN_Exit

vMCurN_NL:      xor	dl,dl
		cmp	dh,TxtNumRows-1
		je	vMCurN_Scrl
		inc	dh
		call	VGATX_MoveCursor
		jmp	short vMCurN_Exit

vMCurN_Scrl:	call	VGATX_MoveCursor
		mov	dl,1
		call	VGATX_Scroll
		mov	bl,al			; Keep AL
		xor	al,al
		call	VGATX_ClrLine
		mov	al,bl			; Restore AL
vMCurN_Exit:	pop	edx
		pop	ebx
		ret
endp		;---------------------------------------------------------------



		; VGATX_ClrLine - clear line
		; Input: AL=0 - clear entire line,
		;	 AL<>0 - clear line from cursor to end of line,
		;	 CF=0 - keep attributes,
		;	 CF=1 - use new attributes,
		;	 AH=new attributes (if CF=1).
		; Output: none.
		; (Date: 21.11.98)
proc VGATX_ClrLine near
		push	eax
		push	ebx
		push	edx
		pushfd
		call	VGATX_GetCurPos
		or	al,al			; Clear from cursor?
		jnz	vClrLine_Do
		xor	dl,dl
vClrLine_Do:	mov	bl,ah
		xor	al,al
vClrLine_Loop:	mov	ah,[byte esp]		; Restore flags
		sahf
		mov	ah,bl
		call	VGATX_WrCharXY
		inc	dl
		cmp	dl,TxtNumCols
		jae	vClrLine_Exit
		jmp	short vClrLine_Loop

vClrLine_Exit:	popfd
		pop	edx
		pop	ebx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; VGATX_ClrVidPage - clear video page.
		; Input: BH=page number,
		;	 AH=attribute (if CF=1),
		;	 CF=0 - don't change attributes,
		;	 CF=1 - change attributes (AH).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; (Date: 22.11.98)
proc VGATX_ClrVidPage near
		pushfd
		cmp	bh,TxtNumVPages
		jae	vClrVP_Err
		push	eax
		push	ebx
		push	ecx
		push	edi

		movzx	edi,bh			; Set EDI to begin of
		shl	edi,12			; specified video page
		add	edi,[VGA_TxtMemAddr]
		mov	ecx,TxtNumCols*TxtNumRows
		xor	al,al
		test	[byte esp+16],1		; Keep attributes?
		jz	vClrVP_KeepA

		shl	ecx,1			; Number of dwords in page
		mov	bx,ax
		shl	eax,16
		mov	ax,bx			; EAX=filled dword
		cld
		rep	stos [dword edi]
		jmp	short vClrVP_OK

vClrVP_KeepA:   lea	ebx,[edi+ecx*2]
vClrVP_KAloop:	mov	[byte edi],al
		inc	edi
		inc	edi
		cmp	edi,ebx
		jae	vClrVP_OK
		jmp	short vClrVP_KAloop

vClrVP_OK:	pop	edi
		pop	ecx
		pop	ebx
		pop	eax
		popfd
		clc
		jmp	vClrVP_Exit

vClrVP_Err:     popfd
		mov	ax,ERR_VID_BadVPage
		stc
vClrVP_Exit:	ret
endp		;---------------------------------------------------------------



		; DrvVideo - video device driver.
		; Action: calls video function number EAX.
proc DrvVideo near
		ret
endp