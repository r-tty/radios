;*******************************************************************************
; startup.nasm - startup code.
; Copyright (c) 2002 RET & COM research.
;*******************************************************************************

module $rmk

%include "sys.ah"
%include "errors.ah"
%include "parameters.ah"
%include "asciictl.ah"
%include "bootdefs.ah"
%include "serventry.ah"
%include "module.ah"
%include "hw/ports.ah"
%include "hw/pit.ah"
%include "hw/kbc.ah"


; --- Exports ---

exportproc Start, SysReboot
exportdata ModuleInfo


; --- Imports ---

; Kernel variables and data
library kernel
extern RadiOS_Version, TxtRVersion, TxtRCopyright
extern GDTaddrLim

; Kernel procedures
extern K_InitIDT, CPU_Init, FPU_Init, K_InitMem
extern K_DescriptorAddress
extern K_GetDescriptorBase, K_GetDescriptorLimit
extern K_GetDescriptorAR
extern K_SetDescriptorBase, K_SetDescriptorLimit

library kernel.initmem
extern ?LowerMemSize, ?UpperMemSize

library kernel.paging
extern PG_Init, PG_StartPaging
extern PG_AllocContBlock

library kernel.mt
extern MT_Init, MT_GetNumThreads
extern MT_CreateThread, MT_ThreadExec

library kernel.x86.basedev
extern PIC_Init, PIC_SetIRQmask, PIC_EnbIRQ
extern TMR_InitCounter, TMR_CountCPUspeed
extern CMOS_EnableInt
extern ?CPUinfo, ?CPUspeed

library kernel.strutil
extern StrComp

library kernel.ipc
extern IPC_Init

%ifdef LINKMONITOR
library monitor
extern MonitorInit
%endif


; --- Data ---

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

TxtFatalErr	DB	NL,"Fatal error - system is halted.", 0
TxtKernDone	DB	NL,"There is no work left for the kernel - bye.",0
TxtDetected	DB	"Detected ", 0
TxtKBRAM	DB	" KB RAM", NL, 0
TxtX86family	DB	"86 family CPU, speed index=", 0
TxtInitKExtMods	DB	"Initializing kernel extension modules...", NL, 0


; --- Variables ---

section .bss

IdleTCB		RESD	1				; Idle thread TCB


; --- Code ---

section .text

		; Start - kernel initialization entry point.
		; Input: none.
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
		mov	edx,[BOOTPARM(MemLower)]	; EDX=base memory top
		shl	edx,10
		lea	esp,[edx-4]
		sub	edx,8000h			; Kernel stack size	

		; Initialize global page pool
		mov	eax,[BOOTPARM(BMDkernel)]
		mov	ebx,[eax+tModule.CodeStart]
		add	ebx,[eax+tModule.Size]
		mov	ecx,[BOOTPARM(MemUpper)]	; Upper memory size
		call	PG_Init

		; Build IDT and initialize IDTR
		call	K_InitIDT

		; Initialize interrupt controllers
		xor	ah,ah
		mov	al,IRQVECTOR(0)
		call	PIC_Init
		inc	ah
		mov	al,IRQVECTOR(8)
		call	PIC_Init
		xor	eax,eax
		mov	al,1				; IRQ0 disabled
		call	PIC_SetIRQmask
		dec	al
		inc	ah
		call	PIC_SetIRQmask
		call	CMOS_EnableInt

		; Initialize the PIT (counters 0 and 2)
		mov	al,PITCW_Mode3+PITCW_LH+PITCW_CT0
		mov	cx,PIT_INPCLK/HZ
		call	TMR_InitCounter
		mov	al,PITCW_Mode3+PITCW_LH+PITCW_CT2
		mov	cx,PIT_SPEAKERFREQ
		call	TMR_InitCounter

		; Finally, enable interrupts
		sti
		
%ifdef LINKMONITOR
		; Initialize monitor
		xor	ebx,ebx
		call	MonitorInit
%endif
		; Show version information
		mServPrintStr TxtRVersion
		mServPrintStr RadiOS_Version
		mServPrintStr TxtRCopyright

		; Initialize CPU and FPU
		call	CPU_Init
		call	FPU_Init
		call	TMR_CountCPUspeed
		
		; Print basic CPU information
		mServPrintStr TxtDetected
		movzx	eax,byte [?CPUinfo+tCPUinfo.Family]
		mServPrintDec
		mServPrintStr TxtX86family
		mServPrintDec [?CPUspeed]
		mServPrintChar NL

		; Initialize memory
		call	K_InitMem
		
		; Print how much memory we have
		mServPrintStr TxtDetected
		mServPrintDec [?LowerMemSize]
		mServPrintChar '+'
		mServPrintDec [?UpperMemSize]
		mServPrintStr TxtKBRAM

		; Initialize IPC structures
		call	IPC_Init
		jc	near .Monitor

		; Initialize multitasking memory structures
		mov	eax,MAXNUMTHREADS
		call	MT_Init
		jc	near .Monitor

		; Enable paging
		call	PG_StartPaging
		jc	near .Monitor

		; Create idle thread
		mov	ebx,IdleThread
		xor	ecx,ecx
		xor	esi,esi
		call	MT_CreateThread
		jc	.Monitor
		mov	[IdleTCB],ebx
		
		; Initialize kernel extension modules
		call	InitKernExtModules

		; Check if some threads were created.
		; If not, we've done our job.
		call	MT_GetNumThreads
		cmp	ecx,1
		je	.Done

		; At last, enable timer interrupts and roll the dice.
		xor	al,al
		call	PIC_EnbIRQ
		mov	ebx,[IdleTCB]
		call	MT_ThreadExec

		; This point must never be reached!
.Monitor:	int3

.Done:		mServPrintStr TxtKernDone
		mServReadKey

		; When everything has crashed...
SysReboot:	cli
		mov	al,KBC_P4W_HardReset
		out	PORT_KBC_4,al
Halt:		hlt
		jmp	Halt
FatalError:	mServPrintStr TxtFatalErr
		jmp	Halt
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
		mServPrintStr TxtInitKExtMods
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
