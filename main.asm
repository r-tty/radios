;*******************************************************************************
;  main.asm - RadiOS initializer.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
ideal

include "initdefs.ah"
include "biosdata.ah"
include "macros.ah"

DEBUGUNDERDOS=1
DEBUG=1

;*********************** Protected mode starting segment ***********************

segment		PMSTARTSEG 'code' use16
		assume CS:PMSTARTSEG, DS:PMSTARTSEG, ES:RADIOSKRNLSEG
		org 0

		; Now program is in real mode.
		; This	code sets GDT and IDT, then enter protected mode.
RMstart:	cli

IFDEF	DEBUGUNDERDOS
include "ETC\dbgudos.asm"
ENDIF
		mov	ax,cs
		mov	ds,ax
		mov	eax,offset GDT			; Prepare for LGDT
		mov	[dword	GDTptr+2],eax
    		mov	eax,offset IDT			; Prepare for LIDT
    		mov	[dword	IDTptr+2],eax
		lgdt	[GDTptr]
		lidt	[IDTptr]
		mov	eax,cr0
		or	al,1
		mov	cr0,eax				; Enter PM
		PMJF16	KernelCode,PMinit		; Far jump to PM kernel

GDTptr		DF	(size GDT)-1
IDTptr		DF	(size tDescriptor)*256-1

ends


;**************************** Kernel segment ***********************************

segment		RADIOSKRNLSEG public 'code' use32
		assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG
		org 0

;-------------------- External and global procedures and data-------------------

		extrn CPU_GetType:	near

		extrn PIC_Init:		near
		extrn PIC_SetIRQmask:	near

		extrn TMR_InitCounter:	near
		extrn TMR_CountCPUspeed:near

		extrn SPK_Beep:		near

		extrn DrvKeyboard:	tDriver		; Hardware drivers
		extrn DrvVGATX:		tDriver
		extrn DrvVGAGR:		tDriver
		extrn DrvAudio:		tDriver
		extrn DrvEthernet:	tDriver
		extrn DrvSerial:	tDriver
		extrn DrvParallel:	tDriver
		extrn DrvFDD:		tDriver
		extrn DrvHDIDE:		tDriver
		extrn DrvHDSCSI:	tDriver

		extrn DrvConsole:	tDriver		; Software drivers
;		extrn DrvCache:		tDriver

		extrn MonitorEntry:	near		; Monitor

;------------------------------ BIOS data area ---------------------------------

RMIntsTbl	tRMIntsTbl	<>
BIOSData	tBIOSDA		<>

		DB BIOSDAsize-(size RMIntsTbl)-(size BIOSData) dup (?)


;------------------------------- Kernel body -----------------------------------

include "KERNEL\kernel.asm"


;-------------------------- Internal drivers table -----------------------------

InternalDriversTable	DD	DrvCPU
			DD	DrvFPU
			DD	DrvMemory
			DD	DrvKeyboard
			DD	DrvVGATX
			DD	DrvVGAGR
			DD	DrvAudio
			DD	DrvEthernet
			DD	DrvSerial
			DD	DrvParallel
			DD	DrvFDD
			DD	DrvHDIDE


;------------------------- Initialization procedures ---------------------------

		; INIT_ShowCPUFPU - show CPU & FPU type
proc INIT_ShowCPUFPU near
		mWrChar ' '
		mCallDriverCtrl DRVID_CPU,DRVCTL_GetInitStatStr
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

		mWrChar' '
		mCallDriverCtrl DRVID_FPU,DRVCTL_GetInitStatStr
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskDrvs - initialize disk drivers.
proc INIT_InitDiskDrvs near
		mWrString INFO_InitDskDr

		mWrChar ' '
		mCallDriver DRVID_FDD,DRVF_Init
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

;		mWrChar ' '
;		mCallDriver DRVID_HDD,DRVF_Init
;		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		ret
endp		;---------------------------------------------------------------

;----------------------- Inititialization entry point --------------------------

label PMinit far

		; Disable interrupts
		cli

		; Set segment registers
		mov	ax,offset (tRGDT).KernelData
		mov	ds,ax
		mov	es,ax
		mov	gs,ax
		mov	fs,ax
		mov	ss,ax
		mov	esp,InitESP

		; Install internal device drivers
		mov	esi,offset InternalDriversTable
DrvInstLoop:	mov	ebx,[esi]
		xor	edx,edx
		call	DRV_InstallNew
		add	esi,4
		cmp	eax,DRVID_HDD
		jne	DrvInstLoop

		; Initialize CPU and FPU drivers.
		mCallDriver DRVID_CPU,DRVF_Init
		mCallDriver DRVID_FPU,DRVF_Init

		; Initialize interrupt controller (PIC)
		xor	ah,ah
		mov	al,IRQ0int
		call	PIC_Init
		inc	ah
		mov	al,IRQ8int
		call	PIC_Init
		xor	eax,eax
		call	PIC_SetIRQmask
		not	eax
		call	PIC_SetIRQmask

		; Initialize timer (counter 0)
		mov	al,36h				; Counter 0, mode 3
		mov	cx,59659			; 1/20 second
		call	TMR_InitCounter
		sti

		; Install and initialize console driver
		mov	ebx,offset DrvConsole
		xor	edx,edx
		call	DRV_InstallNew
		mov	[DrvId_Con],eax
		mCallDriver eax,DRVF_Init
;		jc	Init_Halt
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

		; Show kernel version message
		mWrString INFO_RadiOS

		; Show CPU & FPU type
		call	INIT_ShowCPUFPU

		; Initialize memory driver
		mCallDriver DRVID_Memory,DRVF_Init
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

		; Initialize disk drivers
		call	INIT_InitDiskDrvs

		; Initialize file systems
mov edi,offset WriteChar
		; Mount root

		; Call debugger
		call	MonitorEntry

		; Reset system
		mWrString INFO_Shutdown
		mCallDriver [DrvId_Con],DRVF_Read
		cli
		mov	[word BIOSDA_Begin+(tBIOSDA).RebootFlag],1234h
		mov	esi,[0FFFF0h]
		jmp	[dword esi]

Init_Halt:	jmp	Init_Halt

ends

end	RMstart
