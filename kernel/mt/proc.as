;*******************************************************************************
;  proc.as - process management.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

; --- Exports ---

global ?ProcListPtr, ?MaxNumOfProc
global MT_InitProc, MT_InitKernelProc


; --- Imports ---

library kernel
extern KernelEventHandler

library kernel.paging
extern ?KernPagePool


; --- Variables ---

section .bss

?ProcListPtr	RESD	1			; Address of process list
?MaxNumOfProc	RESD	1			; Max. number of processes
?ProcessPool	RESB	tMasterPool_size	; Process master pool

; --- Code ---

section .text

		; MT_InitPCBpool - initialize the process descriptor pool.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_InitPCBpool
		mpush	ebx,ecx
		mov	[?MaxNumOfProc],eax
		mov	ebx,?ProcessPool
		mov	ecx,tProcDesc_size
		xor	dl,dl
		call	K_PoolInit
		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_NewProcess - create a new process.
		; Input: ESI=address of parent PCB.
		; Output: CF=0 - OK, ESI=pointer to created PCB;
		;	  CF=1 - error, AX=error code.
proc MT_NewProcess
		mpush	ebx,ecx,edx
		mov	edx,esi				; Save parent PCB
		mov	ebx,?ProcessPool
		call	K_PoolAllocChunk
		jc	short .Exit

		mov	ecx,tProcDesc_size
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
		jz	.Error
		mEnqueue  dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB
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
		jz	.Error
		mDequeue  dword [esi+tProcDesc.ThreadList], ProcNext, ProcPrev, ebx, tTCB
		clc
		ret
		
.Error:		mov	ax,ERR_MT_UnableDetachThread
		stc
		ret
endp		;---------------------------------------------------------------


		; MT_InitKernelProc - initialize process 0 (kernel).
		; Input: ESI=address of process init structure.
		; Output: none.
proc MT_InitKernelProc
int3
		mov	esi,ebx				; ESI=init structure addr.
		mov	edi,[?ProcListPtr]		; EDI=process descriptor addr.
		xor	eax,eax
		mov	al,[esi+tProcInit.MaxFHandles]
		mov	dl,al

;		movzx	ecx,word [esi+tProcInit.EnvSize] 
;		xor	dl,dl				; Allocate memory
;		call	PG_AllocContBlock		; for environment
;		jc	short .Exit
;		call	BZero				; Clear it
;		mov	[edi+tProcDesc.EnvAddr],ebx
;		mov	[edi+tProcDesc.EnvSize],cx

		mov	dword [edi+tProcDesc.EventHandler],KernelEventHandler
		xor	eax,eax
		mov	[edi+tProcDesc.Flags],al
		mov	[edi+tProcDesc.Module],ax
.Exit:		ret
endp		;---------------------------------------------------------------


		; MT_GetNewPID - get a new PID for process.
		; Input: ESI=PCB address.
		; Output: EAX=new PID.
proc MT_GetNewPID
		mov	eax,esi
		sub	eax,[?KernPagePool]
		shr	eax,PROCDESCSHIFT
		ret
endp		;---------------------------------------------------------------

