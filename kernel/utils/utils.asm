;-------------------------------------------------------------------------------
;  utils.asm - various kernel routines.
;-------------------------------------------------------------------------------

; --- Publics ---

		public K_TTDelay
		public K_LDelay


		; K_TTDelay - kernel delay (using timer ticks counter).
		; Input: ECX=number of quantum of times in delay.
		; Output: none.
proc K_TTDelay near
		push	eax
		push	ecx
		mov	eax,[TimerTicksLo]
		lea	ecx,[eax+ecx]
TDel_Loop:	mov	eax,[TimerTicksLo]
		cmp	eax,ecx
		jb	TDel_Loop
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_LDelay - kernel delay (using LOOP).
		; Input: ECX=number of repeats in loop.
		; Output: none.
		; Note: uses CPUspeed variable.
proc K_LDelay near
		push	eax
		push	ecx
		push	edx
		xor	edx,edx
		mov	eax,[CPUspeed]
		mul	ecx
		mov	ecx,eax
LDel:		loop	LDel
		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


; -------------------------- Debugging procedures ------------------------------

proc putc near
		call	CON_WrCharTTY
putc_Exit:	ret
endp

proc puts near
		push	esi
		push	eax
  puts10:	mov	al,[byte esi]
		or	al,al
		jz	puts20
		call	putc
		inc	esi
		jmp	puts10
  puts20:	pop	eax
		pop	esi
		ret
endp

proc ddecout near
		push	eax
		push	ebx
		push	ecx
		push	edx
		mov	ebx,1000000000
		xor	cl,cl
		or	eax,eax
		jnz	ddoloop
		mov	al,'0'
                call	putc
                jmp	ddoexit

  ddoloop:	xor	edx,edx
		div	ebx
		or	al,al
		jnz	ddonz
		or	cl,cl
		jz	ddoz

  ddonz:	mov	cl,1
		add	al,48
		call	putc
  ddoz:		mov	eax,edx
                xor	edx,edx
                push	eax
                mov	eax,ebx
                mov	ebx,10
                div	ebx
                mov	ebx,eax
                pop	eax
                or	ebx,ebx
                jnz	ddoloop

  ddoexit:	pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		ret
endp