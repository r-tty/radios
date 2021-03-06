;-------------------------------------------------------------------------------
; disasm.nasm - disassembler routines.
;-------------------------------------------------------------------------------

%define	DEFAULTBYTES	32
%define	TAB_ARGPOS	12

externproc FindOpcode
externproc TabTo
externproc ReadOverrides, DispatchOperands, FormatDisassembly
externdata ?CodeAddress


section .bss

DisStart	RESD	1
dEnd		RESD	1
ExtraBytes	RESD	1
TheSeg		RESW	1


section .text

		; GetCodeLine - get a dissassembled line of code.
		; Input:
		; Output:
proc GetCodeLine
		locals	isnl, oldpos, put, bytestomove
		prologue

		mov	dword [%$isnl],TRUE	; Assume it has an opcode
		mov	byte [edi],0		; Clear output buffer
		mov	[%$oldpos],esi		; Current position
		test	dword [ExtraBytes],-1	; See if still printing bytes
		jz	.NotExtra		; from last instruction
		add	esi,[ExtraBytes]	; New position to EDI
		xchg	esi,edi			;
		mov	byte [esi],0		; Clear buffer
		mov	al,14			; Tab to pos 14
		call	TabTo
		xchg	esi,edi			; edi = buffer
		push	edi
		mov	ecx,4			; next four DWORDS = 0;
		xor	eax,eax			;
		push	es			; ES = DS
		push	ds
		pop	es
		cld
		rep	stosd			; Store the words
		pop	es			; Restore ES and EDI
		pop	edi
		mov	dword [%$isnl],FALSE	; Doesn't have an opcode
		jmp	.BTM

.NotExtra:	mov	eax,[?CodeAddress]	; Get code address
		cmp	eax,[dEnd]		; See if done
		jae	near .EndCodeLine	; Quit if nothing left
		xchg	esi,edi			; esi = buffer
		push	esi
		mov	eax,gs
		call	HexW2Str		; Put segment
		mov	byte [esi],':'		; Print ':'
		inc	esi
		mov	eax,[?CodeAddress]	; Get code address
		call	HexD2Str		; Print it out
		mov	byte [esi],' '		; Put a space
		inc	esi
		mov	byte [esi],0		; Put an end-of-buffer
		xchg	esi,[esp]		; esi = original buffer, stack = offset to byte dump
		mov	al,29                   ; Tab to pos 29
		call	TabTo

		xchg	esi,edi			; edi = buffer
		call	ReadOverrides		; Read any overrides
		call	FindOpcode		; Find the opcode table

		xchg	esi,edi			; esi = buffer
		jnc	.GotOpcode		; Got opcode, go format the text
		push	esi			; Else just put a DB
		mov	eax,"DB"
		mov	[esi],eax
		pop	esi
		mov	al,TAB_ARGPOS		; Tab to the arguments
		call	TabTo
		mov	al,[gs:edi]		; Put the byte out
		inc	edi			; Point to next byte
		call	HexB2Str
		mov	byte [esi],0		; End the buffer
		xchg	esi,edi
		pop	edi
		jmp	.BTM			; Go do the byte dump

.GotOpcode:	push	esi			; Got opcode, parse operands
		mov	esi,edi
		call	DispatchOperands
		mov	edi,esi
		pop	esi
		push	edi
		call	FormatDisassembly	; Use the operand parse to format output
		pop	edi
		xchg	esi,edi
		pop	edi

.BTM:		mov	byte [edi],0		; End the buffer
		mov	eax,esi			; Calculate number of bytes to dump
		sub	eax,[%$oldpos]
		mov	[%$bytestomove],eax
		mov	dword [ExtraBytes],0	; Bytes for next round = 0
		cmp	dword [%$bytestomove],5	; See if > 5
		jbe	.NotMultiline		; No, not multiline
		mov	eax,[%$bytestomove]	; Else calculate bytes left
		sub	al,5
		mov	[ExtraBytes],eax
		mov	dword [%$bytestomove],5	; Dumping 5 bytes

.NotMultiline:	xchg	esi,edi			; esi = buffer
		push	edi			; Save code pointer
 		mov	edi,[%$oldpos]		; Get original code position
		mov	ecx,[%$bytestomove]	; Get bytes to move

.PutLoop:	mov	al,[gs:edi]		; Get a byte
		call	HexB2Str		; Expand to ASCII
		mov	byte [esi],' '		; Put in a space
		inc	esi			; Next buffer pos
		inc	edi			; Next code pos
		loop	.PutLoop		; Loop till done
		xchg	esi,edi			; Restore regs
		mov	eax,[%$bytestomove]	; Codeaddress+=bytes dumped
		add	[?CodeAddress],eax

.EndCodeLine:	mov	eax,[%$isnl]		; Return new line flag
		epilogue
		ret
endp		;---------------------------------------------------------------


		; MON_Disassembly - main disassembler.
proc MON_Disassembly
		locauto	buf, DISFMTBUFSIZE
		prologue

		call	PageTrapErr		; Turn on page trapping
		call	WadeSpace		; See if any parms
		cmp	al,13
		je	.AtIndex		; No disassemble at index
		call	ReadAddress		; Else read address
		jc	near .Err		; Get out bad args
		mov	eax,DEFAULTBYTES	; Number of bytes to disassemble
		add	eax,ebx			; Find end of disassembly
		mov	[dEnd],eax		; Save it as default
		call	WadeSpace		; See if any more args
		cmp	al,13
		je	.GotArgs		; No, got args
		call	ReadNumber		; Read the end address
		jc	near .Err		; Out if bad args
		mov	[dEnd],eax		; Save end
		jmp	.GotArgs		; We have args

.AtIndex:	mov	ebx,[DisStart]		; Get the next address to disassemble
		mov	dx,[TheSeg]
		mov	eax,DEFAULTBYTES	; Default bytes to disassemble
		add	eax,ebx
		mov	[dEnd],eax		; Set up end

.GotArgs:	or	dx,dx			; If null selector, use CS
		jnz	.GotSeg
		mov	dx,[rCS]

.GotSeg:	push	ebx			; Check offset
		call	K_DescriptorAddress
		call	K_GetDescriptorLimit
		pop	ebx
		cmp	ebx,eax
		jae	near .Err
		mov	[?CodeAddress],ebx	; Save code address for printout
		mov	esi,ebx

		pushfd				; Need to keep interrupts
		cli				; disabled while using GS
		push	gs
		mov	gs,edx			; GS = the seg
		mov	[TheSeg],gs
		mPrintChar NL

.Loop:		lea	edi,[%$buf]		; Get the buffer
		call	GetCodeLine		; Get a line of text
		push	esi
		lea	esi,[%$buf]		; Print out the text
		mPrintString
		pop	esi
		mPrintChar NL			; Print a CR/LF
		mov	eax,esi			; See if done
		cmp	eax,[dEnd]
		jb	.Loop			; Loop if not
		test	dword [ExtraBytes],-1	; Loop if not done with dump
		jnz	.Loop
		mov	[DisStart],esi		; Save new start address
		pop	gs
		popfd
		mov	esi,[?CodeAddress]
		mov	[DisStart],esi
		clc
		jmp	.Exit

.Err:		stc				; Error
.Exit:		pushfd
		call	PageTrapUnerr		; Turn off page faults
		popfd
		epilogue
		ret
endp		;---------------------------------------------------------------


		; DisOneLine - disassemble one line.  Used by the Reg display command
proc DisOneLine
		locauto	buf, DISFMTBUFSIZE
		prologue
		call	PageTrapErr			; Enable page traps
		mPrintChar NL
		mov	eax,1
		add	eax,ebx				; 1 byte to disassemble
		mov	[dEnd],eax			; (will disassemble
		mov	[?CodeAddress],ebx		;  entire instruction)
		pushfd					; Need to keep interrupts
		cli					; disabled while using GS
		push	gs
		mov	gs,edx
		mov	esi,ebx

.Loop:	 	lea	edi,[%$buf]			; Get buffer
		call	GetCodeLine			; Get a line of code
		push	esi
		lea	esi,[%$buf]			; Display the line
		mPrintString
		pop	esi
		mPrintChar NL				; CR/LF
		test	dword [ExtraBytes],-1		; See if more to dump
		jnz	.Loop				; Loop if so
		mov	[DisStart],esi			; Save new index
		mov	[TheSeg],gs
		pop	gs
		popfd

		call	PageTrapUnerr			; Back to user trap
		clc					; No errors
		epilogue
		ret
endp		;---------------------------------------------------------------
