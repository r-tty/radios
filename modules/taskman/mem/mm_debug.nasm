;-------------------------------------------------------------------------------
;  mm_debug.nasm - memory manager debugging stuff.
;-------------------------------------------------------------------------------

%ifdef MMDEBUG

module kernel.mm_debug

%include "sys.ah"
%include "errors.ah"
%include "memman.ah"
%include "cpu/paging.ah"
%include "process.ah"
%include "bootdefs.ah"

global MM_DebugAllocMem, MM_DebugFreeMem, MM_PrintStat, MM_DebugFreeMCBs

library kernel
extern ?UserAreaStart

library kernel.mt
extern ?ProcListPtr
extern MT_PID2PCB

library kernel.mm
extern MM_AllocBlock, MM_FreeBlock, MM_FreeMCBarea

library kernel.paging
extern PG_GetNumFreePages, PG_NewDir
extern PG_AllocAreaTables

section .data

MsgMemStatHdr	DB 10,"MCB",9,9,"Addr",9,9,"Len",9,9,"Next MCB",9,"Prev MCB",10,0
MsgFreeMem	DB 10,"Physical memory free (KB): ",0


section .text

		; MM_DebugAllocMem - allocate memory block.
		; Input: ESI=command line address,
		;	 ECX=command length.
		; Note: requires two arguments - PID and number of bytes
		;	to allocate (decimal). If PID is missing, kernel
		;	is considered
proc MM_DebugAllocMem
		mpush	ecx,esi

		add	esi,ecx
		inc	esi
		
		xor	edx,edx
		mov	al,' '
		mov	edi,esi
		call	StrScan
		or	edi,edi
		jz	short .GetSize
		mov	byte [edi],0
		inc	edi
		
		call	ValDwordDec			
		jc	short .Exit
		mov	edx,eax				; EDX=PID
		mov	esi,edi

.GetSize:	call	ValDwordDec			
		jc	short .Exit
		mov	ecx,eax				; ECX=block size
		
		mov	eax,edx
		call	MT_PID2PCB
		jc	short .Exit
		mov	dx,1
		call	MM_AllocBlock
		jnc	short .PrintAddr
		call	RKDT_ErrorHandler
		jmp	short .Exit

.PrintAddr:	mServPrintChar 10
		mServPrint32h ebx

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_DebugFreeMem - free memory block.
		; Note: requires two arguments - PID (decimal) and address of
		;	the block (hex). If PID is missing, kernel is considered
proc MM_DebugFreeMem
		mpush	ecx,esi

		add	esi,ecx
		inc	esi
		
		xor	edx,edx
		mov	al,' '
		mov	edi,esi
		call	StrScan
		or	edi,edi
		jz	short .GetBlockAddr
		mov	byte [edi],0
		inc	edi
		
		call	ValDwordDec			
		jc	short .Exit
		mov	edx,eax				; EDX=PID
		mov	esi,edi

.GetBlockAddr:	call	ValDwordHex		
		jc	short .Exit
		mov	ebx,eax				; EBX=block address
		
		mov	eax,edx
		call	MT_PID2PCB			; ESI=PCB address
		jc	short .Exit

		xor	edi,edi
		call	MM_FreeBlock
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_PrintStat - print process memory state.
		; Input: ESI = command line address,
		;	 ECX = command length.
proc MM_PrintStat
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	near .Exit

		call	MT_PID2PCB
		jc	near .Exit
		mov	ebx,[esi+tProcDesc.FirstMCB]

		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		or	ebx,ebx
		jz	near .PrintTotal
		mServPrintStr MsgMemStatHdr

.Loop:		or	ebx,ebx
		jz	near .PrintTotal
		mServPrint32h ebx
		mServPrintChar 9
		mServPrint32h [ebx+tMCB.Addr]
		mServPrintChar 9
		mServPrint32h [ebx+tMCB.Len]
		mServPrintChar 9
		mServPrint32h [ebx+tMCB.Next]
		mServPrintChar 9
		mServPrint32h [ebx+tMCB.Prev]
		mov	ebx,[ebx+tMCB.Next]
		mServPrintChar 10
		jmp	.Loop

.PrintTotal:	mServPrintStr MsgFreeMem
		call	PG_GetNumFreePages
		mov	eax,ecx
		shl	eax,2
		mServPrint32h
		mServPrintChar 10

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


		; MM_DebugAllocDir - allocate a directory and user page tables.
proc MM_DebugAllocDir
		call	PG_NewDir
		jc	short .Exit
		mov	ebx,[?UserAreaStart]
		call	PG_AllocAreaTables
.Exit:		ret
endp		;---------------------------------------------------------------

%endif
