;-------------------------------------------------------------------------------
;  8042.asm - keyboard controller (8042) control module.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Port 61h bits (R/W)
KBC_P1_PTYCHK		EQU	80h		; Parity check
KBC_P1_IOCHK		EQU	40h		; I/O check
KBC_P1_T20		EQU	20h		; Counter 2 output
KBC_P1_RFD		EQU	10h		; Regeneration of RAM
KBC_P1_EIC		EQU	8		; Enable I/O checking
KBC_P1_ERP		EQU	4		; Enable RAM parity checking
KBC_P1_SPK		EQU	2		; Speaker gate
KBC_P1_T2G		EQU     1		; Counter GATE2 input

; Port 64h status bits (R)
KBC_P4S_PTYERR		EQU	80h		; Parity error
KBC_P4S_RCTO		EQU	40h		; KB receiver timeout
KBC_P4S_TRTO		EQU	20h		; KB transmitter timeout
KBC_P4S_KBLock		EQU	10h		; Keyboard locked
KBC_P4S_Command		EQU	8		; Command/data
KBC_P4S_ResetOK		EQU	4		; Reset OK/Power ON
KBC_P4S_KBNRDY		EQU	2		; Keyboard not ready
KBC_P4S_OutBFull	EQU	1		; Output buffer full

; Port 64h commands (W)
KBC_P4W_EnA20		EQU	0DFh		; Enable A20
KBC_P4W_DisA20		EQU	0DDh		; Disable A20
KBC_P4W_Wr8042out	EQU	0D1h		; Write to 8042 output port
KBC_P4W_Rd8042out	EQU	0D0h		; Read from 8042 output port
KBC_P4W_Rd8042in	EQU	0C0h		; Read from 8042 input port
KBC_P4W_KBEnable	EQU	0AEh		; Keyboard enable
KBC_P4W_KBDisable	EQU	0ADh		; Keyboard disable
KBC_P4W_Rd8042RAM	EQU	0ACh		; Read KBC RAM
KBC_P4W_TestSD		EQU	0ABh		; Synchronizing and data test
KBC_P4W_Test8042	EQU	0AAh		; Internal test of KBC
KBC_P4W_WriteKBC	EQU	60h		; Write to KBC
KBC_P4W_ReadKBC		EQU	20h		; Read from KBC


; --- Publics ---
		public KBC_DisableKB
		public KBC_EnableKB
		public KBC_SendKBCmd
		public KBC_ReadKBPort


; --- Procedures ---

		; KBC_WaitReady - wait until KBC will be ready for write
		;		  command/data.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - waiting timeout.
proc KBC_WaitReady near
		push	eax
		push	ecx
		pushfd
		cli
		mov	ecx,10000h
WRDY_Loop1:	PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_KBNRDY
		loopnz	WRDY_Loop1
		jz	WRDY_OK
		mov	ecx,10000h
WRDY_Loop2:	PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_KBNRDY
		loopnz	WRDY_Loop2
		jz	WRDY_OK
		popfd
		stc
		jmp	WRDY_Exit
WRDY_OK:	popfd
		clc
WRDY_Exit:	pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_WaitKBcode - wait until keyboard send code to 60h
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - waiting timeout.
proc KBC_WaitKBcode near
		push	eax
		push	ecx
		mov	ecx,1000000h
WKBB_Loop1:	PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_OutBFull
		loopz	WKBB_Loop1
		jnz	WKBB_OK
		mov	ecx,1000000h
WKBB_Loop2:	PORTDELAY
		in	al,PORT_KBC_4
		test	al,KBC_P4S_OutBFull
		loopz	WKBB_Loop2
		jnz	WKBB_OK
		stc
		jmp	WKBB_Exit
WKBB_OK:	clc
WKBB_Exit:	pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KBC_DisableKB - disable keyboard.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KBC_DisableKB near
		call	KBC_WaitReady
		jc	DisKB_Exit
		push	eax
		mov	al,KBC_P4W_KBDisable
		out	PORT_KBC_4,al
		pop	eax
		clc
DisKB_Exit:	ret
endp		;---------------------------------------------------------------


		; KBC_EnableKB - enable keyboard.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KBC_EnableKB near
		call	KBC_WaitReady
		jc	EnbKB_Exit
		push	eax
		mov	al,KBC_P4W_KBEnable
		out	PORT_KBC_4,al
		pop	eax
		clc
EnbKB_Exit:	ret
endp		;---------------------------------------------------------------


		; KBC_SendKBCmd - send command to keyboard.
		; Input: AL=command code,
		;	 AH=data byte (if CF=1),
		;	 CF=0 - don't send data byte,
		;	 CF=1 - send data byte (AH).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KBC_SendKBCmd near
		pushfd
		cli
		call	KBC_WaitReady
		jc	SndKBcmd_Err
		out	PORT_KBC_0,al
		test	[byte esp],1
		jz	SndKBcmd_OK
		call	KBC_WaitReady
		jc	SndKBcmd_Err
		mov	al,ah
		out	PORT_KBC_0,al
SndKBcmd_OK:	popfd
		clc
		jmp	short SndKBcmd_Exit
SndKBcmd_Err:   mov	ax,ERR_KBC_NotRDY
		popfd
		stc
SndKBcmd_Exit:	ret
endp		;---------------------------------------------------------------


		; KBC_ReadKBPort - read byte from keyboard port
		; Input: none.
		; Output: AL=read value.
proc KBC_ReadKBPort near
		in	al,PORT_KBC_0
		ret
endp		;---------------------------------------------------------------


		; KBC_SpeakerON - turn on PC speaker.
		; Input: none.
		; Output: none.
		; Note: simply enables timer GATE2 and opens speaker gate.
		;	doesn't change counter 2 divisor rate.
proc KBC_SpeakerON near
		push	eax
		in      al,PORT_KBC_1
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
proc KBC_SpeakerOFF near
		push	eax
		in      al,PORT_KBC_1
		PORTDELAY
		and	al,not KBC_P1_SPK
		out	PORT_KBC_1,al
		pop	eax
		ret
endp		;---------------------------------------------------------------

