;*******************************************************************************
;  init.as - RadiOS initializer.
;  Copyright (c) 1998,99 RET & COM research.
;*******************************************************************************

module init

%include "sys.ah"
%include "errors.ah"
%include "initdefs.ah"
%include "biosdata.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "i386/descript.ah"
%include "process.ah"
%include "commonfs.ah"
%include "kconio.ah"
%include "asciictl.ah"
%include "hw/partids.ah"

%define	DEBUG
%define LOADRDIMAGE


; --- Exports ---

global Start, SysReset


; --- Imports ---

; Built-in drivers
extern DrvBIOS32:near, DrvKeyboard:near,
extern DrvVTX:near, DrvVGAGR:near
extern DrvAudio:near
;extern DrvNetwork:near
extern DrvSerial:near, DrvParport:near
extern DrvFDD:near, DrvIDE:near
extern DrvRD:near, DrvRFS:near
extern DrvRDM:near, DrvCOFF:near
extern DrvConsole:near

; Kernel variables and data
library kernel
extern GDTaddrLim, IDTaddr, IntHandlersArr
extern DrvId_Con, DrvId_RD, DrvId_RFS, DrvId_BIOS32
extern HeapBegin, HeapEnd
extern BaseMemSz, ExtMemSz
extern TotalMemPages, VirtMemPages

; Kernel procedures
extern K_CheckCPU:near, K_InitFPU:near, K_InitMem:near
extern K_GetCPUtypeStr:near, K_GetFPUtypeStr:near
extern KernelEventHandler:near
extern K_DescriptorAddress:near
extern K_GetDescriptorBase:near, K_GetDescriptorLimit:near
extern K_GetDescriptorAR:near
extern K_SetDescriptorBase:near, K_SetDescriptorLimit:near

library kernel.kheap
extern KH_Init:near, KH_Alloc:near

library kernel.driver
extern DRV_InitTable:near, DRV_InstallNew:near
extern DRV_CallDriver:near, DRV_GetName:near, DRV_FindName:near
extern EDRV_FixDrvSegLimit:near, EDRV_InitCodeAlloc:near

library kernel.mm
extern MM_Init:near, PG_Init:near

library kernel.mt
extern MT_Init:near, MT_InitProc:near, MT_InitKernelProc:near
extern MT_CreateThread:near, MT_ThreadExec:near

library kernel.module
extern MOD_InitMem:near, MOD_InitKernelMod:near
extern MOD_Register:near

library kernel.fs
extern BUF_InitMem:near, CFS_Init:near
extern CFS_LinkFS:near
extern CFS_GetLPbyName:near, CFS_SetCurrentLP:near

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

library hardware.genhd
extern HD_Init:near

library monitor
extern MonitorInit:near

library rkdt
extern RKDT_Main:near

; --- Data ---

section .data

Msg_A20Fail	DB "A20 line opening failure.",0
Msg_Bytes	DB " bytes.",NL,0
Msg_RadiOS	DB NL
		DB "ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออป",NL
		DB "บ Radiant Operating System (RadiOS), kernel version d0.01 บ",NL
		DB "บ This is a first GPLed release by Yuri Zaporogets.       บ",NL
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
Msg_TryCrFS	DB NL,"Try to create file system manually :)",NL,0
Msg_TotMem	DB NL,"Total memory size: ",0
Msg_KB		DB " KB",NL,0
Msg_MemKrnl	DB " Kernel:  ",0
Msg_MemDrv	DB " Drivers: ",0
Msg_MemFree	DB " Free:    ",0
Msg_MemVirt	DB " Virtual: ",0
Msg_InitChDr	DB NL,"Initializing character device drivers...",NL,0
Msg_InitAudio	DB NL,"Initializing audio device driver...",NL,0
Msg_InitErr	DB ": init error ",0

Msg_SysReset1	DB ASC_BEL,NL,NL,"Main process completed (exit code=",0
Msg_SysReset2	DB "). Press any key to reset...",0

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
			DD	DrvAudio
			DD	0
			DD	DrvSerial
			DD	DrvParport
			DD	DrvFDD
			DD	DrvIDE

BinFmtDrivers		DD	DrvRDM
			DD	DrvCOFF


; --- Variables ---

section .bss

IDTaddrLim	RESB	6
InitStringBuf	RESB	256


; --- Code ---

section .text

%include "buildxdt.as"
%include "parsecfg.as"
%include "launcher.as"


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
		mov	al,16				; 16 hard disks
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
.InitIDE:	mov	dl,1
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
		mov	ebx,DRVID_HDIDE				; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

.Loop1:		push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		mPrintChar NL
		mPrintChar ' '
		mPrintString
		inc	cl
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
		mov	cx,Init_SerOutBufSize
		shl	ecx,16
		mov	cx,Init_SerInpBufSize
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


		; INIT_CreateKernelProcess - initialize kernel process.
proc INIT_CreateKernelProcess
%define	.procinfo	ebp-tProcInit_size
		prologue tProcInit_size
		lea	ebx,[.procinfo]
		mov	byte [ebx+tProcInit.MaxFHandles],Init_NumKernFHandles
		mov	word [ebx+tProcInit.EnvSize],Init_KernEnvSize
		mov	dword [ebx+tProcInit.EventHandler],KernelEventHandler
		call	MT_InitKernelProc
		epilogue
		ret
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

		mov	esi,offset InitStringBuf
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
%ifdef DEBUG
extern RKDT_CreateRDimage
	call	RKDT_CreateRDimage
%endif
		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskBuffers - initialize disk buffers
proc INIT_InitDiskBuffers
		mov	al,SCFG_BuffersMem		; Read config item
		call	INIT_GetStCfgItem		; (buffers memory in KB)
		xor	ecx,ecx
		mov	cx,[ebx]			; ECX=buffers memory
		cmp	cx,8192
		cmc
		jb	short .Exit
		call	BUF_InitMem
		jc	short .Exit
		mPrintChar NL
		mov	eax,ecx				; Print message
		call	PrintDwordDec
		mPrintString Msg_DiskBuf
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitFileSystems - install and initialize all
		;			 file system drivers.
proc INIT_InitFileSystems

		; RFS driver
		mov	ebx,offset DrvRFS
		xor	edx,edx
		call	DRV_InstallNew
		jc	short .Exit
		mov	[DrvId_RFS],eax

		mov	al,26				; Max. number of LPs
		mov	cl,48				; Max. number of FCBs
		mov	esi,InitStringBuf		; Buffer for status string
		mCallDriver dword [DrvId_RFS], byte DRVF_Init
		jc	short .Exit
		mPrintChar ' '
		mPrintString

		; MDOSFS driver

		clc
.Exit:		ret
endp		;---------------------------------------------------------------



		; INIT_PrintPartTbl - open boot disk device and print its
		;		      partition table.
proc INIT_PrintPartTbl
		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	near .Exit

		mov	esi,ebx				; Check for %hd or %sd
		mov	edi,offset BootDev_HD
		xor	ecx,ecx
		mov	cl,3
		call	StrLComp			; "%hd"?
		or	al,al
		jz	short .Do
		mov	edi,offset BootDev_SD
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
		mov	esi,offset InitStringBuf
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


		; INIT_GetFSdrvIDfromCode - get file system driver ID from
		;			    partition system code.
		; Input: AL=partition system code.
		; Output: CF=0 - OK, EDX=driver ID;
		;	  CF=1 - error (unknown code).
proc INIT_GetFSdrvIDfromCode
		mov	edx,[DrvId_RFS]
		cmp	al,FS_ID_RFSNATIVE
		je	short .OK
;		mov	edx,[DrvId_MDOSFS]
;		cmp	al,CFS_ID_DOSFAT16SMALL
;		je	short .OK
;		cmp	al,CFS_ID_DOSFAT16LARGE
;		je	short .OK
;		mov	edx,[DrvId_HPFS]
;		cmp	al,CFS_ID_OS2HPFS
;		je	short .OK

		stc
		ret

.OK:		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_LinkPrimFS - link primary file system.
proc INIT_LinkPrimFS
%define	.devicestr	ebp-4
%define	.fsdrvstr	ebp-8
%define	.fslpstr	ebp-12

		prologue 12				; Save space
		mPrintString Msg_LinkPrimFS

		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	near .Exit
		mov	[.devicestr],ebx		; Keep it

		mov	esi,ebx
		call	DRV_FindName			; Get boot device ID
		jc	near .Exit
		mov	edi,eax				; Keep it in EDI
		mCallDriverCtrl edi,DRVCTL_GetParams	; Get partition type
		or	al,al				; Known file system?
		jnz	short .KnownFS			; Yes, continue
		mPrintString Msg_UnknFS			; Else print error msg
		mov	esi,ebx
		mPrintString
		mPrintString Msg_TryCrFS
		stc					; and exit with error
		jmp	.Exit

.KnownFS:	call	INIT_GetFSdrvIDfromCode		; Get FS driver ID in EDX
		jc	near .Exit

		mov	al,SCFG_PrimFS_LP		; Get config item
		call	INIT_GetStCfgItem		; (primary FSLP string)
		jc	near .Exit
		mov	[.fslpstr],ebx			; Keep it

		mov	eax,edx				; Keep FS driver ID
		call	DRV_GetName			; Get name of FS driver
		mov	[.fsdrvstr],esi
		mov	esi,ebx				; ESI=pointer to LP string
		call	CFS_GetLPbyName			; Get FSLP in DL
		jc	near .Exit
		mov	esi,eax				; ESI=FS driver ID

		mov	dh,0				; Linking mode
		call	CFS_LinkFS			; Do link
		jc	near .Exit
		call	CFS_SetCurrentLP		; Set current FSLP

		mov	esi,[.devicestr]		; Print linking status
		mPrintString
		mPrintString Msg_Arrow
		mov	esi,[.fsdrvstr]
		mPrintString
		mPrintString Msg_At
		mov	esi,[.fslpstr]
		mPrintString
		mPrintChar NL
		clc

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; INIT_PrepEDRVcodeSeg - prepare to use external drivers
		;			 code segment.
proc INIT_PrepEDRVcodeSeg
		xor	al,al
		call	EDRV_FixDrvSegLimit		; Fix limit of data seg.
		mov	dx,DRVDATA
		call	K_DescriptorAddress
		call	K_GetDescriptorBase		; Get its base
		call	K_GetDescriptorLimit		; and limit
		add	edi,eax				; Count base for
		inc	edi				; code segment
		test	edi,0Fh				; Alignment required?
		jz	short .NoAlign
		shr	edi,4				; Align by paragraph
		inc	edi
		shl	edi,4
.NoAlign:	mov	dx,DRVCODE
		call	K_DescriptorAddress
		call	K_SetDescriptorBase		; Set base of code seg.
		call	EDRV_InitCodeAlloc		; Reinit code alloc vars
		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_PrepUserSeg - prepare to use user segment.
proc INIT_PrepUserSeg
		mov	al,1
		call	EDRV_FixDrvSegLimit		; Fix limit of
		mov	dx,DRVCODE			; drivers code segment
		call	K_DescriptorAddress
		call	K_GetDescriptorBase		; Get its base
		call	K_GetDescriptorAR		; and ARs
		or	ax,ax				; Allocated?
		jz	short .SegSetup		; No, begin setup
		call	K_GetDescriptorLimit		; Else get its limit
		add	edi,eax				; Count base for
		inc	edi				; user segment

.SegSetup:	test	edi,0FFFh			; Alignment required?
		jz	short .NoAlign
		shr	edi,12				; Align by page
		inc	edi
		shl	edi,12

.NoAlign:	mov	[HeapBegin],edi
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
		mPrintString Msg_TotMem
		mov	eax,[TotalMemPages]
		shl	eax,2
		add	eax,[BaseMemSz]
		call	PrintDwordDec
		mPrintString Msg_KB
		mPrintString Msg_MemKrnl
		mov	eax,[BaseMemSz]
		call	PrintDwordDec
		mPrintString Msg_KB
		mPrintString Msg_MemDrv
		mov	eax,[HeapBegin]
		sub	eax,StartOfExtMem
		shr	eax,10
		call	PrintDwordDec
		mPrintString Msg_KB
		mPrintString Msg_MemFree
		mov	eax,[ExtMemSz]
		mov	ebx,[HeapBegin]
		sub	ebx,StartOfExtMem
		shr	ebx,10
		sub	eax,ebx
		call	PrintDwordDec
		mPrintString Msg_KB
		mov	eax,[VirtMemPages]
		shl	eax,2
		or	eax,eax
		jz	short .OK
		push	eax
		mPrintString Msg_MemVirt
		pop	eax
		call	PrintDwordDec
		mPrintString Msg_KB

.OK:		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_InstallBinFmtDrvs - install and initialize binary
		;			   format drivers.
proc INIT_InstallBinFmtDrvs
		xor	ecx,ecx
.Loop:		cmp	cl,Init_BinFormats
		je	short .Done
		mov	ebx,[BinFmtDrivers+ecx*4]
		xor	edx,edx
		call	DRV_InstallNew
		jc	short .Exit
		call	MOD_Register
		jc	short .Exit
		inc	cl
		jmp	.Loop

.Done:		or	cl,cl
		jnz	short .Exit
		mov	ax,ERR_INIT_NoBinFmtDrivers
		stc
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


; --- Inititialization entry point ---

proc Start
		; Disable interrupts
		cli
		
		; Initialize GDTR
		lgdt	[GDTaddrLim]
		jmp	KERNELCODE:.InitSegs

		; Set segment registers
.InitSegs:	mov	ax,KERNELDATA
		mov	ds,ax
		mov	es,ax
		mov	gs,ax
		mov	fs,ax
		mov	ss,ax
		mov	esp,InitESP

		; Initialize kernel heap
		mov	ebx,[KHeapBeginAddr]		; EBX=kernel heap bottom
		add	ebx,byte 16			; Align by paragraph
		and	bl,0F0h
		mov	edx,[KHeapTopAddr]		; EDX=top
		sub	edx,BaseMemReservedSz
		call	KH_Init

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
		add	esi,4
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
call ReadChar
		; Enable A20
		mov	al,1
		call	KBC_A20Control
		jnc	short .InitMem
		mPrintString Msg_A20Fail

		; Initialize memory
.InitMem:	mov	esi,InitStringBuf
		call	K_InitMem
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
		jnc	short .BIOSinitOK
		call	DrvInitErr
		jmp	short .InitProc

.BIOSinitOK:	mPrintChar ' '
		mPrintString

		; Initialize process management
.InitProc:	mov	eax,Init_MaxNumOfProcesses
		call	MT_InitProc
		jc	near .Monitor

		; Initialize paging
.InitPaging:	mov	al,SCFG_SwapSize
		call	INIT_GetStCfgItem
		mov	ecx,[ebx]
		call	PG_Init
		jc	near .Monitor

		; Initialize multitasking memory structures
.InitMT:	mov	ecx,Init_MaxNumOfThreads
		call	MT_Init
		jc	near .Monitor

		; Create kernel process
		call	INIT_CreateKernelProcess
		jc	near .Monitor

		; Initialize disk drivers
		call	INIT_InitDiskDrvs

		; Initialize common file system structures
		mov	al,Init_NumFSlinkPoints
		mov	ecx,Init_NumIndexes
		call	CFS_Init

		; Check startup configuration table signature
		mov	ebx,StartCfgTblAddr
		cmp	dword [ebx+tStartConfig.Signature],SCFG_Signature
		mov	ax,ERR_INIT_BadSCT
		jne	near FatalError

		; Initialize RAM-disk
		call	INIT_InitRAMdisk
		jc	near .Monitor

		; Initialize disk buffers
		call	INIT_InitDiskBuffers
		jc	near .Monitor

		; Install and initialize file system drivers
;		mPrintString Msg_InitFSDRV
;		call	INIT_InitFileSystems
;		jc	near .Monitor

		; Print partition table on boot device
		call	INIT_PrintPartTbl
		jc	near .Monitor

		; Check and initialize swap device
		call	INIT_ChkSwapDev
		jc	near .Monitor

		; Initialize character device drivers
		call	INIT_InitChDrv

		; Initialize audio device
		mPrintString Msg_InitAudio
		mov	esi,offset InitStringBuf
		mCallDriver byte DRVID_Audio, byte DRVF_Init
		jc	short .ShowVer
		mPrintString

		; Show kernel version message
.ShowVer:	mPrintString Msg_RadiOS


		; Load RAM-disk image
%ifdef LOADRDIMAGE 
;		call INIT_LoadRDimage
%endif

		; Link primary file system
;		call	INIT_LinkPrimFS
;		jc	near .Monitor

		; Prepare to use external drivers code segment
		call	INIT_PrepEDRVcodeSeg
		jc	near .Monitor

		; Read and parse system configuration file
		call	INIT_ReadCfgFile
		jc	near .Monitor

		; Prepare user segment and print memory info
		call	INIT_PrepUserSeg
		jc	near .Monitor

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

		; Create two initial kernel threads
		; (launcher and RKDT).
		mov	ebx,INIT_Launcher
		xor	ecx,ecx
		xor	esi,esi
		call	MT_CreateThread
		jc	.Monitor
		mov	edi,ebx				; Save launcher TCB

		mov	ebx,RKDT_Main
		mov	ecx,16384			; 16KB stack
		call	MT_CreateThread
		jc	.Monitor

		; Enable timer interrupts and roll the dice! ;)
		xor	al,al
		call	PIC_EnbIRQ
		mov	ebx,edi
		call	MT_ThreadExec

		; This point must never be reached!
.Monitor:	int3

		; Reset system
		mPrintString Msg_SysReset1
		call	PrintByteDec
		mPrintString Msg_SysReset2
		call	ReadChar

SysReset:	call	KBC_HardReset

		; Fatal error: print error message, error number
		; and halt the system
FatalError:	push	eax
		mPrintString Msg_Fatal
		pop	eax
		call	PrintWordHex
		mPrintString Msg_SysHlt

.Halt:		jmp	.Halt
endp		;---------------------------------------------------------------

