;
; mtrap.asm
;
; Function: handle the all traps.  Int 3 and Int 1 are debug traps and
; are handled specially
	IDEAL
	P386

include "segs.asi"
include	"gdt.asi"
include "prints.ase"
include "os.asi"
include "boot.ase"
include "traps.ase"
include "regs.ase"
include "input.ase"
include "breaks.ase"

	PUBLIC	reflags,reax,rebx,recx,redx
	PUBLIC	resi,redi,rebp
	PUBLIC	resp,reip
	PUBLIC	rcs,res,rds,rss,rfs,rgs
	PUBLIC	monitor_init, CRLF, rtoss, sstoss
	PUBLIC	entry12

;
; CPU instruction trap enable flag
;
TRAPFLAG = 100h
;
; Macro which sets things up to call the generic trap handler
;
MACRO	trap	num,error,clflag
	local	notrace
entry&num:
	push	ds		; Switch to system data seg
	push	ds386
	pop	ds
	mov	[trapnum],num	; Save trapnu,
	ifnb	<error>		; If it has an error# on stack
	inc	[haserr]	; Set the error flag
	endif
	ifnb	<xclflag>	; If is int #1
	test	[dword ptr esp + 12], TRAPFLAG; See if trap is set in flags
	jz	short notrace	; No, not tracing
	or	[tracing],1	; Else set tracing flag
notrace:
	and	[dword ptr esp + 12], NOT TRAPFLAG ; Reset trap flag
	endif
	jmp	traphandler	; Jump to trap handler
ENDM	trap
SEGMENT	seg386data
;
; List of all trap handlers
;
tsvects	dd	16		; Not allowing TRAP 16 because is video int
	dd	entry0,entry1,entry2,entry3,entry4,entry5
	dd	entry6,entry7,entry8,entry9,entry10,entry11
	dd	entry12,entry13,entry14,entry15,entry16
;
; Register image
;
reflags	dd	0
reax	dd	0
rebx	dd	0
recx	dd	0
redx	dd	0
resi	dd	0
redi	dd	0
rebp	dd	0
resp	dd	0
reip	dd	0
rtoss	dd	0
sstoss	dw	0
rcs	dw	0
res	dw	0
rds	dw	0
rss	dw	0
rfs	dw	0
rgs	dw	0
;
haserr	dw	0	; If there is an error# on stack
errnum	dw	0	; The error#
trapnum	dw	0	; The trap#
tracing	db	0	; True if tracing
proctrap db	'Trap: ',0
CRLF	db	10,13,0
procErr	db	'Error: ',0
ENDS	seg386data

SEGMENT seg386
;
; Save an image of the regs
; This MUST BE the first thing the trap handler calls; it assumes
; there is ONE PUSH (return address) followed by the DS at the time
; of interrupt followed by the interrupt data
;
PROC	saveregs
	mov	[reax],eax	; Save GP regs
	mov	[rebx],ebx	;
	mov	[recx],ecx	;
	mov	[redx],edx	;
	mov	[resi],esi	;
	mov	[redi],edi	;
	mov	[rebp],ebp	;
	mov	ebp,esp		; Point BP at interrupt data
	add	ebp,4		;
	mov	ax,[ebp]	; Get the DS
	mov	[rds],ax	;
	mov	ebx,4		; Offset past this routine's return
	bt	[haserr],0	; See if an error
	jnc	short noerr	;
      	add	ebp,4		; Yes, point at eip,cs
	add	ebx,4		; Offset to eip,cs
	mov	ax,[ebp]	; Get the error #
	mov	[errnum],ax	;
noerr:
	mov	eax,[ebp + 4]	; Get CS:eip
	mov	[reip],eax	;
	mov	ax,[ebp + 8]	;
	mov	[rcs],ax	;
	mov	ax,es		; Get other segs
	mov	[res],ax	;
	mov	ax,fs		;
	mov	[rfs],ax	;
	mov	ax,gs		;
	mov	[rgs],ax	;
	mov	eax,[ebp + 12]	; Get flags
	mov	[reflags],eax	;
	add	ebx,12		; Offset past CS:eip & flags
	mov	ax,cs		; See if CS has a selector other than 0
				; ( this program runs in ring 0 )
	xor	ax,[rcs]	;
	and	ax,SEL_RPL	;
	jnz	short stackofstack; Yes, we must pull the ring x stack ptr off the ring 0 stack
	mov	ax,ss		; Otherwise just save the current
	mov	[rss],ax	; stack pointer before we started pushing
	mov	eax,ebp		; things in the trap routine
	add	eax,16		;
	mov	[resp],eax	;
	jmp	short gotstack	; Done , get out
stackofstack:
	add	ebx,8		; Offset pass SP:ESS
	mov	eax,[ebp + 16]	; Get SP:ESS from ring 0 stack
	mov	[resp],eax	;
	mov	ax,[ebp + 20]	;
	mov	[rss],ax	;
gotstack:
	ret
ENDP	saveregs
;
; Adjust EIP to the trap if it's not int 3
;
PROC	adjusteip
	cmp	[trapnum],3	; See if int 3
	jnz	short noadj	; No, get out
	push	es		; Else get CS:EIP
	push	DSABS		;
	pop	es		;
	mov	ebx,[reip]	;
	movzx	edx,[rcs]	;
	call	BaseAndLimit	; Refer to it in absolute segment
	dec	esi		;
	cmp	[byte ptr es:esi],0cch ; See if is an INT 3
	jz	short nodecrement ; Get out if so
	dec	[reip]		; Else point at trap
nodecrement:
	pop	es
noadj:
	ret
ENDP	adjusteip
;
; Generic trap handler
;
PROC	traphandler
	call	saveregs	; Save Regs
	add	esp,ebx		; Find usable top of stack
	mov	[sstoss],ss	; Save it for page error routine
	mov	[rtoss],esp	;
	test	[tracing],1	; See if tracing
	jnz	istracing	;
	call	disableBreaks	; Disable breakpoints if not
istracing:
	call	adjusteip	; Adjust the EIP to point to the breakpoint
	mov	[tracing],0	; Clear tracing flag
	Message	CRLF            ; CR/LF
	cmp     [trapnum],3	; No stats if it is int 3
	jz	short nostats	;
	cmp	[trapnum],1	; Or int 1
	jz	short nostats	;
	MESSAGE	proctrap	; Else tell it's a trap
	mov	ax,[trapnum]	; Say which one
	call	printbyte	;
	MESSAGE	CRLF		; CRLF
	btr	[haserr],0	; If has error 
	jnc	nostats		;
	MESSAGE	procErr		; Say there's an error
	mov	ax,[errnum]	; Say which one
	call	printdword
	MESSAGE CRLF		; CR/LF
nostats:
	call	DisplayRegisters; Display registers
	jmp	InputHandler	; Go do input

ENDP	traphandler
;
; Monitor init routine, point all traps to point to the monitor handler
;
PROC	monitor_init
;	mov	ebx,offset entry3
;	mov	edx,cs
;	mov	edi,3
;	call	SetTrapVect
;	mov	ebx,offset entry1
;	mov	edx,cs
;	mov	edi,1
;	call	SetTrapVect
;	ret
	mov	ecx,[tsvects]		; Get the number of vectors
	mov	esi,offset tsvects + 4	; Get the offset to the vector handlers
	mov	edi,0			; Get the initial trap #
tilp:
	lodsd				; Read a trap handler
	mov	ebx,eax			;
	mov	edx,cs			;
	call	SetTrapVect		; Set the trap
	inc	edi			; Update trap#
	loop	tilp			; Loop till done
	ret
ENDP	monitor_init
;
; Here are the individual trap handlers
;
TRAP	0
TRAP	1,,yes
TRAP	2
TRAP	3
TRAP	4
TRAP	5
TRAP	6
TRAP	7
TRAP	8,yes
TRAP	9
TRAP	10,YES
TRAP	11,YES
TRAP	12,YES
TRAP	13,YES
TRAP	14,YES
TRAP	15
TRAP	16
 

ENDS	seg386
END