;-------------------------------------------------------------------------------
;  thread.as - thread management routines.
;-------------------------------------------------------------------------------

%include "thread.ah"


; --- Exports ---

global MT_ThreadSleep, MT_ThreadWakeup, MT_ThreadExec
global MT_CreateThread


; --- Imports ---

library kernel.pool
extern K_PoolInit:near
extern K_PoolAllocChunk:near, K_PoolFreeChunk:near

library kernel.mm
extern MM_AllocBlock:near


; --- Data ---

section .data

MsgThrSleep	DB	":THREAD:MT_ThreadSleep: warning: this thread is already sleeps",0
MsgThrRunning	DB	":THREAD:MT_ThreadSleep: warning: this thread is already running",0

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
		cmp	byte [ebx+tTCB.State],THRST_WAITING
		jne	.1
	%ifdef KPOPUPS
		push	esi
		mov	esi,MsgThrSleep
		call	K_PopUp
		pop	esi
	%endif
		ret

.1:		pushfd
		cli
		mov	byte [ebx+tTCB.State],THRST_WAITING
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
		cmp	byte [ebx+tTCB.State],THRST_READY
		jne	.1
	%ifdef KPOPUPS
		push	esi
		mov	esi,MsgThrRunning
		call	K_PopUp
		pop	esi
	%endif
		ret

.1:		pushfd
		cli
		mov	byte [ebx+tTCB.State],THRST_READY
		call	MT_ThrRLink
		inc	dword [?ReadyThrCnt]
		popfd
		ret
endp		;---------------------------------------------------------------


		; MT_CreateThread - create new thread.
		; Input: EBX=start address,
		;	 ESI=address of process descriptor (might be 0 for
		;	     kernel threads),
		;	 ECX=0:
 		;	     kernel threads: don't allocate kernel stack;
		;	     user/drv threads: don't allocate user/drv stack.
		;	 ECX!=0:
		;	     kernel threads: ECX=kernel stack size;
		;	     user/drv threads: ECX=user/drv stack size
		;			       (kernel stack will be PAGESIZE).
		; Output: CF=0 - OK, EBX=TCB address;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set.
proc MT_CreateThread
		mpush	ecx,edx,esi,edi

		mov	edx,ebx					; EDX=start addr
		mov	ebx,?ThreadPool
		push	esi
		call	K_PoolAllocChunk			; Allocate TCB
		mov	edi,esi
		pop	esi
		jc	near .Err1

		; Initialize 'Entry' field
		mov	[edi+tTCB.Entry],edx

		; Initial values for typical scheduler fields.
		mov	byte [edi+tTCB.State],THRST_READY
		mov	byte [edi+tTCB.PrioClass],THRPRCL_NORMAL
		mov	byte [edi+tTCB.Priority],THRPRVAL_DEFAULT
		mov	byte [edi+tTCB.CurrPriority],THRPRVAL_DEFAULT
		mov	byte [edi+tTCB.Count],0
		mov	eax,[?SchedTicksCnt]
		mov	dword [edi+tTCB.Stamp],eax

		; Initialize 'PCB' field and check stack size
		mov	[edi+tTCB.PCB],esi
		mIsKernProc esi
		cmp	esi,[?ProcListPtr]		; Kernel thread?
		je	.KStackCheck
		mov	dword [edi+tTCB.Stack],0
		or	ecx,ecx				; Allocate stack?
		jz	.SetKStack

		; Setup user/driver stack (for non-kernel threads).
		mov	dl,1				; Don't load CR3
		mov	dh,PG_WRITEABLE+PG_USERMODE
		call	MM_AllocBlock
		jc	.Err1
		call	BZero
		add	ebx,ecx
		and	bl,0FCh				; Align by dword
		sub	ebx,byte 4
		mov	[edi+tTCB.Stack],ebx
		jmp	.SetKStack

.KStackCheck:	or	ecx,ecx				; Allocate kernel stack?
		jnz	.SetKStack2
		mov	[edi+tTCB.KStack],esp		; Use current stack
		mov	[edi+tTCB.Context+tJmpBuf.R_ESP],esp
		jmp	short .KCtxSet

		; Setup kernel stack.
		; Every thread has a kernel stack regardless if it
		; is a kernel thread or regular user/driver mode thread.
		;
		; For user and driver mode threads, this stack is used when
		; entering kernel mode (its state is pushed on it).
		; For kernel threads, this is actual working stack
		; NOTE: kernel stack is only one page long, there is no
		; mechanism to grow kernel stack at the moment
		; therefore kernel threads mustn't be stack hungry
.SetKStack:	mov	ecx,PageSize
.SetKStack2:	mov	dl,1				; Don't load CR3
		mov	dh,PG_WRITEABLE
		call	MM_AllocBlock			; Get kernel stack
		jc	.Err2
		call	BZero
		lea	ebx,[ebx+ecx-4]
		mov	[edi+tTCB.KStack],ebx
		mov	[edi+tTCB.Context+tJmpBuf.R_ESP],ebx

		cmp	dword [edi+tTCB.PCB],0		; Kernel thread?
		jne	.Attach				; No, attach to process
.KCtxSet:	mov	eax,[edi+tTCB.Entry]
		mov	[edi+tTCB.Context+tJmpBuf.R_EIP],eax
		jmp	short .EnqReady
	
		; This will add newly created thread to its process
.Attach:	call	MT_ProcAttachThread
		jc	.Done
		mov	dword [edi+tTCB.Context+tJmpBuf.R_EIP],K_GoRing13

.EnqReady:	pushfd
		cli
		mov	ebx,edi
		call	MT_ThrEnqueue
		inc	dword [?ReadyThrCnt]
		inc	dword [?NumThreads]
		popfd

.Done:		mpop	edi,esi,edx,ecx
		ret

.Err1:		mov	ax,ERR_MT_NoFreeTCB
.Err:		stc
		jmp	short .Done

.Err2:		mov	ax,ERR_MT_CantAllocStack
		jmp	short .Err

.Err3:		mov	ax,ERR_MT_CantAllocKernStk
		jmp	short .Err
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
		
endp		;---------------------------------------------------------------


		; K_GoRing13 - routine used to switch to driver or user mode.
		; Input: AL=target mode:
		;	  AL=1 - driver mode;
		;	  AL=3 - user mode.
		; Output: never returns.
proc K_GoRing13
%define	.rESDS		ebp-24
%define .rEIP		ebp-20
%define	.rECS		ebp-16
%define	.rEFLAGS	ebp-12
%define	.rESP		ebp-8
%define	.rESS		ebp-4

		push	ebp
		mov	ebp,esp
		sub	esp,byte 24

		; Setup ring 0 stack
		cli
		mov	ebx,[?CurrThread]
		mov	eax,[ebx+tTCB.KStack]
		mov	[KernTSS+tTSS.ESP0],eax

		cmp	al,1
		je	.DriverMode
		mov	esi,(USER_DSEG << 16) | USER_DSEG
		mov	edi,(USER_CSEG << 16) | USER_CSEG
		jmp	short .Prepare

.DriverMode:	mov	esi,(DRV_DSEG << 16) | DRV_DSEG
		mov	edi,(DRV_CSEG << 16) | DRV_CSEG

		; This is a layout of what 'iret' pops off the stack
.Prepare:	mov	[.rESDS],esi
		mov	eax,[ebx+tTCB.Entry]
		mov	[.rEIP],eax
		mov	[.rECS],edi
		mov	dword [.rEFLAGS],FLAG_IOPL | FLAG_IF
		mov	eax,[ebx+tTCB.Stack]
		mov	[.rESP],eax
		mov	[.rESS],esi

		; Go to driver/user mode
		lea	esp,[.rESDS]
		pop	es
		pop	ds
		iret
endp		;---------------------------------------------------------------


;--- Debugging stuff -----------------------------------------------------------

%ifdef DEBUG

global MT_DumpReadyThreads

section .data

MsgNoReady	DB	10,"no ready threads.",10,0
MsgDumpHdr	DB	10,"TCB       S  Ticks     Cnt       Prio      BPrio     Preempt   Sem       Stamp",10,0
  
section .text

		; MT_DumpReadyThreads - dump state of all ready threads.
		; Input: none.
		; Output: none.
proc MT_DumpReadyThreads
		push	esi
		mov	ebx,[?ReadyThrList]
		or	ebx,ebx
		jne	short .WrHdr
		mPrintString MsgNoReady
		ret
		
.WrHdr:		mPrintString MsgDumpHdr
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
		mPrintChar ' '
		call	PrintChar
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

