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
%include "tm/procmsg.ah"

publicproc TM_InitProc
publicproc TM_NewProcess, TM_DelProcess
publicproc TM_ProcAttachThread, TM_ProcDetachThread
publicdata ?ProcessPool, ?ProcListPtr, ?MaxNumOfProc
publicdata ProcMsgHandlers

externproc HashAdd
externproc PoolInit, PoolAllocChunk, PoolFreeChunk
externproc PoolChunkNumber, PoolChunkAddr
externproc PageAlloc, NewPageDir
externproc RegisterLDT, UnregisterLDT

library $rmk
importdata ?ConnPool, ?ConnHash

section .data

ProcMsgHandlers:
mMHTabEnt MH_ProcSpawn, PROC_SPAWN
mMHTabEnt MH_ProcWait, PROC_WAIT
mMHTabEnt MH_ProcFork, PROC_FORK
mMHTabEnt MH_ProcGetSetID, PROC_GETSETID
mMHTabEnt MH_ProcSetPGID, PROC_SETPGID
mMHTabEnt MH_ProcUmask, PROC_UMASK
mMHTabEnt MH_ProcGuardian, PROC_GUARDIAN
mMHTabEnt MH_ProcSession, PROC_SESSION
mMHTabEnt MH_ProcDaemon, PROC_DAEMON
mMHTabEnt MH_ProcEvent, PROC_EVENT
mMHTabEnt MH_ProcResource, PROC_RESOURCE
mMHTabEnt 0


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
		locals	parent
		prologue

		mpush	ebx,ecx,edx,edi
		mov	[%$parent],esi
		mov	edx,ebx

		; Get a process descriptor
		mov	ebx,?ProcessPool
		call	PoolAllocChunk
		jc	near .Exit

		; Zero a part of it, and copy coid bitmap if necessary
		xor	eax,eax
		xor	ecx,ecx
		mov	cl,tProcDesc.MaxConn
		mov	edi,esi
		cld
		rep	stosb
		mov	edi,esi
		mov	esi,[%$parent]
		or	esi,esi
		jz	near .NoParent
		push	edi
		add	esi,tProcDesc.CoIDbmap
		add	edi,tProcDesc.CoIDbmap
		mov	ecx,(tProcDesc_size - tProcDesc.MaxConn) / 4
		rep	movsd
		pop	esi

		; Fill in the fields
		mov	[esi+tProcDesc.Module],edx
		mov	edi,[%$parent]
		mov	[esi+tProcDesc.Parent],edi

		mov	ecx,[edi+tProcDesc.MaxChan]
		mov	[esi+tProcDesc.MaxChan],ecx
		push	edi
		lea	edi,[esi+tProcDesc.ChanIDbmap]
		mov	[esi+tProcDesc.ChanIDbmapAddr],edi
		shr	ecx,1
		xor	eax,eax
		dec	eax
		rep	stosd
		pop	edi
		inc	eax
		btr	[esi+tProcDesc.ChanIDbmap],eax

		Mov32	esi+tProcDesc.MaxConn,edi+tProcDesc.MaxConn
		lea	eax,[esi+tProcDesc.CoIDbmap]
		mov	[esi+tProcDesc.CoIDbmapAddr],eax

		call	PoolChunkNumber
		mov	[esi+tProcDesc.PID],eax
		xor	eax,eax
		mov	[esi+tProcDesc.Lock+tSemaphore.WaitQ],eax
		inc	eax
		mov	[esi+tProcDesc.Lock+tSemaphore.Count],eax

		; Allocate a new page directory
		call	NewPageDir
		jc	.Exit
		mov	[esi+tProcDesc.PageDir],edx

		; Create a LDT
		call	TM_CreateLDT
		jc	.Exit

		; Put the process descriptor into a linked list
		mEnqueue dword [?ProcListPtr], Next, Prev, esi, tProcDesc, edx

.Exit:		mpop	edi,edx,ecx,ebx
		epilogue
		ret

.NoParent:	mov	ax,ERR_PM_NoParent
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; TM_DelProcess - delete all process resources.
		; Input: ESI=PCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_DelProcess
		push	edx

		; Remove process descriptor from the list
		mDequeue dword [?ProcListPtr], Next, Prev, esi, tProcDesc, edx

		pop	edx
		ret
endp		;---------------------------------------------------------------


		; TM_ProcAttachThread - add thread to process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_ProcAttachThread
		push	edi
		mov	esi,[ebx+tTCB.PCB]
		or	esi,esi
		jz	.Error
		mEnqueue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB, edi
		clc

.Exit:		pop	edi
		ret

.Error:		mov	ax,ERR_MT_UnableAttachThr
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; TM_ProcDetachThread - remove thread from process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_ProcDetachThread
		mpush	esi,edi
		mov	esi,[ebx+tTCB.PCB]
		or	esi,esi
		jz	.Error
		mDequeue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB, edi
		clc
.Exit:		mpop	edi,esi
		ret
		
.Error:		mov	ax,ERR_MT_UnableDetachThr
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; TM_CreateLDT - create a LDT for the process.
		; Input: ESI=process descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
		; Note: modifies EBX,ECX,EDX and EDI
proc TM_CreateLDT
		; Allocate one page for LDT and zero it
		mov	dl,1
		call	PageAlloc
		jc	.Exit
		and	eax,PGENTRY_ADDRMASK
		mov	[esi+tProcDesc.LDTaddr],eax
		mov	ebx,eax
		mov	edi,eax
		mov	ecx,PAGESIZE / 4
		xor	eax,eax
		cld
		rep	stosd

		; Register this LDT in GDT
		mov	eax,[esi+tProcDesc.PID]
		call	RegisterLDT
		jc	.Exit
		mov	[esi+tProcDesc.LDTdesc],dx

.Exit:		ret
endp		;---------------------------------------------------------------


		; TM_FreeLDT - free process's LDT.
		; Input: ESI=process descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc TM_FreeLDT
		ret
endp		;---------------------------------------------------------------



; --- Message handlers ---------------------------------------------------------

		; PROC_SPAWN handler
proc MH_ProcSpawn
		ret
endp		;---------------------------------------------------------------


		; PROC_WAIT handler
proc MH_ProcWait
		ret
endp		;---------------------------------------------------------------


		; PROC_FORK handler
proc MH_ProcFork
		ret
endp		;---------------------------------------------------------------


		; PROC_SETSETID handler
proc MH_ProcGetSetID
		ret
endp		;---------------------------------------------------------------


		; PROC_SETPGID handler
proc MH_ProcSetPGID
		ret
endp		;---------------------------------------------------------------


		; PROC_UMASK handler
proc MH_ProcUmask
		ret
endp		;---------------------------------------------------------------


		; PROC_GUARDIAN handler
proc MH_ProcGuardian
		ret
endp		;---------------------------------------------------------------


		; PROC_SESSION handler
proc MH_ProcSession
		ret
endp		;---------------------------------------------------------------


		; PROC_DAEMON handler
proc MH_ProcDaemon
		ret
endp		;---------------------------------------------------------------


		; PROC_EVENT handler
proc MH_ProcEvent
		ret
endp		;---------------------------------------------------------------


		; PROC_RESOURCE handler
proc MH_ProcResource
		ret
endp		;---------------------------------------------------------------
