;
; breaks.asm
;
; handle breakpoint setting, resetting, enabling, commands
;
	IDEAL
	P386

include "segs.asi"
include "os.asi"
include "prints.ase"
include "mtrap.ase"
include "input.ase"

	PUBLIC	setbreak, breaks, enableBreaks, disableBreaks
SEGMENT	seg386data
breaklist df 16 DUP (?)		; List of breakpoints
breakhold db 16 dup (?)		; List of values where 'int 3' has covered
				; the opcode
breakenum dw	0		; Flags telling which breakpoints are set
ENDS	seg386data
SEGMENT	seg386
;
; Command to set a breakpoint comes here
;
PROC	setbreak
	or	dx,dx		; Null segment defaults to CS
	jnz	hasbreak	;
	movzx	edx,[rcs]	;
hasbreak:
	push	edx
	push	ebx
	push	eax
	push	es
	push	DSABS
	pop	es
	call	BaseAndLimit  	; Get absolute base & limit.  We'll only use base
	push	esi
	call	PageTrapErr	; Turn on page traps
	pop	esi		;
	mov	al,[es:esi]	; Read the byte at the base to see if
				; its page is accessable
				; (if trap is followed, input routine
				; will be entered )
	pushfd			; Turn off page traps
	call	PageTrapUnerr	;
	popfd			;
	pop	es
	pop	eax
	pop	ebx
	pop	edx
	and	eax,0fh		; Set the breakpoint set bit
	bts	[breakenum],ax	;
	mov	ecx,eax		; Put the seg & offset in the breaklist
	add	eax,eax		;
	add	eax,ecx		;
	add	eax,eax		;
	add	eax,offset breaklist
	mov	[eax],ebx	;
	mov	[eax + 4],dx	;
	ret
ENDP	setbreak
;
; Command to clear a breakpoint comes here
;
PROC	clearbreak
	and	eax,0fh		; Reset the flag bit
	btr	[breakenum],ax	;
	ret
ENDP	clearbreak
;
; Command to display a breakpoint comes here
;
PROC	displaybreak
	and	eax,0fh		; See if set
	bt	[breakenum],ax	;
	jnc	short nodisplay	; Quit with no disp if no breakpoint set
	push	eax		; CR/LF
	Message	CRLF		;
	pop	eax		;
	push	eax		;
	call	printbyte	; Print breakpoint #
	mov	dl,'-'		; Print '-'
	os	VF_CHAR		;
	pop	eax		;
	mov	ebx,eax		; Get offset into breakpoint address list
	add	ebx,ebx		;
	add	ebx,eax		;
	add	ebx,ebx		;
	add	ebx,offset breaklist	;
	movzx	eax,[word ptr ebx + 4]	; Print segment
	call	printword	;
	mov	dl,':'		; Print ':'
	os	VF_CHAR		;
	mov	eax,[ebx]	; Print offset
	call	printdword      ;
nodisplay:
	ret
ENDP	displaybreak
;
; When GO or TRAP or PROCEED commands execute, they call this to
; enable breakpoints
;
PROC	enableBreaks
	push	es		; Get absolute seg in ES
	push	DSABS
	pop	es
	mov	ecx,15		; For each breakpoint
eblp:
	bt	[breakenum],cx	; If not set
	jnc	short ebnn	; Don't do anything
	mov	eax,ecx		; Else get breakpoint address
	add	eax,eax		;
	add	eax,ecx		;
	add	eax,eax		;
	add	eax,offset breaklist;
	mov	ebx,[eax]	;
	movzx	edx,[word ptr eax + 4]
	push	eax             ; Calculate absolute base & limit
	push	ecx		;
	call	BaseAndLimit	;
	pop	ecx		;
	pop	eax		;
	mov	bl,[es:esi]	; Get the byte at that location
	mov	[ecx + breakhold],bl	; Save it for restore
	mov	[byte ptr es:esi],0cch	; Put an int 3
ebnn:
	dec	ecx		; Next breakpoint
	jns	eblp		;
	mov	eax,ecx		;
	pop	es
	ret	
ENDP	enableBreaks
;
; Int 3 or int 1 call this to disable breakpoints and restore the
; values covered by the int 3
;
PROC	disableBreaks
	push	es		; Absolute segment
	push	DSABS		;
	pop	es		;
	mov	ecx,15		; For each breakpoint
dblp:
	bt	[breakenum],cx	; If not set
	jnc	short dbnn	; Go nothing
	mov	eax,ecx		; Else get address
	add	eax,eax		;
	add	eax,ecx		;
	add	eax,eax		;
	add	eax,offset breaklist	;
	mov	ebx,[eax]	;
	movzx	edx,[word ptr eax + 4]	;
	push	eax		; Make address absolute
	push	ecx		;
	call	BaseAndLimit	;
	pop	ecx		;
	pop	eax		;
	mov	bl,[ecx + breakhold] ; Restore the covered value
	mov	[es:esi],bl	;
dbnn:
	dec	ecx
	jns	dblp		; Next breakpoint
	pop	es		;
	btr	[breakenum],0   ; Reset breakpoint 0 (the automatic breakpoint)
	ret
ENDP	disableBreaks
;
; Handle breakpoint-related commands
;
PROC	breaks
	call	WadeSpace	; Wade through spaces
	cmp	al,13		; If no args
	jz	short showall	; Show all breakpoints
	cmp	al,'-'		; Else check for '-'
	pushfd			;
	jnz	noinc		;
	inc	esi		; Skip to next arg
	call	WadeSpace	;
noinc:
	call    ReadNumber	; Read break number
	jc	short badbreak2	; Exit if error
	cmp	eax,16		; Make sure in range
	jnc	short badbreak2	; Exit if error
	or	eax,eax		; Can't do anything with break #0, it's automatic
	jz	short badbreak2	;
	popfd			;
	push	eax		;
	jz	short unmake	; If was '-', clear break
	call	WadeSpace	; Else wade to next arg
	call	ReadAddress	; Read the bp address
	pop	eax		;
	jc	short badbreak	; Quit if error
	call	setbreak	; Set breakpoint at this address
	jmp	short breakdone	; Get out
unmake:
	call	WadeSpace	; Wade to end
	cmp	al,13		;
	pop	eax		;
	jnz	short badbreak	; If there is more we have an error
	call	clearbreak	; Clear breakpoint
	jmp	short breakdone	; Get out
showall:
	mov	ecx,15		; For each breakpoint
salp:
	mov	eax,ecx		; Display it if set
	call	displaybreak	;
	loop	salp		;
breakdone:
	clc			; Exit, no errors
	ret
badbreak2:
	pop	eax		;
badbreak:
	stc			; Exit, errors
	ret
ENDP	breaks	
ENDS	seg386
END