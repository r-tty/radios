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
global SysReboot


; --- Imports ---

; Kernel variables and data
library kernel
extern GDTaddrLim, ?IDTaddr, TrapHandlersArr
extern RadiOS_Version, Msg_RVersion, Msg_RCopyright

; Kernel procedures
extern K_CheckCPU:near, K_InitFPU:near, K_InitMem:near
extern K_DescriptorAddress:near
extern K_GetDescriptorBase:near, K_GetDescriptorLimit:near
extern K_GetDescriptorAR:near
extern K_SetDescriptorBase:near, K_SetDescriptorLimit:near

library kernel.mm
extern MM_Init:near

library kernel.paging
extern PG_Init:near, PG_StartPaging:near

library kernel.mt
extern MT_Init:near, MT_InitKernelProc:near
extern MT_CreateThread:near, MT_ThreadExec:near

library kernel.module
extern MOD_InitMem:near, MOD_InitKernelMod:near, MOD_Insert:near

library kernel.x86.basedev
extern PIC_Init:near, PIC_SetIRQmask:near, PIC_EnbIRQ:near
extern TMR_InitCounter:near
extern KBC_A20Control:near, KBC_HardReset:near
extern CMOS_EnableInt:near

%ifdef DEBUG
library monitor
extern MonitorInit:near
%endif


; --- Data ---

section .data

Msg_SysReboot	DB NL,NL,"Press a key to reboot...",ASC_BEL,0

Msg_Fatal	DB NL,NL,"FATAL ERROR ",0
Msg_SysHlt	DB NL,"System halted.",0

NLNL		DB NL,NL,0


; --- Variables ---

section .bss

IdleTCB		RESD	1				; Idle thread TCB
IDTaddrLim	RESB	6
InitStringBuf	RESB	256


; --- Code ---

section .text

%include "buildxdt.nasm"


; --- Initialization procedures ---

		; INIT_BootModules - initialize boot-time modules.
		; Input: none:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_BootModules
		mov	ecx,[BootModulesCount]
		jecxz	.Exit
		mov	edi,[BootModulesListAddr]
		xor	esi,esi
.Loop:		mov	ebx,[edi+tModList.Start]
		call	MOD_Insert
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
.Infinite:	inc	byte [0xB8000+158]
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

		; Initialize CPU and FPU.
		call	K_CheckCPU
		call	K_InitFPU

%ifdef DEBUG
		; Initialize monitor
		call	MonitorInit
%endif

		; Initialize memory
		mov	eax,[KernelFreeMemEnd]
		shr	eax,10				; Addr -> KB
		call	K_InitMem

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

		; Initialize memory management
		call	MM_Init
		jc	near FatalError
		
		; Initialize boot-time modules
		call	INIT_BootModules
		jc	near FatalError
		
		; Show version information
		mServPrintStr Msg_RVersion
		mServPrintStr RadiOS_Version
		mServPrintStr Msg_RCopyright

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

		; Enable timer interrupts and roll the dice
		xor	al,al
		call	PIC_EnbIRQ
		mov	ebx,[IdleTCB]
		call	MT_ThreadExec

		; This point must never be reached!
.Monitor:	int3

		; Reboot the machine
		mServPrintStr Msg_SysReboot
		mServReadKey
SysReboot:	call	KBC_HardReset

		; Fatal error: print error message, error number
		; and halt the system
FatalError:	mServPrintStr Msg_Fatal
		mServPrintStr Msg_SysHlt

.Halt:		jmp	.Halt
endp		;---------------------------------------------------------------
