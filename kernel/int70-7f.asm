;-------------------------------------------------------------------------------
;  int70-7f.asm - Hardware interrupts handlers.
;-------------------------------------------------------------------------------

		; IRQ0: system timer.
proc Int70handler	far
		push	eax
		mov	eax,0B8010h
		mov	[byte eax],'@'
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC1_0,al
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ1: keyboard.
proc Int71handler	far
		push	eax
		in	al,PORT_KBC_0
		shl	eax,16
		in	al,PORT_KBC_1
		mov	ah,al
		or	al,80h
		out	PORT_KBC_1,al
		jmp	short $+2
		mov	al,ah
		out	PORT_KBC_1,al
                shr	eax,16
		call	AnlsKBcode
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC1_0,al
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc		Int72handler	far
		iret
endp		;---------------------------------------------------------------


		; IRQ 3: serial ports #2 & #4
proc		Int73handler	far
		iret
endp		;---------------------------------------------------------------


		; IRQ 4: serial ports #1 & #3
proc		Int74handler	far
		iret
endp		;---------------------------------------------------------------


		; IRQ 5: audio device.
proc		Int75handler	far
		iret
endp		;---------------------------------------------------------------


		; IRQ 6: FDD.
proc		Int76handler	far
		iret
endp		;---------------------------------------------------------------


		; IRQ 7: parallel port #1.
proc		Int77handler	far
		iret
endp		;---------------------------------------------------------------



		; IRQ 8: CMOS real-time clock.
proc		Int78handler	far
		push	eax
		mov	eax,0B8030h
		mov	[byte eax],'@'
		mov	al,PIC_OCW2_EOI
		out	PORT_PIC2_0,al
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc		Int79handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int7Ahandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int7Bhandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int7Chandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int7Dhandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int7Ehandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int7Fhandler	far
		iret
endp		;---------------------------------------------------------------

