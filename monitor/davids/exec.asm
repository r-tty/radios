;
; EXEC.ASM
;
; Function: Handle T,G,P commands
;
	IDEAL
	P386


include "segs.asi"
include "os.asi"
include "gdt.asi"
include "prints.ase"
include "input.ase"
include "mtrap.ase"
include "breaks.ase"

TRAPFLAG = 100h			; 80386 trap enable flag

	PUBLIC go,trap, proceed

SEGMENT	seg386
;
; Wade through spaces only
;
PROC	WadeSpaceOnly
	lodsb			; Get a char
	cmp	al,' '		; Is space
	jz	WadeSpaceOnly	; Loop if so
	dec	esi		; Else point at char
	ret
ENDP	WadeSpaceOnly
;
; Execute program
;
PROC	go
	Call	WadeSpaceOnly	; Wade till address
	cmp	al,13		; CR means from this point on
	jz	short dogo	; Do it from this EIP if CR
	inc	esi		; See if is a comma
	cmp	al,','		;
	jz	short dobreak	; Only a breakpoint if so
	dec	esi		; Get the execution point
	call	ReadAddress	;
	jc	goerr		;
	mov	[reip],ebx	; Fix CS:EIP for new routine
	or	dx,dx		;
	jz	short checkbreak;
	mov	[rcs],dx	;
checkbreak:
	call	WadeSpaceOnly	; Wade
	cmp	al,13		; execute if CR
	jz	short dogo	;
	cmp	al,','		; Check for comma
	jnz	goerr		; Error if not a comma
	inc	esi		; Wade to address
	call	WadeSpaceOnly
dobreak:
	call	ReadAddress	; Read break address
	jc	goerr		; Quit if errir
	sub	eax,eax		; Break 0
	call	SetBreak	; Set the break
dogo:
	call	EnableBreaks	; Enable breaks
	xor	eax,eax		; Not trapping
	jmp	short gotrap	; Run the code
ENDP	go
;
; Limited procede, only traps through near and far direct calls
;
PROC	PROCEED
	push	fs		; Get CS:EIP in FS:EBX
	mov	fs,[rcs]	;
	mov	ebx,[reip]	;
	mov	ah,[fs:ebx]	; Load the first byte of the instruction
	pop	fs
	cmp	ah,0e8h		; Near Call?
	mov	al,5		; Yes, this is five bytes
	jz	short pgo	; And execute it
	cmp	ah,09ah		; Far call
	mov	al,7		; This one is 7 bytes
	jnz	short trap	; Not either of these, just trap
pgo:
	cbw			; EAX = bytes to skip past
	cwde			;
	add	ebx,eax		; Ebx = breakpoint
	mov	dx,[rcs]	; DX:EBX = position to break at
	sub	eax,eax		; Use the scratch breakpoint
	call	SetBreak	; Set a break
	call	EnableBreaks	; Enable breakpoints
	sub	eax,eax		; No trapping
	jmp	short gotrap	; Run the code
ENDP	PROCEED
;
; Trap command
;
PROC	trap
	mov	eax,TRAPFLAG	; Are trapping on instruction
gotrap:
	mov	esp,[rtoss]	; Load toss
	mov	ebx,cs		; See if changing priv levels
	movzx	ecx,[rcs]	;
	xor	ebx,ecx		;
	test	ebx,SEL_RPL	;
	jz	short nostack   ;
	movzx	ebx,[rss]       ; Yeah, have to put outer stack on inner stack
	push	ebx		;
	push	[resp]		;
nostack:
	or	eax,[reflags]	; Fill stack frame with FLAGS , CS:EIP
	push	eax		;
	movzx	ebx,[rcs]	;
	push	ebx		;
	push	[reip]		;
	movzx	ebx,[rds]	; Load DS last
	push	ebx		;
	movzx	eax,[res]	; Load other segs
	mov	es,eax		;
	movzx	eax,[rfs]	;
	mov	fs,eax		;
	movzx	eax,[rgs]	;
	mov	gs,eax		;
	mov	eax,[reax]	; Load regs
	mov	ebx,[rebx]	;
	mov	ecx,[recx]	;
	mov	edx,[redx]	;
	mov	esi,[resi]	;
	mov	edi,[redi]	;
	mov	ebp,[rebp]	;
	pop	ds		; Load DS
	iretd
goerr:
	stc
	ret
ENDP	TRAP
ENDS	seg386
end