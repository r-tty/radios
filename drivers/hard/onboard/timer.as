;-------------------------------------------------------------------------------
;  timer.as - Programmable interval timer control routines.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Counter/timer control word
%define	TMRCW_BCD		1		; BCD counting

%define	TMRCW_Mode0		0		; Counting modes
%define	TMRCW_Mode1		2
%define	TMRCW_Mode2		4
%define	TMRCW_Mode3		6
%define	TMRCW_Mode4		8
%define	TMRCW_Mode5		10

%define	TMRCW_Latch		0		; Latch value
%define	TMRCW_LB		10h		; Low byte
%define	TMRCW_HB		20h		; High byte
%define	TMRCW_LH		30h		; Low & high

%define	TMRCW_CT0		0		; Counter select
%define	TMRCW_CT1		40h
%define	TMRCW_CT2		80h


; --- Exports ---

global TMR_InitCounter,TMR_CountCPUspeed


; --- Procedures ---

		; TMR_InitCounter - initialize counter.
		; Input: AL=control byte,
		;	 CX=divisor rate.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc TMR_InitCounter
		cmp	al,0C0h			; Counter number is right?
		jae	short .Err
		mpush	eax,edx
		out	PORT_TIMER_CTL,al
		mov	ah,al
		shr	al,6			; AL=counter number
		mov	dl,PORT_TIMER_C0
		add	dl,al
		xor	dh,dh			; DX=counter port
		test	ah,TMRCW_LB		; Write low byte?
		jz	short .WrHiByte
		mov	al,cl
		out	dx,al
		test	ah,TMRCW_HB		; Write high byte?
		jz	short .OK
.WrHiByte:	mov	al,ch
		out	dx,al
.OK:		mpop	edx,eax
		clc
		ret
.Err:		mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
		ret
endp		;---------------------------------------------------------------


		; TMR_ReadOnFly - read counter value "on flying"
		; Input: AL=counter number (0..2),
		;	 CF=0 - read byte,
		;	 CF=1 - read word.
		; Output: CF=0 - OK, AX (AL)=read value;
		;	  CF=1 - error, AX=error code.
proc TMR_ReadOnFly
		pushfd
		cmp	al,3
		jae	short .Error
		push	edx
		mov	dx,PORT_TIMER_C0
		add	dl,al
		shl	al,7
		out     PORT_TIMER_CTL,al
		PORTDELAY
		in	al,dx
		test	byte [esp+4],1		; Read one byte?
		jz	short .OK
		xchg	al,ah
                in	al,dx
		xchg	al,ah

.OK:		pop	edx
		popfd
		clc
		ret

.Error:		popfd
		mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; TMR_Delay - timer delay.
		; Input: CX=number of counter 0 ticks.
		; Output: none.
		; Note: doesn't disable interrupt.
proc TMR_Delay
		mpush	eax,ecx
		xor	al,al
		stc
		call	TMR_ReadOnFly
		sbb	ax,cx
		mov	cx,ax
.Loop:		xor	al,al
		stc
		call	TMR_ReadOnFly
		cmp	ax,cx
		jbe	short .Exit
		jmp	.Loop

.Exit:		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; TMR_DelayLong - long timer delay.
		; Input: ECX=number of counter 0 ticks * 10000h
		; Output:none.
proc TMR_DelayLong
		push	edx
		mov	edx,ecx
.Loop:		mov	cx,-1
		call	TMR_Delay
		dec	edx
		jnz	.Loop
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; TMR_CountCPUspeed - count CPU speed rate.
		; Input: none.
		; Output: ECX=CPU speed rate.
proc TMR_CountCPUspeed
		mpush	eax,ebx,edx,esi,edi
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

.Loop1:
%rep 33
		mov	ax,di
		div	bx
%endrep
		dec	cl
		jz	short .NextTest
		jmp	.Loop1

.NextTest:	call	KBC_DisableGate2
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

.Loop2:		mov	ax,di
		div	bx
		loop	.Loop2

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

.Loop3:		inc	ecx
		sub	eax,64h
		jbe	short .Exit
		jmp	.Loop3

.Exit:		sti
		mpop	edi,esi,edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; TMR_GetLoopsPerSecond - get number of loops per second.
		; Input: none.
		; Output: ECX=loops per second.
proc TMR_GetLoopsPerSecond
		cli
		call	KBC_SpeakerOFF			; Turn off speaker
		call	KBC_DisableGate2
		mov	al,0B4h
		xor	ecx,ecx
		call	TMR_InitCounter
		mov	ecx,32000
		call	KBC_EnableGate2
		jmp	short .Loop
.Loop:		nop
		dec	ecx
		jnz	.Loop
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
