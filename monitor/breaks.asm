;-------------------------------------------------------------------------------
;  breaks.asm - handle breakpoint setting, resetting, enabling commands.
;-------------------------------------------------------------------------------


; --- Data ---
segment KVARS
BreakList	 DF 16 dup (?)		; List of breakpoints
BreakHold	 DB 16 dup (?)		; List of values where 'int 3'
					; has covered the opcode
BreakEnum	 DW	0		; Flags telling which breakpoints are set
ends

; --- Procedures ---

		; SetBreak - set a breakpoint.
proc SetBreak near
		or	dx,dx			; Null segment defaults to CS
		jnz	short @@HasBreak
		movzx	edx,[rCS]
@@HasBreak:	push	edx ebx eax
		push	gs
		push	ABSDS
		pop	gs
		call	BaseAndLimit  	; Get absolute base & limit
		push	esi		; (only base will be used).
		call	PageTrapErr	; Turn on page traps
		pop	esi		;
		mov	al,[gs:esi]	; Read the byte at the base to see if
					; its page is accessable
					; (if trap is followed, input routine
					; will be entered )
		pushfd			; Turn off page exceptions
		call	PageTrapUnerr
		popfd
		pop	gs
		pop	eax ebx edx
		and	eax,0Fh		; Set the breakpoint set bit
		bts	[BreakEnum],ax
		mov	ecx,eax		; Put the seg & offset in the BreakList
		add	eax,eax
		add	eax,ecx
		add	eax,eax
		add	eax,offset BreakList
		mov	[eax],ebx
		mov	[eax + 4],dx
		ret
endp		;---------------------------------------------------------------


		; ClearBreak - clear a breakpoint.
		; Input: AL=break number.
proc ClearBreak near
		and	eax,0Fh			; Reset the flag bit
		btr	[BreakEnum],ax
		ret
endp		;---------------------------------------------------------------


		; DisplayBreak - display a breakpoint.
proc DisplayBreak near
		and	eax,0Fh		; See if set
		bt	[BreakEnum],ax
		jnc	@@Exit		; Quit with no disp if no breakpoint set
		push	eax		; CR/LF
		mWrChar NL
		pop	eax
		push	eax
		call	PrintByteDec		; Print breakpoint #
		mWrChar	'-'			; Print '-'
		pop	eax
		mov	ebx,eax			; Get offset into
		add	ebx,ebx			; breakpoint address list
		add	ebx,eax
		add	ebx,ebx
		add	ebx,offset BreakList
		movzx	eax,[word ebx+4]	; Print segment
		call	PrintWordHex
		mWrChar ':'			; Print ':'
		mov	eax,[ebx]		; Print offset
		call	PrintDwordHex
@@Exit:		ret
endp		;---------------------------------------------------------------



		; EnableBreaks - called by GO, TRACE and PROCEED commands
		;		 to enable breakpoints.
proc EnableBreaks near
		push	gs
		push	ABSDS
		pop	gs
		mov	ecx,15			; For each breakpoint
@@Loop:		bt	[BreakEnum],cx		; If not set
		jnc	short @@NN		; Don't do anything
		mov	eax,ecx			; Else get breakpoint address
		add	eax,eax
		add	eax,ecx
		add	eax,eax
		add	eax,offset BreakList
		mov	ebx,[eax]
		movzx	edx,[word eax+4]
		push	eax             	; Calculate
		push	ecx			; absolute base & limit
		call	BaseAndLimit
		pop	ecx
		pop	eax
		mov	bl,[gs:esi]		; Get the byte at that location
		mov	[ecx+BreakHold],bl	; Save it for restore
		mov	[byte gs:esi],0CCh	; Put an int 3
@@NN:		dec	ecx			; Next breakpoint
		jns	@@Loop
		mov	eax,ecx
		pop	gs
		ret
endp		;---------------------------------------------------------------


		; DisableBreaks - called by Int 3 or Int 1 handlers
		;		  to disable breakpoints and restore the
		;		  values covered by the int 3.
proc DisableBreaks near
		push	gs
		push	ABSDS
		pop	gs
		mov	ecx,15			; For each breakpoint
@@Loop:		bt	[BreakEnum],cx		; If not set
		jnc	@@NN			; Go nothing
		mov	eax,ecx			; Else get address
		add	eax,eax
		add	eax,ecx
		add	eax,eax
		add	eax,offset BreakList
		mov	ebx,[eax]
		movzx	edx,[word eax+4]
		push	eax			; Make address absolute
		push	ecx
		call	BaseAndLimit
		pop	ecx
		pop	eax
		mov	bl,[ecx+BreakHold] 	; Restore the covered value
		mov	[gs:esi],bl
@@NN:		dec	ecx
		jns	@@Loop			; Next breakpoint
		pop	gs			;
		btr	[BreakEnum],0   	; Reset breakpoint 0
		ret				; (the automatic breakpoint)
endp		;---------------------------------------------------------------


		; MON_Breaks - handle breakpoint-related commands.
proc MON_Breaks near
		call	WadeSpace		; Wade through spaces
		cmp	al,13			; If no args
		je	@@ShowAll		; Show all breakpoints
		cmp	al,'-'			; Else check for '-'
		pushfd
		jne	short @@NoInc
		inc	esi			; Skip to next arg
		call	WadeSpace
@@NoInc:	call    ReadNumber		; Read break number
		jb	@@BadBreak2		; Exit if error
		cmp	eax,16			; Make sure in range
		jae	@@BadBreak2		; Exit if error
		or	eax,eax			; Can't do anything with
		jz	@@BadBreak2		; break #0, it's automatic
		popfd
		push	eax
		jz	short @@UnMake		; If was '-', clear break
		call	WadeSpace		; Else wade to next arg
		call	ReadAddress		; Read the bp address
		pop	eax			
		jc	short @@BadBreak	; Quit if error
		call	SetBreak		; Set breakpoint at this address
		jmp	short @@Done		; Get out

@@UnMake:	call	WadeSpace		; Wade to end
		cmp	al,13
		pop	eax
		jne	short @@BadBreak	; If there is more we have an error
		call	ClearBreak		; Clear breakpoint
		jmp	short @@Done		; Get out

@@ShowAll:      mov	ecx,15			; For each breakpoint
@@Loop:		mov	eax,ecx			; Display it if set
		call	DisplayBreak
		loop	@@Loop
@@Done:		clc				; Exit, no errors
		ret

@@BadBreak2:	pop	eax
@@BadBreak:	stc				; Exit, errors
		ret
endp		;---------------------------------------------------------------


