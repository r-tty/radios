;-------------------------------------------------------------------------------
;  exec.nasm - handle T,P,G commands.
;-------------------------------------------------------------------------------


; --- Procedures ---

section .text

		; WadeSpaceOnly - wade through spaces only.

proc WadeSpaceOnly
.Wade:		lodsb			; Get a char
		cmp	al,' '		; Is space
		jz	.Wade		; Loop if so
		dec	esi		; Else point at char
		ret
endp		;---------------------------------------------------------------


		; MON_Go - execute program.
proc MON_Go
		call	WadeSpaceOnly	; Wade till address
		cmp	al,13		; CR means from this point on
		je	.DoGo		; Do it from this EIP if CR
		inc	esi		; See if is a comma
		cmp	al,','
		je	.Break		; Only a breakpoint if so
		dec	esi		; Get the execution point
		call	ReadAddress
		jc	.Err
		mov	[rEIP],ebx	; Fix CS:EIP for new routine
		or	dx,dx
		jz	.CheckBreak
		mov	[rCS],dx

.CheckBreak:	call	WadeSpaceOnly	; Wade
		cmp	al,13		; execute if CR
		je	.DoGo
		cmp	al,','		; Check for comma
		jne	.Err		; Error if not a comma
		inc	esi		; Wade to address
		call	WadeSpaceOnly

.Break:		call	ReadAddress	; Read break address
		jc	.Err		; Quit if error
		xor	eax,eax		; Break 0
		call	SetBreak	; Set the break

.DoGo:		call	EnableBreaks	; Enable breaks
		xor	eax,eax		; Not trapping
		jmp	GoTrace		; Run the code
.Err:		stc
		ret
endp		;---------------------------------------------------------------



		; MON_Proceed - limited proceed, only traces through
		;		and far direct calls.
proc MON_Proceed
		pushfd
		cli
		push	gs			; Get CS:EIP in GS:EBX
		mov	gs,[rCS]
		mov	ebx,[rEIP]
		mov	ah,[gs:ebx]		; Load the first byte
		pop	gs			; of the instruction
		popfd
		cmp	ah,0E8h			;  Call?
		mov	al,5			; Yes, this is five bytes
		jz	.Go			; And execute it
		cmp	ah,09Ah			; Far call
		mov	al,7			; This one is 7 bytes
		jnz	MON_Trace		; Not either of these, just trace
.Go:		cbw				; EAX = bytes to skip past
		cwde
		add	ebx,eax			; EBC = breakpoint
		mov	dx,[rCS]		; DX:EBX = position to break at
		sub	eax,eax			; Use the scratch breakpoint
		call	SetBreak		; Set a break
		call	EnableBreaks		; Enable breakpoints
		xor	eax,eax			; No trapping
		jmp	GoTrace			; Run the code
endp		;---------------------------------------------------------------


		; MON_Trace - trace command.
proc MON_Trace
		mov	eax,FLAG_TF		; Are tracing on instruction
GoTrace:	mov	esp,[rtoss]		; Load ESP
		mov	ebx,cs			; See if changing priv levels
		movzx	ecx,word [rCS]
		xor	ebx,ecx
		test	ebx,SELECTOR_RPL
		jz	.NoStack
		movzx	ebx,word [rSS]       	; Yes, have to put
		push	ebx			; outer stack on inner stack
		push	dword [rESP]
.NoStack:	or	eax,[rEFLAGS]		; Fill stack frame
		push	eax			; with FLAGS , CS:EIP
		movzx	ebx,word [rCS]
		push	ebx
		push	dword [rEIP]
		movzx	ebx,word [rDS]		; Load DS last
		push	ebx
		movzx	eax,word [rES]		; Load other segs
		mov	es,eax
		cli
		lldt	[rLDTR]
		movzx	eax,word [rFS]
		mov	fs,eax
		movzx	eax,word [rGS]
		mov	gs,eax
		mov	eax,[rEAX]		; Load regs
		mov	ebx,[rEBX]
		mov	ecx,[rECX]
		mov	edx,[rEDX]
		mov	esi,[rESI]
		mov	edi,[rEDI]
		mov	ebp,[rEBP]
		pop	ds			; Load DS
		iretd
.Err:		stc
		ret
endp		;---------------------------------------------------------------
