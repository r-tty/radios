;-------------------------------------------------------------------------------
;  commands.asm - monitor commands routines.
;-------------------------------------------------------------------------------


; --- Dump routines ---

		; MON_Dump - print screen portion of memory dump.
		; Input: ESI=monitor input line pointer.
		; Output: none.
proc MON_Dump near
;		call	PageTrapErr		; Enable error on page trap
		mov	ecx,DUMPLEN		; Default amount to dump
		call	WadeSpace		; Wade to end of spaces
		cmp	al,13			; If no numbers -
		jz	@@AtIndex		; use the old default
		call	ReadAddress		; Else read start address
		jc	@@Done			; Quit on error
		call	WadeSpace		; Wade through spaces
		cmp	al,13			; If no numbers -
		jz	@@DoDump		; just use default
		call	ReadNumber		; Else read end offset
		jc	@@Done
		sub	eax,ebx			; Calculate length of dump
		jc	@@DoDump		; If <0 - use default length
		mov	ecx,eax
		jmp	short @@DoDump

@@AtIndex:	mov	ebx,[DumpIndex]
		mov	dx,[DumpIndexSeg]

@@DoDump:	or	dx,dx			; If DX = null selector -
		jnz	short @@GotSel		; assume DS
		mov	dx,[rDS]

@@GotSel:	push	es
		mov	eax,offset (tRGDT).KernelData	; Kernel data  segment
		mov	es,eax				; Calculate absolute
		call	BaseAndLimit			; address and count

		mov	edi,offset WriteChar
@@DumpLoop:	mWrChar NL
		mov	eax,edx			; Print the selector
		call	K_WrHexW
		mWrChar	':'
		mov	eax,ebx
		and	eax,0FFFFFFF0h		; Address low nibble = 0
		call	K_WrHexD		; Print address
		call	DumpLine		; Dump a line
		or	ecx,ecx			; Continue while count > 0
		jg	@@DumpLoop
		mov	[DumpIndex],ebx		; Save new index value
		mov	[DumpIndexSeg],dx
		pop	es
		clc				; No errors

@@Done:		pushfd
;		call	PageTrapUnerr		; Disable page traps
		popfd
		ret
endp		;---------------------------------------------------------------


		; DumpLine - dump one line.
		; Input: EBX=address of memory block,
		;	 ECX=block bytes counter.
		; Output: EBX=address of next block,
		;	  ECX=new counter value.
proc DumpLine near
		push	edi
		push	edx
		push	ebx		; EBX MUST be on second of stack
		push	ecx		; ECX MUST be on top of stack
		xor	eax,eax
		mov	ecx,16		; Total bytes to dump
		mov	al,bl  		; AL = lower byte of address
		and	al,15		; AL = lower nibble
		jz	short @@DoLine	; Go do hexdump if start of line = 0
		neg	al		; Else calculate number of bytes in line
		add	al,16
		mov	ecx,eax		; To ECX

@@DoLine:	sub	[esp],ecx	; Decrement count which is on stack
		add	[esp+4],ecx	; Increment address which is on stack
		mov	al,16		; Get count of amount to space over
		sub	al,cl		;
		jz	short @@PutHex	; Don't space over any, just put out hex

		push	ecx		; Else ecx = spacecount * 3
		mov	ecx,eax
		add	ecx,ecx
		add	ecx,eax
@@BlankLoop1:	mWrChar ' '		; Dump spaces
		loop	@@BlankLoop1
		pop	ecx

@@PutHex:	push	ecx		; Save count and address for ASCII dump
		push	esi
		mov	edi,offset WriteChar

@@HexLoop:	cmp	cl,8
		je	@@PrintMinus
		mWrChar	' '
		jmp	short @@GetByte
@@PrintMinus:	mWrChar '-'			; Print a space
@@GetByte:	mov	al,[es:esi]		; Get the byte
		inc	esi			; Increment address pointer
		call	K_WrHexB		; Print byte in hex
		loop	@@HexLoop
		pop	esi
		pop	ecx

		mWrChar ' '			; Print two spaces
		mWrChar ' '			; to seperate ASCII dump

		sub	eax,eax			; Calculate amount
		mov	al,16			; to space over
		sub	al,cl
		jz	short @@PutASCII	; None to space over, put ascii
		push	ecx			; ECX = space value
		mov	ecx,eax
@@BlankLoop2:	mWrChar ' '			; Space over
		loop	@@BlankLoop2
		pop	ecx

@@PutASCII:	mov	al,[es:esi]		; Get char
		inc	esi			; Increment buffer
		mCallDriverCtrl [DrvId_Con],DRVCTL_DirectWrite
		loop	@@PutASCII
		pop	ecx
		pop	ebx
		pop	edx
		pop	edi
		ret
endp		;---------------------------------------------------------------


; --- View/modify registers routines ---

proc MON_Registers near
		ret
endp		;---------------------------------------------------------------


; --- Disassembler routines ---

proc MON_Disassembly near
		ret
endp		;---------------------------------------------------------------


; --- Memory modifying routines
proc MON_Enter near
		ret
endp		;---------------------------------------------------------------
