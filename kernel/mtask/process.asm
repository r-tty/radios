;-------------------------------------------------------------------------------
;  process.asm - process management routines.
;-------------------------------------------------------------------------------

include "process.ah"
include "commonfs.ah"

; --- Variables ---
segment KVARS
K_CurrPID		DD	0			; Process being executed
ends


; --- Procedures ---

		; MT_CreateKernelProcess - initialize process 0 (kernel).
		; Input: EBX=pointer to process init structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_CreateKernelProcess near
		push	ecx edx esi edi

		mov	esi,ebx				; ESI=init structure addr.
		mov	edi,[MT_ProcTblAddr]		; EDI=process descriptor addr.
		xor	eax,eax
		mov	al,[esi+tProcInit.MaxFHandles]
		mov	dl,al
		mov	ecx,size tCFS_FHandle
		mul	ecx
		mov	ecx,eax				; Allocate memory
		call	KH_Alloc			; for kernel file handles
		jc	short @@Exit
		call	KH_FillWithFF			; Fill it with -1
		mov	[edi+tProcDesc.FHandlesAddr],ebx
		mov	[edi+tProcDesc.NumFHandles],dl

		movzx	ecx,[esi+tProcInit.EnvSize]	; Allocate memory
		call	KH_Alloc			; for environment
		jc	short @@Exit
		call	KH_FillZero			; Clear it
		mov	[edi+tProcDesc.EnvAddr],ebx
		mov	[edi+tProcDesc.EnvSize],cx

		mov	[edi+tProcDesc.EventHandler],offset KernelEventHandler
		xor	eax,eax
		mov	[edi+tProcDesc.Seg],ax
		mov	[edi+tProcDesc.Module],ax

@@Exit:		pop	edi esi edx ecx
		ret
endp		;---------------------------------------------------------------


		; MT_Exec - execute a program.
		; Input: EAX=parent PID,
		;	 ESI=pointer to program name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Exec near
int 3
		call	CFS_Path2Index
		jc	short @@Exit

@@Exit:		ret
endp		;---------------------------------------------------------------



; --- Additional routines ---

		; K_GetProcDescAddr - get process descriptor address.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc K_GetProcDescAddr near
		cmp	eax,[MT_MaxProcQuan]
		jae	short @@Err
		mov	ebx,eax
		shl	ebx,PROCDESCSHIFT
		add	ebx,[MT_ProcTblAddr]
		clc
		ret
@@Err:		mov	ax,ERR_MT_BadPID
		stc
		ret
endp		;---------------------------------------------------------------
