;-------------------------------------------------------------------------------
;  cmosrtc.asm - CMOS memory and real-time clock control module.
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

CMOSREG_StatusA		EQU	0Ah
CMOSREG_StatusB		EQU	0Bh
CMOSREG_StatusC		EQU	0Ch
CMOSREG_StatusD		EQU	0Dh
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


; --- Publics ---
		public CMOS_ReadBaseMemSz
		public CMOS_ReadExtMemSz


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
		; Output: AL=FDD0 type,
		;	  AH=FDD1 type.
proc CMOS_ReadFDDTypes near
		mov	al,CMOSREG_FDDtype
		call	CMOS_Read
		mov	ah,al
		shr	al,4
		and	ah,15
		ret
endp		;---------------------------------------------------------------

		