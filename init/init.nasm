;*******************************************************************************
;  init.nasm - RadiOS initializer.
;  Copyright (c) 2002 RET & COM research.
;*******************************************************************************

module $rmk

%include "sys.ah"
%include "errors.ah"
%include "bootdefs.ah"
%include "asciictl.ah"
%include "biosdata.ah"
%include "cpu/paging.ah"
%include "cpu/descript.ah"
%include "hw/timer.ah"


; --- Exports ---

exportproc Start
exportdata ModuleInfo


; --- Public ---
publicproc SysReboot


; --- Imports ---

; Kernel variables and data
library kernel
extern RadiOS_Version, Msg_RVersion, Msg_RCopyright
extern GDTaddrLim

; Kernel procedures
extern K_InitIDT, CPU_Init, FPU_Init, K_InitMem
extern K_DescriptorAddress
extern K_GetDescriptorBase, K_GetDescriptorLimit
extern K_GetDescriptorAR
extern K_SetDescriptorBase, K_SetDescriptorLimit

library kernel.initmem
extern ?BaseMemSz, ?ExtMemSz

library kernel.paging
extern PG_Init, PG_StartPaging
extern PG_AllocContBlock

library kernel.mt
extern MT_Init
extern MT_CreateThread, MT_ThreadExec

library kernel.x86.basedev
extern PIC_Init, PIC_SetIRQmask, PIC_EnbIRQ
extern TMR_InitCounter, TMR_CountCPUspeed
extern KBC_A20Control, KBC_HardReset
extern CMOS_EnableInt
extern ?CPUinfo, ?CPUspeed

library monitor
extern MonitorInit


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
iend

MsgFatalErr	DB	NL,"Fatal error. System will be halted.",0
MsgDetected	DB	"Detected ",0
MsgKBRAM	DB	" KB RAM",NL,0
MsgX86family	DB	"86 family CPU, speed index=",0


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
		mov	ebx,[eax+tBMD.CodeStart]
		add	ebx,[eax+tBMD.Size]
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

		; Initialize timer (counter 0)
		mov	al,36h				; Counter 0, mode 3
		mov	cx,TIMER_InpFreq/TIMER_OutFreq	; Set divisor
		call	TMR_InitCounter

		; Finally, enable interrupts
		sti
		
		; Show version information
		mServPrintStr Msg_RVersion
		mServPrintStr RadiOS_Version
		mServPrintStr Msg_RCopyright

		; Initialize monitor
		call	MonitorInit

		; Initialize CPU and FPU
		call	CPU_Init
		call	FPU_Init
		call	TMR_CountCPUspeed
		
		; Print basic CPU information
		mServPrintStr MsgDetected
		movzx	eax,byte [?CPUinfo+tCPUinfo.Family]
		mServPrintDec
		mServPrintStr MsgX86family
		mServPrintDec [?CPUspeed]
		mServPrintChar NL

		; Initialize memory
		call	K_InitMem
		
		; Print how much memory we have
		mServPrintStr MsgDetected
		mServPrintDec [?BaseMemSz]
		mServPrintChar '+'
		mServPrintDec [?ExtMemSz]
		mServPrintStr MsgKBRAM

		; Initialize multitasking memory structures
.InitMT:	mov	eax,MAXNUMTHREADS
		call	MT_Init
		jc	near .Monitor

		; Enable paging
		call	PG_StartPaging
		jc	near .Monitor

		; Create idle thread
		mov	ebx,INIT_IdleThread
		xor	ecx,ecx
		mov	edx,cr3
		call	MT_CreateThread
		jc	.Monitor
		mov	[IdleTCB],ebx
		
		; Check if a task manager is loaded. If yes, create its thread
		call	INIT_CreateTMthread
		jc	.Monitor

		; At last, enable timer interrupts and roll the dice.
		xor	al,al
		call	PIC_EnbIRQ
		mov	ebx,[IdleTCB]
		call	MT_ThreadExec

		; This point must never be reached!
.Monitor:	int3

SysReboot:	call	KBC_HardReset

FatalError:	mServPrintStr MsgFatalErr
		mServReadKey
.Halt:		hlt
		jmp	.Halt
endp		;---------------------------------------------------------------


; --- Initialization procedures ---

		; INIT_IdleThread - kernel idle thread.
		;		    Currently does nothing, only displays its
		;		    activity.
		; Input: none.
		; Output: none.
proc INIT_IdleThread
		mov	eax,"\-/|"
.Infinite:	mov	[0xB8000+158],al
		ror	eax,8
		jmp	.Infinite
endp		;---------------------------------------------------------------

%include "tmlaunch.nasm"
