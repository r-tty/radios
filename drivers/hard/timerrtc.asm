;-------------------------------------------------------------------------------
;  timer.asm - Timer and CMOS RTC control routines.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Counter/timer control word
TMRCW_BCD		EQU	1		; BCD counting

TMRCW_Mode0		EQU	0		; Counting modes
TMRCW_Mode1		EQU	2
TMRCW_Mode2		EQU	4
TMRCW_Mode3		EQU	6
TMRCW_Mode4		EQU	8
TMRCW_Mode5		EQU	10

TMRCW_Latch		EQU	0		; Latch value
TMRCW_LB		EQU	10h		; Low byte
TMRCW_HB		EQU	20h		; High byte
TMRCW_LH		EQU	30h		; Low & high

TMRCW_CT0		EQU	0		; Counter select
TMRCW_CT1		EQU     40h
TMRCW_CT2		EQU	80h


; --- Publics ---
		public TMR_CountCPUspeed


; --- Procedures ---

		; TMR_InitCounter - initialize counter.
		; Input: AL=control byte,
		;	 CX=divisor rate.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; (Date: 22.11.98)
proc TMR_InitCounter near
		cmp	al,0C0h			; Counter number is right?
		jae	TMRInit_Err
		push	eax
		push	edx
		out	PORT_TIMER_CTL,al
		mov	ah,al
		shr	al,6			; AL=counter number
		mov	dl,PORT_TIMER_C0
		add	dl,al
		xor	dh,dh			; DX=counter port
		test	ah,TMRCW_LB		; Write low byte?
		jz	TMRInit_WHB
		mov	al,cl
		out	dx,al
		test	ah,TMRCW_HB		; Write high byte?
		jz	TMRInit_OK
TMRInit_WHB:	mov	al,ch
		out	dx,al
TMRInit_OK:	pop	eax
		pop	edx
		clc
		jmp	TMRInit_Exit
TMRInit_Err:	mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
TMRInit_Exit:	ret
endp		;---------------------------------------------------------------


		; TMR_ReadOnFly - read counter value "on flying"
		; Input: AL=counter number (0..2),
		;	 CF=0 - read byte,
		;	 CF=1 - read word.
		; Output: CF=0 - OK, AX (AL)=read value;
		;	  CF=1 - error, AX=error code.
		; (Date: 22.11.98)
proc TMR_ReadOnFly near
		pushfd
		cmp	al,3
		jae	TMRROF_Err1
		push	edx
		mov	dx,PORT_TIMER_C0
		add	dl,al
		shl	al,7
		out     PORT_TIMER_CTL,al
		PORTDELAY
		in	al,dx
		test	[byte esp+4],1		; Read one byte?
		jz	TMRROF_OK
		xchg	al,ah
                in	al,dx
		xchg	al,ah

TMRROF_OK:	pop	edx
		popfd
		clc
		jmp	TMRROF_Exit

TMRROF_Err1:    popfd
		mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
TMRROF_Exit:	ret
endp		;---------------------------------------------------------------


		; TMR_Delay - timer delay.
		; Input: CX=number of counter 0 ticks.
		; Output: none.
		; Note: doesn't disable interrupt.
proc TMR_Delay near
		push	eax
		push	ecx
		xor	al,al
		stc
		call	TMR_ReadOnFly
		sub	ax,cx
		mov	cx,ax
TMRDEL_Loop:	xor	al,al
		stc
		call	TMR_ReadOnFly
		cmp	ax,cx
		jbe	TMRDEL_Exit
		jmp	short TMRDEL_Loop

TMRDEL_Exit:	pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; TMR_CountCPUspeed - count CPU speed rate (using counter 0)
		; Input: CX=counter 0 ticks per loop.
		; Output: ECX=CPU speed rate.
		; (Date: 23.11.98)
proc TMR_CountCPUspeed near
		push	eax
		push	ebx
		push	edx
		push	esi
		pushfd
		cli
		mov	si,cx
		xor	ebx,ebx			; EBX - previous value
		xor	eax,eax
		stc
		call	TMR_ReadOnFly
TMRCDL_Beg:	mov	cx,ax
		sub	cx,si
		xor	edx,edx			; Counter
TMRCDL_Loop:	xor	al,al
		stc
		call	TMR_ReadOnFly
		cmp	ax,cx
		jbe	TMRCDL_Check
		inc	edx
		jmp	short TMRCDL_Loop

TMRCDL_Check:	or	edx,edx
		jz	TMRCDL_Beg
		cmp	edx,ebx
		je	TMRCDL_Exit
		mov	ebx,edx
		jmp	short TMRCDL_Beg
		
TMRCDL_Exit:	mov	ecx,edx
		popfd
		pop	esi
		pop	edx
		pop	ebx
		pop	eax
		ret
endp		;---------------------------------------------------------------
