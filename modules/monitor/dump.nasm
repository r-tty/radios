;-------------------------------------------------------------------------------
;  dump.nasm - dump command handling.
;-------------------------------------------------------------------------------

; --- Definitions ---
%define	DumpDefaultLen	80h			; Default length of dump block


; --- Variables ---

section .bss

DumpIndex		RESD	1		; Offset next dump block
DumpIndexSeg		RESW	1		; Selector of next dump block


; --- Procedures ---

section .text

		; MON_Dump - print screen portion of memory dump.
		; Input: ESI=monitor input line pointer.
		; Output: CF=0 - OK,
		;	  CF=1 - error.
proc MON_Dump
		call	PageTrapErr		; Enable error on page trap
		mov	ecx,DumpDefaultLen	; Default amount to dump
		call	WadeSpace		; Wade to end of spaces
		cmp	al,13			; If no numbers -
		je	.AtIndex		; use the old default
		call	ReadAddress		; Else read start address
		jc	near .Done		; Quit on error
		call	WadeSpace		; Wade through spaces
		cmp	al,13			; If no numbers -
		jz	.DoDump			; just use default
		call	ReadNumber		; Else read end offset
		jc	near .Done
		sub	eax,ebx			; Calculate length of dump
		jc	.DoDump			; If <0 - use default length
		mov	ecx,eax
		jmp	.DoDump

.AtIndex:	mov	ebx,[DumpIndex]
		mov	dx,[DumpIndexSeg]

.DoDump:	or	dx,dx			; If DX = null selector -
		jnz	.GotSel			; assume DS
		mov	dx,[rDS]

.GotSel:	pushfd
		cli
		push	gs
		mov	eax,KERNELDATA		; Absolute segment
		mov	gs,eax			; Calculate absolute
		call	BaseAndLimit		; address and count

.DumpLoop:	mPrintChar NL
		mov	eax,edx			; Print the selector
		call	PrintWordHex
		mPrintChar ':'
		mov	eax,ebx
		and	eax,0FFFFFFF0h		; Address low nibble = 0
		call	PrintDwordHex		; Print address
		call	DumpLine		; Dump a line
		or	ecx,ecx			; Continue while count > 0
		jg	.DumpLoop
		mov	[DumpIndex],ebx		; Save new index value
		mov	[DumpIndexSeg],dx
.exit:		pop	gs
		popfd
		clc				; No errors

.Done:		pushfd
		call	PageTrapUnerr		; Disable page traps
		popfd
		ret
endp		;---------------------------------------------------------------


		; DumpLine - dump one line.
		; Input: EBX=address of memory block,
		;	 ECX=block bytes counter.
		; Output: EBX=address of next block,
		;	  ECX=new counter value.
proc DumpLine
		push	edi
		push	edx
		push	ebx		; EBX MUST be on second of stack
		push	ecx		; ECX MUST be on top of stack
		xor	eax,eax
		mov	ecx,16		; Total bytes to dump
		mov	al,bl  		; AL = lower byte of address
		and	al,15		; AL = lower nibble
		jz	.DoLine		; Go do hexdump if start of line = 0
		neg	al		; Else calculate number of bytes in line
		add	al,16
		mov	ecx,eax		; To ECX

.DoLine:	sub	[esp],ecx	; Decrement count which is on stack
		add	[esp+4],ecx	; Increment address which is on stack
		mov	al,16		; Get count of amount to space over
		sub	al,cl		;
		jz	.PutHex		; Don't space over any, just put out hex

		push	ecx		; Else ecx = spacecount * 3
		mov	ecx,eax
		add	ecx,ecx
		add	ecx,eax
.BlankLoop1:	mPrintChar ' '		; Dump spaces
		loop	.BlankLoop1
		pop	ecx

.PutHex:	push	ecx		; Save count and address for ASCII dump
		push	esi

.HexLoop:	cmp	cl,8
		je	.PrintMinus
		mPrintChar ' '
		jmp	.GetByte
.PrintMinus:	mPrintChar '-'			; Print a space
.GetByte:	mov	al,[gs:esi]		; Get the byte
		inc	esi			; Increment address pointer
		call	PrintByteHex		; Print byte in hex
		loop	.HexLoop
		pop	esi
		pop	ecx

		mPrintChar ' '			; Print two spaces
		mPrintChar			; to separate ASCII dump

		sub	eax,eax			; Calculate amount
		mov	al,16			; to space over
		sub	al,cl
		jz	.PutASCII		; None to space over, put ASCII
		push	ecx			; ECX = space value
		mov	ecx,eax
.BlankLoop2:	mPrintChar ' '			; Space over
		loop	.BlankLoop2
		pop	ecx

.PutASCII:	mov	al,[gs:esi]		; Get char
		inc	esi			; Increment buffer
		call	PrintCharRaw
		loop	.PutASCII
		pop	ecx
		pop	ebx
		pop	edx
		pop	edi
		ret
endp		;---------------------------------------------------------------

