;-------------------------------------------------------------------------------
;  timer.asm - Programmable interval timer control routines.
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


; --- Procedures ---

		; TMR_InitCounter - initialize counter.
		; Input: AL=control byte,
		;	 CX=divisor rate.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
		; (Date: 22.11.98)
proc TMR_InitCounter near
		cmp	al,0C0h			; Counter number is right?
		jae	short @@Err
		push	eax edx
		out	PORT_TIMER_CTL,al
		mov	ah,al
		shr	al,6			; AL=counter number
		mov	dl,PORT_TIMER_C0
		add	dl,al
		xor	dh,dh			; DX=counter port
		test	ah,TMRCW_LB		; Write low byte?
		jz	short @@WrHiByte
		mov	al,cl
		out	dx,al
		test	ah,TMRCW_HB		; Write high byte?
		jz	short @@OK
@@WrHiByte:	mov	al,ch
		out	dx,al
@@OK:		pop	edx eax
		clc
		ret
@@Err:		mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
		ret
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
		jae	short @@Error
		push	edx
		mov	dx,PORT_TIMER_C0
		add	dl,al
		shl	al,7
		out     PORT_TIMER_CTL,al
		PORTDELAY
		in	al,dx
		test	[byte esp+4],1		; Read one byte?
		jz	short @@OK
		xchg	al,ah
                in	al,dx
		xchg	al,ah

@@OK:		pop	edx
		popfd
		clc
		ret

@@Error:	popfd
		mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
@@Exit:		ret
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
		sbb	ax,cx
		mov	cx,ax
@@Loop:		xor	al,al
		stc
		call	TMR_ReadOnFly
		cmp	ax,cx
		jbe	short @@Exit
		jmp	@@Loop

@@Exit:		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; TMR_DelayLong - long timer delay.
		; Input: ECX=number of counter 0 ticks * 10000h
		; Output:none.
proc TMR_DelayLong near
		push	edx
		mov	edx,ecx
@@Loop:		mov	cx,-1
		call	TMR_Delay
		dec	edx
		jnz	@@Loop
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; TMR_CountCPUspeed - count CPU speed rate.
		; Input: none.
		; Output: ECX=CPU speed rate.
proc TMR_CountCPUspeed near
		push	eax ebx edx esi edi
		cli
		call	KBC_SpeakerOFF			; Turn off speaker
		call	KBC_DisableGate2
		mov	al,0B4h
		xor	ecx,ecx
		call	TMR_InitCounter
		mov	di,7AAAh
		mov	bx,5555h
		mov	cl,3Eh
		xor	edx,edx
		call	KBC_EnableGate2
		jmp	short $+2			; Clear pipeline

@@Loop1:	rept	33
		mov	ax,di
		div	bx
		endm
		dec	cl
		jz	short @@NextTest
		jmp	@@Loop1

@@NextTest:	call	KBC_DisableGate2
		xor	eax,eax
		in	al,PORT_TIMER_C2
		PORTDELAY
		mov	ah,al
		in	al,PORT_TIMER_C2
		PORTDELAY
		xchg	al,ah
		mov	esi,eax

		xor	ecx,ecx
		mov	cl,3Eh
		xor	edx,edx
		call	KBC_EnableGate2
		jmp	short $+2

@@Loop2:	mov	ax,di
		div	bx
		loop	@@Loop2

		call	KBC_DisableGate2
		xor	eax,eax
		in	al,PORT_TIMER_C2
		PORTDELAY
		mov	ah,al
		in	al,PORT_TIMER_C2
		PORTDELAY
		xchg	al,ah
		mov	ecx,eax
		sub	ecx,esi

		mov	eax,5A26F5h
		xor	edx,edx
		div	ecx
		xor	ecx,ecx

@@Loop3:	inc	ecx
		sub	eax,64h
		jbe	short @@Exit
		jmp	@@Loop3

@@Exit:		sti
		pop	edi esi edx ebx eax
		ret
endp		;---------------------------------------------------------------


		; TMR_GetLoopsPerSecond - get number of loops per second.
		; Input: none.
		; Output: ECX=loops per second.
proc TMR_GetLoopsPerSecond near
		cli
		call	KBC_SpeakerOFF			; Turn off speaker
		call	KBC_DisableGate2
		mov	al,0B4h
		xor	ecx,ecx
		call	TMR_InitCounter
		mov	ecx,32000
		call	KBC_EnableGate2
		jmp	short @@Loop
@@Loop:		nop
		dec	ecx
		jnz	@@Loop
		call	KBC_DisableGate2
		xor	eax,eax
		in	al,PORT_TIMER_C2
		PORTDELAY
		mov	ah,al
		in	al,PORT_TIMER_C2
		PORTDELAY
		xchg	al,ah

		sti
		ret
endp		;---------------------------------------------------------------
