;-------------------------------------------------------------------------------
;  exec.asm - handle T,P,G commands.
;-------------------------------------------------------------------------------


		; WadeSpaceOnly - wade through spaces only.

proc WadeSpaceOnly near
@@Wade:		lodsb			; Get a char
		cmp	al,' '		; Is space
		jz	@@Wade		; Loop if so
		dec	esi		; Else point at char
		ret
endp		;---------------------------------------------------------------


		; MON_Go - execute program.
proc MON_Go near
		call	WadeSpaceOnly	; Wade till address
		cmp	al,13		; CR means from this point on
		je	short @@DoGo	; Do it from this EIP if CR
		inc	esi		; See if is a comma
		cmp	al,','		;
		je	short @@Break	; Only a breakpoint if so
		dec	esi		; Get the execution point
		call	ReadAddress
		jc	@@Err
		mov	[rEIP],ebx	; Fix CS:EIP for new routine
		or	dx,dx
		jz	short @@CheckBreak
		mov	[rCS],dx

@@CheckBreak:	call	WadeSpaceOnly	; Wade
		cmp	al,13		; execute if CR
		je	short @@DoGo
		cmp	al,','		; Check for comma
		jne	@@Err		; Error if not a comma
		inc	esi		; Wade to address
		call	WadeSpaceOnly

@@Break:	call	ReadAddress	; Read break address
		jc	short @@Err	; Quit if error
		xor	eax,eax		; Break 0
		call	SetBreak	; Set the break

@@DoGo:		call	EnableBreaks	; Enable breaks
		xor	eax,eax		; Not trapping
		jmp	short GoTrace	; Run the code
@@Err:		stc
		ret
endp		;---------------------------------------------------------------



		; MON_Proceed - limited proceed, only traces through near
		;		and far direct calls.
proc MON_Proceed near
		push	fs			; Get CS:EIP in FS:EBX
		mov	fs,[rCS]
		mov	ebx,[rEIP]
		mov	ah,[fs:ebx]		; Load the first byte
		pop	fs			; of the instruction
		cmp	ah,0E8h			; Near Call?
		mov	al,5			; Yes, this is five bytes
		jz	short @@Go		; And execute it
		cmp	ah,09Ah			; Far call
		mov	al,7			; This one is 7 bytes
		jnz	short MON_Trace		; Not either of these, just trace
@@Go:		cbw				; EAX = bytes to skip past
		cwde
		add	ebx,eax			; EBC = breakpoint
		mov	dx,[rCS]		; DX:EBX = position to break at
		sub	eax,eax			; Use the scratch breakpoint
		call	SetBreak		; Set a break
		call	EnableBreaks		; Enable breakpoints
		xor	eax,eax			; No trapping
		jmp	short GoTrace		; Run the code
endp		;---------------------------------------------------------------


		; MON_Trace - trace command.
proc MON_Trace near
		mov	eax,FLAG_TF		; Are tracing on instruction
GoTrace:	mov	esp,[rtoss]		; Load ESP
		mov	ebx,cs			; See if changing priv levels
		movzx	ecx,[rCS]
		xor	ebx,ecx
		test	ebx,SELECTOR_RPL
		jz	short @@NoStack
		movzx	ebx,[rSS]       	; Yes, have to put
		push	ebx			; outer stack on inner stack
		push	[rESP]
@@NoStack:	or	eax,[rEFLAGS]		; Fill stack frame
		push	eax			; with FLAGS , CS:EIP
		movzx	ebx,[rCS]
		push	ebx
		push	[rEIP]
		movzx	ebx,[rDS]		; Load DS last
		push	ebx
		movzx	eax,[rES]		; Load other segs
		mov	es,eax
		movzx	eax,[rFS]
		mov	fs,eax
		movzx	eax,[rGS]
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
@@Err:		stc
		ret
endp		;---------------------------------------------------------------