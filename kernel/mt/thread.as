;-------------------------------------------------------------------------------
;  thread.as - thread management routines.
;-------------------------------------------------------------------------------

%include "sema.ah"
%include "pool.ah"
%include "thread.ah"


; --- Exports ---

global K_CurrThread
global MT_ThreadSleep, MT_ThreadWakeup


; --- Imports ---

library kernel.pool
extern K_PoolInit:near
extern K_PoolAllocChunk:near, K_PoolFreeChunk:near

library kernel.mm
extern MM_AllocBlock:near

; --- Variables ---

section .bss

K_MaxThreads	RESD	1
K_CurrThread	RESD	1

MT_ThrPool	RESB	tMasterPool_size

MT_ReadyThrLst	RESD	1		; Pointer to a list of ready threads
MT_ReadyThrCnt	RESD	1		; Counter of ready threads


; --- Procedures ---

section .text

		; MT_InitTCBpool - initialize the TCB pool.
		; Input: EAX=maximum number of threads.
		; Output: CF=0 - OK;
		;         CF=1 - error, AX=error code.
proc MT_InitTCBpool
		mpush	ebx,ecx
		mov	[K_MaxThreads],eax
		mov	ecx,tTCB_size
		mov	ebx,MT_ThrPool
		call	K_PoolInit
.Done:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_ThrEnqueue -  add a thread to the list.
		;		    It also ends up on the ready queue.
		; Input: EBX=TCB address.
		; Output: none.
proc MT_ThrEnqueue
		cmp	dword [MT_ReadyThrLst],0
		jne	.NotFirst
		mov	[MT_ReadyThrLst],ebx
		mov	[ebx+tTCB.Next],ebx
		mov	[ebx+tTCB.Prev],ebx
		mov	[ebx+tTCB.ReadyNext],ebx
		mov	[ebx+tTCB.ReadyPrev],ebx
		ret

.NotFirst:	mov	eax,[MT_ReadyThrLst]
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
		cmp	[MT_ReadyThrLst],ebx
		jne	.TuneReadyList
		mov	[MT_ReadyThrLst],esi

		; Take care of ready list to
.TuneReadyList:	mov	esi,[ebx+tTCB.ReadyNext]
		mov	edi,[ebx+tTCB.ReadyPrev]
		mov	[esi+tTCB.ReadyPrev],edi
		mov	[edi+tTCB.ReadyNext],esi

		mpop	edi,esi
		ret

.IsFirst:	mov	dword [MT_ReadyThrLst],0
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
		mov	eax,[MT_ReadyThrLst]
		mov	[ebx+tTCB.ReadyNext],eax
		mov	eax,[eax+tTCB.ReadyPrev]
		mov	[ebx+tTCB.ReadyPrev],eax
		mov	[eax+tTCB.ReadyNext],ebx
		mov	eax,[MT_ReadyThrLst]
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
	%endif
		ret

.1:		pushfd
		cli
		mov	byte [ebx+tTCB.State],THRST_WAITING
		mov	al,[ebx+tTCB.Priority]
		mov	[ebx+tTCB.CurrPriority],al
		call	MT_ThrRUnlink
		dec	dword [MT_ReadyThrCnt]
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
	%endif
		ret

.1:		pushfd
		cli
		mov	byte [ebx+tTCB.State],THRST_READY
		call	MT_ThrRLink
		inc	dword [MT_ReadyThrCnt]
		popfd
		ret
endp		;---------------------------------------------------------------


		; MT_CreateThread - create new thread.
		; Input: EBX=start address,
		;	 ECX=stack size (0=don't allocate stack),
		;	 EDX=address of process descriptor.
		; Output: CF=0 - OK, EBX=TCB address;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set.
proc MT_CreateThread
%define	.pid	ebp-4
%define .tstart	ebp-8

		prologue 8
		mpush	ecx,edx,esi
		mov	[.tstart],ebx

		mov	ebx,MT_ThrPool
		call	K_PoolAllocChunk			; Allocate TCB
		jc	near .Err1
		mov	ebx,esi

		; Initialize 'PCB' and 'Entry' fields
		mov	[ebx+tTCB.PCB],edx
		mPDA2PID edx
		mov	[.pid],eax
		mov	eax,[.tstart]
		mov	[ebx+tTCB.Entry],eax

		; Initial values for typical scheduler fields.
		mov	byte [ebx+tTCB.State],THRST_READY
		mov	byte [ebx+tTCB.PrioClass],THRPRCL_NORMAL
		mov	byte [ebx+tTCB.Priority],THRPRVAL_DEFAULT
		mov	byte [ebx+tTCB.CurrPriority],THRPRVAL_DEFAULT

		; Setup user/driver stack (for non-kernel threads).
		mov	[edi+tTCB.Stack],eax
		mov	eax,[.pid]
		or	eax,eax
		jz	.SetKStack
		or	ecx,ecx
		jz	.SetKStack
		mov	dl,1				; Don't load CR3
		mov	dh,PG_WRITEABLE+PG_USERMODE
		call	MM_AllocBlock
		jc	.Err1
		call	BZero
		add	ebx,ecx
		and	bl,0FCh				; Align by dword
		sub	ebx,byte 4
		mov	[edi+tTCB.Stack],ebx

		; Setup kernel stack.
		; Every thread has a kernel stack regardless if it
		; is a kernel thread or regular user/driver mode thread.
		;
		; For user and driver mode threads, this stack is used when
		; entering kernel mode (its state is pushed on it).
		; For kernel threads, this is actual working stack
		; NOTE: kernel stack is only one page long, there is no
		;	 mechanism to grow kernel stack at the moment
		;	 therefore kernel threads mustn't be stack hungry
.SetKStack:	mov	edi,ebx				; Keep TCB address
		mov	ecx,PageSize
		mov	dl,1				; Don't load CR3
		mov	dh,PG_WRITEABLE
		mov	eax,[.pid]
		call	MM_AllocBlock			; Get kernel stack
		jc	.Err2
		call	BZero
		add	ebx,PageSize-4
		mov	[edi+tTCB.KStack],ebx

		; This will add newly created thread to its process
		call	MT_ProcAttachThread
		jc	.Done

.Done:		mpop	esi,edx,ecx
		epilogue
		ret

.Err1:		mov	ax,ERR_MT_NoFreeTCB
.Err:		stc
		jmp	short .Done

.Err2:		mov	ax,ERR_MT_CantAllocStack
		jmp	short .Err

.Err3:		mov	ax,ERR_MT_CantAllocKernStk
		jmp	short .Err
endp		;---------------------------------------------------------------

