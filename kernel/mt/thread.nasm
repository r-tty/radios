;*******************************************************************************
; thread.nasm - RadiOS thread management.
; Copyright (c) 2000 RET & COM Research.
; This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

%include "parameters.ah"
%include "thread.ah"
%include "tm/process.ah"


; --- Exports ---

publicproc MT_ThreadSleep, MT_ThreadWakeup
publicproc MT_SleepTQ, MT_WakeupTQ
exportproc MT_CreateThread, MT_ThreadExec
publicproc MT_GetNumThreads


; --- Imports ---

library kernel.pool
externproc K_PoolInit
externproc K_PoolAllocChunk, K_PoolFreeChunk

library kernel.paging
externproc PG_Alloc, PG_AllocContBlock, PG_AllocAreaTables


; --- Data ---

section .data

TxtThrSleep	DB	":THREAD:MT_ThreadSleep: warning: this thread already sleeps",0
TxtThrRunning	DB	":THREAD:MT_ThreadWakeup: warning: this thread is already running",0

; --- Variables ---

section .bss

?MaxThreads	RESD	1

?ThreadPool	RESB	tMasterPool_size

?ReadyThrList	RESD	1		; Pointer to a list of ready threads
?ReadyThrCnt	RESD	1		; Counter of ready threads
?NumThreads	RESD	1		; Total number of threads


; --- Procedures ---

section .text

		; MT_InitTCBpool - initialize the TCB pool.
		; Input: EAX=maximum number of threads.
		; Output: CF=0 - OK;
		;         CF=1 - error, AX=error code.
proc MT_InitTCBpool
		mpush	ebx,ecx
		mov	[?MaxThreads],eax
		mov	ebx,?ThreadPool
		mov	ecx,tTCB_size
		xor	edx,edx
		call	K_PoolInit
.Done:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_ThrEnqueue -  add a thread to the list.
		;		   It also ends up on the ready queue.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThrEnqueue
		cmp	dword [?ReadyThrList],0
		jne	.NotFirst
		mov	[?ReadyThrList],ebx
		mov	[ebx+tTCB.Next],ebx
		mov	[ebx+tTCB.Prev],ebx
		mov	[ebx+tTCB.ReadyNext],ebx
		mov	[ebx+tTCB.ReadyPrev],ebx
		ret

.NotFirst:	mov	eax,[?ReadyThrList]
		push	eax
		mov	[ebx+tTCB.Next],eax
		mov	eax,[eax+tTCB.Prev]
		mov	[ebx+tTCB.Prev],eax
		mov	[eax+tTCB.Next],ebx
		pop	eax
		mov	[eax+tTCB.Prev],ebx

		push	eax
		mov	[ebx+tTCB.ReadyNext],eax
		mov	eax,[eax+tTCB.ReadyPrev]
		mov	[ebx+tTCB.ReadyPrev],eax
		mov	[eax+tTCB.ReadyNext],ebx
		pop	eax
		mov	[eax+tTCB.ReadyPrev],ebx
		
		ret
endp		;---------------------------------------------------------------


		; MT_ThrRemove - remove thread from the list (and ready queue).
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThrRemove
		cmp	[ebx+tTCB.Next],ebx
		je	.IsFirst
		mpush	esi,edi
		mov	esi,[ebx+tTCB.Next]
		mov	edi,[ebx+tTCB.Prev]
		mov	[esi+tTCB.Prev],edi
		mov	[edi+tTCB.Next],esi
		cmp	[?ReadyThrList],ebx
		jne	.TuneReadyList
		mov	[?ReadyThrList],esi

		; Take care of ready list to
.TuneReadyList:	mov	esi,[ebx+tTCB.ReadyNext]
		mov	edi,[ebx+tTCB.ReadyPrev]
		mov	[esi+tTCB.ReadyPrev],edi
		mov	[edi+tTCB.ReadyNext],esi

		mpop	edi,esi
		ret

.IsFirst:	mov	dword [?ReadyThrList],0
		ret
endp		;---------------------------------------------------------------


		; MT_ThrRLink - link a thread to ready list.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThrRLink
		; When linking or unlinking a thread from a ready list
		; we don't have to take care of the head of the list
		; since no such thing exists. There is always one thread
		; ready to run (idle thread) linked on this list.
		; Assuming that, the code gets easier and quicker.
		mov	eax,[?ReadyThrList]
		mov	[ebx+tTCB.ReadyNext],eax
		mov	eax,[eax+tTCB.ReadyPrev]
		mov	[ebx+tTCB.ReadyPrev],eax
		mov	[eax+tTCB.ReadyNext],ebx
		mov	eax,[?ReadyThrList]
		mov	[eax+tTCB.ReadyPrev],ebx
		ret
endp		;---------------------------------------------------------------


		; MT_ThrRUnlink - unlink a thread from ready list.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThrRUnlink
		mpush	esi,edi
		mov	esi,[ebx+tTCB.ReadyNext]
		mov	edi,[ebx+tTCB.ReadyPrev]
		mov	[esi+tTCB.ReadyPrev],edi
		mov	[edi+tTCB.ReadyNext],esi
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; MT_ThreadSleep - sleep a thread.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThreadSleep
		cmp	byte [ebx+tTCB.State],THRSTATE_STOPPED
		jne	.1
	%ifdef KPOPUPS
		mKPopUp TxtThrSleep
	%endif
		ret

.1:		pushfd
		cli
		mov	byte [ebx+tTCB.State],THRSTATE_STOPPED
		mov	al,[ebx+tTCB.Priority]
		mov	[ebx+tTCB.CurrPriority],al
		call	MT_ThrRUnlink
		dec	dword [?ReadyThrCnt]
		popfd
		ret
endp		;---------------------------------------------------------------


		; MT_ThreadWakeup - wake up a thread.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThreadWakeup
		cmp	byte [ebx+tTCB.State],THRSTATE_READY
		jne	short .1
	%ifdef KPOPUPS
		mKPopUp TxtThrRunning
	%endif
		ret

.1:		pushfd
		cli
		mov	byte [ebx+tTCB.State],THRSTATE_READY
		call	MT_ThrRLink
		inc	dword [?ReadyThrCnt]
		popfd
		ret
endp		;---------------------------------------------------------------


		; MT_SleepTQ - add a thread to a sleep queue and sleep it.
		; Input: EBX=address of pointer to a wait queue.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_SleepTQ
		ret
endp		;---------------------------------------------------------------


		; MT_WakeupTQ - wake up all threads waiting in a queue.
		; Input: EBX=address of pointer to a wait queue.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_WakeupTQ
		ret
endp		;---------------------------------------------------------------


		; MT_CreateThread - create new thread.
		; Input: EBX=start address,
		;	 ECX=user stack size (if 0, default value of 4096 bytes
		;	     is assumed),
		;	 EDI=user stack address (if ECX != 0),
		;	 ESI=PCB address (may be 0 for kernel).
		; Output: CF=0 - OK, EBX=TCB address;
		;	  CF=1 - error, AX=error code.
proc MT_CreateThread
		mpush	ecx,edx,esi,edi

		mov	edx,edi
		mpush	ebx,esi
		mov	ebx,?ThreadPool
		call	K_PoolAllocChunk			; Allocate TCB
		mov	edi,esi
		mpop	esi,ebx
		jc	near .Err1

		; Initialize 'Entry' and 'PCB' fields
		mov	[edi+tTCB.Entry],ebx
		mov	[edi+tTCB.PCB],esi

		; Initial values for typical scheduler fields.
		mov	byte [edi+tTCB.State],THRSTATE_READY
		mov	byte [edi+tTCB.PrioClass],THRPRCL_NORMAL
		mov	dword [edi+tTCB.Priority],THRPRVAL_DEFAULT
		mov	dword [edi+tTCB.CurrPriority],THRPRVAL_DEFAULT
		mov	dword [edi+tTCB.Count],0
		mov	eax,[?SchedTick]
		mov	dword [edi+tTCB.Stamp],eax

		; Every thread has a kernel stack regardless if it
		; is a kernel thread or regular user mode thread.
		;
		; For user threads, this stack is used when entering kernel
		; mode (its state is pushed on it).
		; For kernel threads, this is actual working stack.
		;
		; Note: currently there is no mechanism of kernel stack growing.
		push	ecx
		mov	ecx,DFLTKSTACKSIZE
		xor	dl,dl				;  Get kernel stack
		call	PG_AllocContBlock		; in lower memory
		pop	ecx
		jc	.Err2
		call	BZero
		mov	[ebx],edi			; TCB address at bottom
		lea	ebx,[ebx+ecx-4]
		mov	[edi+tTCB.KStack],ebx
		mov	[edi+tTCB.Context+tJmpBuf.R_ESP],ebx

		cmp	dword [edi+tTCB.PCB],0		; Kernel thread?
		jne	.User

		mov	eax,[edi+tTCB.Entry]
		mov	[edi+tTCB.Context+tJmpBuf.R_EIP],eax
		jmp	.EnqReady
	
.User:		mov	dword [edi+tTCB.Context+tJmpBuf.R_EIP],K_GoRing3
		or	ecx,ecx
		jz	.DfltUStk
		lea	edx,[edx+ecx]
		mov	dword [edi+tTCB.Stack],edx
		jmp	.EnqReady
		
.DfltUStk:	mov	edx,[esi+tProcDesc.PageDir]
		call	MT_AllocMinUserStack
		jc	.Err3
		mov	dword [edi+tTCB.Stack],USTACKTOP-4

.EnqReady:	cli
		mov	ebx,edi
		call	MT_ThrEnqueue
		inc	dword [?ReadyThrCnt]
		inc	dword [?NumThreads]
		clc

.Done:		mpop	edi,esi,edx,ecx
		ret

.Err1:		mov	ax,ERR_MT_NoFreeTCB
		stc
		jmp	.Done

.Err2:		mov	ax,ERR_MT_CantAllocKernStk
		stc
		jmp	.Done

.Err3:		mov	ax,ERR_MT_CantAllocStack
		stc
		jmp	.Done
endp		;---------------------------------------------------------------


		; MT_ThreadExec - pass execution to thread.
		; Input: EBX=address of TCB.
		; Output: (no return) if successes;
		;	  CF=1 and AX=error code if fails.
proc MT_ThreadExec
		cmp	ebx,[?CurrThread]
		je	short .Err
		cli
		mov	[?CurrThread],ebx
		mov	dword [ebx+tTCB.Quant],THRQUANT_DEFAULT
		xor	eax,eax
		lea	edi,[ebx+tTCB.Context]
		call	K_LongJmp

.Err:		mov	ax,ERR_MT_SwitchToCurrThr
		stc
		ret
endp		;---------------------------------------------------------------


		; MT_ThreadKillCurrent - terminate current thread.
		; Input: none.
		; Output: none.
		; Note: assumes that interrupts are disabled.
proc MT_ThreadKillCurrent
		; This should never happen
		ret
endp		;---------------------------------------------------------------


		; MT_GetNumThreads - get total number of created threads.
		; Input: none.
		; Output: ECX=number of threads.
proc MT_GetNumThreads
		mov	ecx,[?NumThreads]
		ret
endp		;---------------------------------------------------------------


		; K_GoRing3 - routine used to switch to user mode.
		; Input: none.
		; Output: never returns.
proc K_GoRing3
		; This is a layout of what 'iret' pops off the stack
		locals	rESS, rESP, rEFLAGS, rECS, rEIP, rESDS
		prologue

		; Setup ring 0 stack
		cli
		mov	ebx,[?CurrThread]
		mov	eax,[ebx+tTCB.KStack]
		mov	[KernTSS+tTSS.ESP0],eax
		
		; Load a process's page directory
		mov	eax,[ebx+tTCB.PCB]
		mov	eax,[eax+tProcDesc.PageDir]
		mov	cr3,eax
		
		; Prepare user registers
		mov	eax,(USER_DSEG << 16) | USER_DSEG
		mov	[%$rESDS],eax
		mov	fs,ax
		mov	gs,ax
		mov	eax,[ebx+tTCB.Entry]
		mov	[%$rEIP],eax
		mov	dword [%$rECS],USER_CSEG
		mov	dword [%$rEFLAGS],FLAG_IOPL | FLAG_IF
		mov	eax,[ebx+tTCB.Stack]
		mov	[%$rESP],eax
		mov	dword [%$rESS],USER_DSEG

		; Go to user mode
		lea	esp,[%$rESDS]
	o16	pop	es
	o16	pop	ds
		iret

		; To make assembler happy
		epilogue
endp		;---------------------------------------------------------------


		; Create a minimal user stack (if it is not allocated yet).
		; Input: EDX=page directory address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_AllocMinUserStack
		push	ebx
		; Allocate page table if necessary
		mov	ah,PG_USERMODE | PG_WRITABLE
		mov	ebx,USERAREASTART+USTACKTOP-PAGESIZE
		mov	ecx,PAGESIZE
		call	PG_AllocAreaTables
		jc	.Exit

		mov	ebx,[edx+PG_ITEMSPERTABLE*4-4]
		and	ebx,PGENTRY_ADDRMASK			; EBX=PT address
		cmp	dword [ebx+PG_ITEMSPERTABLE*4-4],PG_DISABLE
		jne	.OK

		; Get a page and clean it
		mov	dl,1
		call	PG_Alloc
		jc	.Exit
		or	eax,PG_USERMODE | PG_WRITABLE
		mov	[ebx+PG_ITEMSPERTABLE*4-4],eax
		and	eax,PGENTRY_ADDRMASK
		mov	ebx,eax
		call	BZero
		
.OK:		clc
.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


;--- Debugging stuff -----------------------------------------------------------

%ifdef MTDEBUG

publicproc MT_DumpReadyThreads

section .data

TxtNoReady	DB	10,"no ready threads.",10,0
TxtDumpHdr	DB	10,"TCB       S     Ticks  Cnt     Prio    BPrio  Preempt  Sem     Stamp",10,0
  
section .text

		; MT_DumpReadyThreads - dump state of all ready threads.
		; Input: none.
		; Output: none.
proc MT_DumpReadyThreads
		push	esi
		mov	ebx,[?ReadyThrList]
		or	ebx,ebx
		jne	short .WrHdr
		mPrintString TxtNoReady
		ret
		
.WrHdr:		mPrintString TxtDumpHdr
.Walk:		mov	dl,[ebx+tTCB.State]
		mov	dh,'R'
		cmp	dl,THRST_READY
		je	short .Print
		mov	dh,'W'
		cmp	dl,THRST_WAITING
		je	short .Print
		mov	dh,'?'

.Print:		mov	eax,ebx				; TCB
		call	PrintDwordHex
		mPrintChar ' '
		call	PrintChar
		mPrintChar dh				; State
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.Ticks]
		call	PrintDwordDec			; Ticks
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.Count]
		call	PrintDwordDec			; Count
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.CurrPriority]
		call	PrintDwordDec			; Current priority
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.Priority]
		call	PrintDwordDec			; Base priority
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.Preempt]
		call	PrintDwordDec			; Preemptive counter
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.SemWait]
		call	PrintDwordDec			; Semaphore wait count
		mPrintChar HTAB
		mov	eax,[ebx+tTCB.Stamp]
		call	PrintDwordDec			; Stamp
		mPrintChar NL

		mov	ebx,[ebx+tTCB.ReadyNext]
		cmp	ebx,[?ReadyThrList]
		jne	.Walk
		pop	esi
		ret
endp		;---------------------------------------------------------------

%endif
