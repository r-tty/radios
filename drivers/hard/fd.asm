;-------------------------------------------------------------------------------
;  fd.asm - Floppy driver.
;-------------------------------------------------------------------------------

; --- Definitions ---

; FD control register bits
FD_Drive0		EQU	0
FD_Drive1		EQU	1
FD_EnbCTL		EQU	4
FD_EnbDMAIRQ		EQU	8
FD_Motor0ON		EQU	16
FD_Motor1ON		EQU	32

; FD status register bits
FDst_Busy0		EQU	1
FDst_Busy1		EQU	2
FDst_CTLBusy		EQU	16
FDst_NoDMA		EQU	32
FDst_Direct2CPU		EQU	64
FDst_Ready		EQU	128

; FDC (chip) commands
FDC_CmdRead		EQU	0E6h
FDC_CmdWrite		EQU	0C5h
FDC_Format		EQU	04Dh
FDC_CmdRecalibrate	EQU	7
FDC_CmdSeek		EQU	0Fh

; AT FD parameters register bits
FDATpar_Speed500	EQU	0
FDATpar_Speed300	EQU	1
FDATpar_Speed250	EQU	2
FDATpar_Speed1000	EQU	3
FDATpar_WrPrecomp1	EQU	4
FDATpar_WrPrecomp2	EQU	8
FDATpar_WrPrecomp3	EQU	16
FDATpar_ExtFilter	EQU	32
FDATpar_PowerOFF	EQU	64
FDATpar_Reset		EQU	128

; AT diagnostic register bits
FDATst_PosCodeDrv0	EQU	1
FDATst_PosCodeDrv0	EQU	2
FDATst_PosCodeHead0	EQU	4
FDATst_PosCodeHead1	EQU	8
FDATst_PosCodeHead2	EQU	16
FDATst_PosCodeHead3	EQU	32
FDATst_Write		EQU	64
FDATst_DiskChanged	EQU	128


; FDC types
FDCtype_8272		EQU	0
FDCtype_82072		EQU	1
FDCtype_82077old	EQU	2
FDCtype_82077new	EQU	3

; Drive types
FDtype_360		EQU	0
FDtype_720_5		EQU	1
FDtype_1200		EQU	2
FDtype_720_3		EQU	3
FDtype_1440		EQU	4
FDtype_2880		EQU	5


; --- Data ---

; FD driver main structure
DrvFDD		tDriver <"%fd             ",offset DrvFDET,0>

; Driver entry points table
DrvFDET		tDrvEntries < FDC_Init,\
			      FDC_HandleEvent,\
			      DrvNULL,\
			      DrvNULL,\
			      FD_ReadSector,\
			      FD_WriteSector,\
			      DrvNULL,\
			      FDC_Control >

; Driver control functions table
FDC_Control	DD	?

; Driver initialization status string
FDC_DrvInfStr	DB 80 dup (0)

FDCstr_8272	DB "8272A/765",0
FDCstr_82072	DB "82072",0
FDCstr_82077o	DB "pre-1991 82077",0
FDCstr_82077n	DB "post-1991 82077",0
FDCstr_FDC	DB " FDC, ",0

FDCstr_Drive	DB "drive(s)",0
FDCstr_NotInst	DB ": not detected.",0


; --- Variables ---
FD_DrTypes	DB	0				; FDD type
FD_MotorSt	DB	0				; Motors status bits
FD_CurrDr	DB	0				; Current drive


; --- Publics ---
		public DrvFDD



; --- Procedures ---

		; FDC_Init - initialize floppy disk controller.
		; Input: none.
		; Output: CF=0 - OK:
		;		 AL=controller type,
		;		 AH=drive type,
		;		 ESI=pointer to driver information string.
proc FDC_Init near
		push	edi
		mov	edi,offset FDC_DrvInfStr
		mov	esi,offset DrvFDD.DrvName
		call	StrCopy
		mov	esi,edi
		call	StrEnd
		mov	[word edi],909h
		mov	[word edi+2]," :"
		mov	[byte edi+4],0
		mov	edi,esi

		call	FDC_Search82077
		jnc	@@82077
		call	FDC_Search82072
		jnc	@@82072
		mov	esi,offset FDCstr_8272
		jmp	short @@Test

@@82077:        or	al,al
		jz	@@82077o
		mov	esi,offset FDCstr_82077n
		jmp	short @@Test
@@82077o:	mov	esi,offset FDCstr_82077o
		jmp	short @@Test

@@82072:	mov	esi,offset FDCstr_82072

@@Test:		call	StrAppend
		mov	esi,offset FDCstr_FDC
		call	StrAppend
		mov	esi,edi
		call	StrEnd

		call	CMOS_ReadFDDTypes
		or	ax,ax
		jz	@@NotInst
		or	ah,ah
		jz	@@OneDrive
		mov	[word edi],' 2'
		jmp	@@Inst

@@OneDrive:	mov	[word edi],' 1'

@@Inst:         mov	[byte edi+2],0
		mov	edi,esi
		mov	esi,offset FDCstr_Drive
		call	StrAppend
		jmp	short @@Done

@@NotInst:	mov	edi,esi
		mov	esi,offset FDCstr_Drive
		call	StrAppend
		mov	esi,offset FDCstr_NotInst
		call	StrAppend

@@Done:		mov	esi,edi
		call	StrEnd
		mov	[word edi],NL
		mov	esi,offset FDC_DrvInfStr
		clc
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; FDC_HandleEvent
proc FDC_HandleEvent near
		ret
endp		;---------------------------------------------------------------


		; FDC_Search82077 - search 82077 FDC.
		; Input: none.
		; Output: CF=0 - 82077 found:
		;		  AL=0 - pre-1991,
		;		  AL=1 - post-1991.
		;	  CF=1 - 82077 not found.
proc FDC_Search82077 near
		stc
		ret
endp		;---------------------------------------------------------------


		; FDC_Search82072 - search 82072 FDC.
		; Input: none.
		; Output: CF=0 - 82072 found,
		;	  CF=1 - 82072 not found.
proc FDC_Search82072 near
		stc
		ret
endp		;---------------------------------------------------------------


		; FDC_MotorControl - turn floppy drive motor on/off.
		; Input: AL=drive number,
		;	 AH=motor status (1=ON, 0=OFF).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc FDC_MotorControl near
		cmp	al,2
		jae	FDCmotor_Err
		push	eax
		push	ecx
		push	edx
		mov	cl,al
		mov	al,16
		shl	al,cl
		mov	ch,[FD_MotorSt]
		add	ch,[FD_CurrDr]
		or	ch,FD_EnbCTL+FD_EnbDMAIRQ
		xchg	al,ch
		or	ah,ah
		jz	FDCmot_OFF
                or	al,ch
		jmp	short FDCmot_Do
FDCmot_OFF:	not	ch
		and	al,ch
FDCmot_Do:	mov	dx,PORT_FDC_Control
		out	dx,al
		or	[FD_MotorSt],al
		and	[FD_MotorSt],0F0h
		pop	ecx
		pop	edx
		pop	eax
		clc
		jmp	short FDCmotor_Exit

FDCmotor_Err:	mov	ax,ERR_FDC_BadDrNum
		stc
FDCmotor_Exit:	ret
endp		;---------------------------------------------------------------


		; FD_ReadSector - read sectors.
		; Input: DL=drive number,
		;	 AL=sector number,
		;	 AH=head number,
		;	 BL=track number,
		;	 CX=number of sectors,
		;	 EDI=buffer address.
proc FD_ReadSector near

		ret
endp		;---------------------------------------------------------------


		; FD_WriteSector - write sectors.
		; Input: DL=drive number,
		;	 AL=sector number,
		;	 AH=head number,
		;	 BL=track number,
		;	 CX=number of sectors,
		;	 EDI=buffer address.
proc FD_WriteSector near

		ret
endp		;---------------------------------------------------------------

