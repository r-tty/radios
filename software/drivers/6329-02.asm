; ***************************************************************************
;    Robotron CM6329-02 printer support driver V1.0
;    Copyright (c) 1998 RET & COM research
; ***************************************************************************

.286
ideal

segment		CSEG 'code'
	        assume CS:CSEG; DS:CSEG;

                org 100h

start:          jmp init

; ----------------------------- Constants -----------------------------------

cESC            EQU 1Bh

BIOSDATASEG	EQU	40h
BDS_LPT1ADDR	EQU	8


; ------------------------------ TSR data -----------------------------------

KOI8rustable	DB 'Ó†°Ê§•‰£Â®©™´¨≠ÆØÔ‡·‚„¶¢ÏÎßËÌÈÁÍ'	; Russian KOI8 table
		DB 'ûÄÅñÑÖîÉïàâäãåçéèüêëíìÜÇúõáòùôóö'

GrCharsTbl	DB 'ıÙÛÚ⁄¬ø√≈¥¿¡Ÿ…ÀªÃŒπ» º’—∏∆ÿµ‘œæ÷“∑«◊∂”–Ω≥ƒ∫Õﬂ˛˝‹',0

ExtChrGen	DB 255,255,255,255,255,255,255,255
		DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255

                DB 255,255,255,255,255,255,255,255
		DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255

                DB 255,255,255,255,255,255,255,255
		DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255
                DB 255,255,255,255,255,255,255,255

OldINT17        DD 0

LastCh		DB 0			; Last printed char
GrMode		DB 0			; Using in graphics mode
RusSetON	DB 0			; Russian charset ON(1)/OFF(0)
TopR		DW 0

StatWB		DB 0

PrnAddr		DW 0

; ---------------------------- TSR procedures --------------------------------

; *** PrintGrChar - prints character, missing in printer symbol table
; *** as a graphics matrix.
; *** Character number in table in AL.
proc	PrintGrChar	near
			push	ax
			push	bx
			push	cx
			xor	ah,ah
			shl	ax,2
			mov	bx,offset ExtChrGen
			add	bx,ax

			mov	al,cESC
			call	print
			mov	al,'K'
			call	print
                        mov	al,4
			call	print
                        mov	al,0
			call	print
			mov	cx,4

	 PGCloop:	mov	al,[bx]
			call	print
			inc	bx
			loop	PGCloop
	
			pop	cx
			pop	bx
			pop	ax
			ret
endp	PrintGrChar


; ---------------------- New interrupt 17h handler ---------------------------

NewINT17:	or ah,ah
		jz PrintCharFun         ; Print character
		jmp StatCtrlFun         ; Get status and control functions


PrintCharFun:	push	ds
		push	cs		; Initialize data segment
		pop	ds

		cmp 	[GrMode],0	; Last command is "Graph mode"?
		je	PCF10		;
		jmp	NextC		; Begin handle in graphics mode

PCF10:          cmp	[TopR],0	; Graphics sequence?
		jne	PCF40		;

		cmp	[LastCh],cESC	; Last char==ESC?
		jne	PCF101
		jmp	ESCseq		; Yes, handle next char of ESC seq.

PCF101:		mov	ah,al
		cmp	al,cESC		; Begin of ESC sequence?
		jne	PCF102
		jmp	isESC		; Yes, handle it

PCF102:		xor	ah,ah
		cmp	al,' '		; Space?
		je	PCF50		; Yes, print it

		mov	ah,al
		cmp	al,80h		; Standard ASCII char (0..127) ?
		jb	PCF30		; Yes, print it

		push	bx			; Else extended ASCII char
		mov	bx,offset KOI8rustable	; (Russian or pseudo-graphics)
		mov	ah,40h			; Begin search of russian char

PCF11:          cmp	al,[bx]			; Russian char found?
		je	PCF12			; Yes, print it
		inc	bx
		inc	ah
		cmp	ah,80h
		jb	PCF11

		xor	ah,ah			; Begin search ext. chars
		mov	bx,offset GrCharsTbl
PCF_ExtSearch:	cmp	al,[bx]
		je	PCF_GrChar
		inc	bx
		inc	ah
		cmp	ah,48			; size GrCharsTbl
		jb	PCF_ExtSearch
		mov	ah,'.'
		jmp	PCF12

PCF_GrChar:	xchg	al,ah
		call	PrintGrChar
		mov	[LastCh],ah
		pop	bx
		jmp	ExitInt

PCF12:          pop	bx

PCF30:		cmp	[RusSetON],0	; Russian table is ON?
		jne	PCF31		; Yes, work with it

		cmp	al,80h		; Std ASCII?
		jb	PCF32

		call RusTbl		; Switch on russian table
		jmp PCF32

PCF31:		cmp al,80h		; Ext ASCII?
		jnc PCF32		;

		call EngTbl		; Switch on english table

PCF32:		mov al,ah
		xor ah,ah

PCF40:		cmp	[TopR],0		; All graphics symbols are printed?
		jz	PCF50
		dec	[TopR]			; Else decrease counter
		jmp	PCF60

PCF50:		mov	[LastCh],al		; Store printed char

PCF60:          call	print			; Print character
		jmp	ExitInt

NextC:		cmp	[GrMode],1		;èêéÇÖêäÄ èÖêÖïéÑÄ Ç ÉêÄîàóÖëäàâ
		jne	NextC1			;êÖÜàå

		mov	[TopR],ax		;áÄèéåçàíú åãÄÑòàâ ÅÄâí
		mov	[GrMode],3		; Ñãàçõ ëíêéäà
		jmp	PCF50

NextC1:		cmp	[GrMode],2
		jz	contr1
		cmp	[GrMode],3
		jnz	PCF60
		push	ax
		mov	ah,al
		xor	al,al
		add	[TopR],ax		;áÄèéåçàíú ëíÄêòàâ ÅÄâí
		pop	ax
		mov	[GrMode],0
		jmp	PCF50

ESCseq:         ;mov	[RusSetON],0

Contr:          cmp al,'K'			; Select graphics mode
		jz contr1
		cmp al,'L'
		jz contr1
		cmp al,'Y'
		jz contr1
		cmp al,'Z'
		jz contr1
		cmp al,'*'
		jz contr2
		cmp al,'!'
		jz one_byte			;ÅÄâí çÖ äéçíêéãàêéÇÄíú
		cmp al,'S'
		jz one_byte
		cmp al,'J'
		jz one_byte

		cmp	al,'9'			;Öëãà äéÑ ÇäãûóÖçàü äéçíêéãü
		jnz	PCF50			;ÅìåÄÉà, íé éíäãûóàíú ÖÉé
		mov	al,'8'
		jmp	PCF50

Contr1:		mov	[GrMode],1		;éÑàç ÅÄâí - êÖÜàå
		jmp	PCF50			;ÑÇÄ - ÑãàçÄ

Contr2:		mov	[GrMode],2		;ÑÇÄ ÅÄâíÄ - êÖÜàå
		jmp	PCF50			;ÑÇÄ - ÑãàçÄ

one_byte:	mov	[GrMode],0
		mov	[TopR],1
		jmp	PCF50

isESC:		mov	[LastCh],al
		call	print
		jmp	ExitInt

ExitInt:	mov	ah,0D0h			; Set exit status
		pop	ds			; Restore data segment
		iret				; Exit interrupt


; Procedures

proc	RusTbl	near			; Switch on russian table
		push	ax
		mov	[RusSetON],1
		mov	ax,cESC
		call	print
		mov	ah,0
		mov	al,'R'
		call	print
		mov	ax,1
		call	print
		pop	ax
		ret
endp	RusTbl          

proc	EngTbl	near		; Switch on english table
		push	ax
		mov	[RusSetON],0
		mov	ax,cESC
		call	print
		mov	ah,0
		mov	al,'R'
		call	print
		xor	ax,ax
		call	print
		pop	ax
		ret
endp	EngTbl

proc	Print	near
		pushf
	        mov	dx,[PrnAddr]
	        mov	ah, al
        	inc	dx
		inc	dx
		mov	al,8			; Set -S0 (-SLCT IN) signal
		out	dx,al

		dec	dx
WaitREADY:	in	al, dx
	        test	al, 80h
	        jz	WaitREADY		; Wait printer ready (AC signal)

	        dec	dx
	        mov	al,ah
	        not	al
	        out	dx,al

	        inc	dx
	        inc	dx
	        mov	al, 1		; Set SC (-STROBE) signal
	        out	dx, al

	        dec	dx
WaitBUSY:	in	al, dx
	        test	al, 80h
	        jnz	WaitBUSY

		inc	dx
		xor	al,al
		out	dx,al

	        mov	ah,0D0h
		popf
		ret
endp	Print

; --------------------- Get status and control functions --------------------

StatCtrlFun:	or	dx,dx
		jz	SCF10
		jmp	[CS:OldINT17]

SCF10:          mov	[CS:StatWB],0
                cmp	ah,1
		jz	SCF101
                mov	[CS:StatWB],1
SCF101:         mov	dx,[CS:PrnAddr]		; Function 1: initialize printer
                inc	dx			; and get status in AH
		inc	dx
		mov	al,8
		out	dx,al
		dec	dx
                in	al,dx
                or	al,10h
                test	al,40h			; If printer is off-line,
                jz	SCF11			; bit 6 = 1
                and	al,0E7h

SCF11:          test	al,20h			; If no paper, bit 5 = 0
                jnz	SCF102
                and	al,0F7h
                or	al,20h
		jmp	SCF12
SCF102:		and	al,0DFh

SCF12:          cmp	[CS:StatWB],0
                jz	SCF30
                and	al,0F8h
		xor	al,8
SCF30:          mov	ah,al
                iret


; -------------------------- Initialization code -------------------------------

init:		push	ds
		push	es
		mov	ax,cs
		mov	ds,ax
		mov	dx,offset Message	; Write message
		mov	ah,9
		int	21h

		mov	bx,BIOSDATASEG		; Get printer port address
		mov	es,bx			; from BIOS data area
		mov	dx,[ES:BDS_LPT1ADDR]
		mov	[PrnAddr],dx
		inc	dx
		mov	al,8			; Set -S0 (-SLCT IN) signal
		out	dx,al

		mov	ax,3517h		; Get old INT17h handler
		int	21h
		mov	[word low OldINT17],bx
		mov	[word high OldINT17],es

		mov	ax,2517h		; Set new INT17h handler
		mov	dx,offset NewINT17
		int	21h
		pop	es
		pop	ds

		mov	dx,offset CS:Init	; End of TSR body
		int	27h			; Terminate and stay resident

Message         DB 0Dh,0Ah
		DB 'Robotron CM6329-02 printer support driver V1.0',0Dh,0Ah
                DB 'Copyright (c) 1998 RET & COM research',0Dh,0Ah,'$'

ends		CSEG
	        end start

