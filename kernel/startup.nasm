;*******************************************************************************
; startup.nasm - startup code.
; Copyright (c) 2002 RET & COM research.
;*******************************************************************************

module $rmk

%include "sys.ah"
%include "errors.ah"
%include "parameters.ah"
%include "bootdefs.ah"
%include "module.ah"
%include "asciictl.ah"
%include "kcons.ah"
%include "hw/ports.ah"
%include "hw/pit.ah"
%include "hw/kbc.ah"


exportproc Start, ExitKernel
exportdata ModuleInfo


externproc K_BuildGDT, K_InitInterrupts, CPU_Init, FPU_Init, K_InitMem
externproc PIC_Init, PIC_SetIRQmask, PIC_EnableIRQ
externproc TMR_InitCounter, TMR_CountCPUspeed
externproc PG_Init, PG_StartPaging
externproc MT_Init, MT_GetNumThreads, MT_CreateThread
externproc MT_ThrEnqueue, MT_ThreadExec
externproc K_InitTime, K_InitHashPool, K_SyncInit
externproc IPC_ChanInit, IPC_ConnInit, IPC_PulseInit
externdata GDTlimAddr
externdata ?CPUinfo, ?CPUspeed
externdata ?LowerMemSize, ?UpperMemSize

externproc StrComp
externproc PrintChar, PrintString, PrintDwordDec, ReadChar

%ifdef LINKMONITOR
externproc MonitorInit
%endif


section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_KERNEL)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	4000h)
    field(Entry,	DD	Start)
iend

TxtRVersion	DB	10,"RadiOS ", 0E6h, "kernel, version ",0
TxtSysVersion	DB	RADIOS_VERSION,0
TxtRCopyright	DB	" (c) 2003 RET & COM Research.",10,10,0

TxtKernDone	DB	NL,"There is no work left for the kernel - bye.",0
TxtRAM		DB	"RAM: ", 0
TxtKB		DB	" KB", NL, 0
TxtCPU		DB	"CPU: ",0
TxtFamily	DB	"family ",0
TxtSpeedIndex	DB	", speed index=", 0
TxtInitKExtMods	DB	"Initializing kernel extension modules...", NL, 0

%ifdef VERBOSE
TxtDumpHdr	DB	NL,"BIOS memory map dump:"
		DB	NL," Base address",ASC_HT,"Size (bytes)",ASC_HT
		DB	"Pages",NL,0
%endif


section .bss

?BTLstack	RESD	1
?IdleTCB	RESD	1


section .text

		; Start - kernel initialization entry point.
		; Input: none.
proc Start
		; Initialize GDTR
		cli
		call	K_BuildGDT
		lgdt	[GDTlimAddr]
		jmp	KERNELCODE:.InitSegs

		; Set segment registers and kernel LDTR
.InitSegs:	xor	eax,eax
		mov	al,KERNELDATA
		mov	ds,eax
		mov	es,eax
		mov	gs,eax
		mov	fs,eax
		mov	ss,eax
		mov	al,KLDT
		lldt	ax

		; Store the address of BTL stack
		mov	[?BTLstack],esp

		; Kernel stack occupies 64K at the top of lower memory
		mov	edx,[BOOTPARM(MemLower)]
		shl	edx,10
		lea	esp,[edx-4]
		sub	edx,8000h

		; Initialize global page pool
		mov	eax,[BOOTPARM(BMDkernel)]
		mov	ebx,[eax+tModule.CodeStart]
		add	ebx,[eax+tModule.Size]
		mov	ecx,[BOOTPARM(MemUpper)]	; Upper memory size
		call	PG_Init
		jc	near ExitKernel

		; Initialize interrupt tables and load IDTR
		call	K_InitInterrupts
		jc	near ExitKernel

		; Initialize interrupt controllers and block all interrupts
		xor	ah,ah
		mov	al,IRQVECTOR(0)
		call	PIC_Init
		inc	ah
		mov	al,IRQVECTOR(8)
		call	PIC_Init
		xor	eax,eax
		not	al
		call	PIC_SetIRQmask
		inc	ah
		call	PIC_SetIRQmask
		sti

		; Initialize the PIT (counters 0 and 2)
		mov	al,PITCW_Mode3+PITCW_LH+PITCW_CT0
		mov	cx,PIT_INPCLK/HZ
		call	TMR_InitCounter
		mov	al,PITCW_Mode3+PITCW_LH+PITCW_CT2
		mov	cx,PIT_SPEAKERFREQ
		call	TMR_InitCounter

%ifdef LINKMONITOR
		; Initialize monitor
		xor	ebx,ebx
		call	MonitorInit
		jc	near ExitKernel
%endif
		; Show version information
		kPrintStr TxtRVersion
		kPrintStr TxtSysVersion
		kPrintStr TxtRCopyright

		; Initialize CPU and FPU
		call	CPU_Init
		call	FPU_Init
		call	TMR_CountCPUspeed
		
		; Print basic CPU information
		kPrintStr TxtCPU
		mov	esi,?CPUinfo+tCPUinfo.ModelID
		cmp	byte [esi],0
		je	.NoModel
		kPrintStr
		jmp	.1
.NoModel:	kPrintStr TxtFamily
		movzx	eax,byte [?CPUinfo+tCPUinfo.Family]
		kPrintDec
		kPrintStr TxtSpeedIndex
		kPrintDec [?CPUspeed]
.1:		kPrintChar NL

		; Initialize memory
		call	K_InitMem
		
		; Print how much memory we have
		kPrintStr TxtRAM
		kPrintDec [?LowerMemSize]
		kPrintChar '+'
		kPrintDec [?UpperMemSize]
		kPrintStr TxtKB

		; Enable paging
		call	PG_StartPaging
		jc	near ExitKernel

		; Initialize hash elements pool
		mov	eax,MAXHASHELEMS
		call	K_InitHashPool
		jc	near ExitKernel

		; Initialize RTC
		call	K_InitTime

		; Initialize IPC structures
		call	IPC_ChanInit
		jc	near ExitKernel
		call	IPC_ConnInit
		jc	near ExitKernel
		mov	eax,MAXPULSES
		call	IPC_PulseInit
		jc	near ExitKernel

		; Initialize synchronization object pool
		call	K_SyncInit
		jc	near ExitKernel

		; Initialize multitasking memory structures
		mov	eax,MAXNUMTHREADS
		call	MT_Init
		jc	near ExitKernel

		; Create idle thread
		mov	ebx,IdleThread
		xor	esi,esi
		call	MT_CreateThread
		jc	ExitKernel
		mov	[?IdleTCB],ebx
		call	MT_ThrEnqueue
		
		; Initialize kernel extension modules
		call	InitKernExtModules

		; Check if some threads were created.
		; If not, we've done our job.
		call	MT_GetNumThreads
		cmp	ecx,1
		je	.Done

		; At last, enable timer interrupts and roll the dice.
		xor	al,al
		call	PIC_EnableIRQ
		mov	ebx,[?IdleTCB]
		call	MT_ThreadExec

.Done:		kPrintStr TxtKernDone
		kReadKey

		; In case when everything crashed..
SysReboot:	mov	al,KBC_P4W_HardReset
		out	PORT_KBC_4,al

		; Return to BTL, it will print some message.
ExitKernel:	mov	esp,[?BTLstack]
		ret
endp		;---------------------------------------------------------------


; --- Initialization procedures ---

		; Kernel idle thread.
		; Currently does nothing, only displays its activity.
		; Input: none.
		; Output: none.
proc IdleThread
		mov	eax,"\-/|"
.Infinite:	mov	[0xB8000+158],al
		ror	eax,8
		jmp	.Infinite
endp		;---------------------------------------------------------------


		; Initialize kernel extension modules.
		; Input: none.
		; Output: none.
		; Note: this routine simply calls "Start" procedure from
		;	each kernel extension module. Address of Boot Module
		;	Descriptor (BMD) is passed in EBX.
		;	If module wants to get CPU slices, it can create a
		;	kernel thread, as usual.
proc InitKernExtModules
		mov	ecx,[BOOTPARM(NumModules)]
		jecxz	.Exit
		kPrintStr TxtInitKExtMods
		mov	ebx,[BOOTPARM(BMDmodules)]
		mov	esi,ebx
.Loop:		cmp	byte [ebx+tModule.Type],MODTYPE_KERNEL
		jne	.Next
		mov	eax,[ebx+tModule.Entry]
		or	eax,eax
		jz	.Next
		mpush	ebx,ecx
		call	eax
		mpop	ecx,ebx
.Next:		add	ebx,byte tModule_size
		loop	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


%ifdef VERBOSE

		; K_DumpBMM - Dump BIOS memory map.
		; Input: none.
		; Output: none.
proc K_DumpBMM
		mpush	ebx,ecx,esi
		mov	ecx,[BOOTPARM(MemMapSize)]
		or	ecx,ecx
		jz	near .Exit
		mServPrintStr TxtDumpHdr
		mov	ebx,[BOOTPARM(MemMapAddr)]
.Loop:		mServPrintChar ' '
		mov	eax,[ebx+tAddrRangeDesc.BaseAddrLow]
		mServPrint32h
		mServPrintChar 9
		mov	eax,[ebx+tAddrRangeDesc.LengthLow]
		push	eax
		mServPrint32h
		mServPrintChar 9
		pop	eax
		shr	eax,PAGESHIFT
		mServPrintDec
		mServPrintChar 10
		mov	eax,[ebx+tAddrRangeDesc.Size]
		add	eax,byte 4
		sub	ecx,eax
		jz	.OK
		add	ebx,eax
		jmp	.Loop
.OK:		mServPrintChar 10
.Exit:		mpop	esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------

%endif
