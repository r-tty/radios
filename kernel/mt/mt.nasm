;*******************************************************************************
;  mt.nasm - RadiOS multitasking.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

module kernel.mt

%include "sys.ah"
%include "errors.ah"
%include "cpu/tss.ah"
%include "cpu/paging.ah"
%include "cpu/stkframe.ah"
%include "cpu/setjmp.ah"
%include "sema.ah"
%include "pool.ah"

%ifdef DEBUG
%include "bootdefs.ah"
%endif

; --- Exports ---

global MT_Init


; --- Imports ---

library kernel
extern KernTSS, DrvTSS
extern K_DescriptorAddress, K_SetDescriptorBase

library kernel.misc
extern BZero


; --- Variables ---

section .bss


; --- Procedures ---

%include "thread.nasm"
%include "sched.nasm"

section .text

		; MT_InitKTSS - inialize kernel's TSS.
		; Input: none.
		; Output: none.
proc MT_InitKTSS
		mov	edi,KernTSS
		mov	eax,[?KernPageDir]
		mov	[edi+tTSS.CR3],eax
		mov	dx,KTSS
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		ltr	dx
		ret
endp		;---------------------------------------------------------------


		; MT_InitDTSS - initialize drivers' TSS.
		; Input: none.
		; Output: none.
proc MT_InitDTSS
		mov	edi,DrvTSS
		mov	dx,DTSS
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		ret
endp		;---------------------------------------------------------------


		; MT_Init - initialize multitasking memory structures.
		; Input: EAX=maximum number of threads.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Init
		call	MT_InitTCBpool
		jc	.Done
		call	MT_InitKTSS		; Initialize PL0 TSS
		call	MT_InitDTSS		; Initialize PL1 TSS
		call	MT_InitTimeout		; Initialize sched timeout queue
.Done		ret
endp		;---------------------------------------------------------------
