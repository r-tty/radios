;*******************************************************************************
; proc.nasm - process management.
; Copyright (c) 2000-2002 RET & COM Research.
;*******************************************************************************

module tm.proc

%include "sys.ah"
%include "parameters.ah"
%include "errors.ah"
%include "pool.ah"
%include "thread.ah"
%include "msg.ah"
%include "tm/process.ah"

publicproc TM_InitProc
publicproc TM_NewProcess, TM_DelProcess
publicdata ?ProcessPool, ?ProcListPtr, ?MaxNumOfProc

externproc PoolAllocChunk, PoolFreeChunk, PoolChunkNumber, PoolChunkAddr
externproc NewPageDir

library $libc
importproc _memset


section .bss

?ProcListPtr	RESD	1			; Address of process list
?MaxNumOfProc	RESD	1			; Max. number of processes
?ProcessPool	RESB	tMasterPool_size	; Process master pool


section .text

		; TM_NewProcess - create a new process.
		; Input: EBX=address of module descriptor,
		;	 ESI=address of parent PCB.
		; Output: CF=0 - OK, ESI=address of PCB;
		;	  CF=1 - error, AX=error code.
proc TM_NewProcess
		push	edi
		mov	edi,esi				; Save parent PCB
		push	ebx
		mov	ebx,?ProcessPool
		call	PoolAllocChunk
		pop	ebx
		jc	.Exit

		lea	eax,[esi+4]			; Don't erase signature
		Ccall	_memset, eax, byte 0, dword tProcDesc_size-4
		mov	[esi+tProcDesc.Parent],edi
		mov	[esi+tProcDesc.Module],ebx

		call	PoolChunkNumber
		mov	[esi+tProcDesc.PID],eax
		
		; Allocate a new page directory
		call	NewPageDir
		jc	.Exit
		mov	[esi+tProcDesc.PageDir],edx

		; Put the process descriptor into a linked list
		mEnqueue dword [?ProcListPtr], Next, Prev, esi, tProcDesc

.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; TM_DelProcess - delete process.
		; Input: ESI=PCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_DelProcess
		ret
endp		;---------------------------------------------------------------


		; TM_ProcAttachThread - add thread to process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_ProcAttachThread
		mov	esi,[ebx+tTCB.PCB]
		or	esi,esi
		jz	.Error
		mEnqueue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB
		clc
		ret

.Error:		mov	ax,ERR_MT_UnableAttachThread
		stc
		ret
endp		;---------------------------------------------------------------


		; TM_ProcDetachThread - remove thread from process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_ProcDetachThread
		mov	esi,[ebx+tTCB.PCB]
		or	esi,esi
		jz	short .Error
		mDequeue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB
		clc
		ret
		
.Error:		mov	ax,ERR_MT_UnableDetachThread
		stc
		ret
endp		;---------------------------------------------------------------
