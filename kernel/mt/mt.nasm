;*******************************************************************************
; mt.nasm - thread and scheduling routines.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module kernel.mt

%include "sys.ah"
%include "rmk.ah"
%include "pool.ah"
%include "thread.ah"
%include "errors.ah"
%include "cpu/tss.ah"
%include "cpu/paging.ah"
%include "cpu/stkframe.ah"
%include "cpu/setjmp.ah"
%include "tm/process.ah"

%ifdef DEBUG
%include "serventry.ah"
%endif

publicproc MT_Init

publicproc sys_ThreadCancel
publicproc sys_ThreadDetach, sys_ThreadJoin
publicproc sys_ThreadCtl
publicproc sys_SchedYield

externproc K_DescriptorAddress, K_SetDescriptorBase, K_SetGateOffset
externproc BZero
externdata KernTSS


section .bss

?ProcListLock	RESB	tSemaphore_size


section .text


		; MT_Init - initialize multitasking memory structures.
		; Input: EAX=maximum number of threads.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Init
		call	MT_InitTCBpool
		jc	.Ret

		; Initialize kernel TSS
		mov	edi,KernTSS
		mov	eax,cr3
		mov	[edi+tTSS.CR3],eax
		mov	dx,KTSS
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		ltr	dx

		; Initialize exit gate
		mov	dx,EXITGATE
		call	K_DescriptorAddress
		mov	eax,MT_ExitGateHandler
		call	K_SetGateOffset

.Ret:		ret
endp		;---------------------------------------------------------------


		; MT_ExitGateHandler - terminate current thread.
proc MT_ExitGateHandler
		int3
		hlt
		jmp	$
endp		;---------------------------------------------------------------


; --- System call routines -----------------------------------------------------


		; int ThreadDetach(int tid);
proc sys_ThreadDetach
		arg	tid
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ThreadJoin(int tid, void **status);
proc sys_ThreadJoin
		arg	tid, status
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ThreadCancel(int tid, void (*canstub)(void));
proc sys_ThreadCancel
		arg	tid, canstub
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ThreadCtl(int cmd, void *data);
proc sys_ThreadCtl
		arg	cmd, data
		prologue

		mov	eax,[%$cmd]
		cmp	eax,TCTL_IO
		jne	.Inval

		mCurrThread ebx
		mov	esi,[ebx+tTCB.PCB]
		mIsRoot esi
		jne	.Perm

		or	dword [ebx+tTCB.Flags],TF_IOPRIV
		or	dword [edx+tStackFrame.EFLAGS],FLAG_IOPL
		
.Exit:		epilogue
		ret

.Perm:		mov	eax,-EPERM
		jmp	.Exit
.Inval:		mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int SchedYield(void);
proc sys_SchedYield
		mCurrThread ebx
		MISSINGSYSCALL
		ret
endp		;---------------------------------------------------------------


%include "thread.nasm"
%include "sched.nasm"
