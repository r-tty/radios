;-------------------------------------------------------------------------------
; ring0init.nasm - initialization of kernel part of the task manager.
;-------------------------------------------------------------------------------

module tm.kern.ring0init

%include "sys.ah"
%include "errors.ah"
%include "parameters.ah"
%include "module.ah"
%include "serventry.ah"
%include "thread.ah"
%include "pool.ah"
%include "syscall.ah"
%include "tm/process.ah"


exportproc Start
publicproc R0_Pid2PCBaddr, R0_IteratePgrp

publicdata ?BootModsArr, ?KernPCB


externproc TM_Main, TM_InitTimerPool, MapArea, DestroyThread
externdata ClockSyscallTable, TimerSyscallTable
externdata SignalSyscallTable, ThreadSyscallTable, ConnectSyscallTable
externdata ?ProcListPtr, ?MaxNumOfProc, ?ProcessPool

library $rmk
importproc K_InstallSyscallHandler, K_InstallSoftIntHandler
importproc K_PoolInit, K_PoolAllocChunk, K_PoolChunkAddr
importproc K_SemV, K_SemP
importproc PG_Alloc, PG_AllocAreaTables
importproc K_RegisterLDT
importproc MT_CreateThread, MT_ThrEnqueue
importproc BZero, MemSet
importdata ?UpperMemSize


section .data

SyscallTables	DD	SignalSyscallTable
		DD	ClockSyscallTable
		DD	TimerSyscallTable
		DD	ThreadSyscallTable
		DD	ConnectSyscallTable
		DD	0

TxtInitErr	DB	"taskman ring0 init error, code=", 0


section .bss

?BootModsArr	RESD	1
?KernPCB	RESD	1


section .text

		; Task manager initialization - entry point.
		; Input: EBX=address of TM boot module descriptor,
		;	 ESI=address of boot modules descriptors array.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc Start
		locals	bmd
		prologue

		mpush	ebx,esi
		mov	[?BootModsArr],esi
		mov	[%$bmd],ebx

		; Install our syscall handlers
		call	R0_InitSyscalls

		; Install thread termination trap handler
		mov	al,THRKILL_TRAP
		mov	ebx,R0_ThrKillHandler
		call	K_InstallSoftIntHandler

		; Initialize process descriptor pool
		mov	dword [?MaxNumOfProc],MAXNUMPROCESSES
		mov	ebx,?ProcessPool
		xor	ecx,ecx
		xor	edx,edx
		mov	cl,tProcDesc_size
		mov	dl,POOLFL_HIMEM
		call	K_PoolInit

		; Pseudo-process with PID 0 is actually the kernel.
		; It it not used anywhere except for obtaining the address
		; of kernel page directory
		call	K_PoolAllocChunk
		jc	near .Err
		mov	[?KernPCB],esi
		mov	ebx,esi				
		call	BZero
		mov	eax,cr3
		mov	[esi+tProcDesc.PageDir],eax

		; Get our process descriptor
		mov	ebx,?ProcessPool
		call	K_PoolAllocChunk
		jc	near .Err
		mov	ebx,esi
		call	BZero

		; Allocate a new page directory for our process
		mov	dl,1
		call	PG_Alloc
		jc	near .Err
		and	eax,PGENTRY_ADDRMASK
		mov	edx,eax

		; Copy the kernel page directory
		push	esi
		mov	esi,cr3
		mov	edi,edx
		mov	ecx,PG_ITEMSPERTABLE
		cld
		rep	movsd
		pop	esi

		; Fill in some fields of our process descriptors
		mov	[esi+tProcDesc.PageDir],edx
		inc	ecx
		mov	[esi+tProcDesc.PID],ecx
		mov	ebx,[%$bmd]
		mov	[esi+tProcDesc.Module],ebx
		mov	ecx,MAXCONNECTIONS
		mov	[esi+tProcDesc.MaxConn],ecx
		lea	ebx,[esi+tProcDesc.CoIDbmap]
		mov	dword [esi+tProcDesc.CoIDbmapAddr],ebx
		shr	ecx,3
		xor	eax,eax
		dec	eax
		call	MemSet

		; Initialize process descriptor lock semaphore
		xor	eax,eax
		mov	[esi+tProcDesc.Lock+tSemaphore.WaitQ],eax
		inc	eax
		mov	[esi+tProcDesc.Lock+tSemaphore.Count],eax

		; Allocate a page for LDT and register it
		mov	dl,1
		call	PG_Alloc
		jc	near .Err
		and	eax,PGENTRY_ADDRMASK
		mov	[esi+tProcDesc.LDTaddr],eax
		mov	ebx,eax
		mov	ecx,PAGESIZE
		call	BZero
		xor	eax,eax
		inc	al
		call	K_RegisterLDT
		mov	[esi+tProcDesc.LDTdesc],dx

		; Put our process descriptor into a linked list
		mEnqueue dword [?ProcListPtr], Next, Prev, esi, tProcDesc, edx

		; Create a thread within our process
		mov	ebx,TM_Main
		xor	edx,edx
		call	MT_CreateThread
		jc	near .Err
		mLockCB	esi, tProcDesc
		mEnqueue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB, ecx
		mUnlockCB esi, tProcDesc
		call	MT_ThrEnqueue

		; Create page tables for mapping physical memory
		mov	edx,[esi+tProcDesc.PageDir]
		mov	ebx,USERAREASTART
		mov	ecx,[?UpperMemSize]
		shl	ecx,10
		add	ecx,UPPERMEMSTART
		add	ecx,~ADDR_PDEMASK
		shr	ecx,PAGEDIRSHIFT
		mov	ah,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		call	PG_AllocAreaTables
		jc	near .Err
		
		; Map first megabyte and HMA read-only
		mov	ecx,HMASTART+HMASIZE
		mov	al,PG_PRESENT | PG_USERMODE
		mov	ah,al
		mov	edi,USERAREASTART
		xor	esi,esi
		call	MapArea
		jc	.Err

		; Map the rest of the physical memory read-write.
		mov	esi,ecx
		add	edi,ecx
		mov	al,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		mov	ah,al
		mov	ecx,[?UpperMemSize]
		sub	ecx,HMASIZE / 1024
		shl	ecx,10
		call	MapArea
		jc	.Err

		; Adjust the "Size" field of our module descriptor, so heap
		; will work correctly.
		add	ecx,UPPERMEMSTART
		mov	ebx,[%$bmd]
		mov	[ebx+tModule.Size],ecx

		; Initialize timer pool
		mov	eax,MAXTIMERS
		call	TM_InitTimerPool
		jc	.Err

.Exit		mpop	esi,ebx
		epilogue
		ret

.Err:		mov	edx,eax
		mServPrintStr TxtInitErr
		mServPrint16h dx
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; R0_InitSyscalls - install syscall handlers.
		; Input: none.
		; Output: none.
proc R0_InitSyscalls
		mov	esi,SyscallTables
.LoopTables:	mov	edi,[esi]
		add	esi,byte 4
		or	edi,edi
		jz	.Exit
.LoopEntries:	mov	ebx,[edi]
		or	ebx,ebx
		jz	.LoopTables
		mov	ax,[edi+4]
		mov	cl,[edi+6]
		call	K_InstallSyscallHandler
		add	edi,byte 8
		jmp	.LoopEntries
.Exit:		ret
endp		;---------------------------------------------------------------


		; Get the address of PCB by a pid
		; Input: EAX=PID.
		; Output: CF=0 - OK, ESI=address of PCB;
		;	  CF=1 - error, EAX=errno.
proc R0_Pid2PCBaddr
		push	ebx
		mov	ebx,?ProcessPool
		call	K_PoolChunkAddr
		pop	ebx
		jc	.Err
		ret

.Err:		mov	eax,-ESRCH
		ret
endp		;---------------------------------------------------------------


		; Iterate through a process group applying the function.
		; Input: EDX=function address,
		;	 ESI=address of head's PCB.
		; Output: CF=0 - OK, all processes have been processed;
		;	  CF=1 - function error, AX=error code.
proc R0_IteratePgrp
		push	esi
.Loop:		or	esi,esi
		jz	.Exit
		call	edx
		jc	.Exit
.Next:		mov	eax,esi
		mov	esi,[esi+tProcDesc.PgrpNext]
		cmp	esi,eax
		jne	.Loop
.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; Thread kill trap handler.
proc R0_ThrKillHandler
		xor	edx,edx
		jmp	DestroyThread
endp		;---------------------------------------------------------------
