;-------------------------------------------------------------------------------
;  int70-7f.asm - Hardware interrupts handlers.
;-------------------------------------------------------------------------------

		; IRQ0: system timer.
proc Int70handler
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

i70_SwTask:	call	K_SwitchTask

 IFDEF DEBUG
		mov     ax,0E0Fh
		test	[TimerTicksLo],16
		jnz	i70_DBG1
		xor	al,al
i70_DBG1:	mov	dx,1800h+79
		xor	bh,bh
		stc
		push	DRVID_VideoTx
		push	DRVF_Control
		mov	[word esp+2],DRVCTL_VGATX_WrCharXY
		call	DRV_CallDriver
 ENDIF
		pop	edx
		pop	ebx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------


		; IRQ1: keyboard.
proc Int71handler
		push	eax
		push	edx
		mov	edx,EV_IRQ1
		mov	eax,DRVID_Keyboard
		call	DRV_HandleEvent
		pop	edx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------


proc Int72handler
		iret
endp		;---------------------------------------------------------------


		; IRQ 3: serial ports #2 & #4
proc Int73handler
		push	eax
		push	edx
		mov	edx,EV_IRQ3
		mov	eax,DRVID_Serial
		call	DRV_HandleEvent
		pop	edx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------


		; IRQ 4: serial ports #1 & #3
proc Int74handler
		push	eax
		push	edx
		mov	edx,EV_IRQ4
		mov	eax,DRVID_Serial
		call	DRV_HandleEvent
		pop	edx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------


		; IRQ 5: audio device.
proc Int75handler
		push	eax
		push	edx
		mov	edx,EV_IRQ5
		mov	eax,DRVID_Audio
		call	DRV_HandleEvent
		pop	edx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------


		; IRQ 6: FDD.
proc Int76handler
		push	eax
		push	edx
		mov	edx,EV_IRQ6
		mov	eax,DRVID_FDD
		call	DRV_HandleEvent
		pop	edx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------


		; IRQ 7: parallel port #1.
proc Int77handler
		push	eax
		push	edx
		mov	edx,EV_IRQ7
		mov	eax,DRVID_Parallel
		call	DRV_HandleEvent
		pop	edx
		pop	eax
		call	PIC_EOI1
		iret
endp		;---------------------------------------------------------------



		; IRQ 8: CMOS real-time clock.
proc Int78handler
		push	eax
		mov	eax,0B8030h
		mov	[byte eax],'*'
		call	PIC_EOI2
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int79handler
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------


proc Int7Ahandler
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------


proc Int7Bhandler
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------


proc Int7Chandler
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------


proc Int7Dhandler
		push	eax
		mov	edx,EV_IRQ13
		mov	eax,DRVID_FPU
		call	DRV_HandleEvent
		pop	eax
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------


proc Int7Ehandler
		push	eax
		mov	edx,EV_IRQ14
		mov	eax,DRVID_HDD
		call	DRV_HandleEvent
		pop	eax
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------


proc Int7Fhandler
		push	eax
		mov	edx,EV_IRQ15
		mov	eax,DRVID_HDD
		call	DRV_HandleEvent
		pop	eax
		call	PIC_EOI2
		iret
endp		;---------------------------------------------------------------

