;*******************************************************************************
;  mt.nasm - RadiOS multitasking.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

module kernel.mt

%include "sys.ah"
%include "errors.ah"
%include "x86/tss.ah"
%include "x86/paging.ah"
%include "x86/stkframe.ah"
%include "x86/setjmp.ah"
%include "sema.ah"
%include "pool.ah"
%include "process.ah"

%ifdef DEBUG
%include "boot/bootdefs.ah"
%endif

; --- Exports ---

global MT_Init


; --- Imports ---

library kernel
extern KernTSS, DrvTSS

library kernel.misc
extern BZero


; --- Variables ---

section .bss


; --- Procedures ---

%include "proc.nasm"				; Process management
%include "thread.nasm"				; Thread management
%include "sched.nasm"				; Scheduler

section .text

		; MT_InitKTSS - inialize kernel's TSS.
		; Input: none.
		; Output: none.
proc MT_InitKTSS
		mov	ebx,KernTSS
		mov	eax,esp
		mov	[ebx+tTSS.ESP0],eax
		mov	[ebx+tTSS.ESP],eax
		mov	dword [ebx+tTSS.EIP],.TSSinitOK
		mov	ax,KTSS
		ltr	ax
.TSSinitOK:
		ret
endp		;---------------------------------------------------------------


		; MT_InitDTSS - initialize drivers' TSS.
		; Input: none.
		; Output: none.
proc MT_InitDTSS
		mov	ebx,DrvTSS
		mov	eax,esp
		mov	[ebx+tTSS.ESP0],eax
		ret
endp		;---------------------------------------------------------------


		; MT_Init - initialize multitasking memory structures.
		; Input: EAX=maximum number of processes,
		;	 ECX=maximum number of threads.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Init
		call	MT_InitPCBpool
		jc	short .Done
		mov	eax,ecx
		call	MT_InitTCBpool
		jc	.Done
		call	MT_InitKTSS		; Initialize PL0 TSS
		call	MT_InitDTSS		; Initialize PL1 TSS
		call	MT_InitTimeout		; Initialize sched timeout queue
.Done		ret
endp		;---------------------------------------------------------------
