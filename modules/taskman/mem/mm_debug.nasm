;-------------------------------------------------------------------------------
; mm_debug.nasm - memory manager debugging stuff.
;-------------------------------------------------------------------------------

%ifdef MMDEBUG

module tm.memman.debug

%include "sys.ah"
%include "errors.ah"
%include "serventry.ah"
%include "tm/memman.ah"
%include "tm/process.ah"
%include "cpu/paging.ah"

publicproc MM_DebugAllocMem, MM_DebugFreeMem, MM_PrintStat, MM_DebugFreeMCBs

library tm.proc
externdata ?ProcListPtr
extern MT_PID2PCB

library tm.mm
externproc MM_AllocBlock, MM_FreeBlock, MM_FreeMCBarea

library kernel.paging
importproc PG_GetNumFreePages, PG_NewDir

section .data

TxtMemStatHdr	DB 10,"MCB",9,9,"Addr",9,9,"Len",9,9,"Next MCB",9,"Prev MCB",10,0
TxtFreeMem	DB 10,"Physical memory free (KB): ",0


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
		jz	.GetSize
		mov	byte [edi],0
		inc	edi
		
		call	ValDwordDec			
		jc	.Exit
		mov	edx,eax				; EDX=PID
		mov	esi,edi

.GetSize:	call	ValDwordDec			
		jc	.Exit
		mov	ecx,eax				; ECX=block size
		
		mov	eax,edx
		call	MT_PID2PCB
		jc	.Exit
		mov	al,PG_WRITABLE
		call	MM_AllocBlock
		jc	.Exit

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
		jz	.GetBlockAddr
		mov	byte [edi],0
		inc	edi
		
		call	ValDwordDec			
		jc	.Exit
		mov	edx,eax				; EDX=PID
		mov	esi,edi

.GetBlockAddr:	call	ValDwordHex		
		jc	.Exit
		mov	ebx,eax				; EBX=block address
		
		mov	eax,edx
		call	MT_PID2PCB			; ESI=PCB address
		jc	.Exit

		xor	edi,edi
		call	MM_FreeBlock

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
		mov	ebx,[esi+tProcDesc.MCBlist]

		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		or	ebx,ebx
		jz	near .PrintTotal
		mServPrintStr TxtMemStatHdr

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

.PrintTotal:	mServPrintStr TxtFreeMem
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
		jc	.Exit
		or	eax,eax
		jz	.Exit
		mov	edx,eax

		mov	esi,ebx

		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		mov	eax,edx
		call	MM_FreeMCBarea
		jc	.Exit

.RestorePD:	pop	eax
		mov	cr3,eax

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------

%endif
