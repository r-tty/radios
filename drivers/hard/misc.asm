;-------------------------------------------------------------------------------
;  misc.asm - Miscellaneous hardware routines (speaker, CPU determination, etc.)
;-------------------------------------------------------------------------------

; --- CPU types ---
CPU_386SX		EQU	3
CPU_386DX		EQU	3
CPU_486			EQU	4
CPU_586			EQU	5

; --- Miscellaneous defines ---
SpeakerBeepTone		EQU	1200


; --- Routines ---	

		; CPU_GetType - determine type of CPU.
		; Input: none.
		; Output: CF=1 - can't determine CPU type;
		;	  CF=0 - All OK, CPU type in AL:
		;		  3 - i386 compatible,
		;		  4 - i486 compatible,
		;		  5 - Pentium compatible.
proc CPU_GetType near
		push	ebx
		mov	eax,cr0
		mov	ebx,eax			; Original CR0 into EBX
		or	al,10h			; Set bit
		mov	cr0,eax			; Store it
		mov	eax,cr0			; Read it back
		mov	cr0,ebx			; Restore CR0
		test	al,10h			; Did it set?
		jnz	@@Test386DX		; Go if not 386SX

                mov	al,CPU_386SX
                jmp	@@OK

@@Test386DX:	mov	ecx,esp			; Original ESP in ECX
		pushfd				; Original EFLAGS in EBX
		pop	ebx
		and	esp,not 3		; Align stack to prevent 486
						;  fault when AC is flipped
		mov	eax,ebx			; EFLAGS => EAX
		xor	eax,40000h		; Flip AC flag
		push	eax			; Store it
		popfd
		pushfd				; Read it back
		pop	eax
		push	ebx			; Restore EFLAGS
		popfd
		mov	esp,ecx			; Restore ESP
		cmp	eax,ebx			; Compare old/new AC bits
		jne	@@Test486		; If AC changes, not 386

		mov	al,CPU_386DX
		jmp	short @@OK

@@Test486:	mov	al,CPU_486		;Until the Pentium appears...

@@OK:		clc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; SPK_Sound - play sound signal on PC-speaker.
		; Input: ECX - sound tone (high word) and length (low word).
proc SPK_Sound near
		push	eax
		mov	al,TMRCW_Mode3+TMRCW_LH+TMRCW_CT2
		ror	ecx,16
		call	TMR_InitCounter
		call	KBC_SpeakerON
		shr	ecx,16
		call	K_TTDelay
		call	KBC_SpeakerOFF
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SPK_Beep - play ASC_BEL.
proc SPK_Beep near
		push	ecx
		mov	ecx,SpeakerBeepTone
		shl	ecx,16
		mov	cl,5
		call	SPK_Sound
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; SPK_Tick - play short sound tick.
proc SPK_Tick near
		push	eax ecx
		mov	al,TMRCW_Mode3+TMRCW_LH+TMRCW_CT2
		mov	cx,SpeakerBeepTone/4
		call	TMR_InitCounter
		call	KBC_SpeakerON
		mov	cx,5000
		call	TMR_Delay
		call	KBC_SpeakerOFF
		pop	ecx eax
		ret
endp		;---------------------------------------------------------------
