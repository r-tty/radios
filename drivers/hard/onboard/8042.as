;-------------------------------------------------------------------------------
;  8042.as - keyboard controller (8042) support.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Port 61h bits (R/W)
%define	KBC_P1_PTYCHK		80h		; Parity check
%define	KBC_P1_IOCHK		40h		; I/O check
%define	KBC_P1_T20		20h		; Counter 2 output
%define	KBC_P1_RFD		10h		; Regeneration of RAM
%define	KBC_P1_EIC		8		; Enable I/O checking
%define	KBC_P1_ERP		4		; Enable RAM parity checking
%define	KBC_P1_SPK		2		; Speaker gate
%define	KBC_P1_T2G		1		; Counter GATE2 input

; Port 64h status bits (R)
%define	KBC_P4S_PTYERR		80h		; Parity error
%define	KBC_P4S_RXTO		40h		; KB receiver timeout
%define	KBC_P4S_TXTO		20h		; KB transmitter timeout
%define	KBC_P4S_KBLock		10h		; Keyboard locked
%define	KBC_P4S_Command		8		; Command/data
%define	KBC_P4S_ResetOK		4		; Reset OK/Power ON
%define	KBC_P4S_KBNRDY		2		; Keyboard not ready
%define	KBC_P4S_OutBFull	1		; Output buffer full

; Port 64h commands (W)
%define	KBC_P4W_Pulse		0FFh		; Pulse output line
%define	KBC_P4W_HardReset	0FEh		; Hardware reset
%define	KBC_P4W_EnA20		0DFh		; Enable A20
%define	KBC_P4W_DisA20		0DDh		; Disable A20
%define	KBC_P4W_Wr8042out	0D1h		; Write to 8042 output port
%define	KBC_P4W_Rd8042out	0D0h		; Read from 8042 output port
%define	KBC_P4W_Rd8042in	0C0h		; Read from 8042 input port
%define	KBC_P4W_KBEnable	0AEh		; Keyboard enable
%define	KBC_P4W_KBDisable	0ADh		; Keyboard disable
%define	KBC_P4W_Rd8042RAM	0ACh		; Read KBC RAM
%define	KBC_P4W_TestSD		0ABh		; Synchronizing and data test
%define	KBC_P4W_Test8042	0AAh		; Internal test of KBC
%define	KBC_P4W_WriteKBC	60h		; Write to KBC
%define	KBC_P4W_ReadKBC		20h		; Read from KBC


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
		push	eax
		push	ecx
		mov	ecx,1000000h
.Loop1:	PORTDELAY
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
.Exit:		pop	ecx
		pop	eax
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
