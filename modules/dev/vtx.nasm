;*******************************************************************************
;  vtx.nasm - VGA text mode driver.
;  Copyright (c) 1999 RET & COM research.
;  Font mapping procedures (c) 1995 by David Lindauer.
;*******************************************************************************

module hw.vtx

%define extcall near

%include "sys.ah"
%include "errors.ah"
%include "biosdata.ah"
%include "hw/ports.ah"
%include "hw/vga.ah"


; --- Exports ---

global DrvVTX


; --- Imports ---

library kernel.misc
extern StrCopy:extcall, StrAppend:extcall


; --- Definitions ---

%define	FNT_BytesPerChar	16
%define	FNT_Entries		256


; --- Data ---

section .data

; Video text driver main structure
DrvVTX		DB	"%videotx"
		TIMES	16-$+DrvVTX DB 0
		DD	DrvVTXET
		DW	0

; Driver entry points table
DrvVTXET	DD	VTX_Init
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	VTX_CtrlTbl

VTX_CtrlTbl	DD	VTX_GetInitStatStr
		DD	VTX_GetParameters
		DD	VTX_SetParameters
		DD	NULL
		DD	NULL
		DD	VTX_ClrVidPage
		DD	VTX_ClrLine
		DD	NULL
		DD	VTX_MoveCursor
		DD	VTX_GetCurPos
		DD	VTX_HideCursor
		DD	VTX_ShowCursor
		DD	VTX_SetActPage
		DD	VTX_Scroll
		DD	VTX_WrCharXY
		DD	VTX_WrChar
		DD	VTX_WrCharA
		DD	VTX_MoveCurNext
		DD	VTX_WrCharTTY

VTXInfStr	DB	9,": VGA, 8 video pages, 32 KB video memory",0


; --- Variables ---

section .bss

?VidMemAddr	RESD	1		; Video memory base address
?CRTCport	RESW	1		; CRT controller port
?CurrVidPg	RESB	1		; Current video page
?MaxColNum	RESB	1		; Maximum column number
?MaxRowNum	RESB	1		; Maximum row number
?CharHorSz	RESB	1		; Character vertical size (in pixels)
?CharVerSz	RESB	1		; Char. horizontal size (in pixels)
?ScanLines	RESW	1		; Number of scan lines
?CursorPos	RESW	1		; Absolute position of cursor

; --- Procedures ---

section .text

		; VTX_Init - search and initialize text-mode VGA.
		; Input: none.
		; Output: CF=0 - OK:
		;		 EAX=0,
		;		 DL=number of columns,
		;		 DH=number of rows;
		; 	  CF=1 - error, AX=error code.
		; Note: uses CRTC R1 and R6 to detect VGA port;
		;	sets page 0 active;
		;	clears pages 1-7;
		;	loads system font.
proc VTX_Init
		cmp	byte [BDA(VideoMode)],7		; Monochrome?
		je	.Mono
		mov	dword [VidMemAddr],VIDMEMCGA
		jmp	.1
.Mono:		mov	dword [VidMemAddr],VIDMEMMDA
.1:		mov	ax,[BDA(CRTCportAddr)]
		mov	[CRTCport],ax
		mov	byte [CharHorSz],8
		mov	byte [MaxRowNum],24
		push	ebx
		pushfd
		mov	dx,[CRTCport]
		mov	al,CRTC(1)
		cli
		out	dx,al
		PORTDELAY
		inc	dx
		in	al,dx				; AL=maximum column number
		PORTDELAY
		mov	[MaxColNum],al
		dec	dx
		mov	al,CRTC(9)
		out	dx,al
		PORTDELAY
		inc	dx
		in	al,dx
		PORTDELAY
		and	al,31
		inc	al				; AL=char vert. size
		mov	[CharVerSz],al
		dec	dx
		mov	al,CRTC(18)
		out	dx,al
		PORTDELAY
		inc	dx
		in	al,dx
		PORTDELAY
		mov	bl,al				; BL=low byte of
		dec	dx				; number of scan lines
		mov	al,CRTC(7)
		out	dx,al
		PORTDELAY
		inc	dx
		in	al,dx
		popfd					; Restore flags
		mov	bh,al
		and	bh,2
		shr	bh,1
		and	al,40h
		shr	al,5
		add	bh,al				; BH=high byte of
		inc	bx				; number of scan lines
		mov	[ScanLines],bx

		mov	ax,bx				; Count number of rows
		div	byte [CharVerSz]
		mov	dh,al
		mov	dl,[MaxColNum]
		inc	dl

		mov	eax,[VidMemAddr]		; Check video memory
		add	eax,7FFEh
		mov	bl,55h
		mov	[eax],bl
		mov	bh,[eax]
		cmp	bl,bh
		jne	short .Err
		mov	byte [eax],0

		push	edx
		xor	bh,bh
		call	VTX_SetActPage			; Set video page 0
		mov	dx,[BDA(CursorPos0)]		; Set cursor position
		call	VTX_MoveCursor
		pop	edx

		mov	bh,1
.ClearLoop:	mov	ah,7				; Clear pages 1-7
		stc
		call	VTX_ClrVidPage
		inc	bh
		cmp	bh,VGATXTPAGES
		jb	.ClearLoop

		xor	eax,eax

.Exit:		pop	ebx
		ret

.Err:		mov	ax,ERR_VTX_DetFail
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; VTX_GetInitStatStr - get pointer to init status string.
		; Input: ESI=string buffer.
		; Output: none.
proc VTX_GetInitStatStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,DrvVTX
		call	StrCopy
		mov	esi,VTXInfStr
		call	StrAppend
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------



		; VTX_GetParameters - get device parameters.
		; Input: none.
		; Output: DL=current video mode,
		;	  DH=cursor shape,
		;	  EBX=pointer to font table.
proc VTX_GetParameters
		ret
endp		;---------------------------------------------------------------


		; VTX_SetParameters - set video parameters.
		; Input: DL=video mode,
		;	 DH=cursor shape,
		;	 EBX=font table pointer.
proc VTX_SetParameters
		ret
endp		;---------------------------------------------------------------


		; VTX_ReadInpReg - read from VGA input register.
		; Input: AL=register number.
		; Output: AH=read data.
		; Note: DX must be set to the VGA base I/O address.
proc VTX_ReadInpReg
		out	dx,al		; Select the register
		inc	dx		; Point at data
		xchg	ah,al		; Get data
		in	al,dx
		xchg	ah,al
		dec	dx		; Reselect address register
		ret
endp		;---------------------------------------------------------------


		; VTX_MoveCursor - move cursor to specified position.
		; Input: DL=column (0..79),
		;	 DH=row (0..24),
		;	 BH=video page(0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; Notes: always keeps cursor position in CursorPos;
		;	 physically sets cursor only if it is visible.
proc VTX_MoveCursor
		cmp	bh,VGATXTPAGES
		jae	short .Err2
		cmp	dl,MODE3TXTCOLS
		jae	short .Err1
		cmp	dh,MODE3TXTROWS
		jae	short .Err1
		mpush	eax,ebx,ecx,edx

		movzx	ebx,bh			; Count offset in video
		shl	ebx,11			; memory (CRTC format)
		xor	eax,eax
		mov	al,dh
		movzx	edx,dl			; Store column
		shl	eax,4
		lea	eax,[eax*4+eax]
		add	eax,edx			; Now EAX=row*80+column
		add	eax,ebx			; Add video page address
		mov	[CursorPos],ax
		mov	cx,ax

		mov	dx,[CRTCport]
		pushfd				; Store interrupts state
		mov	al,CRTC(14)
		cli
		out	dx,al
		inc	dx
		in	al,dx
		test	al,40h
		jnz	short .Hidden
		dec	dx
		mov	al,CRTC(14)
		out	dx,ax
		mov	ah,cl
		mov	al,CRTC(15)
		out	dx,ax
.Hidden:	popfd
		mpop	edx,ecx,ebx,eax
		clc
		jmp	short .Exit

.Err1:		mov	ax,ERR_VTX_BadCurPos
		jmp	.Err
.Err2:		mov	ax,ERR_VTX_BadVPage
.Err:		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; VTX_GetCurPos - get cursor position.
		; Input: none.
		; Output: DL=column (0..79),
		;	  DH=row (0..24),
		;	  BH=video page (0..7).
		;	  CF=1 - cursor is hidden,
		;	  CF=0 - cursor is visible:
		; Note: destroys BL, high words of EBX and EDX.
proc VTX_GetCurPos
		push	eax
		pushfd				; Store interrupts state
		mov	dx,[CRTCport]
		mov	al,CRTC(14)
		cli
		out	dx,al
		inc	dx
		in	al,dx                   ; AL=HB of physical position
		popfd
		shl	al,2			; CF=0 if hidden
		lahf
		mov	bl,ah

		movzx	edx,word [CursorPos]
		mov	eax,edx
		shr	dx,11
		mov	bh,dl			; Now BH=cursor video page.
		shl	dx,11
		sub	eax,edx			; Now EAX=row*80+column
		mov	dl,MODE3TXTCOLS
		div	dl
		mov	dh,al			; Row
		mov	dl,ah			; Column

		mov	ah,bl			; Restore status of cursor
		sahf				; (visible/hidden)
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; VTX_HideCursor - hide cursor.
		; Input: none.
		; Output: none.
proc VTX_HideCursor
		push	eax
		push	edx
		pushfd
		mov	dx,[CRTCport]
		mov	ax,CRTC(14)+4000h
		cli
		out	dx,ax
		mov	ax,CRTC(15)
		out	dx,ax
		popfd
		pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; VTX_ShowCursor - show cursor.
		; Input: none.
		; Output: none.
		; Note: restores cursor position from CursorPos
proc VTX_ShowCursor
		mpush	eax,edx
		pushfd
		mov	dx,[CRTCport]
		mov	al,CRTC(14)
		mov	ah,[CursorPos+1]
		cli
		out	dx,ax
		mov	al,CRTC(15)
		mov	ah,[CursorPos]
		out	dx,ax
		popfd
		mpop	edx,eax
		ret
endp		;---------------------------------------------------------------


		; VTX_SetActPage - set active video page.
		; Input: BH=page number (0..7).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc VTX_SetActPage
		cmp	bh,VGATXTPAGES
		jae	short .Err
		mov	[CurrVidPg],bh
		mpush	eax,edx
		movzx	eax,bh			; Count offset in video
		shl	eax,11			; memory (CRTC format)
		mov	dx,[CRTCport]
		pushfd				; Keep interrupts state
		push	eax
		mov	al,CRTC(12)
		cli
		out	dx,ax
		pop	eax
		mov	ah,al
		mov	al,CRTC(13)
		out	dx,ax
		popfd
		mpop	edx,eax
		clc
		ret
.Err:		mov	ax,ERR_VTX_BadVPage
		stc
		ret
endp		;---------------------------------------------------------------


		; VTX_Scroll - scroll screen.
		; Input: DL=number of lines by which to scroll (signed),
		;	 BH=video page (0..7).
		; Output: CF=0 - OK,
		; 	  CF=1 - error, AX=error code.
		; Notes: DL=0..24 to scroll up, -24..0 to scroll down;
		;	 scrolls with attributes.
proc VTX_Scroll
		cmp	bh,VGATXTPAGES
		jae	.Err
		mpush	ecx,edx,esi,edi
		test	dl,80h
		jnz     .Down
		cmp	dl,MODE3TXTROWS
		jae	.OK
		movzx	edi,bh			; Begin preparing to scroll up
		shl	edi,12			; Set EDI to begin of video page
		add	edi,[VidMemAddr]
		movzx	esi,dl
		shl	esi,5			; Set ESI to address of line
		lea	esi,[esi*4+esi]		; which must be moved up
		add	esi,edi
		mov	cl,MODE3TXTROWS
		sub	cl,dl
		movzx	ecx,cl			; ECX=number of scrolled lines
		shl	ecx,3
		lea	ecx,[ecx*4+ecx]		; ECX=number of moved dwords
		cld
		rep	movsd
		jmp     .OK

.Down:		cmp	dl,(~MODE3TXTROWS)+2
		jb	.OK
		not	dl
		inc	dl
		movzx	edi,bh
		shl	edi,12			; Set EDI to end of video page
		add	edi,[VidMemAddr]
		add	edi,MODE3TXTCOLS*MODE3TXTROWS*2-4
		movzx	ecx,dl
		shl	ecx,5
		lea	ecx,[ecx*4+ecx]
		mov	esi,edi			; Set ESI to end of line
		sub	esi,ecx			; which must be moved down
		mov	cl,MODE3TXTROWS
		sub	cl,dl
		movzx	ecx,cl			; ECX=number of scrolled lines
		shl	ecx,3
		lea	ecx,[ecx*4+ecx]		; ECX=number of moved dwords
		std
		rep	movsd

.OK:		mpop	edi,esi,edx,ecx
		clc
		jmp	short .Exit
.Err:		mov	ax,ERR_VTX_BadVPage
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; VTX_WrCharXY - write character at coordinates.
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
proc VTX_WrCharXY
		pushfd
		cmp	bh,VGATXTPAGES
		jae	.Err2
		cmp	dl,MODE3TXTCOLS
		jae	.Err1
		cmp	dh,MODE3TXTROWS
		jae	.Err1
		popfd
		mpush	eax,ebx,ecx,edx
		pushfd
		pop	ecx			; Keep flags
		shl	ecx,16			; in high word of ECX
		mov	cx,ax
		movzx	ebx,bh			; Count offset in video memory
		shl	ebx,12
		add	ebx,[VidMemAddr]
		movzx	eax,dl
		shl	eax,1
		movzx	edx,dh			; Store column
		shl	edx,5
		lea	edx,[edx*4+edx]
		add	edx,eax			; Now EAX=row*160+column
		add	edx,ebx			; Add video page address
		mov	[edx],cl		; Write char
		test	ecx,10000h
		jz	.NoAttr
		mov	[edx+1],ch
.NoAttr:	mpop	edx,ecx,ebx,eax
		clc
		ret

.Err1:		mov	ax,ERR_VTX_BadCurPos
		jmp	short .Err
.Err2:		mov	ax,ERR_VTX_BadVPage
.Err:		popfd
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; VTX_WrChar - write character at cursor position.
		; Input: AL=character code.
		; Output: none.
		; Notes: doesn't move cursor;
		;	 uses existing attributes;
		;	 doesn't handle CTRL chars.
proc VTX_WrChar
		mpush	ebx,edx
		pushfd
		call	VTX_GetCurPos
		clc
		call	VTX_WrCharXY
		popfd
		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; VTX_WrCharA - write char at cursor position with attributes.
		; Input: AL=character code,
		;	 AH=attribute.
		; Output: none.
		; Notes: doesn't move cursor;
		;	 doesn't handle CTRL chars.
proc VTX_WrCharA
		mpush	ebx,edx
		pushfd
		call	VTX_GetCurPos
		stc
		call	VTX_WrCharXY
		popfd
		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; VTX_MoveCurNext - move cursor to next position.
		; Input: none.
		; Output: none.
		; Notes: if cursor is at last column, moves it to new line;
		;	 if cursor is at right down corner, scrolls the screen.
proc VTX_MoveCurNext
		mpush	eax,ebx,edx
                call	VTX_GetCurPos
		cmp	dl,MODE3TXTCOLS-1
		je	.NL
		inc	dl
		call	VTX_MoveCursor
		jmp	short .Exit

.NL:		xor	dl,dl
		cmp	dh,MODE3TXTROWS-1
		je	.Scrl
		inc	dh
		call	VTX_MoveCursor
		jmp	short .Exit

.Scrl:		call	VTX_MoveCursor
		mov	dl,1
		call	VTX_Scroll
		mov	bl,al			; Keep AL
		xor	al,al
		call	VTX_ClrLine
		mov	al,bl			; Restore AL
.Exit:		mpop	edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; VTX_WrCharTTY - write a char (without attributes) and move
		;		  cursor in next position.
		; Input: AL=character code.
		; Output: none.
proc VTX_WrCharTTY
		call	VTX_WrChar
		call	VTX_MoveCurNext
		ret
endp		;---------------------------------------------------------------


		; VTX_ClrLine - clear line
		; Input: AL=0 - clear entire line,
		;	 AL<>0 - clear line from cursor to end of line,
		;	 CF=0 - keep attributes,
		;	 CF=1 - use new attributes,
		;	 AH=new attributes (if CF=1).
		; Output: none.
proc VTX_ClrLine
		mpush	eax,ebx,edx
		pushfd
		call	VTX_GetCurPos
		or	al,al			; Clear from cursor?
		jnz	.Do
		xor	dl,dl
.Do:		mov	bl,ah
		xor	al,al
.Loop:		mov	ah,[esp]		; Restore flags
		sahf
		mov	ah,bl
		call	VTX_WrCharXY
		inc	dl
		cmp	dl,MODE3TXTCOLS
		jae	.Exit
		jmp	.Loop

.Exit:		popfd
		mpop	edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; VTX_ClrVidPage - clear video page.
		; Input: BH=page number,
		;	 AH=attribute (if CF=1),
		;	 CF=0 - don't change attributes,
		;	 CF=1 - change attributes (AH).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc VTX_ClrVidPage
		pushfd
		cmp	bh,VGATXTPAGES
		jae	short .Err
		mpush	eax,ebx,ecx,edi

		movzx	edi,bh			; Set EDI to begin of
		shl	edi,12			; specified video page
		add	edi,[VidMemAddr]
		mov	ecx,MODE3TXTCOLS*MODE3TXTROWS
		xor	al,al
		test	byte [esp+16],1		; Keep attributes?
		jz	short .KeepAttr

		shl	ecx,1			; Number of dwords in page
		mov	bx,ax
		shl	eax,16
		mov	ax,bx			; EAX=filled dword
		cld
		rep	stosd
		jmp	short .OK

.KeepAttr:	lea	ebx,[edi+ecx*2]
.Loop:		mov	[edi],al
		inc	edi
		inc	edi
		cmp	edi,ebx
		jae	short .OK
		jmp	.Loop

.OK:		mpop	edi,ecx,ebx,eax
		popfd
		clc
		jmp	short .Exit

.Err:		popfd
		mov	ax,ERR_VTX_BadVPage
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; VTX_MapFontMem - map font memory linearly at A0000h.
		; Input: none.
		; Output: none.
		; Note: changes stack.
proc VTX_MapFontMem
		pop	ebx				; Return address
		mov	dx,PORT_VGA_Graphics		; Select graphics controller
		mov	al,GRREG_WrMode			; Write mode will be 0
		call	VTX_ReadInpReg
		push	eax
		and	ah,0FCh
		out	dx,ax
		mov	al,GRREG_Misc			; Set mapping to 64K at A0000h
		call	VTX_ReadInpReg			; & turn off o/e at graphics controller
		push	eax
		and	ah,0F1h
		or	ah,4
		out	dx,ax
		mov	dx,PORT_VGA_Sequencer		; Get sequencer
		mov	al,SQREG_MapMask 		; Start by setting map mask reg
		call	VTX_ReadInpReg	; to plane 2
		push	eax
		mov	ah,4
		out	dx,ax
		mov	al,SQREG_Memory			; Turn Odd/Even off at the sequencer
		call	VTX_ReadInpReg
		push	eax
		or	ah,4
		out	dx,ax
		jmp	ebx
endp		;---------------------------------------------------------------


		; VTX_UnmapFontMem - unmap the font memory.
proc VTX_UnmapFontMem
		pop	ebx
		mov	dx,PORT_VGA_Sequencer	; Now popping sequencer info
		pop	eax
		out	dx,ax
		pop	eax
		out	dx,ax
		mov	dx,PORT_VGA_Graphics	; Popping graphics controller
		pop	eax			; info first
		out	dx,ax
		pop	eax
		out	dx,ax
		jmp	ebx
endp		;---------------------------------------------------------------


		; VTX_LoadFont -  load the font into VGA font memory.
		; Input: ESI=font address.
		; Output: none.
proc VTX_LoadFont
		pushad
		call	VTX_MapFontMem		; Map font memory
		mov	edi,VIDMEMVGA		; Address to load font at
		mov	ecx,FNT_Entries 	; Number of chars in font
.Loop:	 	mov	edx,ecx			; In edx
		mov	ebx,edi			; Output buffer in ebx
		mov	ecx,FNT_BytesPerChar	; Bytes to xfer per font entry
		rep	movsb			; Write the font entry
		lea	edi,[ebx+32]		; Index to next output buffer
		mov	ecx,edx			; Restore chars left to move
		loop	.Loop
		call	VTX_UnmapFontMem	; Unmap font memory
		popad
		ret
endp		;---------------------------------------------------------------

