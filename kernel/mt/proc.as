;*******************************************************************************
;  proc.as - process management.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

;KLUGE
%include "commonfs.ah"

global ?ProcListPtr, ?MaxNumOfProc
global MT_InitProc, MT_InitKernelProc

extern KernelEventHandler

; --- Variables ---

section .bss

?ProcListPtr	RESD	1			; Address of process list
?MaxNumOfProc	RESD	1			; Max. number of processes


; --- Code ---

section .text

		; MT_InitProc - initialize process subsystem.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: ?MaxNumOfProc must be set.
proc MT_InitProc
		mpush	ebx,ecx,edx
		mov	[?MaxNumOfProc],eax
		mov	ecx,tProcDesc_size
		mul	ecx
		mov	ecx,eax
		call	KH_Alloc
		jc	.Exit
		mov	[?ProcListPtr],ebx
		call	BZero

.Exit:		mpop	edx,ecx,ebx
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
.Exit:		ret
endp		;---------------------------------------------------------------

