;*******************************************************************************
;  init.nasm - RadiOS initializer.
;  Copyright (c) 2002 RET & COM research.
;*******************************************************************************

module $init

%include "sys.ah"
%include "errors.ah"
%include "initdefs.ah"
%include "boot/bootdefs.ah"
%include "boot/mb_info.ah"
%include "asciictl.ah"
%include "biosdata.ah"
%include "x86/descript.ah"
%include "x86/paging.ah"


; --- Exports ---

global Start:export proc
publicproc SysReboot


; --- Imports ---

; Kernel variables and data
library kernel
extern GDTaddrLim, ?IDTaddr, TrapHandlersArr
extern RadiOS_Version, Msg_RVersion, Msg_RCopyright

; Kernel procedures
extern CPU_Init, FPU_Init, K_InitMem
extern K_DescriptorAddress
extern K_GetDescriptorBase, K_GetDescriptorLimit
extern K_GetDescriptorAR
extern K_SetDescriptorBase, K_SetDescriptorLimit

library kernel.mm
extern MM_Init

library kernel.initmem
extern ?BaseMemSz, ?ExtMemSz

library kernel.paging
extern PG_Init, PG_StartPaging

library kernel.mt
extern MT_Init, MT_InitKernelProc
extern MT_CreateThread, MT_ThreadExec

library kernel.module
extern MOD_InitMem, MOD_RegisterFormat, MOD_InitKernelMod, MOD_Insert

library kernel.x86.basedev
extern PIC_Init, PIC_SetIRQmask, PIC_EnbIRQ
extern TMR_InitCounter, TMR_CountCPUspeed
extern KBC_A20Control, KBC_HardReset
extern CMOS_EnableInt
extern ?CPUinfo, ?CPUspeed

library kernel.rdoff
extern BinFmtRDOFF

%ifdef DEBUG
library monitor
extern MonitorInit
%endif


; --- Data ---

section .data

MsgFatalErr	DB	NL,"Fatal error. System will be halted.",0
MsgDetected	DB	"Detected ",0
MsgKBRAM	DB	" KB RAM",NL,0
MsgX86family	DB	"86 family CPU, speed index=",0
MsgInitBootMods	DB	"Linking system modules:",NL,0
MsgProgress	DB	"System startup in progress..."

; --- Variables ---

section .bss

IdleTCB		RESD	1				; Idle thread TCB
IDTaddrLim	RESB	6
InitStringBuf	RESB	256


; --- Code ---

section .text

%include "buildxdt.nasm"


; --- Initialization procedures ---

		; INIT_BinaryFormats - initialize all binary formats
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_BinaryFormats
		mov	edx,BinFmtRDOFF
		call	MOD_RegisterFormat
		ret
endp		;---------------------------------------------------------------


		; INIT_BootModules - initialize boot-time modules.
		; Input: none:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_BootModules
		mov	ecx,[BootModulesCount]
		jecxz	.Exit
	%ifdef VERBOSE
		mServPrintStr MsgInitBootMods
	%endif
		mov	edi,[BootModulesListAddr]
		xor	esi,esi
.Loop:		mov	ebx,[edi+tModList.Start]
		mov	edx,[edi+tModList.End]
		mov	esi,[edi+tModList.CmdLine]
		push	edi
		call	MOD_Insert
		jc	.1
	%ifdef VERBOSE
	%endif
.1:		pop	edi
		add	edi,byte tModList_size
		loop	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


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


		; INIT_Spinup
proc INIT_Spinup
extern MT_ThreadSleep:near
extern ?CurrThread
	int3
	mov ebx,[?CurrThread]
	call MT_ThreadSleep
		jmp	$
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
		mov	eax,[?IDTaddr]
		mov	word [IDTaddrLim],IDT_size-1
		mov	[IDTaddrLim+2],eax
		lidt	[IDTaddrLim]

		; Build and initialize LDTs
		call	INIT_InitLDTs

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

		; Finally, enable interrupts
		sti
		
		; Show version information
		mServPrintStr Msg_RVersion
		mServPrintStr RadiOS_Version
		mServPrintStr Msg_RCopyright
%ifdef DEBUG
		; Initialize monitor
		call	MonitorInit
%endif
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
		mov	eax,[KernelFreeMemEnd]
		shr	eax,10				; Addr -> KB
		call	K_InitMem
		
		; Print how much memory we have
		mServPrintStr MsgDetected
		mServPrintDec [?BaseMemSz]
		mServPrintChar '+'
		mServPrintDec [?ExtMemSz]
		mServPrintStr MsgKBRAM

		; Initialize multitasking memory structures
.InitMT:	mov	eax,Init_MaxNumOfProcesses
		mov	ecx,Init_MaxNumOfThreads
		call	MT_Init
		jc	near .Monitor

		; Enable paging
		call	PG_StartPaging
		jc	near .Monitor

		; Create kernel process
		call	MT_InitKernelProc
		jc	near .Monitor

		; Initialize module table
		mov	eax,Init_MaxNumLoadedMods
		call	MOD_InitMem
		jc	near .Monitor

		; Initialize kernel module
		call	MOD_InitKernelMod
		jc	near .Monitor
		
		; Initialize binary formats
		call	INIT_BinaryFormats
		jc	near .Monitor

		; Initialize memory management
		call	MM_Init
		jc	near FatalError

		; Initialize boot-time modules
		call	INIT_BootModules
		jc	near FatalError

		; Create two initial kernel threads
		; (idle and spin-up).
		mov	ebx,INIT_IdleThread
		xor	ecx,ecx
		xor	esi,esi
		call	MT_CreateThread
		jc	.Monitor
		mov	[IdleTCB],ebx			; Save launcher TCB

		mov	ebx,INIT_Spinup
		mov	ecx,16384			; 16KB stack
		call	MT_CreateThread
		jc	.Monitor

		; At last, enable timer interrupts and roll the dice.
		mServPrintStr MsgProgress
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
