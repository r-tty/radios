;-------------------------------------------------------------------------------
; cmosrtc.nasm - CMOS memory and real-time clock control routines.
;-------------------------------------------------------------------------------

; RTC registers
%define	RTCREG_Sec		0
%define	RTCREG_SecAlarm		1
%define	RTCREG_Min		2
%define	RTCREG_MinAlarm		3
%define	RTCREG_Hour		4
%define	RTCREG_HourAlarm	5
%define	RTCREG_WeekDay		6
%define	RTCREG_Day		7
%define	RTCREG_Month		8
%define	RTCREG_YearLo		9
%define	RTCREG_YearHi		32h

%define	RTCREG_StatusA		0Ah
%define	RTCREG_StatusB		0Bh
%define	RTCREG_StatusC		0Ch
%define	RTCREG_StatusD		0Dh

%define	CMOSREG_POSTbyte	0Eh
%define	CMOSREG_ShtDwn		0Fh
%define	CMOSREG_FDDtype		10h
%define	CMOSREG_HDDtype		12h
%define	CMOSREG_InstHard	14h
%define	CMOSREG_BaseMemLo	15h
%define	CMOSREG_BaseMemHi	16h
%define	CMOSREG_ExtMemLo	17h
%define	CMOSREG_ExtMemHi	18h
%define	CMOSREG_ExtDrCtype	19h
%define	CMOSREG_ExtDrDtype	20h
%define	CMOSREG_RExtMemLo	30h
%define	CMOSREG_RExtMemHi	31h

; Bits of RTC status register B
%define	RTC_STB_StopTmr		128
%define	RTC_STB_TicksIntEnb	64
%define	RTC_STB_AlarmIntEnb	32
%define	RTC_STB_UpdEndedInt	16
%define	RTC_STB_SquareWave	8
%define	RTC_STB_BINmode		4
%define	RTC_STB_24hour		2
%define	RTC_STB_SummerTime	1


publicproc CMOS_ReadLowerMemSize, CMOS_ReadUpperMemSize
publicproc CMOS_ReadFDDTypes, CMOS_ReadHDDTypes
publicproc CMOS_EnableInt, CMOS_DisableInt
publicproc CMOS_GetDate, CMOS_GetTime


section .text

		; CMOS_Read - read CMOS register.
		; Input: AL=port number.
		; Output: AL=read value.
proc CMOS_Read
		out	PORT_CMOS_Addr,al
		PORTDELAY
		PORTDELAY
		in	al,PORT_CMOS_Data
		ret
endp		;---------------------------------------------------------------


		; CMOS_Write - write CMOS register.
		; Input: AL=port number,
		;	 AH=value.
proc CMOS_Write
		out	PORT_CMOS_Addr,al
		PORTDELAY
		PORTDELAY
		mov	al,ah
		out	PORT_CMOS_Data,al
		ret
endp		;---------------------------------------------------------------


		; CMOS_ReadLowerMemSize - read base memory size from CMOS.
		; Input: none.
		; Output: AX=number of KBytes of base memory.
proc CMOS_ReadLowerMemSize
		mov	al,CMOSREG_BaseMemHi
		call	CMOS_Read
		mov	ah,al
		mov	al,CMOSREG_BaseMemLo
		call	CMOS_Read
		ret
endp		;---------------------------------------------------------------


		; CMOS_ReadUpperMemSize - read extended memory size from CMOS.
		; Input: none.
		; Output: AX=number of KBytes of extended memory.
		; Note: maximum value is 64 MB.
proc CMOS_ReadUpperMemSize
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
proc CMOS_ReadFDDTypes
		mov	al,CMOSREG_FDDtype
		call	CMOS_Read
		ret
endp		;---------------------------------------------------------------


		; CMOS_ReadHDDTypes - read a number and types of hard disk
		;		      drives (C: and D:) from CMOS.
		; Input: none.
		; Output: AL=HDD types byte,
		;	  CL=number of drives.
proc CMOS_ReadHDDTypes
		mov	al,CMOSREG_HDDtype
		xor	cl,cl
		test	al,0Fh
		jz	.Exit
		inc	cl
		test	al,0F0h
		jz	.Exit
		inc	cl		
.Exit:		ret
endp		;---------------------------------------------------------------
		

		; CMOS_EnableInt - enable 1024 Hz CMOS interrupt (IRQ8).
		; Input: none.
		; Output: none.
proc CMOS_EnableInt
		push	eax
		mov	al,RTCREG_StatusA
		mov	ah,al
		call	CMOS_Read
		and	al,0F0h
		or	al,1
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
proc CMOS_DisableInt
		push	eax
		mov	al,RTCREG_StatusB
		mov	ah,al
		call	CMOS_Read
		and	al,~RTC_STB_TicksIntEnb
		xchg	al,ah
		call	CMOS_Write
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; CMOS_GetDate - get current date.
		; Input: none.
		; Output: DH=month,
		;	  DL=day,
		;	  CX=year.
proc CMOS_GetDate
		mov	al,RTCREG_Month
		call	CMOS_Read
		call	BCDB2Dec
		mov	dh,al
		mov	al,RTCREG_Day
		call	CMOS_Read
		call	BCDB2Dec
		mov	dl,al
		mov	al,RTCREG_YearHi
		call	CMOS_Read
		call	BCDB2Dec
		mov	ch,al
		mov	al,RTCREG_YearLo
		call	CMOS_Read
		call	BCDB2Dec
		mov	cl,al
		ret
endp		;---------------------------------------------------------------


		; CMOS_GetTime - get current time.
		; Input: none.
		; Output: CH=hours,
		;	  CL=minutes,
		;	  DH=seconds.
proc CMOS_GetTime
		mov	al,RTCREG_Hour
		call	CMOS_Read
		call	BCDB2Dec
		mov	ch,al
		mov	al,RTCREG_Min
		call	CMOS_Read
		call	BCDB2Dec
		mov	cl,al
		mov	al,RTCREG_Sec
		call	CMOS_Read
		call	BCDB2Dec
		mov	dh,al
		ret
endp		;---------------------------------------------------------------
