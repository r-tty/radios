;-------------------------------------------------------------------------------
;  8042.asm - system controller (8042) control module.
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
KBC_P4S_OutBufOF	EQU	1		; Output buffer overflow

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


; --- Routines ---

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

