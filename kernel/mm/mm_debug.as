;-------------------------------------------------------------------------------
;  mm_debug.as - memory manager debugging stuff.
;-------------------------------------------------------------------------------

%include "kconio.ah"
%include "asciictl.ah"

global MM_DebugAllocMem, MM_DebugFreeMem, MM_PrintStat, MM_DebugFreeMCBs

library kernel.kconio
extern PrintChar:near, PrintString:near
extern PrintDwordHex:near, PrintDwordDec: near
extern ValDwordHex:near, ValDwordDec:near

library kernel.paging
extern PG_GetNumFreePages

library rkdt
extern RKDT_ErrorHandler:near


section .data

MsgMemStatHdr	DB 10,10,"MCB",9,9,"Addr",9,9,"Len",9,9,"Next MCB",9,"Prev MCB",10,0
MsgFreeMem	DB 10,"Physical memory free (KB): ",0

		; MM_DebugAllocMem - allocate memory block.
proc MM_DebugAllocMem
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	ValDwordHex
		jc	short .Exit
		mov	ecx,eax
		xor	esi,esi				; Kernel process
		xor	dl,dl
		call	MM_AllocBlock
		jnc	short .PrintAddr
		call	RKDT_ErrorHandler
		jmp	short .Exit

.PrintAddr:	mPrintChar NL
		mov	eax,ebx
		call	PrintDwordHex

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_DebugFreeMem - free memory block.
proc MM_DebugFreeMem
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	ValDwordHex
		jc	short .Exit
		mov	ebx,eax
		xor	eax,eax
		xor	dl,dl
		xor	edi,edi
		call	MM_FreeBlock
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_PrintStat - print process memory state.
proc MM_PrintStat
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	near .Exit

		mIsKernProc ebx
		mov	edi,ebx
		mov	ebx,[ebx+tProcDesc.FirstMCB]

		mov	eax,cr3
		push	eax
		mov	eax,[edi+tProcDesc.PageDir]
		mov	cr3,eax

		or	ebx,ebx
		jz	near .PrintTotal
		mPrintString MsgMemStatHdr

.Loop:		or	ebx,ebx
		jz	near .PrintTotal
		mov	eax,ebx
		call	PrintDwordHex
		mPrintChar HTAB
		mov	eax,[ebx+tMCB.Addr]
		call	PrintDwordHex
		mPrintChar HTAB
		mov	eax,[ebx+tMCB.Len]
		call	PrintDwordHex
		mPrintChar HTAB
		mov	eax,[ebx+tMCB.Next]
		call	PrintDwordHex
		mPrintChar HTAB
		mov	eax,[ebx+tMCB.Prev]
		call	PrintDwordHex
		mov	ebx,[ebx+tMCB.Next]
		mPrintChar NL
		jmp	.Loop

.PrintTotal:	mPrintString MsgFreeMem
		call	PG_GetNumFreePages
		mov	eax,ecx
		shl	eax,2
		call	PrintDwordDec
		mPrintChar NL

		pop	eax
		mov	cr3,eax

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_DebugFreeMCBs - free process MCBs.
proc MM_DebugFreeMCBs
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	short .Exit
		or	eax,eax
		jz	short .Exit
		mov	edx,eax

		mIsKernProc ebx
		mov	esi,ebx

		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		mov	eax,edx
		call	MM_FreeMCBarea
		jnc	short .RestorePD
		call	RKDT_ErrorHandler

.RestorePD:	pop	eax
		mov	cr3,eax

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------
