;
; Entry.asm
;
; Function: handle hex data entry
;
	IDEAL
	P386


include "segs.asi"
include "prints.ase"
include "os.asi"
include "input.ase"
include "mtrap.ase"

	PUBLIC	entry

SEGMENT	seg386
;
; Input function for a number
;
PROC	InputNumber
	push	edx
	push	ecx
	push	ebx
	sub	ecx,ecx 		; Number of digits = 0
	sub	ebx,ebx			; Data = 0
lp:
	os	KB_CHAR			; Get a char & make UC
	cmp	al,60h
	jc	notlower
	and	al,NOT 20h
notlower:
	mov	ah,al			; AH = data
	cmp	al,' '			; Space, data is complete
	jz	short space		;
	cmp	al,13			;
	jz	short isenter		; ENTER = quit entering data
	cmp	al,8			; BACKSPACE or RUBOUT, handle it
	jz	short bckspc		;
	cmp	al,7fh			;
	jz	short bckspc		;
	sub	al,'0'			; Convert to binary, ignore if not valid
	jc	lp			;
	cmp	al,10			;
	jc	short gotdigit		;
	sub	al,7			;
	cmp	al,10			;
	jc	lp			;
	cmp	al,16			;
	jnc	lp			;
gotdigit:
	cmp	cl,2			; If got two digits don't accept
	jz	lp
	shl	bl,4			; Add in the digit
	or	bl,al			;
	mov	dl,ah			;
	os	VF_CHAR			; Echo the char
	inc	ecx			; Inc digit count
	jmp	lp			; Next digit
bckspc:
	or	ecx,ecx			; Get next digit if nothing in buffer
	jz	lp			;
	mov	dl,8			; Erase echoed char
	os	VF_CHAR			;
	mov	dl,' '			;
	os	VF_CHAR			;
	mov	dl,8			; Point at next echo space
	os	VF_CHAR			;
	dec	ecx			; Dec digit count
	jmp	lp
isenter:
	or	ecx,ecx			; Enter key, set carry and get out
	stc				;
	jmp	getout
space:
	or	ecx,ecx			; Space key, clear carry and get out
getout:
	pushfd
	mov	al,3			; Space to line up in columns
	sub	al,cl			;
	mov	cl,al			;
pslp:			
	call	printspace		;
	loop	pslp			;
	popfd				;
	mov	eax,ebx			; AX = number input
	pop	ebx
	pop	ecx
	pop	edx
	ret
ENDP	InputNumber
;
; Number entry with prompt
;
PROC	entry
	call	PageTrapErr		; Trap if no page
	call	WadeSpace		; Wade through commad spaces
	inc	esi			; Point at first non-space
	cmp	al,13			; Error if no address given
	jz	enterr
	dec	esi			;
	call	ReadAddress		; Read the address
	jc	enterr			; Bad address ,error
	or	dx,dx			; Default to DS if null selector
	jnz	short gotsel		;
	mov	dx,[rds]		;
gotsel:
	push	es			; Calculate absolute base and limit
	mov	eax,DSABS		;
	mov	es,eax			;
	mov	ecx,-1			;
	push	esi			;
	call	BaseAndLimit		;
	pop	edi			;
	xchg	esi,edi			;
	call	WadeSpace		; Wade through spaces
	cmp	al,13			; If no values specified
	jz	short prompt		; Go do prompt version
readlp:
	call	ReadNumber		; Else read number off command line
	jc	enterr2			; Quit if error
	mov	[es:edi],al		; Save value
	inc	edi			; Point to next input pos
	call	WadeSpace		; Wade through spaces
	cmp	al,13			; Quit if CR
	jz	short retok		;
	jmp	readlp			; Else get next value
prompt:
	push	ebx			; CR/LF
	Message	CRLF			;
	pop	ebx			;
	mov	eax,edx			; Print segment
	call	PrintWord		;
	push	edx			;
	mov	dl,':'			; Print ':'
	os	VF_CHAR			;
	pop	edx			;
	mov	eax,ebx                 ;
	call	PrintDWord              ; Print offset
elp:
	call	printspace		; Space over two spaces
	call	printspace		;
	mov	al,[es:edi]		; Print current value
	call	printbyte		;
	push	edx			;
	mov	dl,'.'			; Print '.'
	os	VF_CHAR			;
	pop	edx			;
	push	ecx
	call	InputNumber		; Get a number
	pop	ecx
	jz	short nextitem		; No number, go do next
	mov	[es:edi],al		; Save value
nextitem:
	jc	short retok		; Quit if ENTER key pressed
	dec	ecx			; Quit if end of segment
	jz	short retok		;
	inc	edi			; Point at next value
	inc	ebx			; Next address
	test	ebx,7			; If address mod 7 = 0
	jz	prompt			; Do another prompt
	jmp	elp
retok:
	pop	es			;
	clc				; No errors
	jmp	dudone			;
enterr2:
	pop	es
enterr:		
	stc     			; Errors
dudone:
	pushfd				; Restore user page trap
	call	PageTrapUnerr		;
	popfd				;
	ret
ENDP	entry
ENDS	seg386
END