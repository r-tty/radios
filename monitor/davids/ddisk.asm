;
; DDISK.ASM
;
; FUNCTION: Handle reading/writing disk blocks
;   Note: this is NOT an MS-DOS or bios read, it uses a protected mode
;   floppy driver which is an integral part of the system
;
	IDEAL
	P386

include "segs.asi"
include "input.ase"
include "os.asi"
include "mtrap.ase"
include "prints.ase"
	PUBLIC	readdisk

SEGMENT	SEG386
;
; Command to read or write from disk
;
PROC	ReadDisk	
	lodsb           	; Get char after '@'
	and	al,NOT 20h	; Make UC
	cmp	al,'W'		; Write?
	jz	short gotone	;
	cmp	al,'R'		; Read?
	jnz	short rerr	; No, error
gotone:		
	push	eax		; See if any params
	call	WadeSpace	;
	cmp	al,13		;
	pushfd			;
	sub	eax,eax		; Assume block 0
	popfd			;
	jz	short read	; Got the block#
	call	ReadNumber	; Else read in the block#
	jc	short rerr2	; Err if bad
read:
	mov	edx,eax		; Set up block and location#s
	sub	ebx,ebx		;
	mov	esi,1000h	;
	pop	eax		;
	push	ds		;
	mov	ds,[rds]	; See if read or write
	cmp	al,'W'		;
	jz	short dowrite	; Write, do it
	os	DK_READ		; Else read
	jmp	short gotreadwrite
dowrite:
	os	DK_WRITE	; Write
gotreadwrite:
	pop	ds		; See if an error
	jnc	short noerr     ; No, get out
	push	eax		; Else bring LF
	mov	dl,10		;
	os	VF_CHAR		;
	pop	eax		;
      	call	printbyte	; Print error#
noerr:
	clc			; Get out, no errors
	ret
rerr2:
	pop	eax
rerr:
	stc			; Get out, errors
	ret
ENDP	ReadDisk
ENDS	SEG386
END