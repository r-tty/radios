;*******************************************************************************
;  init.asm - RadiOS initializer.
;  Copyright (c) 1998,99 RET & COM research.
;*******************************************************************************

.386p
ideal

include "initdefs.ah"
include "segments.ah"
include "biosdata.ah"
include "macros.ah"
include "drvctrl.ah"
include "hardware.ah"
include "drivers.ah"
include "diskbuf.ah"
include "gdt.ah"
include "kernel.ah"
include "process.ah"
include "commonfs.ah"
include "cfs_func.ah"
include "misc.ah"
include "strings.ah"
include "errdefs.ah"
include "asciictl.ah"
include "hd.ah"

DEBUG=1
DEBUGUNDERDOS=1


segment ABSOLUTE
RMIntsTbl	tRMIntsTbl	<>		; RM interrupts
BIOSData	tBIOSDA		<>		; BIOS data

		DB BIOSDAsize-(size RMIntsTbl)-(size BIOSData) dup (?)
ends

segment	KDATA
Msg_A20Fail	DB "A20 line opening failure.",0
Msg_Bytes	DB " bytes.",NL,0
Msg_RadiOS	DB NL
		DB "ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออป",NL
		DB "บ Radiant Operating System (RadiOS), kernel version d0.01 บ",NL
		DB "บ Public Domain Release 1.0 by RET & COM Research 1998,99 บ",NL
		DB "ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ",NL,0

Msg_InitDskDr	DB NL,NL,"Initializing disk drivers"
Msg_Dots	DB "...",NL,0
Msg_DiskBuf	DB " KB allocated for disk buffers",NL,0
Msg_InitFSDRV	DB NL,"Initializing file system drivers...",NL,0
Msg_SearchPart	DB NL,"Searching partitions on ",0
Msg_LinkPrimFS	DB NL,"Linking primary file system: ",0
Msg_Arrow	DB " <-> ",0
Msg_At		DB " at ",0
Msg_UnknFS	DB "failed, unknown file system on ",0
Msg_TryCrFS	DB NL,"Try to create file system manually :-)",NL,0
Msg_TotMem	DB NL,"Total memory size: ",0
Msg_KB		DB " KB",NL,0
Msg_MemKrnl	DB " Kernel:  ",0
Msg_MemDrv	DB " Drivers: ",0
Msg_MemFree	DB " Free:    ",0
Msg_MemVirt	DB " Virtual: ",0
Msg_InitChDr	DB NL,"Initializing character device drivers...",NL,0
Msg_InitErr	DB ": init error ",0

Msg_Assembler	DB "Assembled with Turbo Assembler (tasmx), version 4.1",NL
		DB "Copyright (C) 1988,1996 Borland International.",NL,0

Msg_SysReset1	DB ASC_BEL,NL,NL,"Main process completed (exit code=",0
Msg_SysReset2	DB "). Press any key to reset...",0

Msg_Fatal	DB NL,NL,"FATAL ERROR ",0
Msg_SysHlt	DB NL,"System halted.",0

NLNL		DB NL,NL,0

BootDev_HD	DB "%hd"
BootDev_SD	DB "%sd"

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

BinFmtDrivers		DD	DrvRDF
;			DD	DrvRMod
;			DD	DrvCOFF
ends

segment KVARS
InitStringBuf	DB 256 dup (?)
ends


include "parsecfg.asm"

segment	KCODE

; --- Initialization procedures ---

		; INIT_GetStCfgItem - get startup configuration item address.
		; Input: AL=item number.
		; Output: CF=0 - OK,EBX=address;
		;	  CF=1 - error.
proc INIT_GetStCfgItem near
		push	eax
		mov	ebx,StartCfgTblAddr
		cmp	al,[byte ebx+tStartConfig.NumOfItems]
		cmc
		jb	short @@Exit
		movzx	eax,al
		shl	eax,1
		lea	eax,[ebx+eax+offset (tStartConfig).ItemOffsets]
		add	bx,[eax]
		clc
		pop	eax
@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_ShowCPUFPU - show CPU & FPU type
proc INIT_ShowCPUFPU near
		mov	esi,offset InitStringBuf
		mCallDriverCtrl DRVID_CPU,DRVCTL_GetInitStatStr
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL

		mCallDriverCtrl DRVID_FPU,DRVCTL_GetInitStatStr
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL
		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskDrvs - initialize disk drivers.
proc INIT_InitDiskDrvs near
		; Print message
		mWrString Msg_InitDskDr
		mov	esi,offset InitStringBuf

		; Initialize DIHD structures
		mov	al,16				; 16 hard disks
		call	HD_Init

		; Initialize FDD driver
		mCallDriver DRVID_FDD,DRVF_Init
		jnc	short @@FDinitOK
		mov	ebx,DRVID_FDD
		call	DrvInitErr
		jmp	short @@InitIDE

@@FDinitOK:	mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		or	dl,dl
		jz	short @@InitIDE

		; Print floppy drives information
		mov	ebx,DRVID_FDD			; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

@@Loop:		push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		mWrChar NL
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		inc	cl
		cmp	cl,dl
		jbe	@@Loop


		; Initialize HD IDE driver
@@InitIDE:	mov	dl,1
		mCallDriver DRVID_HDIDE,DRVF_Init
		jnc	short @@IDEinitOK
		mov	ebx,DRVID_HDIDE
		call	DrvInitErr
		jmp	short @@Exit

@@IDEinitOK:	mWrChar NL
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		or	dl,dl
		jz	short @@Exit

		; Print model of all hard disks found
		mov	ebx,DRVID_HDIDE			; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

@@Loop1:	push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		mWrChar NL
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		inc	cl
		cmp	cl,dl
		jbe	@@Loop1

@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitChDrv - initialize character device drivers.
proc INIT_InitChDrv near
		mWrString Msg_InitChDr
		mov	esi,offset InitStringBuf
		xor	al,al
		mCallDriver DRVID_Parallel,DRVF_Init
		jnc	short @@PrintParSt
		mov	ebx,DRVID_Parallel
		call	DrvInitErr
		jmp	short @@InitSerial

@@PrintParSt:	mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL

@@InitSerial:	xor	al,al
		mov	cx,Init_SerOutBufSize
		shl	ecx,16
		mov	cx,Init_SerInpBufSize
		mCallDriver DRVID_Serial,DRVF_Init
		jnc	short @@PrintSerSt
		mov	ebx,DRVID_Serial
		call	DrvInitErr
		jmp	short @@Continue

@@PrintSerSt:	mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL

@@Continue:	ret
endp		;---------------------------------------------------------------


		; INIT_CreateKernelProcess - initialize kernel process.
proc INIT_CreateKernelProcess near
@@procinfo	EQU	ebp-size tProcInit
		enter	size tProcInit,0
		lea	ebx,[@@procinfo]
		mov	[ebx+tProcInit.MaxFHandles],Init_NumKernFHandles
		mov	[ebx+tProcInit.EnvSize],Init_KernEnvSize
		mov	[ebx+tProcInit.EventHandler],offset KernelEventHandler
		call	MT_CreateKernelProcess
		leave
		ret
endp		;---------------------------------------------------------------


		; INIT_ChkSwapDev - check swap device.
		; Input: none.
		; Output: CF=0 - OK, ECX=size of virtual memory;
		;	  CF=1 - error.
proc INIT_ChkSwapDev near
	mov	ecx,Init_MaxVirtMem
	clc
		ret
endp		;---------------------------------------------------------------


		; INIT_InitRAMdisk - initialize RAM-disk.
proc INIT_InitRAMdisk near
		mov	al,SCFG_RAMdiskSz		; Read config item
		call	INIT_GetStCfgItem		; (disk size in KB)
		xor	ecx,ecx
		mov	cx,[ebx]			; ECX=buffers memory
		or	ecx,ecx				; Initialize?
		jz	short @@OK
		cmp	cx,8192				; Check disk size
		cmc
		jb	short @@Exit

		mov	ebx,offset DrvRD		; Install driver
		xor	edx,edx
		call	DRV_InstallNew
		jc	short @@Exit
		mov	[DrvId_RD],eax			; Keep driver ID

		mov	esi,offset InitStringBuf
		mCallDriver [DrvId_RD],DRVF_Init
		jc	short @@Exit
		mWrChar NL
		mWrChar NL
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
@@OK:		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskBuffers - initialize disk buffers
proc INIT_InitDiskBuffers near
		mov	al,SCFG_BuffersMem		; Read config item
		call	INIT_GetStCfgItem		; (buffers memory in KB)
		xor	ecx,ecx
		mov	cx,[ebx]			; ECX=buffers memory
		cmp	cx,8192
		cmc
		jb	short @@Exit
		call	BUF_InitMem
		jc	short @@Exit
		mWrChar NL
		mov	eax,ecx				; Print message
		call	PrintDwordDec
		mWrString Msg_DiskBuf
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitFileSystems - install and initialize all
		;			 file system drivers.
proc INIT_InitFileSystems near

		; RFS driver
		mov	ebx,offset DrvRFS
		xor	edx,edx
		call	DRV_InstallNew
		jc	short @@Exit
		mov	[DrvId_RFS],eax

		mov	al,26				; Max. number of LPs
		mov	cl,48				; Max. number of FCBs
		mov	esi,offset InitStringBuf	; Buffer for status string
		mCallDriver [DrvId_RFS],DRVF_Init
		jc	short @@Exit
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

		; MDOSFS driver

		clc
@@Exit:		ret
endp		;---------------------------------------------------------------



		; INIT_PrintPartTbl - open boot disk device and print its
		;		      partition table.
proc INIT_PrintPartTbl near
		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	@@Exit

		mov	esi,ebx				; Check for %hd or %sd
		mov	edi,offset BootDev_HD
		xor	ecx,ecx
		mov	cl,3
		call	StrLComp			; "%hd"?
		or	al,al
		jz	short @@Do
		mov	edi,offset BootDev_SD
		call	StrLComp			; "%sd"?
		or	al,al
		jz	short @@Do
		jmp	@@OK				; Else don't print

@@Do:		call	DRV_FindName			; Get device ID
		jc	@@Exit
		mov	ebx,eax				; and keep it

		and	eax,00FFFFFFh			; Mask subminor
		push	eax
		push	DRVF_Open
		call	DRV_CallDriver			; "Open" device
		jc	@@Exit

		mWrString Msg_SearchPart		; Print message
		mov	eax,ebx				; Restore device ID
		and	eax,0000FFFFh
		call	DRV_GetName
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mov	eax,ebx
		shr	eax,16
		add	al,30h
		call	WriteChar
		mWrString Msg_Dots

		mov	dl,1
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr
		mov	esi,offset InitStringBuf
@@Loop:		push	ebx
		mov	[esp+3],dl
		push	edi
		call	DRV_CallDriver
		jnc	short @@Print
		cmp	dl,4
		ja	short @@OK
		jmp	short @@IncCnt
@@Print:	mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL
@@IncCnt:	inc	dl
		jmp	@@Loop
@@OK:		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_GetFSdrvIDfromCode - get file system driver ID from
		;			    partition system code.
		; Input: AL=partition system code.
		; Output: CF=0 - OK, EDX=driver ID;
		;	  CF=1 - error (unknown code).
proc INIT_GetFSdrvIDfromCode near
		mov	edx,[DrvId_RFS]
		cmp	al,CFS_ID_RFSNATIVE
		je	short @@OK
;		mov	edx,[DrvId_MDOSFS]
;		cmp	al,CFS_ID_DOSFAT16SMALL
;		je	short @@OK
;		cmp	al,CFS_ID_DOSFAT16LARGE
;		je	short @@OK
;		mov	edx,[DrvId_HPFS]
;		cmp	al,CFS_ID_OS2HPFS
;		je	short @@OK

		stc
		ret

@@OK:		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_LinkPrimFS - link primary file system.
proc INIT_LinkPrimFS near
@@devicestr	EQU	ebp-4
@@fsdrvstr	EQU	ebp-8
@@fslpstr	EQU	ebp-12

		enter	12,0				; Save space
		mWrString Msg_LinkPrimFS

		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	@@Exit
		mov	[@@devicestr],ebx		; Keep it

		mov	esi,ebx
		call	DRV_FindName			; Get boot device ID
		jc	@@Exit
		mov	edi,eax				; Keep it in EDI
		mCallDriverCtrl edi,DRVCTL_GetParams	; Get partition type
		or	al,al				; Known file system?
		jnz	short @@KnownFS			; Yes, continue
		mWrString Msg_UnknFS			; Else print error msg
		mov	esi,ebx
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrString Msg_TryCrFS
		stc					; and exit with error
		jmp	@@Exit

@@KnownFS:	call	INIT_GetFSdrvIDfromCode		; Get FS driver ID in EDX
		jc	@@Exit

		mov	al,SCFG_PrimFS_LP		; Get config item
		call	INIT_GetStCfgItem		; (primary FSLP string)
		jc	@@Exit
		mov	[@@fslpstr],ebx			; Keep it

		mov	eax,edx				; Keep FS driver ID
		call	DRV_GetName			; Get name of FS driver
		mov	[@@fsdrvstr],esi
		mov	esi,ebx				; ESI=pointer to LP string
		call	CFS_GetLPfromName		; Get FSLP in DL
		jc	@@Exit
		mov	esi,eax				; ESI=FS driver ID

		mov	dh,0				; Linking mode
		call	CFS_LinkFS			; Do link
		jc	short @@Exit
		call	CFS_SetCurrentLP		; Set current FSLP

		mov	esi,[@@devicestr]		; Print linking status
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrString Msg_Arrow
		mov	esi,[@@fsdrvstr]
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrString Msg_At
		mov	esi,[@@fslpstr]
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL
		clc

@@Exit:		leave
		ret
endp		;---------------------------------------------------------------


		; INIT_PrepEDRVcodeSeg - prepare to use external drivers
		;			 code segment.
proc INIT_PrepEDRVcodeSeg near
		xor	al,al
		call	EDRV_FixDrvSegLimit		; Fix limit of data seg.
		mov	dx,EDRVDATA
		call	K_DescriptorAddress
		call	K_GetDescriptorBase		; Get its base
		call	K_GetDescriptorLimit		; and limit
		add	edi,eax				; Count base for
		inc	edi				; code segment
		test	edi,0Fh				; Alignment required?
		jz	short @@NoAlign
		shr	edi,4				; Align by paragraph
		inc	edi
		shl	edi,4
@@NoAlign:	mov	dx,EDRVCODE
		call	K_DescriptorAddress
		call	K_SetDescriptorBase		; Set base of code seg.
		call	EDRV_InitCodeAlloc		; Reinit code alloc vars
		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_PrepUserSeg - prepare to use user segment.
proc INIT_PrepUserSeg near
		mov	al,1
		call	EDRV_FixDrvSegLimit		; Fix limit of
		mov	dx,EDRVCODE			; drivers code segment
		call	K_DescriptorAddress
		call	K_GetDescriptorBase		; Get its base
		call	K_GetDescriptorAR		; and ARs
		or	ax,ax				; Allocated?
		jz	short @@SegSetup		; No, begin setup
		call	K_GetDescriptorLimit		; Else get its limit
		add	edi,eax				; Count base for
		inc	edi				; user segment

@@SegSetup:	test	edi,0FFFh			; Alignment required?
		jz	short @@NoAlign
		shr	edi,12				; Align by page
		inc	edi
		shl	edi,12

@@NoAlign:	mov	[HeapBegin],edi
		mov	eax,[TotalMemPages]		; Count heap size
		shl	eax,PAGESHIFT
		add	eax,StartOfExtMem
		mov	[HeapEnd],eax
		sub	eax,edi				; Count limit
		dec	eax				; of user segment

		mov	dx,USERCODE
		call	K_DescriptorAddress		; Set base and limit of
		call	K_SetDescriptorBase		; user code segment
		call	K_SetDescriptorLimit
		mov	dx,USERDATA
		call	K_DescriptorAddress		; Set base and limit of
		call	K_SetDescriptorBase		; user data segment
		call	K_SetDescriptorLimit

		; Print memory information
		mWrString Msg_TotMem
		mov	eax,[TotalMemPages]
		shl	eax,2
		add	eax,[BaseMemSz]
		call	PrintDwordDec
		mWrString Msg_KB
		mWrString Msg_MemKrnl
		mov	eax,[BaseMemSz]
		call	PrintDwordDec
		mWrString Msg_KB
		mWrString Msg_MemDrv
		mov	eax,[HeapBegin]
		sub	eax,StartOfExtMem
		shr	eax,10
		call	PrintDwordDec
		mWrString Msg_KB
		mWrString Msg_MemFree
		mov	eax,[ExtMemSz]
		mov	ebx,[HeapBegin]
		sub	ebx,StartOfExtMem
		shr	ebx,10
		sub	eax,ebx
		call	PrintDwordDec
		mWrString Msg_KB
		mov	eax,[VirtMemPages]
		shl	eax,2
		or	eax,eax
		jz	short @@OK
		push	eax
		mWrString Msg_MemVirt
		pop	eax
		call	PrintDwordDec
		mWrString Msg_KB

@@OK:		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_InstallBinFmtDrvs - install and initialize binary
		;			   format drivers.
proc INIT_InstallBinFmtDrvs near
		xor	ecx,ecx
@@Loop:		cmp	cl,Init_BinFormats
		je	short @@Done
		mov	ebx,[BinFmtDrivers+ecx*4]
		xor	edx,edx
		call	DRV_InstallNew
		jc	short @@Exit
		call	MOD_Register
		jc	short @@Exit
		inc	cl
		jmp	@@Loop

@@Done:		or	cl,cl
		jnz	short @@Exit
		mov	ax,ERR_INIT_NoBinFmtDrivers
		stc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; Driver initialization error: print driver name,
		; error message, error number, beep and return.
		; Input: EBX=driver ID,
		;	 AX=error number.
proc DrvInitErr near
		xchg	eax,ebx
		call	DRV_GetName
		jc	short @@Exit
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar ASC_BEL
		mWrString Msg_InitErr
		xchg	eax,ebx
		call	PrintWordHex
		mWrChar NL
@@Exit:		ret
endp		;---------------------------------------------------------------


; --- Inititialization entry point ---

proc PMinit far
		; Disable interrupts
		cli

		; Set segment registers
		mov	ax,KERNELDATA
		mov	ds,ax
		mov	es,ax
		mov	gs,ax
		mov	fs,ax
		mov	ss,ax
		mov	esp,InitESP

		; Initialize kernel heap
		shl	ebx,4				; EBX=kernel heap bottom
		shl	edx,4				; EDX=top
		sub	edx,BaseMemReservedSz
		call	KH_Init

		; Install internal device drivers
		mov	eax,Init_MaxNumDrivers
		call	DRV_InitTable
		mov	esi,offset InternalDriversTable
@@DrvInstLoop:	mov	ebx,[esi]
		xor	edx,edx
		call	DRV_InstallNew
		add	esi,4
		cmp	eax,DRVID_HDIDE
		jne	@@DrvInstLoop

		; Initialize interrupt controllers
		xor	ah,ah
		mov	al,IRQ0int
		call	PIC_Init
		inc	ah
		mov	al,IRQ8int
		call	PIC_Init
		xor	eax,eax
		call	PIC_SetIRQmask
		inc	ah
		call	PIC_SetIRQmask
		call	CMOS_EnableInt

		; Initialize timer (counter 0)
		mov	al,36h				; Counter 0, mode 3
		mov	cx,TIMER_InpFreq/TIMER_OutFreq	; Set divisor
		call	TMR_InitCounter
		sti

		; Initialize CPU and FPU drivers.
		mCallDriver DRVID_CPU,DRVF_Init
		mov	al,1				; Use math emulation
		mCallDriver DRVID_FPU,DRVF_Init		; if 387 not present

		; Install and initialize console driver
		mov	ebx,offset DrvConsole
		xor	edx,edx
		call	DRV_InstallNew
		mov	[DrvId_Con],eax
		mov	esi,offset InitStringBuf
		mCallDriver eax,DRVF_Init
		jc	short @@InitMon
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString
		mWrChar NL
		mWrChar NL

		; Initialize monitor
@@InitMon:	call	MonitorInit

		; Show CPU & FPU type
		call	INIT_ShowCPUFPU

		; Enable A20
		mov	al,1
		call	KBC_A20Control
		jnc	short @@InitMem
		mWrString Msg_A20Fail

		; Initialize memory driver
@@InitMem:	mov	esi,offset InitStringBuf
		mCallDriver DRVID_Memory,DRVF_Init
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

		; Install and initialize BIOS32 driver
		mov	ebx,offset DrvBIOS32
		xor	edx,edx
		call	DRV_InstallNew
		mov	[DrvId_BIOS32],eax
		mov	ebx,eax
		mCallDriver eax,DRVF_Init
		jnc	short @@BIOSinitOK
		call	DrvInitErr
		jmp	short @@InitMT

@@BIOSinitOK:	mWrChar NL
		mWrChar ' '
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

		; Initialize multitasking memory structures
@@InitMT:	mov	eax,Init_MaxNumOfProcesses
		call	MT_Init
		jc	@@Monitor

		; Create kernel process
		call	INIT_CreateKernelProcess
		jc	@@Monitor

		; Initialize disk drivers
		call	INIT_InitDiskDrvs

		; Initialize common file system structures
		mov	al,Init_NumFSlinkPoints
		mov	ecx,Init_NumIndexes
		call	CFS_Init

		; Check startup configuration table signature
		mov	ebx,StartCfgTblAddr
		cmp	[ebx+tStartConfig.Signature],SCFG_Signature
		mov	ax,ERR_INIT_BadSCT
		jne	FatalError

		; Initialize RAM-disk
		call	INIT_InitRAMdisk
		jc	@@Monitor

		; Initialize disk buffers
		call	INIT_InitDiskBuffers
		jc	@@Monitor

		; Install and initialize file system drivers
		mWrString Msg_InitFSDRV
		call	INIT_InitFileSystems
		jc	@@Monitor

		; Print partition table on boot device
		call	INIT_PrintPartTbl
		jc	@@Monitor

		; Check swap device and initialize paging
		call	INIT_ChkSwapDev
		jc	@@Monitor
		call	PG_Init
		jc	@@Monitor

		; Initialize character device drivers
		call	INIT_InitChDrv

		; Show kernel version message
		mWrString Msg_RadiOS

; Load RAM-disk image
extrn TEST_CreateRDimage:near
call TEST_CreateRDimage

		; Link primary file system
		call	INIT_LinkPrimFS
		jc	@@Monitor

		; Prepare to use external drivers code segment
		call	INIT_PrepEDRVcodeSeg
		jc	@@Monitor

		; Read and parse system configuration file
		call	INIT_ReadCfgFile
		jc	@@Monitor

		; Prepare user segment and print memory info
		call	INIT_PrepUserSeg
		jc	@@Monitor

		; Initialize module table
		mov	eax,Init_MaxNumLoadedMods
		call	MOD_InitMem
		jc	@@Monitor

		; Install and initialize binary format drivers
		call	INIT_InstallBinFmtDrvs
		jc	FatalError

		; Initialize memory management
		call	MM_Init
		jc	FatalError

extrn TEST_ExamineFS:near
call TEST_ExamineFS

		; Start shell
		;mWaitKey		

		; Call monitor
@@Monitor:	xor	eax,eax				; Exit code=0
		int	3

		; Reset system
SysReset:	mWrString Msg_SysReset1
		call	PrintByteDec
		mWrString Msg_SysReset2
		mCallDriver [DrvId_Con],DRVF_Read

		call	CFS_Done			; Release kernel
		call	DRV_ReleaseTable		; memory blocks

		call	KBC_HardReset

		; Fatal error: print error message, error number
		; and halt the system
FatalError:	push	eax
		mWrString Msg_Fatal
		pop	eax
		call	PrintWordHex
		mWrString Msg_SysHlt

@@Halt:		jmp	@@Halt

endp		;---------------------------------------------------------------

ends


; --- Real mode part (startup) ---

segment	RMSTARTUPCODE para 'CODE16' use16
assume CS:RMSTARTUPCODE, DS:RMSTARTUPCODE, ES:ABSOLUTE
org 0

RMstart:	cli
		mov	ebx,ss				; EBX=k_heap begin seg.

		IFDEF DEBUGUNDERDOS
		INCLUDE "..\ETC\DOSMOVER\dosmover.asm"
		ENDIF

		xor	ax,ax
		mov	es,ax
		mov	dx,[es:BIOSData.BaseMemSize]	; DX=segment address
		shl	dx,6				; of base memory top

		mov	ax,cs
		mov	ds,ax
		mov	eax,offset GDT			; Prepare for LGDT
		mov	[dword GDTptr+2],eax
    		mov	eax,offset IDT			; Prepare for LIDT
    		mov	[dword IDTptr+2],eax
		lgdt	[GDTptr]
		lidt	[IDTptr]
		mov	eax,cr0
		or	al,CR0_PE
		mov	cr0,eax				; Enter PM
		PMJF16	KernelCode,PMinit		; Far jump to PM kernel

GDTptr		DF	(size GDT)-1
IDTptr		DF	(size tDescriptor)*256-1

ends

segment RMSTACK para stack 'STACK16'
		DW	32 dup (?)
ends

end	RMstart
