;-------------------------------------------------------------------------------
; pit.nasm - Programmable Interval Timer (PIT) control routines.
;-------------------------------------------------------------------------------

%include "hw/pit.ah"
%include "hw/kbc.ah"

publicproc TMR_InitCounter,TMR_CountCPUspeed
publicdata ?CPUspeed


section .bss

?CPUspeed	RESD	1


section .text

		; TMR_InitCounter - initialize counter.
		; Input: AL=control byte,
		;	 CX=divisor rate.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc TMR_InitCounter
		cmp	al,0C0h			; Counter number is okay?
		jae	.Err
		mpush	eax,edx
		out	PORT_TIMER_CTL,al
		mov	ah,al
		shr	al,6			; AL=counter number
		mov	dl,PORT_TIMER_C0
		add	dl,al
		xor	dh,dh			; DX=counter port
		test	ah,PITCW_LB		; Write low byte?
		jz	.WrHiByte
		mov	al,cl
		out	dx,al
		test	ah,PITCW_HB		; Write high byte?
		jz	.OK
.WrHiByte:	mov	al,ch
		out	dx,al
.OK:		mpop	edx,eax
		clc
		ret
.Err:		mov	ax,ERR_TMR_BadCNBR	; Error: bad counter number
		stc
		ret
endp		;---------------------------------------------------------------


		; TMR_ReadOnFly - read counter value "on the fly".
		; Input: AL=counter number (0..2),
		;	 CF=0 - read byte,
		;	 CF=1 - read word.
		; Output: CF=0 - OK, AX (AL)=read value;
		;	  CF=1 - error, AX=error code.
proc TMR_ReadOnFly
		pushfd
		cmp	al,3
		jae	.Error
		push	edx
		mov	dx,PORT_TIMER_C0
		add	dl,al
		shl	al,7
		out     PORT_TIMER_CTL,al
		PORTDELAY
		in	al,dx
		test	byte [esp+4],1		; Read one byte?
		jz	.OK
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
		jbe	.Exit
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


		; TMR_CountCPUspeed - count CPU speed rate and store it in
		;		      the [?CPUspeed] variable.
		; Input: none.
		; Output: none.
proc TMR_CountCPUspeed
		mpush	eax,ebx,edx,esi,edi
		xor	ebx,ebx
		xor	ecx,ecx
		xor	edx,edx
		mov	bx,5555h
		mov	di,7AAAh
		cli

		; Disable GATE2 on keyboard controller
		mKBC_Gate2_ctrl 0

		; Initialize counter 2: clock generator (mode2), LSB/MSB
		mov	al,PITCW_CT2+PITCW_Mode2+PITCW_LH
		call	TMR_InitCounter
		mov	cl,3Eh

		; Start the counter
		mKBC_Gate2_ctrl 1
		jmp	.Loop1				; Clear pipeline
.Loop1:
%rep 33
		mov	ax,di
		div	bx
%endrep
		dec	cl
		jz	.NextTest
		jmp	.Loop1

		; Stop the counter and store its value in ESI
.NextTest:	mKBC_Gate2_ctrl 0
		xor	eax,eax
		in	al,PORT_TIMER_C2
		mov	ah,al
		in	al,PORT_TIMER_C2
		xchg	al,ah
		mov	esi,eax

		xor	ecx,ecx
		mov	cl,3Eh
		xor	edx,edx

		; Start the counter again
		mKBC_Gate2_ctrl 1
		jmp	.Loop2

.Loop2:		mov	ax,di
		div	bx
		loop	.Loop2

		; Finally, count the clock
		in	al,PORT_KBC_1
		and	al,~KBC_P1_T2G
		out	PORT_KBC_1,al
		xor	eax,eax
		in	al,PORT_TIMER_C2
		mov	ah,al
		in	al,PORT_TIMER_C2
		xchg	al,ah
		mov	ecx,eax
		sub	ecx,esi

		mov	eax,5A26F5h
		xor	edx,edx
		div	ecx
		xor	ecx,ecx

.Loop3:		inc	ecx
		sub	eax,64h
		ja	.Loop3
		mov	[?CPUspeed],ecx

.Exit:		sti
		mpop	edi,esi,edx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; TMR_GetLoopsPerSecond - get number of loops per second.
		; Input: none.
		; Output: ECX=loops per second.
proc TMR_GetLoopsPerSecond
		cli
		mov	al,PITCW_CT1+PITCW_Mode2+PITCW_LH
		xor	ecx,ecx
		call	TMR_InitCounter
		mov	ecx,32000
.Loop:		nop
		dec	ecx
		jnz	.Loop
		in	al,PORT_TIMER_C1
		mov	ah,al
		in	al,PORT_TIMER_C1
		xchg	al,ah
		xor	ecx,ecx				; XXX
		ret
endp		;---------------------------------------------------------------
