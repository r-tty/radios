;-------------------------------------------------------------------------------
;  pic.asm - Programmable interrupt controller control routines.
;-------------------------------------------------------------------------------

; --- Equates ---

; Initialization command words for PIC #1
PIC1_ICW1		EQU	10h
PIC1_ICW3		EQU	4
PIC1_ICW4		EQU	1Fh

; Initialization command words for PIC #2
PIC2_ICW1		EQU	10h
PIC2_ICW3		EQU	2
PIC2_ICW4		EQU	1Bh

; Operation command words
PIC_OCW2_EOI		EQU	20h
PIC_OCW3		EQU	0Ah


; --- Routines ---

		; PIC_Init - initialize programmable interrupts controller.
		; Input: AH=0 - PIC #1,
		;	 AH=1 - PIC #2,
		;	 AL=base interrupt vector.
		; Output: none.
proc PIC_Init near
		push	eax
		pushfd
		cli
		or	ah,ah			; PIC #1?
		mov	ah,al
		jz	InitPIC1
		mov	al,PIC2_ICW1		; Begin initialize PIC #2
		out	PORT_PIC2_0,al
		PORTDELAY			; Macro (delay by jmp)
		mov	al,ah
		out	PORT_PIC2_1,al
		PORTDELAY
		mov	al,PIC2_ICW3
		out	PORT_PIC2_1,al
		PORTDELAY
		mov	al,PIC2_ICW4
		out	PORT_PIC2_1,al
		PORTDELAY
		mov	al,PIC_OCW3
		out	PORT_PIC2_0,al
		PORTDELAY
		jmp	short InitPIC_End

InitPIC1:	mov	al,PIC1_ICW1		; Begin initialize PIC #1
		out	PORT_PIC1_0,al
		PORTDELAY
		mov	al,ah
		out	PORT_PIC1_1,al
		PORTDELAY
		mov	al,PIC1_ICW3
		out	PORT_PIC1_1,al
		PORTDELAY
		mov	al,PIC1_ICW4
		out	PORT_PIC1_1,al
		PORTDELAY
		mov	al,PIC_OCW3
		out	PORT_PIC1_0,al
		PORTDELAY

InitPIC_End:	popfd
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PIC_SetIRQmask -set IRQ mask.
		; Input: AH=0 - PIC #1,
		;	 AH=1 - PIC #2,
		;	 AL=interrupts mask.
		; Output: none.
proc SetIRQmask	near
		push	eax
		pushfd
		cli
		or	ah,ah
		jz	SIM1
		out	PORT_PIC2_1,al
		jmp	short SIM_Exit
SIM1:		out	PORT_PIC1_1,al
SIM_Exit:	popfd
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PIC_EOI1 - send OCW2 EOI command to PIC1
		; Input: none.
		; Output: none.
proc PIC_EOI1 near
		push	eax
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC1_0,al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PIC_EOI2 - send OCW2 EOI command to PIC2
		; Input: none.
		; Output: none.
proc PIC_EOI2 near
		push	eax
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC2_0,al
		pop	eax
		ret
endp		;---------------------------------------------------------------