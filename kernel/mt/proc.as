;*******************************************************************************
;  proc.as - process management.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

; --- Exports ---

global ?ProcListPtr, ?MaxNumOfProc
global MT_InitProc, MT_InitKernelProc, MT_PID2PCB


; --- Imports ---

library kernel
extern KernelEventHandler:near

library kernel.paging
extern ?KernPagePool, ?KernPageDir

library kernel.misc
extern MemSet:near


; --- Variables ---

section .bss

?ProcListPtr	RESD	1			; Address of process list
?MaxNumOfProc	RESD	1			; Max. number of processes
?ProcessPool	RESB	tMasterPool_size	; Process master pool
?PIDsBitmap	RESD	1			; Address of PIDs bitmap


; --- Code ---

section .text

		; MT_InitPCBpool - initialize the process descriptor pool.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_InitPCBpool
		mpush	ebx,ecx,edx
		mov	[?MaxNumOfProc],eax
		mov	ebx,?ProcessPool
		mov	ecx,tProcDesc_size
		xor	edx,edx
		call	K_PoolInit
		jc	short .Exit
		
		; Allocate memory for PIDs bitmap
		mov	ecx,[?MaxNumOfProc]
		shr	ecx,3				; 8 bits per byte
		xor	dl,dl
		call	PG_AllocContBlock
		jc	short .Exit
		mov	[?PIDsBitmap],ebx
		
		mov	al,0FFh				; All PIDs are free
		call	MemSet
		
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_NewProcess - create a new process.
		; Input: ESI=address of parent PCB.
		; Output: CF=0 - OK, ESI=address of PCB;
		;	  CF=1 - error, AX=error code.
proc MT_NewProcess

		mpush	ebx,ecx,edx
		mov	edx,esi				; Save parent PCB
		mov	ebx,?ProcessPool
		call	K_PoolAllocChunk
		jc	short .Exit

		mov	ecx,tProcDesc_size		; Zero PCB body
		mov	ebx,esi
		call	BZero

		call	MT_GetNewPID
		jc	short .Exit
		mov	[esi+tProcDesc.PID],eax

		mov	[esi+tProcDesc.Parent],edx
		mEnqueue dword [?ProcListPtr], Next, Prev, esi, tProcDesc

.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_DelProcess - delete process.
		; Input: ESI=PCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_DelProcess
		ret
endp		;---------------------------------------------------------------


		; MT_ProcAttachThread - add thread to process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_ProcAttachThread
		mov	esi,[ebx+tTCB.PCB]
		or	esi,esi
		jz	short .Error
		mEnqueue dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB
		clc
		ret

.Error:		mov	ax,ERR_MT_UnableAttachThread
		stc
		ret
endp		;---------------------------------------------------------------


		; MT_ProcDetachThread - remove thread from process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_ProcDetachThread
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


		; MT_InitKernelProc - initialize process 0 (kernel).
		; Input: none.
		; Output: none.
proc MT_InitKernelProc
		xor	esi,esi				; No parent process
		call	MT_NewProcess
		jc	short .Exit
		mov	eax,[?KernPageDir]
		mov	[esi+tProcDesc.PageDir],eax
		
.Exit:		ret
endp		;---------------------------------------------------------------


		; MT_GetNewPID - get a new PID for process.
		; Input: none.
		; Output: EAX=PID.
		; Note: [?MaxNumOfProc] must be >= 32, otherwise this
		;	procedure won't work!
proc MT_GetNewPID
		mpush	ecx,esi
		mov	ecx,[?MaxNumOfProc]
		shr	ecx,byte 5			; # of dwords
		mov	esi,[?PIDsBitmap]
		sub	esi,byte 4
		
.Loop:		add	esi,byte 4
		bsf	eax,[esi]			; Look for free PID
		loopz	.Loop
		jz	short .Err
		btr	[esi],eax
		sub	esi,[?PIDsBitmap]
		shl	esi,3
		add	eax,esi
		clc
		
.Exit:		mpop	esi,ecx
		ret
		
.Err:		mov	ax,ERR_MT_NoPIDs
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MT_ReleasePID - release a PID.
		; Input: EAX=PID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_ReleasePID
		cmp	eax,[?MaxNumOfProc]
		jae	short .Err
		push	esi
		mov	esi,[?PIDsBitmap]
		bts	[esi],eax
		pop	esi
		clc
		ret
		
.Err:		mov	ax,ERR_MT_BadPID
		stc
		ret
endp		;--------------------------------------------------------------


		; MT_PID2PCB - get an address of PCB by a PID.
		; Input: EAX=PID.
		; Output: CF=0 - OK, ESI=address of PCB;
		;	  CF=1 - error, AX=error code.
proc MT_PID2PCB
		mov	esi,[?ProcListPtr]
.Loop:		cmp	eax,[esi+tProcDesc.PID]
		je	short .Exit
		mov	esi,[esi+tProcDesc.Next]
		cmp	esi,[?ProcListPtr]
		jne	.Loop
		
		mov	ax,ERR_MT_BadPID
		stc
.Exit:		ret
endp		;--------------------------------------------------------------
