;*******************************************************************************
;  fd.asm - floppy disk driver.
;  (c) 1998,99 Yuri Zaprogets.
;*******************************************************************************

.386
Ideal

;DEBUG=1

include "segments.ah"
include "errdefs.ah"
include "sysdata.ah"
include "drvctrl.ah"
include "drivers.ah"
include "hardware.ah"
include "kernel.ah"
include "strings.ah"
include "portsdef.ah"
include "fd.ah"

IFDEF DEBUG
include "macros.ah"
include "misc.ah"
ENDIF


; --- Definitions ---

; Common defintitions
FD_MaxNumDrives		EQU	2
FD_Timeout		EQU	500
FD_SelectDelay		EQU	(2*HZ/100)
FD_IRQchan		EQU	6
FD_MaxResultBytes	EQU	10

; FDC types
FDC_NONE		EQU	0
FDC_8272		EQU	1
FDC_82072		EQU	2
FDC_82077		EQU	3
FDC_82077AA		EQU	4
FDC_UNKNOWN		EQU	5

; Drive types
FD_360			EQU	0
FD_720_5		EQU	1
FD_1200			EQU	2
FD_720_3		EQU	3
FD_1440			EQU	4
FD_2880			EQU	5

; Additional FDC flags
FDCfl_NeedReset		EQU	1
FDCfl_NeedConfigure	EQU	2
FDCfl_HasFIFO		EQU	4

; FD status flags
FDST_CALIBRATED		EQU	80h

; Floppy device main structure
struc tFDdevParm
 CMOStype	DB	?				; CMOS type
 PhysParmPtr	DD	?				; Parameters table addr
 State		DB	?				; State flags
 Cyl		DW	?				; Current cylinder
 Head		DB	?				; Current head
 Sector		DB	?				; Current sector
ends


; --- Data ---

segment KDATA
; FD driver main structure
DrvFDD		tDriver <"%fd             ",offset DrvFDET,DRVFL_Block>

; Driver entry points table
DrvFDET		tDrvEntries < FD_Init,\
			      FD_HandleEvent,\
			      FD_Open,\
			      FD_Close,\
			      FD_Read,\
			      FD_Write,\
			      NULL,\
			      FD_Control >

; Driver control functions table
FD_Control	DD	FD_GetInitStatStr
		DD	FD_GetParameters
		DD	NULL
		DD	NULL
		DD	NULL
		DD	FD_Format
		DD	FD_MediaChange
		DD	FD_MotorControl

; Driver initialization status string components
FDCstr_None	DB "not detected",0
FDCstr_8272	DB "8272A/765",0
FDCstr_82072	DB "82072",0
FDCstr_82077	DB "82077",0
FDCstr_82077AA	DB "82077AA",0
FDCstr_Unknown	DB "unknown",0

FDstr_360	DB '360 KB, 5.25"',0
FDstr_720f	DB '720 KB, 5.25"',0
FDstr_1200	DB '1.2 MB, 5.25"',0
FDstr_720h	DB '720 KB, 3.5"',0
FDstr_1440	DB '1.44 MB, 3.5"',0
FDstr_2880	DB '2.88 MB, 3.5"',0

FDCtypeStrs	DD	FDCstr_None,FDCstr_8272,FDCstr_82072
		DD	FDCstr_82077,FDCstr_82077AA,FDCstr_Unknown

FDtypeStrs	DD	FDCstr_Unknown,FDstr_360,FDstr_1200,FDstr_720h
		DD	FDstr_1440,FDstr_2880,FDstr_2880

FDCstr_FDC	DB " FDC, ",0
FDCstr_Drive	DB " drive",0


; Physical parameters for different floppy drive types
FD_PhysParms	tFDphysParm <500,16,16,8000,1*HZ,3*HZ,0,FD_SelectDelay,\
				5,80,3*HZ,20,0,3*HZ/2,0>	; Unknown
		tFDphysParm <300,16,16,8000,1*HZ,3*HZ,0,FD_SelectDelay,\
				5,40,3*HZ,17,0,3*HZ/2,1>	; 360K
		tFDphysParm <500,16,16,6000,4*HZ/10,3*HZ,14,FD_SelectDelay,\
				6,83,3*HZ,17,0,3*HZ/2,2>	; 1.2M
		tFDphysParm <250,16,16,3000,1*HZ,3*HZ,0,FD_SelectDelay,\
				5,83,3*HZ,20,0,3*HZ/2,4>	; 720K 3.5"
		tFDphysParm <500,16,16,4000,4*HZ/10,3*HZ,10,FD_SelectDelay,\
				5,83,3*HZ,20,0,3*HZ/2,7>	; 1.44M
		tFDphysParm <1000,15,8,3000,4*HZ/10,3*HZ,10,FD_SelectDelay,\
				5,83,3*HZ,40,0,3*HZ/2,8>	; 2.88M AMI BIOS
		tFDphysParm <1000,15,8,3000,4*HZ/10,3*HZ,10,FD_SelectDelay,\
				5,83,3*HZ,40,0,3*HZ/2,8>	; 2.88M


; Different floppy media formats
FD_Formats	tMediaFmt <0,0,0,0,0,0,0,0,0 >			; 0 no testing
		tMediaFmt < 720, 9,2,40,0, 2Ah,02h,0DFh,50h>	; 1 360KB PC
		tMediaFmt <2400,15,2,80,0, 1Bh,00h,0DFh,54h>	; 2 1.2MB AT
		tMediaFmt < 720, 9,1,80,0, 2Ah,02h,0DFh,50h>	; 3 360KB SS 3.5"
		tMediaFmt <1440, 9,2,80,0, 2Ah,02h,0DFh,50h>	; 4 720KB 3.5"
		tMediaFmt < 720, 9,2,40,1, 23h,01h,0DFh,50h>	; 5 360KB AT
		tMediaFmt <1440, 9,2,80,0, 23h,01h,0DFh,50h>	; 6 720KB AT
		tMediaFmt <2880,18,2,80,0, 1Bh,00h,0CFh,6Ch>	; 7 1.44MB 3.5"
		tMediaFmt <5760,36,2,80,0, 1Bh,43h,0AFh,54h>	; 8 2.88MB 3.5"
		tMediaFmt <5760,36,2,80,0, 1Bh,43h,0AFh,54h>	; 9 2.88MB 3.5"

		tMediaFmt <2880,18,2,80,0, 25h,00h,0DFh,02h>	; 10 1.44MB 5.25"
		tMediaFmt <3360,21,2,80,0, 1Ch,00h,0CFh,0Ch>	; 11 1.68MB 3.5"
		tMediaFmt < 820,10,2,41,1, 25h,01h,0DFh,2Eh>	; 12 410KB 5.25"
		tMediaFmt <1640,10,2,82,0, 25h,02h,0DFh,2Eh>	; 13 820KB 3.5"
		tMediaFmt <2952,18,2,82,0, 25h,00h,0DFh,02h>	; 14 1.48MB 5.25"
		tMediaFmt <3444,21,2,82,0, 25h,00h,0DFh,0Ch>	; 15 1.72MB 3.5"
		tMediaFmt < 840,10,2,42,1, 25h,01h,0DFh,2Eh>	; 16 420KB 5.25"
		tMediaFmt <1660,10,2,83,0, 25h,02h,0DFh,2Eh>	; 17 830KB 3.5"
		tMediaFmt <2988,18,2,83,0, 25h,00h,0DFh,02h>	; 18 1.49MB 5.25"
		tMediaFmt <3486,21,2,83,0, 25h,00h,0DFh,0Ch>	; 19 1.74 MB 3.5"

		tMediaFmt <1760,11,2,80,0, 1Ch,09h,0CFh,00h>	; 20 880KB 5.25"
		tMediaFmt <2080,13,2,80,0, 1Ch,01h,0CFh,00h>	; 21 1.04MB 3.5"
		tMediaFmt <2240,14,2,80,0, 1Ch,19h,0CFh,00h>	; 22 1.12MB 3.5"
		tMediaFmt <3200,20,2,80,0, 1Ch,20h,0CFh,2Ch>	; 23 1.6MB 5.25"
		tMediaFmt <3520,22,2,80,0, 1Ch,08h,0CFh,2eh>	; 24 1.76MB 3.5"
		tMediaFmt <3840,24,2,80,0, 1Ch,20h,0CFh,00h>	; 25 1.92MB 3.5"
		tMediaFmt <6400,40,2,80,0, 25h,5Bh,0CFh,00h>	; 26 3.20MB 3.5"
		tMediaFmt <7040,44,2,80,0, 25h,5Bh,0CFh,00h>	; 27 3.52MB 3.5"
		tMediaFmt <7680,48,2,80,0, 25h,63h,0CFh,00h>	; 28 3.84MB 3.5"

		tMediaFmt <3680,23,2,80,0, 1Ch,10h,0CFh,00h>	; 29 1.84MB 3.5"
		tMediaFmt <1600,10,2,80,0, 25h,02h,0DFh,2Eh>	; 30 800KB 3.5"
		tMediaFmt <3200,20,2,80,0, 1Ch,00h,0CFh,2Ch>	; 31 1.6MB 3.5"

; Table of drives
FD_DrvTable	tFDdevParm FD_MaxNumDrives dup (<>)
ends


; --- Variables ---
segment KVARS
FD_NumDrives	DB	0				; Number of drives
FD_DrTypes	DB	0				; Drive types
FD_MotorSt	DB	0				; Motors status bits
FD_CurrDr	DB	0				; Current drive

FDC_Type	DB	0				; FDC type
FDC_Flags	DB	0				; Misc. FDC flags
FDC_Results	DB FD_MaxResultBytes dup (0)		; FDC result bytes
ends


; --- Interface procedures ---
segment KCODE

		; FD_Init - initialize floppy disk controller.
		; Input: ESI=pointer to buffer for init status string.
		; Output: CF=0 - OK:
		;		    EAX=0,
		;		    DL=number of drives;
		;	  CF=1 - error, AX=error code.
proc FD_Init near
		call	CMOS_ReadFDDTypes
		xor	ah,ah					; Swap nybbles
		shl	eax,4
		or	al,ah
		mov	[FD_DrTypes],al

		call	FDC_GetVersion
		jnc	short @@GotVersion
		call	FDC_Reset
		call	FDC_GetVersion
		jc	short @@Exit
@@GotVersion:	mov	[FDC_Type],al

		cmp	al,FDC_82077
		jb	short @@Drives
		or	[FDC_Flags],FDCfl_HasFIFO

@@Drives:	or	al,al					; FDC found?
		jz	short @@GetStr
		xor	eax,eax
		mov	al,[FD_DrTypes]
		or	al,al
		jz	short @@GetStr
		test	al,15
		jz	short @@Drive2
		mov	edx,offset FD_DrvTable
		stc

@@Copy:		pushfd
		push	eax ecx
		inc	[FD_NumDrives]
		and	al,15
		mov	[edx+tFDdevParm.CMOStype],al
		mov	ecx,size tFDphysParm
		mul	ecx
		add	eax,offset FD_PhysParms
		mov	[edx+tFDdevParm.PhysParmPtr],eax
		pop	ecx eax
		popfd
		jnc	short @@GetStr

@@Drive2:	test	al,0F0h
		jz	short @@GetStr
		shr	al,4
		mov	edx,offset FD_DrvTable+size FD_DrvTable
		clc
		jmp	@@Copy

@@GetStr:	xor	edx,edx
		call	FD_GetInitStatStr
		mov	dl,[FD_NumDrives]
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------



		; FD_HandleEvent - handle floppy disk events.
		; Input: EAX=event code.
		; Output: none.
proc FD_HandleEvent near
		ret
endp		;---------------------------------------------------------------


		; FD_Open - "open" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc FD_Open near

		ret
endp		;---------------------------------------------------------------


		; FD_Close - "close" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc FD_Close near

		ret
endp		;---------------------------------------------------------------


		; FD_Read - read sectors.
		; Input: EDX (high word) - full minor number of device,
		;	 EBX=sector number,
		;	 ECX=number of sectors to read,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FD_Read near

		ret
endp		;---------------------------------------------------------------


		; FD_Write - write sectors.
		; Input: EDX (high word) - full minor number of device,
		;	 EBX=sector number,
		;	 ECX=number of sectors to write,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FD_Write near

		ret
endp		;---------------------------------------------------------------


		; FD_GetInitStatStr - get initialiation status string.
		; Input: EDX (high word) = minor number,
		;	 ESI=address of buffer for string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FD_GetInitStatStr near
		push	ebx edx esi edi

		mov	edi,esi				; Keep pointer to buffer
		mov	esi,offset DrvFDD.DrvName	; Copy "%fd"
		call	StrCopy
		call	StrEnd

		test	edx,00FF0000h			; FDC info?
		jz	short @@FDCinfo

		call	FD_Minor2Drv
		jc	@@Exit
		mov	al,dl
		add	al,'1'
		stosb
		mov	eax," :		"
		stosd
		xor	eax,eax
		mov	al,[ebx+tFDdevParm.CMOStype]
		mov	esi,[FDtypeStrs+eax*4]
		call	StrCopy
		mov	esi,offset FDCstr_Drive
		call	StrAppend
		jmp	@@Exit

@@FDCinfo:	mov	[dword edi]," :		"
		add	edi,4

		xor	eax,eax
		mov	al,[FDC_Type]
		mov	esi,[FDCtypeStrs+eax*4]
		call	StrCopy
		mov	esi,offset FDCstr_FDC
		call	StrAppend
		call	StrEnd

		mov	al,[FD_DrTypes]
		or	al,al
		jz	short @@NotInst
		test	al,0F0h
		jz	short @@OneDrive
		mov	al,'2'
		jmp	short @@Inst

@@OneDrive:	mov	al,'1'

@@Inst:         stosb
		mov	esi,offset FDCstr_Drive
		call	StrCopy
		cmp	al,'2'
		jne	short @@OK
		call	StrEnd
		mov	[word edi],'s'
		jmp	short @@OK

@@NotInst:	mov	esi,offset FDCstr_Drive
		call	StrCopy
		call	StrEnd
		mov	[dword edi]," :"
		mov	esi,offset FDCstr_None
		call	StrAppend

@@OK:		clc
@@Exit:		pop	edi esi edx ebx
		ret
endp		;---------------------------------------------------------------


		; FD_GetParameters - get device parameters.
		; Input: EDX (high word) = device minor number.
		; Output: CF=0 - OK:
		;		    ECX=total number of sectors on disk,
		;		    AL=file system type or 0, if disk is empty.
		;	  CF=1 - error, AX=error code.
proc FD_GetParameters near
		ret
endp		;---------------------------------------------------------------


		; FD_MediaChange - check whether media is changed.
		; Input: EDX (high word) = device minor number.
		; Output: CF=0 - media not changed;
		;	  CF=1 - media changed.
proc FD_MediaChange near
		ret
endp		;---------------------------------------------------------------


		; FD_Format - format track.
		; Input: EDX (high word) = device minor number,
		;	 BL=head,
		;	 CL=cylinder;
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FD_Format near
		ret
endp		;---------------------------------------------------------------

		; FD_MotorControl - turn floppy drive motor on/off.
		; Input: DL=drive number,
		;	 AH=motor status (1=ON, 0=OFF).
		; Output: none.
proc FD_MotorControl near
		push	eax ecx edx

		mov	cl,dl
		mov	al,16
		shl	al,cl
		mov	ch,[FD_MotorSt]
		add	ch,[FD_CurrDr]
		or	ch,FD_EnbCTL+FD_EnbDMAIRQ
		xchg	al,ch
		or	ah,ah
		jz	@@OFF
                or	al,ch
		jmp	short @@Do
@@OFF:		not	ch
		and	al,ch
@@Do:		mov	dx,PORT_FDC_DOR
		out	dx,al
		or	[FD_MotorSt],al
		and	[FD_MotorSt],0F0h
		clc
		pop	edx ecx eax
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; FDC_GetVersion - get FDC version.
		; Input: none.
		; Output: CF=0 - OK, AL=version;
		;	  CF=1 - error, AX=error code.
proc FDC_GetVersion near
		mov	al,FDCcmd_DumpRegs
		call	FDC_OutPort
		jc	short @@Exit
		call	FDC_ReadStatus
		jc	short @@None

		cmp	al,1
		jne	short @@Not8272
		cmp	[FDC_Results],FDst_Ready
		jne	short @@Not8272
		mov	al,FDC_8272
		jmp	short @@OK

@@Not8272:	cmp	al,FD_MaxResultBytes
		jne	short @@Err1
		mov	al,FDCcmd_Version
		call	FDC_OutPort
		jc	short @@Exit
		call	FDC_ReadStatus
		jc	short @@Exit
		cmp	al,1
		jne	short @@Err1
		cmp	[FDC_Results],FDst_Ready
		jne	short @@Not82072
		mov	al,FDC_82072
		jmp	short @@OK

@@Not82072:	cmp	[FDC_Results],FDst_Ready+FDst_CTLBusy
		jne	short @@Err1
		mov	al,FDCcmd_Unlock
		call	FDC_OutPort
		jc	short @@Exit
		call	FDC_ReadStatus
		jc	short @@Exit
		cmp	al,1
		jne	short @@Err1
		cmp	[FDC_Results],FDst_Ready
		jne	short @@Not82077
		mov	al,FDC_82077
		jmp	short @@OK

@@Not82077:	cmp	[FDC_Results],0
		jne	short @@Err1
		mov	al,FDC_82077AA

@@OK:		clc
@@Exit:		ret

@@None:		mov	al,FDC_NONE
		jmp	@@OK

@@Err1:		mov	ax,ERR_FDC_UnexpBytes
		stc
		ret
endp		;---------------------------------------------------------------


		; FD_MotorON - start FDD motor and wait 1/2 sec.
		; Input: DL=drive number.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc FD_MotorON near
		cmp	dl,2
		jae	@@Err
		push	eax ecx
		mov	cl,dl
		mov	al,16
		shl	al,cl				; AL=current status
		and	al,[FD_MotorSt]			; of motor
		mov	ah,1
		call	FD_MotorControl
		or	al,al				; Was already ran?
		jnz	@@OK

@@OK:		pop	ecx eax
		clc
		ret
@@Err:		mov	ax,ERR_FDC_BadDrNum
		stc
		ret
endp		;---------------------------------------------------------------


		; FD_MotorOFF - stop FDD motors.
		; Input: none.
		; Output: none.
		; Note: called by the timer interrupt after 2 sec have elapsed
		;	with no FD activity.
proc FD_MotorOFF near
		ret
endp		;---------------------------------------------------------------


		; FD_SeekTrack - seek head to specified track.
		; Input: DL=drive number,
		;	 BL=track number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FD_SeekTrack near
		cmp	dl,FD_MaxNumDrives
		jae	@@BadDrive
		push	ebx ecx edx edi
		xor	eax,eax
		mov	al,dl
		mov	cl,dl
		mov	ch,size tFDdevParm		; Count offset
		xor	edx,edx				; in drives table
		mul	ch
		add	eax,offset FD_DrvTable
		mov	dl,cl
		test	[eax+tFDdevParm.State],FDST_CALIBRATED
		jnz	short @@Calibrated
		call	FDC_Recalibrate
		jc	@@Exit

@@Calibrated:	xor	bh,bh
		cmp	[eax+tFDdevParm.Cyl],bx		; Already seeked?
		je	@@OK

		mov	edi,eax				; Output SEEK cmd.
		mov	al,FDCcmd_Seek
		call	FDC_OutPort
		mov	al,[edi+tFDdevParm.Head]
		shl	al,2
		or	al,dl
		call	FDC_OutPort
		mov	al,bl
		call	FDC_OutPort
		test	[FDC_Flags],FDCfl_NeedReset	; Error?
		jnz	@@Error1

		call	FDC_WaitIntr			; Wait for FDC interrupt
		jc	@@Error2

		mov	al,FDCcmd_Sense			; Get FDC status
		call	FDC_OutPort
		call	FDC_ReadStatus
		jc	@@Error1

		mov	ecx,offset FDC_Results		; Check result
		mov	al,[ecx+ST0]			; of operation
		and	al,ST0_Bits
		cmp	al,ST0_Seek
		jne	@@Error1
		cmp	[ecx+ST1],bl
		jne	@@Error1

		mov	[edi+tFDdevParm.Cyl],bx

@@OK:		clc
@@Exit:		pop	edi edx ecx ebx
		ret

@@Error1:	mov	ax,ERR_FDC_Seek
		stc
                jmp	short @@Exit
@@Error2:	mov	ax,ERR_FDC_Timeout
@@Error:	stc
                jmp	short @@Exit

@@BadDrive:	mov	ax,ERR_FDC_BadDrNum
		stc
		ret
endp		;---------------------------------------------------------------


		; FDC_Recalibrate - recalibrate FDC.
		; Input:
		; Output:
proc FDC_Recalibrate near

		ret
endp		;---------------------------------------------------------------


		; FDC_Reset - issue a reset to the controller.
		; Input: none.
		; Output: none.
proc FDC_Reset near
		push	ecx edx
		and	[FDC_Flags],not FDCfl_NeedReset
		or	[FDC_Flags],FDCfl_NeedConfigure
		mov	dx,PORT_FDC_DOR
		xor	al,al
		cli
		mov	[FD_MotorSt],al
		out	dx,al
		mov	al,FD_EnbDMAIRQ+FD_EnbCTL
		out	dx,al
		sti

		; For each drive reset CALIBRATED bit
		mov	edx,offset FD_DrvTable
		mov	cl,FD_MaxNumDrives
@@Loop:		and	[edx+tFDdevParm.State],not FDST_CALIBRATED
		add	edx,size FD_DrvTable
		dec	cl
		jnz	@@Loop
		pop	edx ecx
		ret
endp		;---------------------------------------------------------------


		; FDC_ReadResult - read result of last FDC operation.
		; Input: none.
		; Output: AL=number of got bytes.
		; Note: puts result in FDC_Result.
proc FDC_ReadStatus near
		push	ebx ecx edx edi
		mov	ecx,FD_Timeout			; Timeout
		xor	ebx,ebx				; Bytes counter
		mov	dx,PORT_FDC_Status
		mov	ah,FDst_Direct2CPU+FDst_Ready+FDst_CTLBusy

@@Loop:		in	al,dx				; Read one byte
		and	al,ah
		cmp	al,ah				; Status byte present?
		je	short @@GotByte
		cmp	al,FDst_Ready			; All bytes?
		je	short @@OK
		call	DSF_Yield1ms
		loop	@@Loop
		or	[FDC_Flags],FDCfl_NeedReset
		jmp	short @@Err

@@GotByte:	cmp	bl,FD_MaxResultBytes
		jae	short @@Err
		push	edx
		mov	dx,PORT_FDC_Data
		in	al,dx
		mov	[ebx+offset FDC_Results],al
		pop	edx
		inc	bl
		mov	ecx,FD_Timeout			; Restore timeout
		jmp	@@Loop

@@OK:		mov	al,bl
		clc
@@Exit:         pushfd
		push	eax
		mov	al,FD_IRQchan
		call	PIC_EnbIRQ
		pop	eax
		popfd
		pop	edi edx ecx ebx
		ret

@@Err:		mov	ax,ERR_FDC_Status
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; FDC_OutPort - write byte to FDC.
		; Input: AL=byte.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FDC_OutPort near
		push	ecx edx
		mov	ah,al				; Keep byte
		mov	ecx,FD_Timeout			; Timeout
		mov	dx,PORT_FDC_Status

@@Loop:		in	al,dx
		and	al,FDst_Direct2CPU+FDst_Ready
		cmp	al,FDst_Ready			; Is controller ready?
		je	short @@OutByte
		call	DSF_Yield1ms			; Else yield on 1 ms
		loop	@@Loop
		or	[FDC_Flags],FDCfl_NeedReset
		jmp	short @@Timeout

@@OutByte:	mov	dx,PORT_FDC_Data
		mov	al,ah
		out	dx,al
		clc

@@Exit:		pop	edx ecx
		ret

@@Timeout:	mov	ax,ERR_FDC_Timeout
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; FDC_WaitIntr - wait for FDC interrupt completion
		;		 and return results.
		; Input: EDI=device parameters structure address.
		; Outut: CF=0 - OK;
		;	 CF=1 - error, AX=error code.
proc FDC_WaitIntr near
		ret
endp		;---------------------------------------------------------------


		; FD_Minor2Drv - get drive number and device parameters
		;		 structure address by minor number.
		; Input: EDX (high word) = minor number.
		; Output: CF=0 - OK:
		;		    DL=drive number (0,1),
		;		    EBX=device parameters structure address;
		;	  CF=1 - error, AX=error code.
proc FD_Minor2Drv near
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl			; Minor number nonzero?
		jz	short @@Err
		dec	bl
		mov	dl,bl
		xor	bh,bh
		add	ebx,offset FD_DrvTable
		clc
		ret
@@Err:		mov	ax,ERR_DRV_NoMinor
		stc
		ret
endp		;---------------------------------------------------------------

ends

end
