;*******************************************************************************
; mt.nasm - thread and scheduling routines.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module kernel.mt

%include "sys.ah"
%include "errors.ah"
%include "cpu/tss.ah"
%include "cpu/paging.ah"
%include "cpu/stkframe.ah"
%include "cpu/setjmp.ah"
%include "pool.ah"

%ifdef DEBUG
%include "serventry.ah"
%endif

; --- Exports ---

publicproc MT_Init

exportproc sys_ThreadDestroy, sys_ThreadCancel
exportproc sys_ThreadDetach, sys_ThreadJoin
exportproc sys_ThreadCtl
exportproc sys_SchedYield

; --- Imports ---

externproc K_DescriptorAddress, K_SetDescriptorBase
externproc BZero
externdata KernTSS


; --- Procedures ---

section .text

		; MT_InitKTSS - inialize kernel's TSS.
		; Input: none.
		; Output: none.
proc MT_InitKTSS
		mov	edi,KernTSS
		mov	eax,cr3
		mov	[edi+tTSS.CR3],eax
		mov	dx,KTSS
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		ltr	dx
		ret
endp		;---------------------------------------------------------------


		; MT_Init - initialize multitasking memory structures.
		; Input: EAX=maximum number of threads.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Init
		call	MT_InitTCBpool
		jc	.Done
		call	MT_InitKTSS		; Initialize kernel TSS
		call	MT_InitTimeout		; Initialize sched timeout queue
.Done		ret
endp		;---------------------------------------------------------------


; --- System call routines -----------------------------------------------------


proc sys_ThreadDestroy
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadDetach
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadJoin
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadCancel
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadCtl
		ret
endp		;---------------------------------------------------------------


proc sys_SchedYield
		ret
endp		;---------------------------------------------------------------


%include "thread.nasm"
%include "sched.nasm"
