;-------------------------------------------------------------------------------
;  process.as - process management routines.
;-------------------------------------------------------------------------------

%include "commonfs.ah"

; --- Exports ---

global K_CurrPID
global MT_CreateKernelProcess, K_GetProcDescAddr
global MT_Exec, MT_Exit


; --- Imports ---

library kernel.fs
extern CFS_Path2Index:near

library kernel
extern KernelEventHandler:near


; --- Variables ---

section .bss

MT_ProcTblAddr	RESD	1			; Processes table address
MT_MaxNumOfProc	RESD	1			; Max. number of processes
K_CurrPID	RESB	1			; Process being executed


; --- Procedures ---

section .text

		; MT_InitPCBpool - initialize the process descriptor pool.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_InitPCBpool
		mpush	ebx,ecx,edx
		mov	[MT_MaxNumOfProc],eax
		mov	ecx,tProcDesc_size
		mul	ecx
		mov	ecx,eax
		call	KH_Alloc
		jc	.Exit
		mov	[MT_ProcTblAddr],ebx
		call	BZero

.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MT_AllocPD - allocate the process descriptor (PD).
		; Input: none.
		; Output: CF=0 - OK, EBX=address of PD;
		;	  CF=1 - error, AX=error code.
proc MT_AllocPD
		mov	ebx,[MT_ProcTblAddr]
		xor	ecx,ecx
.Loop:		cmp	dword [ebx+tProcDesc],-1
		je	.FoundSlot
		inc	ecx
		cmp	ecx,[MT_MaxNumOfProc]
		je	.Err
		add	ebx,byte tProcDesc_size
		jmp	short .Loop

.FoundSlot:	xor	eax,eax
		ret

.Err:		mov	ax,ERR_MT_NoFreePD
		stc
		ret
endp		;---------------------------------------------------------------


		; MT_NewProcess - create a new process.
		; Input: EAX=parent PID.
		; Output: CF=0 - OK, EBX=pointer to new process descriptor;
		;	  CF=1 - error, AX=error code.
proc MT_NewProcess
%define	.pid	ebp-4
		prologue 4

		epilogue
		ret
endp		;---------------------------------------------------------------


		; MT_CreateKernelProcess - initialize process 0 (kernel).
		; Input: EBX=pointer to process init structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_CreateKernelProcess
		mpush	ecx,edx,esi,edi

		mov	esi,ebx				; ESI=init structure addr.
		mov	edi,[MT_ProcTblAddr]		; EDI=process descriptor addr.
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
		ret
endp		;---------------------------------------------------------------


		; MT_ProcDetachThread - remove thread from process.
		; Input: EBX=address of TCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_ProcDetachThread
		ret
endp		;---------------------------------------------------------------


; --- Additional routines ---

		; K_GetProcDescAddr - get process descriptor address.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc K_GetProcDescAddr
		cmp	eax,[MT_MaxNumOfProc]
		jae	short .Err
		mov	ebx,eax
		shl	ebx,PROCDESCSHIFT
		add	ebx,[MT_ProcTblAddr]
		clc
		ret
.Err:		mov	ax,ERR_MT_BadPID
		stc
		ret
endp		;---------------------------------------------------------------
