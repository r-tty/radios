;*******************************************************************************
; thread.nasm - RadiOS thread management.
; Copyright (c) 2000,2003 RET & COM Research.
; Based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

%include "syscall.ah"
%include "locstor.ah"
%include "parameters.ah"
%include "tm/process.ah"

publicproc MT_ThreadSleep, MT_ThreadWakeup, MT_GetNumThreads
publicproc MT_SleepTQ, MT_WakeupTQ
exportproc MT_CreateThread, MT_ThrEnqueue, MT_ThreadExec, MT_FindTCBbyNum


externproc K_PoolInit
externproc K_PoolAllocChunk, K_PoolFreeChunk, K_PoolChunkAddr
externproc PG_Alloc, PG_AllocContBlock, PG_AllocAreaTables


section .bss

?MaxThreads	RESD	1

?ThreadPool	RESB	tMasterPool_size

?ReadyThrList	RESD	1		; Pointer to a list of ready threads
?ReadyThrCnt	RESD	1		; Counter of ready threads
?NumThreads	RESD	1		; Total number of threads


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


		; MT_ThrEnqueue - add a thread to the list and to the
		;		  ready queue.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThrEnqueue
		cli
		cmp	dword [?ReadyThrList],0
		jne	.NotFirst
		mov	[?ReadyThrList],ebx
		mov	[ebx+tTCB.Next],ebx
		mov	[ebx+tTCB.Prev],ebx
		mov	[ebx+tTCB.ReadyNext],ebx
		mov	[ebx+tTCB.ReadyPrev],ebx
		jmp	.OK

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

.OK:		inc	dword [?ReadyThrCnt]
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


		; MT_ThreadSleep - suspend a thread.
		; Input: EBX=TCB address,
		;	 AL=blocking state (THRSTATE_*).
		; Output: none.
proc MT_ThreadSleep
		pushfd
		cli
		mov	[ebx+tTCB.State],al
		mov	eax,[ebx+tTCB.Priority]
		mov	[ebx+tTCB.CurrPriority],eax
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
		jne	.1
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
		; Input: EAX=optional argument to pass to the thread,
		;	 EBX=start address,
		;	 EDX=address of thread attributes structure (or 0),
		;	 ESI=PCB address (may be 0 for kernel).
		; Output: CF=0 - OK, EBX=TCB address;
		;	  CF=1 - error, AX=error code.
		; Note: this procedure doesn't put newly created thread to
		;	any lists or queues. You must do it by calling
		;	MT_ThrEnqueue. This allows further manipulations
		;	on a TCB (e.g. attaching to the process) by the
		;	upper-level syscalls.
proc MT_CreateThread
		locals	par, entry, attr, pcb
		prologue
		savereg	ecx,edx,esi,edi

		mov	[%$par],eax
		mov	[%$entry],ebx
		mov	[%$attr],edx
		mov	[%$pcb],esi

		; Allocate a TCB and zero it, initialize lock semaphore
		mov	ebx,?ThreadPool
		call	K_PoolAllocChunk
		jc	near .NoTCB
		mov	ebx,esi
		mov	ecx,tTCB_size
		call	BZero
		mSemInit ebx+tTCB.Lock

		; Initialize 'Arg', 'Entry' and 'PCB' fields
		mov	eax,[%$par]
		mov	[ebx+tTCB.Arg],eax
		mov	eax,[%$entry]
		mov	[ebx+tTCB.Entry],eax
		mov	esi,[%$pcb]
		mov	[ebx+tTCB.PCB],esi

		; Initial values for typical scheduler fields.
		mov	byte [ebx+tTCB.State],THRSTATE_READY
		mov	byte [ebx+tTCB.PrioClass],THRPRCL_NORMAL
		mov	dword [ebx+tTCB.Priority],THRPRVAL_DEFAULT
		mov	dword [ebx+tTCB.CurrPriority],THRPRVAL_DEFAULT
		mov	dword [ebx+tTCB.Count],0
		mov	eax,[?SchedTick]
		mov	dword [ebx+tTCB.Stamp],eax

		; Every thread has a kernel stack regardless if it
		; is a kernel thread or regular user mode thread.
		;
		; For user threads, this stack is used when entering kernel
		; mode (its state is pushed on it).
		; For kernel threads, this is actual working stack.
		;
		; Note: currently there is no mechanism of kernel stack growing.
		mov	edi,ebx
		mov	ecx,DFLTKSTACKSIZE
		xor	dl,dl
		call	PG_AllocContBlock
		jc	near .NoKernStk
		call	BZero
		mov	[ebx],edi			; TCB address at bottom
		lea	ebx,[ebx+ecx-4]
		mov	[edi+tTCB.KStack],ebx
		mov	[edi+tTCB.Context+tJmpBuf.R_ESP],ebx

		; If it's a kernel thread, many things are so simple
		or	esi,esi	
		jne	.User
		mov	eax,[edi+tTCB.Entry]
		mov	[edi+tTCB.Context+tJmpBuf.R_EIP],eax
		jmp	.OK

		; Otherwise, we need to set up user stack, get a TID,
		; fill the TLS and create a small segment pointing it..
.User:		mov	dword [edi+tTCB.Context+tJmpBuf.R_EIP],K_GoRing3
		mov	edx,[%$attr]
		or	edx,edx
		jz	.DfltUStk
		add	edx,USERAREASTART
		jc	near .BadAttr
		mov	ecx,[edx+tThreadAttr.StackSize]
		or	ecx,ecx
		jz	.DfltUStk
		cmp	ecx,tTLS_size+64
		jb	near .BadUserStk
		mov	eax,[edx+tThreadAttr.StackAddr]
		cmp	eax,USERAREACHECK
		jae	near .BadUserStk
		mov	ebx,eax
		add	ebx,ecx
		jc	near .BadUserStk
		sub	ebx,byte tTLS_size
		jmp	.SetUstack

		; User wants default stack. One page is for him (minus TLS)
.DfltUStk:	mov	edx,[esi+tProcDesc.PageDir]
		mov	ebx,USERAREASTART+USTACKTOP-400000h
		call	MT_AllocSpecialPage
		jc	.Done
		lea	ebx,[eax+PAGESIZE-tTLS_size]
.SetUstack:	mov	[edi+tTCB.StackAddr],eax
		mov	[edi+tTCB.TLS],ebx

		; Find an unused LDT slot. Its number will be also TID
		mov	eax,[esi+tProcDesc.LDTaddr]
		xor	ecx,ecx
.LoopLDT:	cmp	dword [eax+ecx*8],0
		je	.FillLDT
		inc	ecx
		cmp	ecx,(ULDT_limit+1)/8
		je	.NoTID
		jmp	.LoopLDT

		; Initialize the TLS descriptor
.FillLDT:	mov	[edi+tTCB.TID],ecx
		mov	word [eax+ecx*8+tDesc.LimitLo],3
		add	ebx,USERAREASTART+tTLS.Self
		mov	[eax+ecx*8+tDesc.BaseLW],bx
		ror	ebx,16
		mov	[eax+ecx*8+tDesc.BaseHLB],bl
		mov	[eax+ecx*8+tDesc.BaseHHB],bh
		mov	byte [eax+ecx*8+tDesc.AR],ARpresent+ARsegment+AR_DS_R+AR_DPL3
		mov	byte [eax+ecx*8+tDesc.LimHiMode],AR_DfltSz

.OK:		mov	ebx,edi
		inc	dword [?NumThreads]
		clc

.Done:		epilogue
		ret

.NoTCB:		mov	ax,ERR_MT_NoFreeTCB
		stc
		jmp	.Done

.NoKernStk:	mov	ax,ERR_MT_CantAllocKernStk
		stc
		jmp	.Done

.NoTID:		mov	ax,ERR_MT_NoFreeTID
		stc
		jmp	.Done

.BadAttr:	mov	ax,ERR_MT_BadAttr
		stc
		jmp	.Done

.BadUserStk:	mov	ax,ERR_MT_BadUserStack
		stc
		jmp	.Done
endp		;---------------------------------------------------------------


		; MT_ThreadExec - pass execution to thread.
		; Input: EBX=address of TCB.
		; Output: (no return) if successes;
		;	  CF=1 and AX=error code if fails.
proc MT_ThreadExec
		cmp	ebx,[?CurrThread]
		je	.Err
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


		; MT_GetNumThreads - get total number of created threads.
		; Input: none.
		; Output: ECX=number of threads.
proc MT_GetNumThreads
		mov	ecx,[?NumThreads]
		ret
endp		;---------------------------------------------------------------


		; MT_FindTCBbyNum - find a TCB by its chunk ordinal number.
		; Input: EAX=chunk number.
		; Output: CF=0 - OK, EBX=TCB address;
		;	  CF=1 - error, AX=error code.
proc MT_FindTCBbyNum
		push	esi
		mov	ebx,?ThreadPool
		call	K_PoolChunkAddr
		jc	.Exit
		mov	ebx,esi
.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; K_GoRing3 - routine used to switch to user mode.
		; Input: none.
		; Output: never returns.
proc K_GoRing3
		; This is a layout of what 'iret' pops off the stack
		locals	rESS, rESP, rEFLAGS, rECS, rEIP, rESDS

		cli
		enter	%$lc,0

		; Setup ring 0 stack
		mov	ebx,[?CurrThread]
		mov	eax,[ebx+tTCB.KStack]
		mov	[KernTSS+tTSS.ESP0],eax
		
		; Load a process's page directory
		mov	esi,[ebx+tTCB.PCB]
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		; Fill in the TLS
		call	MT_FillTLS

		; Prepare user registers
		mov	eax,(USER_DSEG << 16) | USER_DSEG
		mov	[%$rESDS],eax
		mov	gs,ax
		mov	eax,[ebx+tTCB.Entry]
		mov	[%$rEIP],eax
		mov	dword [%$rECS],USER_CSEG
		mov	dword [%$rEFLAGS],FLAG_IF
		mov	eax,[ebx+tTCB.TLS]
		mov	[%$rESP],eax
		mov	dword [%$rESS],USER_DSEG

		; Go to user mode
		lea	esp,[%$rESDS]
	o16	pop	es
	o16	pop	ds
		iret
endp		;---------------------------------------------------------------


		; Allocate a special (e.g. stack) page for a thread.
		; Input: EDX=page directory address,
		;	 EBX=user address of special area (4MB aligned)
		; Output: CF=0 - OK, EAX=page address (user);
		;	  CF=1 - error, AX=error code.
proc MT_AllocSpecialPage
		mpush	ebx,ecx,edx

		; Allocate page table if necessary
		mov	ah,PG_USERMODE | PG_WRITABLE
		xor	ecx,ecx
		inc	ecx
		call	PG_AllocAreaTables
		jc	.Exit

		; Find unused PTE
		shr	ebx,PAGEDIRSHIFT
		mov	edx,[edx+ebx*4]
		and	edx,PGENTRY_ADDRMASK			; EDX=PT address
		mov	ecx,PG_ITEMSPERTABLE-1
.Loop:		cmp	dword [edx+ecx*4],PG_DISABLE
		je	.Found
		loop	.Loop
		mov	ax,ERR_MT_CantAllocStack
		stc
		jmp	.Exit

		; Get a page and clean it
.Found:		mov	dl,1
		call	PG_Alloc
		jc	.Exit
		xor	dl,dl
		or	eax,PG_USERMODE | PG_WRITABLE
		mov	[edx+ecx*4],eax
		and	eax,PGENTRY_ADDRMASK
		xchg	ebx,eax
		mov	edx,ecx
		mov	ecx,PAGESIZE
		call	BZero
		shl	eax,PAGEDIRSHIFT
		shl	edx,PAGESHIFT
		add	eax,edx
		sub	eax,USERAREASTART
		
.OK:		clc
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; Fill in TLS information.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK:
		;		    EAX=TID,
		;		    ECX=PID,
		;		    ESI=address of process descriptor;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be already set;
		;	destroys ESI and EDI.
proc MT_FillTLS
		; Put the actual address of TLS structure at the beginning of
		; TLS segment, so user can easily obtain TLS linear address.
		mov	edi,[ebx+tTCB.TLS]
		mov	eax,edi
		add	edi,USERAREASTART
		mov	[edi+tTLS.Self],eax

		; Fill in the TLS structure itself
		mov	eax,[ebx+tTCB.StackAddr]
		mov	[edi+tTLS.StackAddr],eax
		mov	esi,[ebx+tTCB.PCB]
		mov	ecx,[esi+tProcDesc.PID]
		mov	[edi+tTLS.PID],ecx
		mov	eax,[ebx+tTCB.TID]
		mov	[edi+tTLS.TID],eax
		mov	eax,[ebx+tTCB.Arg]
		mov	[edi+tTLS.Arg],eax
		mov	eax,[ebx+tTCB.ExitProc]
		or	eax,eax
		jnz	.SetExitProc
		mov	word [edi+tTLS.Trampoline],0CDh+(THRKILL_TRAP << 8)
		lea	eax,[edi+tTLS.Trampoline-USERAREASTART]
.SetExitProc:	mov	[edi+tTLS.ExitFunction],eax
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
		jne	.WrHdr
		mPrintString TxtNoReady
		ret
		
.WrHdr:		mPrintString TxtDumpHdr
.Walk:		mov	dl,[ebx+tTCB.State]
		mov	dh,'R'
		cmp	dl,THRST_READY
		je	.Print
		mov	dh,'W'
		cmp	dl,THRST_WAITING
		je	.Print
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
