;
; dis.asm
;
; Function: patch the dissassembly code together, display the output
;	handle disassembler commands
;
	IDEAL
	P386

include "prints.ase"
include "segs.asi"
include "os.asi"
include "remaps.ase"
include "operands.asi"
include "operands.ase"
include "opcodes.asi"
include "opcodes.ase"
include "mtrap.ase"
include "input.ase"

	PUBLIC	diss,DisOneLine

DEFAULTBYTES = 32

SEGMENT	seg386data
start	dd	0
dend	 dd	?
extraBytes dd	0
theSeg	dw	0
ENDS	seg386data
SEGMENT	seg386
	isNewLine = ebp - 4		; Local variables
	oldposition = ebp - 8
	put	= ebp -12
	bytestomove = ebp - 16
;
; Get a dissassembled line of code
;
PROC	GetCodeLine
	ENTER	16,0
	mov	[dword ptr isNewLine],TRUE ; Assume it has an opcode
	mov	[byte ptr edi],0	; Clear output buffer
	mov	[oldposition],esi	; Current position
	test	[extrabytes],-1		; See if still printing bytes
	jz	short notextra		; from last instruction
	add	esi,[extrabytes]	; New position to edi
	xchg	esi,edi			;
	mov	[byte ptr esi],0	; Clear buffer
	mov	al,14			; Tab to pos 14
	call	TabTo			;
	xchg	esi,edi			; edi = buffer
	push	edi			;
	mov	ecx,4			; next four DWORDS = 0;
	sub	eax,eax			;
	push	es			; ES = DS
	push	ds			;
	pop	es			;
	rep	stosd			; Store the words
	pop	es			; Restore ES and EDI
	pop	edi			;
	mov	[dword ptr isNewLine],False; Doesn't have an opcode
	jmp	btm
notextra:
	mov	eax,[code_address]	; Get code address
	cmp	eax,[dend]		; See if done
	jnc	endcodeline		; Quit if nothing left
	xchg	esi,edi			; esi = buffer
	push	esi			;
	mov	eax,es			;
	call	putword			; Put segment
	mov	[byte ptr esi], ':'	; Print ':'
	inc	esi			;
	mov	eax,[code_Address]	; Get code address
	call	putdword		; Print it out
	mov	[byte ptr esi],' '	; Put a space
	inc	esi			;
	mov	[byte ptr esi],0	; Put an end-of-buffer
	xchg	esi,[esp]		; esi = original buffer, stack = offset to byte dump
	mov	al,29                   ; Tab to pos 29
	call	TabTo			;
	xchg	esi,edi			; edi = buffer
	call	ReadOverrides		; Read any overrides
	call	FindOpcode		; Find the opcode table
	xchg	esi,edi			; esi = buffer
	jnc	short gotopcode		; Got opcode, go format the text
	push	esi			; Else just put a DB
	mov	ax,"db"			;
	call	put2			;
	pop	esi			;
	mov	al,TAB_ARGPOS		; Tab to the arguments
	call	TabTo			;
	mov	al,[es:edi]		; Put the byte out
	inc	edi			; Point to next byte
	call	putbyte			;
	mov	[byte ptr esi],0	; End the buffer
	xchg	esi,edi			;
	pop	edi			;
	jmp	short btm		; Go do the byte dump
gotopcode:
	push	esi			; Got opcode, parse operands
	mov	esi,edi			;
	call	DispatchOperands	;
	mov	edi,esi			;
	pop	esi			;
	push	edi			;
	call	FormatDisassembly	; Use the operand parse to format output
	pop	edi			;
	xchg	esi,edi			;
	pop	edi			;
btm:
	mov	[byte ptr edi],0	; End the buffer
	mov	eax,esi			; Calculate number of bytes to dump
	sub	eax,[oldposition]	;
	mov	[bytestomove],eax	;
	mov	[extrabytes],0		; Bytes for next round = 0
	cmp	[dword ptr bytestomove],5; See if > 5
	jbe	short notmultiline	; No, not multiline
	mov	eax,[bytestomove]	; Else calculate bytes left
	sub	al,5			;
	mov	[extrabytes],eax	;
	mov	[dword ptr bytestomove],5; Dumping 5 bytes
notmultiline:
	xchg	esi,edi			; esi = buffer
	push	edi			; Save code pointer
 	mov	edi,[oldposition]	; Get original code position
	mov	ecx,[bytestomove]	; Get bytes to move
putlp:
	mov	al,[es:edi]		; Get a byte
	call	putbyte			; Expand to ASCII
	mov	[byte ptr esi],' '	; Put in a space
	inc	esi			; Next buffer pos
	inc	edi			; Next code pos
	LOOP	putlp			; Loop till done
	xchg	esi,edi			; Restore regs
	mov	eax,[bytestomove]	; Codeaddress+=bytes dumped
	add	[code_address],eax	;
endcodeline:
	mov	eax,[isNewLine]		; Return new line flag
	LEAVE				;
	ret
ENDP	GetCodeLine
;
; Main disassembler
;
PROC	diss
	ENTER	256,0			; Buffer = 256 bytes long
	call	MapStackToSystem	; Map stack into system segment
					; This is done so DS = SS and
					; stack parms will be useful
	call	PageTrapErr		; Turn on page trapping
	Message	CRLF			; CR/LF
	call	WadeSpace		; See if any parms
	cmp	al,13			;
	jz	short atindex		; No disassemble at index
	call	ReadAddress		; Else read address
	jc	badargs			; Get out bad args
	mov	eax,DEFAULTBYTES	; Number of bytes to disassemble
	add	eax,ebx			; Find end of disassembly
	mov	[dend],eax		; Save it as default
	call	WadeSpace		; See if any more args
	cmp	al,13			;
	jz	short gotargs		; No, got args
	call	ReadNumber		; Read the end address
	jc	short badargs           ; Out if bad args
	mov	[dend],eax		; Save end
	jmp	short gotargs		; We have args
badargs:
	stc				; Error
	call	PageTrapUnerr		; Turn off page faults
	call	UnmapStack		; Unmap stack
	stc
	LEAVE
	ret
atindex:
	mov	ebx,[start]		; Get the next address to disassemble
	mov	dx,[theseg]		;
	mov	eax,DEFAULTBYTES	; Default bytes to disassemble
	add	eax,ebx			;
	mov	[dend],eax		; Set up end
gotargs:
	or	dx,dx			; If null selector, use CS
	jnz	short gotseg		;
	mov	dx,[rcs]		;
gotseg:
	mov	[code_address],ebx	; Save code address for printout
	mov	esi,ebx			;
	push	es			;
	mov	es,edx			; ES = the seg
	mov	[theseg],es		;
gcloop:
	lea	edi,[ebp - 256]		; Get the buffer
	call	GetCodeLine		; Get a line of text
	lea	ebx,[ebp - 256]		; Print out the text
	os	vf_text			;
	MESSAGE	CRLF			; Print a CR/LF
	mov	eax,esi			; See if done
	cmp	eax,[dend]		;
	jc	gcloop			; Loop if not
	test	[extrabytes],-1		; Loop if not done with dump
	jnz	gcloop			;
	mov	[start],esi		; Save new start address
	pop	es			;
	mov	esi,[code_address]	;
	mov	[start],esi		;
	call	PageTrapUnerr		; Turn off page traps
	call	UnmapStack		; Unmap stack
	clc
	LEAVE
	ret
ENDP	diss
;
; Disassemble one line.  Used by the Reg display command
;
DOLP_EBX = ebp-4
DOLP_EDX = ebp-8
PROC	DisOneLine
	ENTER	256,0			; Space for buffer
	call	MapStackToSystem	; Map stack to system
	push	ebx
	push	edx
	call	PageTrapErr		; Enable page traps
	MESSAGE	CRLF			; CR/LF
	pop	edx
	pop	ebx
	mov	eax,1
	add	eax,ebx			; One byte to disassemble
	mov	[dend],eax		; ( will disassemble entire instruction)
	mov	[code_address],ebx	;
	push	es
	mov	es,edx
	mov	esi,ebx
dol_loop:
	lea	edi,[ebp - 256]		; Get buffer
	call	GetCodeLine		; Get a line of code
	lea	ebx,[ebp -256]		; Display the line
	os	vf_text			;
	MESSAGE	CRLF			; CR/LF
	test	[extrabytes],-1		; See if more to dump
	jnz	dol_loop		; Loop if so
	mov	[start],esi		; Save new index
	mov	[theSeg],es		;
	pop	es
	Call	PageTrapUnerr		; Back to user trap
	call	UnmapStack		; Unmap stack
	clc				; No errors
	leave
	ret
ENDP	DisOneLine
ENDS	seg386
END