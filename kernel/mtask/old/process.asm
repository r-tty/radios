;*******************************************************************************
;  process.asm - RadiOS process and threads management module.
;  Base OS-32 version (c) 1995 David Lindauer.
;  RadiOS extended version by Yuri Zaporogets.
;*******************************************************************************

include "process.ah"

segment KVARS
MT_Disabled		DB	0		; 0=enable multitasking

MT_CurrStackBase	DD	0		; Stack base of current task

MT_CurrTaskBranch	DD	0
MT_CurrTaskSel		DW	0		; Selector of current task
ends


; --- Procedures ---

include "MTASK\procstat.asm"

		; K_InitMultitasking - initialize multitasking.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_InitMultitasking near
		ret
endp		;---------------------------------------------------------------

		; K_GetPrStructAddr - get address of process structure.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=structure address;
		;	  CF=1 - error, AX=error code.
proc K_GetPrStructAddr near
		cmp	eax,MaxNumProcesses
		jae	@@Error
		push	eax edx
		xor	edx,edx
		mov	ebx,size tProcess
		mul	ebx
		mov	ebx,offset ProcessTable
		add	ebx,eax
		pop	edx eax
		clc
		ret
@@Error:	mov	ax,ERR_MT_BadPID
		stc
		ret
endp		;---------------------------------------------------------------


		; K_NewProcess - create new process.
		; Input: EBX=pointer to process initialization structure.
		; Output: CF=0 - OK:
		;	   EAX=PID,
		;	   EBX=process structre address;
		;	  CF=1 - error, AX=error code.
proc K_NewProcess near
		ret
endp		;---------------------------------------------------------------


		; K_DeleteProcess - delete process.
		; Input: EAX=PID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_DeleteProcess near
		ret
endp		;---------------------------------------------------------------


		; K_ActivateThread - include thread to process and activate it.
		; Input: EAX=PID,
		;	 DX:EBX=address of thread initialization structure.
		; Output: CF=0 - OK, EDX=TID;
		;	  CF=1 - error, AX=error code.
proc K_ActivateThread near
		push	eax ebx ecx esi edi

		pop	edi esi ecx ebx eax
		ret
endp		;---------------------------------------------------------------


		; K_DisposeThread - exclude thread from process.
		; Input: EAX=PID,
		;	 EDX=TID.
		; Output: CF=0 - OK,
		;	  CF-1 - error, AX=error code.
proc K_DisposeThread near
		ret
endp		;---------------------------------------------------------------


		; K_SwitchTask - switch to next thread.
		; Input: none.
		; Output: none.
		; Note: called by timer interrupt handler.
proc K_SwitchTask near
		test	[MT_Disabled],-1	; See if allowed to multitask
		jnz	@@Exit			; No, get out
		push	eax			; Else get TSS of this task
		push	edi
		push	ebx
		str	ax			; Get the running task
		mov	bx,ax
		sti
		call	K_GetNextThread		; Get the next task
		cli
		cmp	ax,bx			; See if is same as last
		pop	ebx
		jz	@@Self			; Yes, can't switch to self
		mov	[MT_CurrTaskSel],ax
		push	edx
		mov	dx,ax
		call	K_DescriptorAddress	; And its TSS
		call	K_GetDescriptorBase
		pop	edx
		cli
		mov	eax,[edi+tTSS.StackBase]	; Load stackbase
		mov	[MT_CurrStackBase],eax		; for this task
		pop	edi				; Restore regs
		pop	eax
		jmp	[fword MT_CurrTaskBranch]	; Jump to new task
						; Which of course will resume
						; the old task here later.
		sti
@@Exit:		ret

@@Self:		pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_GetNextThread - find next available thread.
		; Input: none.
		; Output: AX=TSS selector of next thread.
proc K_GetNextThread near
		inc	[MT_Disabled]			; Disable MT
		push	edx
		mov	edx,eax

		call	K_DescriptorAddress
		call	K_GetDescriptorBase
		mov	dx,[edi+tTSS.Next]	; Get selector of next task

@@Loop:		call	K_DescriptorAddress
		call	K_GetDescriptorBase
		cmp	[edi+tTSS.State],SEM_NoWait	; See if waiting
		jz	@@OK				; No, switch
		mov	eax,[edi+tTSS.Resource]		; Get resource we wait on
		bt	[dword eax],0			; See if ready
		jc	short @@SetNoWait
		mov	dx,[edi+tTSS.Next]
		jmp	@@Loop

@@SetNoWait:	mov	[edi+tTSS.State],SEM_NoWait	; Not waiting anymore

@@OK:		mov	eax,edx
		pop	edx
		dec	[MT_Disabled]			; Enable MT
		ret
endp		;---------------------------------------------------------------


