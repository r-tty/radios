;-------------------------------------------------------------------------------
;  cmosrtc.asm - CMOS memory and real-time clock control routines.
;-------------------------------------------------------------------------------

; --- Definitions ---
RTCREG_Sec		EQU	0
RTCREG_SecAlarm		EQU	1
RTCREG_Min		EQU	2
RTCREG_MinAlarm		EQU	3
RTCREG_Hour		EQU	4
RTCREG_HourAlarm	EQU	5
RTCREG_WeekDay		EQU	6
RTCREG_Day		EQU	7
RTCREG_Month		EQU	8
RTCREG_YearLo		EQU	9
RTCREG_YearHi		EQU	32h

RTCREG_StatusA		EQU	0Ah
RTCREG_StatusB		EQU	0Bh
RTCREG_StatusC		EQU	0Ch
RTCREG_StatusD		EQU	0Dh

CMOSREG_POSTbyte	EQU	0Eh
CMOSREG_ShtDwn		EQU	0Fh
CMOSREG_FDDtype		EQU	10h
CMOSREG_HDDtype		EQU	12h
CMOSREG_InstHard	EQU	14h
CMOSREG_BaseMemLo	EQU	15h
CMOSREG_BaseMemHi	EQU	16h
CMOSREG_ExtMemLo	EQU	17h
CMOSREG_ExtMemHi	EQU	18h
CMOSREG_ExtDrCtype	EQU	19h
CMOSREG_ExtDrDtype	EQU	20h
CMOSREG_RExtMemLo	EQU	30h
CMOSREG_RRExtMemHi	EQU	31h

; Bits of RTC status register B
RTC_STB_StopTmr		EQU	128
RTC_STB_TicksIntEnb	EQU	64
RTC_STB_AlarmIntEnb	EQU	32
RTC_STB_UpdEndedInt	EQU	16
RTC_STB_SquareWave	EQU	8
RTC_STB_BINmode		EQU	4
RTC_STB_24hour		EQU	2
RTC_STB_SummerTime	EQU	1


; --- Procedures ---

		; CMOS_Read - read CMOS register.
		; Input: AL=port number.
		; Output: AL=read value.
proc CMOS_Read near
		out	PORT_CMOS_Addr,al
		PORTDELAY
		PORTDELAY
		in	al,PORT_CMOS_Data
		ret
endp		;---------------------------------------------------------------


		; CMOS_Write - write CMOS register.
		; Input: AL=port number,
		;	 AH=value.
proc CMOS_Write near
		out	PORT_CMOS_Addr,al
		PORTDELAY
		PORTDELAY
		mov	al,ah
		out	PORT_CMOS_Data,al
		ret
endp		;---------------------------------------------------------------


		; CMOS_ReadBaseMemSz - read base memory size from CMOS.
		; Input: none.
		; Output: AX=number of KBytes of base memory.
proc CMOS_ReadBaseMemSz near
		mov	al,CMOSREG_BaseMemHi
		call	CMOS_Read
		mov	ah,al
		mov	al,CMOSREG_BaseMemLo
		call	CMOS_Read
		ret
endp		;---------------------------------------------------------------


		; CMOS_ReadExtMemSz - read extended memory size from CMOS.
		; Input: none.
		; Output: AX=number of KBytes of extended memory.
		; Note: maximum value is 64 MB.
proc CMOS_ReadExtMemSz near
		mov	al,CMOSREG_ExtMemHi
		call	CMOS_Read
		mov	ah,al
		mov	al,CMOSREG_ExtMemLo
		call	CMOS_Read
		ret
endp		;---------------------------------------------------------------


		; CMOS_ReadFDDTypes - read FDD types.
		; Input: none.
		; Output: AL=FDD types byte.
proc CMOS_ReadFDDTypes near
		mov	al,CMOSREG_FDDtype
		call	CMOS_Read
		ret
endp		;---------------------------------------------------------------

		
		; CMOS_EnableInt - enable CMOS interrupt (IRQ8)
proc CMOS_EnableInt near
		push	eax
		mov	al,RTCREG_StatusA
		mov	ah,al
		call	CMOS_Read
		or	al,15
		xchg	ah,al
		call	CMOS_Write
		mov	al,RTCREG_StatusB
		mov	ah,al
		call	CMOS_Read
		or	al,RTC_STB_TicksIntEnb
		xchg	al,ah
		call	CMOS_Write
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; CMOS_DisableInt - disable CMOS interrupt
proc CMOS_DisableInt near
		ret
endp		;---------------------------------------------------------------


		; CMOS_HandleInt - handle RTC interrupt.
		; Input: none.
		; Output: none.
proc CMOS_HandleInt near
		push	eax
		mov	al,RTCREG_StatusC
		call	CMOS_Read
		pop	eax
		ret
endp		;---------------------------------------------------------------
