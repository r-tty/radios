;-------------------------------------------------------------------------------
; cons.nasm - basic console I/O functions.
;-------------------------------------------------------------------------------

%include "errors.ah"
%include "asciictl.ah"
%include "biosdata.ah"
%include "hw/ports.ah"
%include "hw/vga.ah"
%include "hw/8042.ah"
%include "hw/keydefs.ah"

; --- Data ---

section .data

Color		DB	7				; Foreground color

KBlayout	DB	0,27,"1234567890-=",8,9			; 00h - 0Fh
		DB	"qwertyuiop[]",13,0,"as"		; 10h - 1Fh
		DB	"dfghjkl;'`",0,"\zxcv"			; 20h - 2Fh
		DB	"bnm,./",0,"*",0,' ',0,129,130,131,132,133 ; 30h - 3Fh
		DB	134,135,136,137,138,0,0,"789-456+1"	; 40h - 4Fh
		DB	152,127,0,0,139,140,0,0,0,0,0,0,0,0,0,0	; 50h - 5Fh
		DB	13,0					; 60h - 6Fh
		
KBlayoutShift	DB	0,27,"!@#$%^&*()_+",8,9			; 00h - 0Fh
		DB	"QWERTYUIOP{}",10,0,"AS"		; 10h - 1Fh
		DB	'DFGHJKL:"~',0,"|ZXCV"			; 20h - 2Fh
		DB	"BNM<>?",0,"*",0,' ',0,129,130,131,132,133 ; 30h - 3Fh
		DB	134,135,136,137,138,0,0,"789-456+1"	; 40h - 4Fh
		DB	152,127,0,0,139,140,0,0,0,0,0,0,0,0,0,0 ; 50h - 5Fh
		DB	13,0					; 60h - 6Fh

; Service entries

%define	NUMSERVENTRIES	8

FunctionTable	DD	PrintCharRawTTY		; 0
		DD	PrintChar		; 1
		DD	PrintStr		; 2
		DD	PrintDwordHex		; 3
		DD	PrintWordHex		; 4
		DD	PrintByteHex		; 5
		DD	PrintNumDec		; 6
		DD	GetChar			; 7
		

; --- Variables ---

?VideoMem	RESD	1		; Video memory base address
?KeybFlags	RESD	1		; Keyboard flags, like Shift-press, etc

; --- Code ---

section .text

		; MoveCursor - set a cursor position.
		; Input: DL=column (0..79),
		;	 DH=row (0..24).
		; Note:	uses active video page;
		;	displays cursor only if it's inside a visible area.
proc MoveCursor
		cmp	dl,MODE3TXTCOLS
		jae	short .Err
		cmp	dh,MODE3TXTROWS
		jae	short .Err
		mpush	eax,ebx,ecx,edx

		xor	ebx,ebx
		mov	bl,[BDA(VidPageActive)]
		mov	[BDA(CursorPos0)+ebx*2],dx	; Update cursor position
		shl	ebx,11			; Now EBX=video page offset
		xor	eax,eax
		mov	al,dh
		movzx	edx,dl			; Store column
		shl	eax,4
		lea	eax,[eax*4+eax]		; *16*5 == *80
		add	eax,edx			; Now EAX=row*80+column
		add	eax,ebx			; Add video page address
		mov	cx,ax

		mov	dx,[BDA(CRTCportAddr)]
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
		ret
		
.Err:		mov	ax,ERR_VTX_BadCurPos
		stc
		ret
endp		;---------------------------------------------------------------


		; GetCusorPos - get position of the cursor for given video page.
		; Input: BH=video page.
		; Output: DL=column,
		;	  DH=row.
proc GetCursorPos
		movzx	edx,bh
		mov	dx,[BDA(CursorPos0)+edx*2]
		ret
endp		;---------------------------------------------------------------


		; MoveCursorNext - move cursor to the next position.
		; Input: BH=video page.
		; Output: none.
		; Notes: if cursor is at last column, moves it to new line;
		;	 if cursor is at right down corner, scrolls the screen.
proc MoveCursorNext
		mpush	eax,ebx,edx
		call	GetCursorPos
		cmp	dl,MODE3TXTCOLS-1
		je	.NL
		inc	dl
		call	MoveCursor
		jmp	short .Exit

.NL:		xor	dl,dl
		cmp	dh,MODE3TXTROWS-1
		je	.Scrl
		inc	dh
		call	MoveCursor
		jmp	short .Exit

.Scrl:		call	MoveCursor
		mov	dl,1
		call	Scroll
		mov	bl,al			; Keep AL
		xor	al,al
		call	ClearLine
		mov	al,bl			; Restore AL
.Exit:		mpop	edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; Scroll - scroll the screen.
		; Input: DL=number of lines by which to scroll (signed),
		;	 BH=video page.
		; Output: CF=0 - OK,
		; 	  CF=1 - error, AX=error code.
		; Notes: DL=0..24 to scroll up, -24..0 to scroll down;
		;	 scrolls with attributes.
proc Scroll
		cmp	bh,VGATXTPAGES
		jae	.Err
		mpush	ecx,edx,esi,edi
		test	dl,80h
		jnz     .Down
		cmp	dl,MODE3TXTROWS
		jae	.OK
		movzx	edi,bh			; Begin preparing to scroll up
		shl	edi,12			; Set EDI to begin of video page
		add	edi,[?VideoMem]
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
		add	edi,[?VideoMem]
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


		; ClearLine - clear a line
		; Input: AL=0 - clear entire line,
		;	 AL<>0 - clear line from cursor to the end of line,
		;	 AH=new attributes (if CF=1),
		;	 BH=video page,
		;	 CF=0 - preserve attributes,
		;	 CF=1 - use new attributes,
		; Output: none.
proc ClearLine
		mpush	eax,ebx,edx
		pushfd
		call	GetCursorPos
		or	al,al			; Clear from cursor?
		jnz	.Do
		xor	dl,dl
.Do:		mov	bl,ah
		xor	al,al
.Loop:		mov	ah,[esp]		; Restore flags
		sahf
		mov	ah,bl
		call	PrintCharXY
		inc	dl
		cmp	dl,MODE3TXTCOLS
		jae	.Exit
		jmp	.Loop

.Exit:		popfd
		mpop	edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; PrintCharXY - print a character at specified position.
		; Input: AL=character code,
		;	 AH=attribute (when CF=1)
		;	 BH=video page,
		;	 DL=column,
		;	 DH=row,
		;	 CF=0 - doesn't change attributes,
		;	 CF=1 - change attributes (AH).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc PrintCharXY
		pushfd
		cmp	bh,VGATXTPAGES
		jae	.Err2
		cmp	dl,MODE3TXTCOLS
		jae	.Err1
		cmp	dh,MODE3TXTROWS
		jae	.Err1
		xchg	ecx,[esp]		; Preserve original ECX
		mpush	eax,ebx,edx
		shl	ecx,16			; Flags in high word of ECX
		mov	cx,ax
		movzx	ebx,bh			; Count offset in video memory
		shl	ebx,12
		add	ebx,[?VideoMem]
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
.NoAttr:	mpop	edx,ebx,eax,ecx
		clc
		ret

.Err1:		mov	ax,ERR_VTX_BadCurPos
		jmp	short .Err
.Err2:		mov	ax,ERR_VTX_BadVPage
.Err:		popfd
		stc
		ret
endp		;---------------------------------------------------------------


		; PrintCharRaw - print a character at cursor position.
		; Input: AL=character code,
		;	 BH=video page.
		; Output: none.
		; Notes: doesn't move cursor;
		;	 doesn't handle CTRL chars;
		;	 uses existing attributes.
proc PrintCharRaw
		push	edx
		pushfd
		call	GetCursorPos
		clc
		call	PrintCharXY
		popfd
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; PrintCharRawTTY - print a character in "raw" TTY mode.
		; Input: AL=character.
		; Note: uses current video page.
proc PrintCharRawTTY
		push	ebx
		mov	bh,[BDA(VidPageActive)]
		call	PrintCharRaw
		call	MoveCursorNext
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; HandleControlChar - handle ASCII control characters.
		; Input: AL=character code.
		; Output: CF=0 - not CTRL code,
		;	  CF=1 - CTRL code (has been handled).
proc HandleControlChar
		mpush	ebx,edx
		mov	bh,[BDA(VidPageActive)]
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

.BEL:		call	SpeakerBeep
		jmp	.Done

.BS:		call	GetCursorPos
		or	dl,dl
		jz      short .BS_Up
		dec	dl
		call	MoveCursor
		jmp	.BS_Delete
.BS_Up:		or	dh,dh
		jz	near .Done
		dec	dh
		mov	dl,MODE3TXTCOLS-1
		call	MoveCursor
.BS_Delete:	push	eax
		mov	al,' '
		call	PrintCharRaw
		pop	eax
		jmp	.Done

.HT:		call	GetCursorPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,MODE3TXTCOLS-1
		jbe	.HT_Next
		mov	dl,MODE3TXTCOLS-1
		call	MoveCursor
		call	MoveCursorNext
		jmp	.Done
.HT_Next:	call	MoveCursor
		jmp	.Done

.VT:		jmp	short .Done

.LF:		call	GetCursorPos
		cmp	dh,MODE3TXTROWS-1
		jae	.LF_Scroll
		inc	dh
		call	MoveCursor
		jmp	short .Done

.LF_Scroll:	mov	dl,1
		call	Scroll
		push	eax
		xor	al,al
		mov	ah,[Color]
		stc
		call	ClearLine
		pop	eax
		jmp	short .Done

.CR:		call	GetCursorPos
		xor	dl,dl
		call	MoveCursor

.Done:		stc
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; SpeakerBeep - produce a short buzz.
proc SpeakerBeep
		ret
endp		;---------------------------------------------------------------


		; PrintChar - print a character in TTY mode.
		; Input: AL=character.
		; Note: basic control characters (NL, TAB, etc) are recognized.
proc PrintChar
		call	HandleControlChar
		jnc	short .NoCtrl
		cmp	al,ASC_LF
		jne	short .OK
		push	eax
		mov	al,ASC_CR
		call	HandleControlChar
		pop	eax
		jmp	short .OK
.NoCtrl:	call	PrintCharRawTTY
.OK:		clc
		ret
endp		;---------------------------------------------------------------


		; PrintStr - print ASCIIZ string.
		; Input: ESI=pointer to string.
proc PrintStr
		push	esi
		cld
.Loop:		lodsb
		or	al,al
		jz	.Done
		call	PrintChar
		jmp	.Loop
.Done:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; PrintDwordHex - print dword (EAX) in hex;
		; PrintWordHex - print word (AX) in hex;
		; PrintByteHex - print byte (AL) in hex.
		; PrintNibbleHex - print nibble (AL) in hex.
proc PrintDwordHex
		push	eax		; To print a dword
		shr	eax,16		; Print the high 16 bits
		call	PrintWordHex
		pop	eax		; And the low 16 bits
PrintWordHex:	push	eax		; To print a word
		mov	al,ah		; Print the high byte
		call	PrintByteHex
		pop	eax		; And the low byte
PrintByteHex:	push	eax		; To print a byte
		shr	eax,4		; Print the high nibble
		call	PrintNibbleHex
		pop	eax		; And the low nibble
PrintNibbleHex:	and	al,0Fh		; Get a nibble
		add	al,'0'		; Make it numeric
		cmp	al,'9'		; If supposed to be alphabetic
		jle	.Numeric
		add	al,7		; Add 7
.Numeric:	call	PrintChar
		ret
endp		;---------------------------------------------------------------


		; PrintNumDec - print 32-bit number in decimal form.
		; Input: EAX=number.
proc PrintNumDec
%define	.numbuf	ebp-20
		prologue 20
		mpush	ebx,ecx,edx,esi
		lea	esi,[.numbuf]
		mov	ebx,10
		xor	ecx,ecx
.DivLoop:	xor	edx,edx
		div	ebx
		add	dl,'0'
		mov	[esi],dl
		inc	esi
		inc	ecx
		or	eax,eax
		jnz	.DivLoop
		
.PrintLoop:	dec	esi
		mov	al,[esi]
		call	PrintChar
		loop	.PrintLoop
		mpop	esi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; GetChar - wait for a key press and return ASCII keycode.
		; Input: none.
		; Output: AL=ASCII keycode,
		;	  AH=scan code.
proc GetChar
		mpush	ebx,edx
		xor	dl,dl
.WaitLoop:	in	al,PORT_KBC_4
		test	al,KBC_P4S_OutBFull
		jz	.WaitLoop
		in	al,PORT_KBC_0
		mov	ah,al
		and	ah,7Fh
		cmp	ah,KB_LShift			; Shift pressed?
		je	.Shift
		cmp	ah,KB_RShift
		je	.Shift
		test	al,80h
		jz	.Press
		xor	dl,dl				; Ignore all release
		jmp	.WaitLoop			; codes
		
.Press:		cmp	al,dl
		je	.WaitLoop
		mov	dl,al
		mov	ebx,KBlayout
		test	byte [?KeybFlags],1
		jz	.Xlat
		mov	ebx,KBlayoutShift
		
.Xlat:		xlatb
		or	al,al
		jz	.WaitLoop
		mpop	edx,ebx
		ret
		
.Shift:		not	al
		shr	al,7				; Shift released?
		mov	[?KeybFlags],al
		jmp	.WaitLoop
endp		;---------------------------------------------------------------


		; ServiceEntry - entry used for kernel debugging.
		; Input: function code must be on the stack.
		;	 Arguments passed in the registers as usual.
		; Output: function results.
		; Note: Pascal-style (removes argument from the stack)
proc ServiceEntry
		push	ebp
		mov	ebp,esp
		push	dword .Done
		push	eax
		mov	eax,[ebp+8]
		cmp	eax,NUMSERVENTRIES
		jae	short .Done
		mov	eax,[FunctionTable+eax*4]
		xchg	eax,[esp]
		ret					; Call routine
.Done:		leave
		ret	4
endp		;---------------------------------------------------------------


		; ConsInit - prepare for console I/O.
		; Input: none.
		; Output: none.
proc ConsInit
		mov	ebx,VIDMEMCGA
		cmp	byte [BDA(VideoMode)],7		; Monochrome mode?
		jne	.1
		mov	ebx,VIDMEMMDA
.1:		mov	[?VideoMem],ebx
		ret
endp		;---------------------------------------------------------------
