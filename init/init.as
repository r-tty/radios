;*******************************************************************************
;  init.as - RadiOS initializer.
;  Copyright (c) 1999,2000 RET & COM research.
;*******************************************************************************

module $init

%include "sys.ah"
%include "errors.ah"
%include "initdefs.ah"
%include "boot/bootdefs.ah"
%include "boot/mb_info.ah"
%include "biosdata.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "x86/descript.ah"
%include "x86/paging.ah"
%include "kconio.ah"
%include "asciictl.ah"
%include "hw/partids.ah"


; --- Exports ---

global Start:export proc
global SysReboot


; --- Imports ---

; Built-in drivers
extern DrvBIOS32:near, DrvKeyboard:near,
extern DrvVTX:near, DrvVGAGR:near
extern DrvSerial:near, DrvParport:near
extern DrvFDD:near, DrvIDE:near
extern DrvRD:near
extern DrvRDM:near, DrvCOFF:near
extern DrvConsole:near

; Kernel variables and data
library kernel
extern GDTaddrLim, IDTaddr, TrapHandlersArr
extern DrvId_Con, DrvId_RD, DrvId_BIOS32

; Kernel procedures
extern K_CheckCPU:near, K_InitFPU:near, K_InitMem:near, K_GetMemInitStr:near
extern K_GetCPUtypeStr:near, K_GetFPUtypeStr:near
extern KernelEventHandler:near
extern K_DescriptorAddress:near
extern K_GetDescriptorBase:near, K_GetDescriptorLimit:near
extern K_GetDescriptorAR:near
extern K_SetDescriptorBase:near, K_SetDescriptorLimit:near

library kernel.driver
extern DRV_InitTable:near, DRV_InstallNew:near
extern DRV_CallDriver:near, DRV_GetName:near, DRV_FindName:near

library kernel.mm
extern MM_Init:near

library kernel.paging
extern PG_Init:near, PG_StartPaging:near

library kernel.mt
extern MT_Init:near, MT_InitKernelProc:near
extern MT_CreateThread:near, MT_ThreadExec:near

library kernel.module
extern MOD_InitMem:near, MOD_InitKernelMod:near
extern MOD_RegisterFormat:near, MOD_Insert:near

library kernel.misc
extern StrLComp:near

library kernel.kconio
extern PrintChar:near, PrintString:near
extern PrintByteDec:near, PrintDwordDec:near, PrintWordHex:near
extern ReadChar:near

library hw.onboard
extern PIC_Init:near, PIC_SetIRQmask:near, PIC_EnbIRQ:near
extern TMR_InitCounter:near
extern KBC_A20Control:near, KBC_HardReset:near
extern CMOS_EnableInt:near

library cfs.init
extern CFS_Init:near

library hardware.genhd
extern HD_Init:near

library monitor
extern MonitorInit:near

library rkdt
extern RKDT_Main:near

library version
extern RadiOS_Version

; --- Data ---

section .data

Msg_A20Fail	DB "A20 line opening failure",0
Msg_Bytes	DB " bytes.",NL,0
Msg_RVersion	DB NL,"RadiOS kernel, version ",0
Msg_RCopyright	DB " (C) 1998-2001 RET & COM Research.",NL,0

Msg_InitDskDr	DB NL,NL,"Initializing disk drivers"
Msg_Dots	DB "...",NL,0
Msg_SearchPart	DB NL,"Searching partitions on ",0
Msg_InitChDr	DB NL,"Initializing character device drivers...",NL,0
Msg_InitErr	DB ": init error ",0
Msg_InitBootMod	DB NL,"Initializing boot-time modules...",NL,0

Msg_SysReboot	DB NL,NL,"Press a key to reboot...",ASC_BEL,0

Msg_Fatal	DB NL,NL,"FATAL ERROR ",0
Msg_SysHlt	DB NL,"System halted.",0

NLNL		DB NL,NL,0

BootDev_HD	DB "%hd"
BootDev_SD	DB "%sd"

InternalDriversTable	DD	0
			DD	0
			DD	0
			DD	DrvKeyboard
			DD	DrvVTX
			DD	DrvVGAGR
			DD	0
			DD	0
			DD	DrvSerial
			DD	DrvParport
			DD	DrvFDD
			DD	DrvIDE

BinFmtDrivers		DD	DrvRDM
			DD	0


; --- Variables ---

section .bss

IdleTCB		RESD	1				; Idle thread TCB
IDTaddrLim	RESB	6
InitStringBuf	RESB	256


; --- Code ---

section .text

%include "buildxdt.as"


; --- Initialization procedures ---

		; INIT_GetStCfgItem - get startup configuration item address.
		; Input: AL=item number.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error.
proc INIT_GetStCfgItem
		push	eax
		mov	ebx,StartCfgTblAddr
		cmp	al,[ebx+tStartConfig.NumOfItems]
		cmc
		jb	short .Exit
		movzx	eax,al
		shl	eax,1
		lea	eax,[ebx+eax+tStartConfig.ItemOffsets]
		add	bx,[eax]
		clc
		pop	eax
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_ShowCPUFPU - show CPU & FPU type
proc INIT_ShowCPUFPU
		mov	esi,InitStringBuf
		call	K_GetCPUtypeStr
		mPrintChar ' '
		mPrintString
		mPrintChar NL

		call	K_GetFPUtypeStr
		mPrintChar ' '
		mPrintString
		mPrintChar NL
		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskDrvs - initialize disk drivers.
proc INIT_InitDiskDrvs
		; Print message
		mPrintString Msg_InitDskDr
		mov	esi,InitStringBuf

		; Initialize DIHD structures
		mov	al,16				; Max. 16 drives
		call	HD_Init

		; Initialize FDD driver
		mCallDriver byte DRVID_FDD, byte DRVF_Init
		jnc	short .FDinitOK
		mov	ebx,DRVID_FDD
		call	DrvInitErr
		jmp	near .InitIDE

.FDinitOK:	mPrintChar ' '
		mPrintString
		or	dl,dl
		jz	short .InitIDE

		; Print floppy drives information
		mov	ebx,DRVID_FDD			; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

.Loop:		push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		mPrintChar NL
		mPrintChar ' '
		mPrintString
		inc	cl
		cmp	cl,dl
		jbe	.Loop


		; Initialize HD IDE driver
.InitIDE:	mov	dl,2				; Max # of drives to search
		mCallDriver byte DRVID_HDIDE, byte DRVF_Init
		jnc	short .IDEinitOK
		mov	ebx,DRVID_HDIDE
		call	DrvInitErr
		jmp	.Exit

.IDEinitOK:	mPrintChar NL
		mPrintChar ' '
		mPrintString
		or	dl,dl
		jz	short .Exit

		; Print model of all hard disks found
		mov	dl,4
		mov	ebx,DRVID_HDIDE				; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

.Loop1:		push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		jc	short .NoDrive
		mPrintChar NL
		mPrintChar ' '
		mPrintString
.NoDrive:	inc	cl
		cmp	cl,dl
		jbe	.Loop1

.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitChDrv - initialize character device drivers.
proc INIT_InitChDrv
		mPrintString Msg_InitChDr
		mov	esi,InitStringBuf
		xor	al,al
		mCallDriver byte DRVID_Parallel, byte DRVF_Init
		jnc	short .PrintParSt
		mov	ebx,DRVID_Parallel
		call	DrvInitErr
		jmp	short .InitSerial

.PrintParSt:	mPrintChar ' '
		mPrintString
		mPrintChar NL

.InitSerial:	xor	al,al
		mov	ecx,(Init_SerOutBufSize << 16) + Init_SerInpBufSize
		mCallDriver byte DRVID_Serial, byte DRVF_Init
		jnc	short .PrintSerSt
		mov	ebx,DRVID_Serial
		call	DrvInitErr
		jmp	short .Continue

.PrintSerSt:	mPrintChar ' '
		mPrintString
		mPrintChar NL

.Continue:	ret
endp		;---------------------------------------------------------------


		; INIT_ChkSwapDev - check swap device.
		; Input: none.
		; Output: CF=0 - OK, ECX=size of virtual memory;
		;	  CF=1 - error.
proc INIT_ChkSwapDev
	clc
		ret
endp		;---------------------------------------------------------------


		; INIT_InitRAMdisk - initialize RAM-disk.
proc INIT_InitRAMdisk
		mov	al,SCFG_RAMdiskSz		; Read config item
		call	INIT_GetStCfgItem		; (disk size in KB)
		xor	ecx,ecx
		mov	cx,[ebx]
		or	ecx,ecx				; Initialize?
		jz	near .OK
		cmp	cx,8192				; Check disk size
		cmc
		jb	short .Exit

		mov	ebx,DrvRD			; Install driver
		xor	edx,edx
		call	DRV_InstallNew
		jc	short .Exit
		mov	[DrvId_RD],eax			; Keep driver ID

		mov	esi,InitStringBuf
		mCallDriver dword [DrvId_RD], byte DRVF_Init
		jc	short .Exit
		mPrintChar NL
		call	PrintChar
		mPrintChar ' '
		mPrintString
.OK:		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_LoadRDimage - load RAM-disk image.
proc INIT_LoadRDimage
		ret
endp		;---------------------------------------------------------------


		; INIT_PrintPartTbl - open boot disk device and print its
		;		      partition table.
proc INIT_PrintPartTbl
		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	near .Exit

		mov	esi,ebx				; Check for %hd or %sd
		mov	edi,BootDev_HD
		xor	ecx,ecx
		mov	cl,3
		call	StrLComp			; "%hd"?
		or	al,al
		jz	short .Do
		mov	edi,BootDev_SD
		call	StrLComp			; "%sd"?
		or	al,al
		jz	short .Do
		jmp	.OK				; Else don't print

.Do:		call	DRV_FindName			; Get device ID
		jc	near .Exit
		mov	ebx,eax				; and keep it

		and	eax,00FFFFFFh			; Mask subminor
		push	eax
		push	dword DRVF_Open
		call	DRV_CallDriver			; "Open" device
		jc	near .Exit

		mPrintString Msg_SearchPart		; Print message
		mov	eax,ebx				; Restore device ID
		and	eax,0000FFFFh
		call	DRV_GetName
		mPrintString
		mov	eax,ebx
		shr	eax,16
		add	al,30h
		call	PrintChar
		mPrintString Msg_Dots

		mov	dl,1
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr
		mov	esi,InitStringBuf
.Loop:		push	ebx
		mov	[esp+3],dl
		push	edi
		call	DRV_CallDriver
		jnc	short .Print
		cmp	dl,4
		ja	short .OK
		jmp	short .IncCnt
.Print:		mPrintChar ' '
		mPrintString
		mPrintChar NL
.IncCnt:	inc	dl
		jmp	.Loop
.OK:		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InstallBinFmtDrvs - install and initialize binary
		;			   format drivers.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_InstallBinFmtDrvs
		xor	ecx,ecx
.Loop:		mov	ebx,[BinFmtDrivers+ecx*4]
		or	ebx,ebx
		jz	short .Exit
		xor	edx,edx
		call	DRV_InstallNew
		jc	short .Exit
		call	MOD_RegisterFormat
		jc	short .Exit
		inc	cl
		jmp	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_BootModules - initialize boot-time modules.
		; Input: none:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_BootModules
		mov	ecx,[BootModulesCount]
		jecxz	.Exit
		mPrintString Msg_InitBootMod
		mov	edi,[BootModulesListAddr]
		xor	esi,esi
.Loop:		mov	ebx,[edi+tModList.Start]
		call	MOD_Insert
		add	edi,byte tModList_size
		loop	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; Driver initialization error: print driver name,
		; error message, error number, beep and return.
		; Input: EBX=driver ID,
		;	 AX=error number.
proc DrvInitErr
		xchg	eax,ebx
		call	DRV_GetName
		jc	short .Exit
		mPrintString
		mPrintChar ASC_BEL
		mPrintString Msg_InitErr
		xchg	eax,ebx
		call	PrintWordHex
		mPrintChar NL
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_IdleThread - kernel idle thread.
		;		    Currently does nothing, only displays its
		;		    activity.
		; Input: none.
		; Output: none.
proc INIT_IdleThread
.Infinite:	inc	byte [0xB8000+158]
		jmp	.Infinite
endp		;---------------------------------------------------------------



; --- Inititialization entry point ---

proc Start
		; Initialize GDTR
		cli
		lgdt	[GDTaddrLim]
		jmp	KERNELCODE:.InitSegs

		; Set segment registers
.InitSegs:	mov	ax,KERNELDATA
		mov	ds,ax
		mov	es,ax
		mov	gs,ax
		mov	fs,ax
		mov	ss,ax
		mov	edx,[KernelFreeMemEnd]		; EDX=base memory top
		lea	esp,[edx-4]

		; Initialize global page pool
		mov	ebx,[KernelFreeMemStart]	; EBX=begin of
		sub	edx,Init_StackSize		; kernel free memory
		mov	ecx,[UpperMemSizeKB]		; Upper memory size
		call	PG_Init

		; Build IDT
		call	INIT_BuildIDT

		; Initialize IDTR
		mov	eax,[IDTaddr]
		mov	word [IDTaddrLim],IDT_size-1
		mov	[IDTaddrLim+2],eax
		lidt	[IDTaddrLim]

		; Build and initialize LDTs
		call	INIT_InitLDTs

		; Install internal device drivers
		mov	eax,Init_MaxNumDrivers
		call	DRV_InitTable
		mov	esi,InternalDriversTable
.DrvInstLoop:	mov	ebx,[esi]
		xor	edx,edx
		call	DRV_InstallNew
		add	esi,byte 4
		cmp	eax,DRVID_HDIDE
		jne	.DrvInstLoop

		; Initialize interrupt controllers
		xor	ah,ah
		mov	al,IRQ0int
		call	PIC_Init
		inc	ah
		mov	al,IRQ8int
		call	PIC_Init
		xor	eax,eax
		mov	al,1				; IRQ0 disabled
		call	PIC_SetIRQmask
		dec	al
		inc	ah
		call	PIC_SetIRQmask
		call	CMOS_EnableInt

		; Initialize timer (counter 0)
		mov	al,36h				; Counter 0, mode 3
		mov	cx,TIMER_InpFreq/TIMER_OutFreq	; Set divisor
		call	TMR_InitCounter
		sti

		; Initialize CPU and FPU.
		call	K_CheckCPU
		mov	al,1				; Use math emulation
		call	K_InitFPU			; if 387 not present

		; Install and initialize console driver
		mov	ebx,DrvConsole
		xor	edx,edx
		call	DRV_InstallNew
		mov	[DrvId_Con],eax
		mCallDriver eax, byte DRVF_Init
		jc	short .InitMon
		mov	esi,InitStringBuf
		mCallDriverCtrl dword [DrvId_Con],DRVCTL_GetInitStatStr
		mPrintString
		mPrintString NLNL

		; Initialize monitor
.InitMon:	call	MonitorInit

		; Show CPU & FPU type
		call	INIT_ShowCPUFPU

		; Enable A20
		mov	al,1
		call	KBC_A20Control
		jnc	short .InitMem
		mPrintString Msg_A20Fail

		; Initialize memory
.InitMem:	mov	eax,[KernelFreeMemEnd]
		shr	eax,10				; Addr -> KB
		call	K_InitMem
		mov	esi,InitStringBuf
		call	K_GetMemInitStr
		mPrintChar ' '
		mPrintString
		mPrintString NLNL

		; Install and initialize BIOS32 driver
		mov	ebx,DrvBIOS32
		xor	edx,edx
		call	DRV_InstallNew
		mov	[DrvId_BIOS32],eax
		mov	ebx,eax
		mCallDriver eax, byte DRVF_Init		
		jc	short .B32err
		mov	esi,InitStringBuf
		mCallDriverCtrl ebx,DRVCTL_GetInitStatStr
		mPrintChar ' '
		mPrintString
		jmp	short .InitMT
		
.B32err:	call	DrvInitErr
		
		; Initialize multitasking memory structures
.InitMT:	mov	eax,Init_MaxNumOfProcesses
		mov	ecx,Init_MaxNumOfThreads
		call	MT_Init
		jc	.Monitor

		; Enable paging
		call	PG_StartPaging
		jc	.Monitor

		; Create kernel process
		call	MT_InitKernelProc
		jc	.Monitor
call ReadChar
		; Initialize disk drivers
		call	INIT_InitDiskDrvs

		; Check startup configuration table signature
		mov	ebx,StartCfgTblAddr
		cmp	dword [ebx+tStartConfig.Signature],SCFG_Signature
		mov	ax,ERR_INIT_BadSCT
		jne	near FatalError

		; Initialize RAM-disk
		call	INIT_InitRAMdisk
		jc	near .Monitor

		; Print partition table on boot device
		call	INIT_PrintPartTbl
		jc	near .Monitor

		; Check and initialize swap device
		call	INIT_ChkSwapDev
		jc	near .Monitor

		; Initialize character device drivers
		call	INIT_InitChDrv
		
		; Initialize CFS
		call	CFS_Init
		jc	.Monitor

		; Initialize module table
		mov	eax,Init_MaxNumLoadedMods
		call	MOD_InitMem
		jc	near .Monitor

		; Initialize kernel module
		call	MOD_InitKernelMod
		jc	near .Monitor

		; Install and initialize binary format drivers
		call	INIT_InstallBinFmtDrvs
		jc	FatalError

		; Initialize memory management
		call	MM_Init
		jc	FatalError
		
		; Initialize boot-time modules
		call	INIT_BootModules
		jc	FatalError
		
		; Show version information
		mPrintString Msg_RVersion
		mPrintString RadiOS_Version
		mPrintString Msg_RCopyright

		; Create two initial kernel threads
		; (idle and RKDT).
		mov	ebx,INIT_IdleThread
		xor	ecx,ecx
		xor	esi,esi
		call	MT_CreateThread
		jc	.Monitor
		mov	[IdleTCB],ebx			; Save launcher TCB

		mov	ebx,RKDT_Main
		mov	ecx,16384			; 16KB stack
		call	MT_CreateThread
		jc	.Monitor

		; Enable timer interrupts and roll the dice! ;)
		xor	al,al
		call	PIC_EnbIRQ
		mov	ebx,[IdleTCB]
		call	MT_ThreadExec

		; This point must never be reached!
.Monitor:	int3

		; Reboot the machine
		mPrintString Msg_SysReboot
		call	ReadChar
SysReboot:	call	KBC_HardReset

		; Fatal error: print error message, error number
		; and halt the system
FatalError:	push	eax
		mPrintString Msg_Fatal
		pop	eax
		call	PrintWordHex
		mPrintString Msg_SysHlt

.Halt:		jmp	.Halt
endp		;---------------------------------------------------------------
