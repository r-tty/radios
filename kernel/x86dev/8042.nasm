;-------------------------------------------------------------------------------
;  8042.nasm - keyboard controller (8042) support.
;-------------------------------------------------------------------------------

%include "hw/8042.ah"

; --- Exports ---

global KBC_ClrOutBuf, KBC_A20Control, KBC_HardReset
global KBC_SendKBCmd, KBC_ReadKBPort
global KBC_SpeakerON, KBC_SpeakerOFF


; --- Procedures ---

		; KBC_WaitReady - wait until KBC will be ready for write
		;		  command/data.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - waiting timeout.
proc KBC_WaitReady
		push	eax
		push	ecx
		pushfd
		cli
		mov	ecx,10000h
.Loop1:		PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_KBNRDY
		loopnz	.Loop1
		jz	short .OK
		mov	ecx,10000h
.Loop2:		PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_KBNRDY
		loopnz	.Loop2
		jz	short .OK
		popfd
		stc
		jmp	short .Exit
.OK:		popfd
		clc
.Exit:		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_WaitKBcode - wait until keyboard send code to 60h
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - waiting timeout.
proc KBC_WaitKBcode
		mpush	eax,ecx
		mov	ecx,1000000h
.Loop1:		PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_OutBFull
		loopz	.Loop1
		jnz	short .OK
		mov	ecx,1000000h
.Loop2:		PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_OutBFull
		loopz	.Loop2
		jnz	short .OK
		stc
		jmp	short .Exit
.OK:		clc
.Exit:		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; KBC_DisableKB - disable keyboard.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KBC_DisableKB
		call	KBC_WaitReady
		jc	short .Exit
		push	eax
		mov	al,KBC_P4W_KBDisable
		out	PORT_KBC_4,al
		pop	eax
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; KBC_EnableKB - enable keyboard.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KBC_EnableKB
		call	KBC_WaitReady
		jc	short .Exit
		push	eax
		mov	al,KBC_P4W_KBEnable
		out	PORT_KBC_4,al
		pop	eax
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; KBC_SendKBCmd - send command to keyboard.
		; Input: AL=command code,
		;	 AH=data byte (if CF=1),
		;	 CF=0 - don't send data byte,
		;	 CF=1 - send data byte (AH).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KBC_SendKBCmd
		push	eax
		lahf					; Keep flags
		call	KBC_WaitReady
		jc	short .Error
		out	PORT_KBC_0,al
		test	ah,1				; Send data byte?
		jz	short .OK
		call	KBC_WaitReady
		jc	.Error
		mov	al,[esp+1]			; Data byte
		out	PORT_KBC_0,al
.OK:		pop	eax
		clc
		jmp	short .Exit
.Error:		pop	eax
		mov	ax,ERR_KBC_NotRDY
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; KBC_ReadKBPort - read byte from keyboard port
		; Input: none.
		; Output: AL=read value.
proc KBC_ReadKBPort
		in	al,PORT_KBC_0
		ret
endp		;---------------------------------------------------------------


		; KBC_ClrOutBuf - clear KBC output buffer.
		; Input: none.
		; Output: none.
proc KBC_ClrOutBuf
		push	eax
.Loop:		in	al,PORT_KBC_4
		test	al,1
		jz	short .Exit
		in	al,PORT_KBC_0
		PORTDELAY
		PORTDELAY
		jmp	.Loop
.Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_SpeakerON - turn on PC speaker.
		; Input: none.
		; Output: none.
		; Note: simply enables timer GATE2 and opens speaker gate;
		;	doesn't change counter 2 divisor rate.
proc KBC_SpeakerON
		push	eax
		in	al,PORT_KBC_1
		PORTDELAY
		or	al,KBC_P1_SPK+KBC_P1_T2G
		out	PORT_KBC_1,al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_SpeakerOFF - turn off PC speaker.
		; Input: none.
		; Output: none.
		; Note: simply closes speaker gate.
		;	doesn't change timer GATE2 status.
proc KBC_SpeakerOFF
		push	eax
		in	al,PORT_KBC_1
		PORTDELAY
		and	al,~KBC_P1_SPK
		out	PORT_KBC_1,al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_EnableGate2 - enable timer GATE2 line.
		; Input: none.
		; Output: none.
proc KBC_EnableGate2
		push	eax
		in	al,PORT_KBC_1
		PORTDELAY
		or	al,KBC_P1_T2G
		out	PORT_KBC_1,al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_DisableGate2 - enable timer GATE2 line.
		; Input: none.
		; Output: none.
proc KBC_DisableGate2
		push	eax
		in	al,PORT_KBC_1
		PORTDELAY
		and	al,~KBC_P1_T2G
		out	PORT_KBC_1,al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_A20Control - A20 line control.
		; Input: AL=0 - disable A20;
		;	 AL=1 - enable A20.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc KBC_A20Control
		mpush	eax,ecx
		mov	ah,KBC_P4W_EnA20
		or	al,al
		jnz	short .Enable
		mov	ah,KBC_P4W_DisA20

.Enable:	call	KBC_WaitReady
		jc	short .Error

		mov	al,KBC_P4W_Wr8042out
		out	PORT_KBC_4,al
		call	KBC_WaitReady
		jc	short .Error

		mov	al,ah
		out	PORT_KBC_0,al
		call	KBC_WaitReady
		jc	short .Error

		mov	al,KBC_P4W_Pulse
		out	PORT_KBC_4,al
		call	KBC_WaitReady

.OK:		clc
		jmp	short .Exit
.Error:		stc
.Exit:		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; KBC_HardReset - hardware reset.
		; Input: none.
		; Output: none.
proc KBC_HardReset
		cli
		call	KBC_WaitReady
		mov	al,KBC_P4W_HardReset
		out	PORT_KBC_4,al
		hlt
endp		;---------------------------------------------------------------
