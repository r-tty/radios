;
; Input.asm
;
; Function: Handle input
;
;   Handles numbers
;   Handles segments
;   Handles trapping page faults
;   Handles command input
;
	IDEAL
	P386

include "segs.asi"
include "descript.ase"
include "gdt.asi"
include "dispatch.ase"
include "os.asi"
include "boot.ase"
include "prints.ase"
include "traps.ase"
include "mtrap.ase"
include "regs.ase"
include "dump.ase"
include "entry.ase"
include "exec.ase"
include "breaks.ase"
include "ddisk.ase"
include "dis.ase"

	PUBLIC	qerr, BaseAndLimit, ReadNumber, ReadAddress, Inputhandler
	PUBLIC	wadeSpace, PageTrapErr, PageTrapUnerr, GetInputLine
	PUBLIC  VerifySel
IBSIZE = 80

SEGMENT seg386data
oldpagetrap	df	0		; Temp store for user page trap
inputbuffer db	IBSIZE DUP (?)		; Input buffer
Commands db	"@bdegpqrtu"		; List of commands
comlen	= $ - Commands			; Length of list
prompt	db	10,"* ",0		; MONITOR prompt
InvalidPaging db 10,"Invalid paging",0	; Message for page trap
ENDS	seg386data

SEGMENT seg386
;
; Print an error if command wrong
;
PROC	qerr
	MESSAGE	crlf			; Next line
	sub	esi,offset inputbuffer-2; Calculate error pos
	mov	ecx,esi			;
	jcxz	short qestart		;
	dec	ecx			;
	jcxz	short qestart		;
qelp:					
	call	printspace              ; Space over to error pos
     	loop	qelp
qestart:
	mov	dl,'^'			; Display error
	os	VF_CHAR			;
	stc				; Did an error
	ret	
ENDP	qerr
;
; If paging traps, it comes here
;
PROC	PageTrapped
	mov	ss,[sstoss]		; Get top of stack
	mov	esp,[rtoss]		;
	call	PageTrapUnerr		; Turn page trap off
	Message	InvalidPaging		; Print 'trapped' message
	jmp	InputHandler		; Go do more input
ENDP	PageTrapped
;
; Set up monitor page trap error
;
PROC	PageTrapErr
	mov	edi,14			; Get user trap interrupt
	call	GetTrapVect		;
	mov	[dword ptr oldpagetrap],ebx;
	mov	[word ptr oldpagetrap + 4],dx;
	mov	edx,cs			; Set MONITOR trap interrupt
	mov	ebx,offset PageTrapped	;
	mov	edi,14			;
	call	SetTrapVect		;
	ret
ENDP	PageTrapErr
;
; Set user page trap error ( unset monitor error)
;
PROC	PageTrapUnerr
	mov	ebx,[dword ptr oldpagetrap]	; Restore user value
	mov	dx,[word ptr oldpagetrap + 4]	;
	mov	edi,14				;
	call	SetTrapVect			;
	ret
ENDP	PageTrapUnerr
;
; Make sure a select exists and is a memory selector
;
PROC	VerifySel
	push	eax
	cmp	ax,[word ptr pgdt]		; Error if beyod GDT
	jnc	VerErr				;
	call	DescriptorAddress		; Get the descriptor base
	mov	al,[edi + DESCRIPTOR.TYPE]	; Get the type byte
	test	al,DT_PRESENT			; Error if not present
	jz	verErr				;
	test	al,DT_MEMTYPE			; Error if not a mem descript
	jz	verErr				;
ifdef	USER
	and	al,DT_DPL3			; Error if not DPL3
	cmp	al,DT_DPL3			;
	jnz	verErr
endif
	clc					; OK descriptor
	pop	eax
	ret
VerErr:
	stc					; Bad descriptor
	pop	eax
	ret
ENDP	VerifySel
;
; Get the base and limit of memory to access
;
PROC	BaseAndLimit
	mov	eax,edx			; Transfer to OS regs
	mov	esi,ebx                 
	call	DescriptorAddress	; Get descriptor offset
	call	GetDescriptorLimit	; Get it's limit and base
	call	GetDescriptorBase	;
					; EDI = base
					; EAX = limit
	sub	eax,ebx			; Calculate max length left in seg
	cmp	eax,ecx			;
	jnc	bl_ok                   ; If < user specified length
	mov	ecx,eax			; Switch to max length
bl_ok:
	add	esi,edi			; Calculate start address
	ret
ENDP	BaseAndLimit
;
; Read in a number
;
PROC	ReadNumber
	push	ebx
	sub	ebx,ebx			; Number = 0
	push	ecx
	push	edx
	sub	ecx,ecx			; digits = 0
rnlp:
	lodsb				; Get char & convert to uppercase
	cmp	al,60h
	jc	notlower
	and	al,NOT 20h
notlower:
	sub	al,'0'    		; Convert to binary
	jc	short rn_done		; < '0' is an error
	cmp	al,10			; See if is a digit
	jc	short gotdigit		; Yes, got it
	sub	al,7			; Convert letters to binary
	cmp	al,16			; Make sure is < 'G'
	jnc	short rn_done		; Quit if not
	cmp	al,10			; MAke sure not < 'A'
	jc	short rn_done
gotdigit:
	shl	ebx,4			; It is a hex digit, add in
	or	bl,al			;
	inc	ecx			; Set flag to indicate we got digits
	jmp	rnlp
rn_done:
	dec	esi			; Point at first non-digit
	test	cl,-1			; See if got any
	jnz	gotnum			;
	stc				; No, error
gotnum:
	pop	edx
	pop	ecx
	mov	eax,ebx
	pop	ebx
	ret	
ENDP	ReadNumber
;
; Read an address, composed of a number and a possible selector
;
PROC	ReadAddress
	lodsw				; Get first two bytes
	cmp	ax,'sd'			; Translate selectors to their vals
	mov	dx,[rds]		;
	jz	short gotsel		;
	cmp	ax,'se'                 ;
	mov	dx,[res]                ;
	jz	short gotsel            ;
	cmp	ax,'sf'                 ;
	mov	dx,[rfs]                ;
	jz	short gotsel            ;
	cmp	ax,'sg'                 ;
	mov	dx,[rgs]                ;
	jz	short gotsel            ;
	cmp	ax,'ss'                 ;
	mov	dx,[rss]                ;
	jz	short gotsel            ;
	cmp	ax,'sc'                 ;
	mov	dx,[rcs]                ;
	jz	short gotsel            ;
	sub	edx,edx                 ;  Not a reg selector, assume NULL selector
	dec	esi                     ; Point back at first byte
	dec	esi                     ;
	call	ReadNumber              ; Read a number
	jc	short raerr		; Quit if error
	mov	ebx,eax			; Number to EBX
	cmp	[byte ptr esi],':'	; See if is selector
	jnz	short gotaddr		; No, quit
	mov	edx,eax			; Else EDX = selector
	call	VerifySel		; Verify it
	jc	raerr			; Get out on error
getaddr:
	inc	esi			; Point past ':'
	call	ReadNumber		; Read in offset
	jc	short raerr		; Quit if error
	mov	ebx,eax			;
gotaddr:
	clc				; OK, exit
	ret
gotsel:
        cmp	[byte ptr esi],':'	; MAke sure is a selector
	jnz	short raerr		; Error if not
	mov	eax,edx			; Verify it
	call	VerifySel		;
	jc	short raerr		; Error if non-existant
	jmp	getaddr			; Go get offset
raerr:
	stc				; Error on number input
	ret
ENDP	ReadAddress
;
; Get an input line
;
PROC	GetInputLine
	push	es
	push	ds
	pop	es
	mov	edi,offset InputBuffer	; Get input buffer
	mov	esi,edi			; Return buffer pointer
	mov	ecx,IBSIZE		; Size of buffer
moreinput:
	os	KB_CHAR			; Get a key, waits for input
	cmp	al,8			; Is delete or rubout?
	jz	short bkspc		; Yes - go do it
	cmp	al,7fh			;
	jz	short bkspc		; yes - go do it
	stosb
	cmp	al,13			; Is CR
	jz	short endinput		; Yes, return
	mov	dl,al			; Echo character
	os	VF_CHAR
	loop	moreinput		; Loop till buffer full
endinput:
	pop	es
	ret
bkspc:
	cmp	edi,offset InputBuffer	; Quit if nothing in buffer
	jz	moreinput		; And get more input
	mov	dl,8			; Erase last echoed char
	os	VF_CHAR			;
	mov	dl,' '			;
	os	VF_CHAR			;
	mov	dl,8			; Reset pointer
	os	VF_CHAR			;
	dec	edi			; Point at last char
	jmp	moreinput		; Get more input
ENDP	GetInputLine
;
; Wade pasth spaces
;
PROC	WadeSpace
	lodsb				; Get char
	cmp	al,' '			; if ' ' or ',' go again
	jz	short wadeSpace		;
	cmp	al,','			;
	jz	short WadeSpace		;
	dec	esi			; Point at last space char
	ret
ENDP	WadeSpace
;
; Main Input routine
;
PROC	InputHandler
ifdef	USER
	movzx	eax,[rcs]		; Fail if in kernel
	and	al,SEL_RPL		;
	cmp	al,3			;
	jnz	$			;
endif
	MESSAGE	prompt			; Put up prompt
	call	GetInputLine		; Get an input line
	call	WadeSpace		; Wade through spaces
	cmp	al,13			; Go again if nothing typed
	jz	InputHandler		;
	inc	esi			; Point at first non-space char
	mov	edi,offset commands	; Get command list
	mov	ecx,comlen		; Length of list
	push	es			; Scan the list
	push	ds			;
	pop	es			;
	repne	scasb			;
	pop	es			;
	jnz	ierr			; Error if not in list
	mov	eax,comlen-1		; Calculate position
	sub	eax,ecx			;
	push	0			; Command arg = 0
	call	TableDispatch		; Dispatch command
	dd	comlen-1
	dd	ReadDisk
	dd	breaks
	dd	Dump
	dd	entry
	dd	go
	dd	proceed
	dd	_exit
	dd	ModifyRegisters
	dd	trap
	dd	diss
	jnc	InputHandler		; Get more input if no err
ierr:
	call	qerr			; Display error
	jmp	InputHandler		; Get more input
ENDP	InputHandler
ENDS	seg386
END