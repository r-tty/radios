;-------------------------------------------------------------------------------
; ring0init.nasm - initialization of kernel part of the task manager.
;-------------------------------------------------------------------------------

module tm.kern.ring0init

%include "sys.ah"
%include "parameters.ah"
%include "module.ah"
%include "serventry.ah"
%include "thread.ah"
%include "pool.ah"
%include "tm/process.ah"

; --- Exports ---

exportproc Start

publicdata ?BootModsArr, ?KernPCB

; --- Imports ---

externproc TM_Main, TM_InitTimerPool, MapArea
externdata SignalSyscallTable, TimerSyscallTable, ThreadSyscallTable
externdata ?ProcListPtr, ?MaxNumOfProc, ?ProcessPool

library $rmk
importproc K_InstallSyscallHandler
importproc K_PoolInit, K_PoolAllocChunk
importproc PG_Alloc, PG_AllocAreaTables
importproc BZero
importproc MT_CreateThread
importdata ?UpperMemSize

; --- Data ---

section .data

SyscallTables	DD	SignalSyscallTable
		DD	TimerSyscallTable
		DD	ThreadSyscallTable
		DD	0

TxtInitErr	DB	"Error while initializing kernel part of task manager", 0


; --- Variables ---

section .bss

?BootModsArr	RESD	1
?KernPCB	RESD	1

; --- Code ---

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
		call	TM_InitSyscalls

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
		; Zap the pool signature, so any reference to pool chunk # 0
		; will be catched.
		mov	ebx,esi				
		call	BZero
		mov	eax,cr3
		mov	[esi+tProcDesc.PageDir],eax

		; Get our process descriptor and zero it
		mov	ebx,?ProcessPool
		call	K_PoolAllocChunk
		jc	near .Err
		lea	ebx,[esi+4]			; Keep pool signature
		sub	ecx,byte 4
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
		mov	dword [esi+tProcDesc.PID],1
		mov	ebx,[%$bmd]
		mov	[esi+tProcDesc.Module],ebx

		; Put our process descriptor into a linked list
		mEnqueue dword [?ProcListPtr], Next, Prev, esi, tProcDesc

		; Create a thread within our process
		mov	ebx,TM_Main
		xor	ecx,ecx
		call	MT_CreateThread
		jc	.Err

		; Create page tables for mapping physical memory
		mov	ebx,USERAREASTART
		mov	ecx,UPPERMEMSTART
		add	ecx,[?UpperMemSize]
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

.Err:		mServPrintStr TxtInitErr
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; TM_InitSyscalls - install syscall handlers.
		; Input: none.
		; Output: none.
proc TM_InitSyscalls
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
