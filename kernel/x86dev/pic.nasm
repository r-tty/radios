;-------------------------------------------------------------------------------
; pic.nasm - Programmable interrupt controller routines.
;-------------------------------------------------------------------------------

%include "hw/pic.ah"

publicproc PIC_Init,PIC_EnableIRQ,PIC_DisableIRQ,PIC_SetIRQmask
publicproc PIC_EOI1,PIC_EOI2


section .text

		; PIC_Init - initialize programmable interrupts controller.
		; Input: AH=0 - PIC #1,
		;	 AH=1 - PIC #2,
		;	 AL=base interrupt vector.
		; Output: none.
proc PIC_Init
		push	eax
		pushfd
		cli
		or	ah,ah			; PIC #1?
		mov	ah,al
		jz	.PIC1
		mov	al,PIC2_ICW1		; Begin initialize PIC #2
		out	PORT_PIC2_0,al
		PORTDELAY
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
		jmp	.Exit

.PIC1:		mov	al,PIC1_ICW1		; Begin initialize PIC #1
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

.Exit:		popfd
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PIC_SetIRQmask -set IRQ mask.
		; Input: AH=0 - PIC #1,
		;	 AH=1 - PIC #2,
		;	 AL=interrupts mask.
		; Output: none.
proc PIC_SetIRQmask
		push	eax
		pushfd
		cli
		or	ah,ah
		jz	.PIC1
		out	PORT_PIC2_1,al
		jmp	.Exit
.PIC1:		out	PORT_PIC1_1,al
.Exit:		popfd
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; Disable an IRQ.
		; Input: AL=IRQ number
		; Output: none.
proc PIC_DisableIRQ
		cmp	al,10h
		jae	.Exit
		mpush	eax,ecx
		pushfd
		cli
		mov	cl,al
		mov	ah,1
		cmp	al,8
		jae	.PIC2
		shl	ah,cl
		in	al,PORT_PIC1_1
		PORTDELAY
		or	al,ah
		out	PORT_PIC1_1,al
		jmp	.OK
.PIC2:		sub	cl,8
		shl	ah,cl
		in	al,PORT_PIC2_1
		PORTDELAY
		or	al,ah
		out	PORT_PIC2_1,al
.OK:		popfd
		mpop	ecx,eax
.Exit:		ret
endp		;---------------------------------------------------------------


		; Enable an IRQ.
		; Input: AL=IRQ number
		; Output: none.
proc PIC_EnableIRQ
		cmp	al,10h
		jae	.Exit
		mpush	eax,ecx
		pushfd
		cli
		mov	cl,al
		mov	ah,1
		cmp	al,8
		jae	.PIC2
		shl	ah,cl
		not	ah
		in	al,PORT_PIC1_1
		PORTDELAY
		and	al,ah
		out	PORT_PIC1_1,al
		jmp	.OK
.PIC2:		sub	cl,8
		shl	ah,cl
		not	ah
		in	al,PORT_PIC2_1
		PORTDELAY
		and	al,ah
		out	PORT_PIC2_1,al
.OK:		popfd
		mpop	ecx,eax
.Exit:		ret
endp		;---------------------------------------------------------------


		; PIC_EOI1 - send OCW2 EOI command to PIC1
		; Input: none.
		; Output: none.
proc PIC_EOI1
		push	eax
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC1_0,al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; PIC_EOI2 - send OCW2 EOI command to PIC2
		; Input: none.
		; Output: none.
proc PIC_EOI2
		push	eax
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC2_0,al
		pop	eax
		ret
endp		;---------------------------------------------------------------
