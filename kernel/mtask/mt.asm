;*******************************************************************************
;  mt.asm - RadiOS multitasking routines.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

include "mt.ah"

; --- Variables ---
segment KVARS
MT_ProcTblHnd	DW	?
MT_ProcTblAddr	DD	?			; Processes table address
MT_MaxProcQuan	DD	?			; Max. number of processes
ends


; --- Procedures ---

include "MTASK\process.asm"
include "MTASK\thread.asm"


		; MT_Init - initialize multitasking memory structures.
		; Input: EAX=maximum number of processes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Init near
		push	ebx ecx edx
		mov	[MT_MaxProcQuan],eax
		mov	ecx,size tProcDesc
		mul	ecx
		mov	ecx,eax
		call	KH_Alloc
		jc	short @@Exit
		mov	[MT_ProcTblHnd],ax
		mov	[MT_ProcTblAddr],ebx
		call	KH_FillZero

@@Exit:		pop	edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; MT_Done - release multitasking memory structures.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MT_Done near
		mov	ax,[MT_ProcTblHnd]
		call	KH_Free
		ret
endp		;---------------------------------------------------------------

