;-------------------------------------------------------------------------------
;  int70-7f.asm - Hardware interrupts handlers.
;-------------------------------------------------------------------------------

		; IRQ0: system timer.
proc Int70handler far
		push	eax
		push	ebx
		push	edx
		mov	eax,[TimerTicksLo]
		inc	eax
		mov	[TimerTicksLo],eax
		or	eax,eax
		jz	i70_SetTTHi
		jmp	i70_SwTask
i70_SetTTHi:	inc	[TimerTicksHi]

i70_SwTask:	call	KSwitchTask

 IFDEF DEBUG
	extrn VGATX_WrCharXY:near
		mov     ax,0E0Fh
		test	[TimerTicksLo],16
		jnz	i70_DBG1
		xor	al,al
i70_DBG1:	mov	dx,1800h+79
		xor	bh,bh
		stc
		call	VGATX_WrCharXY
 ENDIF
		call	PIC_EOI1
		pop	edx
		pop	ebx
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ1: keyboard.
proc Int71handler far
		push	eax
		call	KBC_ReadKBPort
		shl	eax,16
		call	KBC_ReadPort1
		mov	ah,al
		or	al,80h
		call	KBC_WritePort1
		mov	al,ah
		call	KBC_WritePort1
		shr	eax,16
		call	KB_AnalyseKBcode
		call	PIC_EOI1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int72handler far
		iret
endp		;---------------------------------------------------------------


		; IRQ 3: serial ports #2 & #4
proc Int73handler far
		iret
endp		;---------------------------------------------------------------


		; IRQ 4: serial ports #1 & #3
proc Int74handler far
		iret
endp		;---------------------------------------------------------------


		; IRQ 5: audio device.
proc Int75handler far
		iret
endp		;---------------------------------------------------------------


		; IRQ 6: FDD.
proc Int76handler far
		iret
endp		;---------------------------------------------------------------


		; IRQ 7: parallel port #1.
proc Int77handler far
		iret
endp		;---------------------------------------------------------------



		; IRQ 8: CMOS real-time clock.
proc Int78handler far
		push	eax
		mov	eax,0B8030h
		mov	[byte eax],'*'
		call	PIC_EOI2
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int79handler far
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

