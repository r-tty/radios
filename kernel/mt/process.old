;-------------------------------------------------------------------------------
;  process.as - process management routines.
;-------------------------------------------------------------------------------

%include "commonfs.ah"

; --- Exports ---

global ?ProcListPtr, ?MaxNumOfProc
global MT_CreateKernelProcess
global MT_Exec, MT_Exit


; --- Imports ---

library kernel.pool
extern K_PoolInit:near

library kernel.fs
extern CFS_Path2Index:near

library kernel
extern KernelEventHandler:near


; --- Variables ---

section .bss

?ProcListPtr	RESD	1			; Address of process list
?MaxNumOfProc	RESD	1			; Max. number of processes
?ProcessPool	RESB	tMasterPool_size	; Process master pool

; --- Procedures ---

section .text

		; MT_InitPCBpool - initialize the process descriptor pool.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_InitPCBpool
		mov	[?MaxNumOfProc],eax
		mov	ebx,?ProcessPool
		mov	ecx,tProcDesc_size
		call	K_PoolInit
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
		jc	.Exit

		mov	ecx,tProcDesc_size
		call	BZero
		
		call	MT_GetNewPID
		jc	.Exit
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


		; MT_CreateKernelProcess - initialize process 0 (kernel).
		; Input: EBX=pointer to process init structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_CreateKernelProcess
		mpush	ecx,edx,esi,edi

		mov	esi,ebx				; ESI=init structure addr.
		mov	edi,[?ProcListPtr]		; EDI=process descriptor addr.
		xor	eax,eax
		mov	al,[esi+tProcInit.MaxFHandles]
		mov	dl,al
		mov	ecx,tCFS_FHandle_size
		mul	ecx
		mov	ecx,eax				; Allocate memory
		call	KH_Alloc			; for kernel file handles
		jc	.Exit
		call	KH_FillWithFF			; Fill it with -1
		mov	[edi+tProcDesc.FHandlesAddr],ebx
		mov	[edi+tProcDesc.NumFHandles],dl

		movzx	ecx,word [esi+tProcInit.EnvSize] ; Allocate memory
		call	KH_Alloc			; for environment
		jc	.Exit
		call	BZero				; Clear it
		mov	[edi+tProcDesc.EnvAddr],ebx
		mov	[edi+tProcDesc.EnvSize],cx

		mov	dword [edi+tProcDesc.EventHandler],KernelEventHandler
		xor	eax,eax
		mov	[edi+tProcDesc.Flags],al
		mov	[edi+tProcDesc.Module],ax

.Exit:		mpop	edi,esi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; MT_Exec - execute a program.
		; Input: EAX=parent PID,
		;	 ESI=pointer to program name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Exec
int3
		call	CFS_Path2Index
		jc	.Exit

.Exit:		ret
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
		ret
endp		;---------------------------------------------------------------


;--- Additional ----------------------------------------------------------------

		; MT_GetNewPID - get a new PID for process.
		; Input: ESI=PCB address.
		; Output: EAX=new PID.
proc MT_GetNewPID
		mov	eax,esi
		sub	eax,StartOfExtMem
		shr	eax,PROCDESCSHIFT
		ret
endp		;---------------------------------------------------------------


		; MT_PID2PCB - get a PCB address by a PID.
		; Input: EAX=PID.
		; Output: CF=0 - OK, ESI=PCB address;
		;	  CF=1 - error, AX=error code.
proc MT_PID2PCB
		push	ebx
		; Walk on the PCB queue searching requested PID.
		mov	ebx,[?ProcListPtr]
.Loop:		cmp	[ebx+tProcDesc.PID],eax
		je	.Found
		mov	ebx,[ebx+tProcDesc.Next]
		cmp	ebx,[?ProcListPtr]		; End of list?
		jne	.Loop
		mov	ax,ERR_MT_BadPID		; Error: no such process
		stc
		jmp	short .Exit

.Found:		mov	esi,ebx
		xor	eax,eax				; Success

.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; MT_GetCurrPCB - get PCB address of thread being executed.
		; Input: none.
		; Output: ESI=PCB address,
		;	  EAX=PID.
proc MT_GetCurrPCB
		mov	eax,[?CurrThread]
		mov	esi,[eax+tTCB.PCB]
		mov	eax,[esi+tProcDesc.PID]
		ret
endp		;---------------------------------------------------------------

