;
; Regs.asm
;
; Function: Handle register display and input
;
	IDEAL
	P386


include "segs.asi"
include "os.asi"
include "prints.ase"
include "mtrap.ase"
include "input.ase"
include "dis.ase"

	PUBLIC	DisplayRegisters, ModifyRegisters
SEGMENT	seg386data
;
; This is a list corresponding ASCII names for general purpose regs
; with the address the value can be found at;
;
peax	dd	reax
	db	10,"eax:",0
pebx	dd	rebx
	db	"ebx:",0
pecx	dd	recx
	db	"ecx:",0
pedx	dd	redx
	db	"edx:",0
pesi	dd	resi
	db	"esi:",0
pedi	dd	redi
	db	"edi:",0
pebp	dd	rebp
	db	10,"ebp:",0
pesp	dd	resp
	db	"esp:",0
peip	dd	reip
	db	"eip:",0
	dd	0
;
; This is a list corresponding ASCII names for segment regs with
; the address the value can be found out
;
pds	dd	rds
	db	10,"ds: ",0	
PES	dd	res
	db	"es:",0
pfs	dd	rfs
	db	"fs:",0
pgs	dd	rgs
	db	"gs:",0
Pss	dd	rss
	db	"ss:",0
pcs	dd	rcs
	db	"cs:",0
	dd	0
peflags	dd	reflags
	db	"eflags:",0
regprompt db	10,": ",0
ENDS	seg386data

SEGMENT	seg386
;
; Print a general purpose reg and it's value
;
PROC	PutDword
	lodsd			; Get pointer to val
	mov	eax,[eax]	; Get val
	push	eax		;
	mov	ebx,esi		; Get text pointer
	os	VF_TEXT		; Display register name
	pop	eax		;
	call	printdword	; Print value
	call	printspace	;
	ret
ENDP	PutDword
;
; Print a segment reg and its value
;
PROC	PutWord
	lodsd			; Get pointer to value
	mov	ax,[eax]	; Get value
	push	eax		;
	mov	ebx,esi		; Pointer to text
	os	VF_TEXT		; Print register name
	pop	eax		;
	call	printword	; Print value
	call	printspace	;
	ret
ENDP	PutWord
;
; Print either the GP regs or the SEG regs
;

PROC	PrintaFew
	call	edx		; Call the print routine
pf_lp:
	lodsb			; Wade past the text
	or	al,al		;
	jnz	pf_lp		;
	test	[dword ptr esi],-1 ; See if trailer found
	jnz	PrintAFew	; Go print another
	ret
ENDP	PrintAFew
;
; Read value for a register
;
PROC	ReadReg
    	push	es
	push	ds
	pop	es
rr2:
	mov	edi,ebx			; Point at list
	test	[dword ptr edi],-1	; See if found trailer
	jz	short rr_notfound 	; Quit if so
	add	edi,4			; Skip past value
	cmp	[byte ptr edi],10	; Skip past line feed, if exists
	jnz	short notlf		;
	inc	edi			;
notlf:
	push	ecx			; Compare specified reg name to list
	push	esi			;
	repe	cmpsb			;
	pop	esi			;
	pop	ecx			;
	jz	short rr_got		; Got it
	add	ebx,4			; Else skip past value
rr_wade:
	inc	ebx			; Skip past name
	test	[byte ptr ebx-1],-1	;
	jnz	rr_wade			;
	jmp	rr2			; Check next name
rr_got:
	add	esi,ecx         	; Point after reg name
	call	WadeSpace		; Wade through spaces
	cmp	al,13			; Don't prompt if input is here
	jnz	gotinput		;
	push	ebx			; Else put up prompt
	push	ecx			;
	MESSAGE	regPrompt		;
	call	GetInputLine		; Get input line
	pop	ecx			;
	pop	ebx			;
	call	WadeSpace		; Ignore spaces
	cmp	al,13			; See if CR
	jz	short rr_out		; Quit if so
gotinput:
	mov	ebx,[ebx]		; Get pointer to addres
	call	ReadNumber		; Read number
	jc	rr_notfound		; Error if bad number
	cmp	cl,2			; Check if is segment reg
	jz	short rr_word		; Yes, go verify it
	mov	[ebx],eax		; Else just save offset
	jmp	short rr_out		;
rr_word:
	call	VerifySel		; Verify selector
	jc	rr_notfound		; Quit if error
	mov	[ebx],ax		; Save segment
rr_out:
	clc				; Get out no errors
	pop	es
	ret
rr_notfound:
	stc				; Get out, errors
	pop	es
	ret

ENDP	ReadReg
;
; main 'Reg' command
;
PROC	ModifyRegisters
	call	wadespace		; Wade through spaces
	cmp	al,13			; If CR
	jz	short DisplayRegisters	; Display regs
	push	esi			; 
	sub	ecx,ecx			; Point at text-1
	dec	ecx			; Default count at -1
	dec	esi			;
cloop:
	inc	esi 			; Next text
	inc	ecx			; Next count
	mov	al,[esi]		; Get char
	cmp	al,13			; IF CR or SPACE
	jz	short gotend		;
	cmp	al,' '			;
	jnz	short cloop		;
gotend:
	pop	esi			; Then we have the length of reg name
	cmp	cl,2			; If 2
	jnz	short check3		;
	mov	ebx,offset pds		; Read in a segment reg
	call	ReadReg			;
	jmp	short gotdata		; End
check3:
	cmp	cl,3			; If not 3
	jnz	badreg			; Bad reg name
	mov	ebx,offset peax		; Read in a general purpose reg
	call	ReadReg			;
	jmp	short gotdata		;
badreg:
	stc				; Error
gotdata:
	ret
ENDP	ModifyRegisters
;
; Display the processor regs
;
PROC	DisplayRegisters
	mov	esi, offset peax	; Print GP regs
	mov	edx,offset PutDword	; with the DWORD function
	call	PrintAFew		; Print them
	mov	esi,offset peflags	; Put the flags
	call    PutDword		;
ifndef	USER
	mov	esi,offset pds		; Now put the segs
	mov	edx,offset PutWord	;
	call	PrintAFew		;
endif
	mov	ebx,[reip]		; Dissassemble at current code pointer
	movzx	edx,[rcs]		;
	call	DisOneLine		;
	clc
	ret
ENDP	DisplayRegisters
ENDS	seg386
END