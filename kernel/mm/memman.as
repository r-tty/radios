;*******************************************************************************
;  memman.as - RadiOS memory management routines.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module kernel.mm

%include "sys.ah"
%include "errors.ah"
%include "memman.ah"
%include "i386/paging.ah"
%include "process.ah"


; --- Definitions ---
%define	MM_MCBAREABEG	100000h				; Begin of MCB area
%define	MM_MCBAREASIZE	10000h				; Size of MCB area


; --- Exports ---

global MM_Init, MM_FreeMCBarea
global MM_AllocBlock, MM_FreeBlock
global MM_AllocRegion, MM_FreeRegion


; --- Imports ---

library kernel
extern K_DescriptorAddress:near, K_GetDescriptorBase:near
extern HeapBegin, TotalMemPages

library kernel.kheap
extern KH_Top

library kernel.paging
extern PG_Prepare:near, PG_GetPTEaddr:near
extern PG_Alloc:near, PG_Dealloc:near

library kernel.mt
extern ?ProcListPtr


; --- Variables ---

section .bss

PagesPerProc	RESD	1				; Pages per process


; --- Procedures ---

%include "region.as"

section .text

		; MM_Init - initialize memory management.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_Init
		mpush	ebx,ecx,edx,edi
		mov	dx,USERCODE
		call	K_DescriptorAddress
		call	K_GetDescriptorBase
		mov	ebx,edi
		call	PG_Prepare

		; Initialize kernel MCB area
		call	MM_PrepareMCBarea
		mov	ebx,MM_MCBAREABEG
		mov	ecx,MM_MCBAREASIZE/PageSize
		xor	eax,eax

.Loop:		call	PG_GetPTEaddr
		jc	short .Exit
		or	dword [edi],PG_ALLOCATED
		add	ebx,PageSize
		loop	.Loop

		; Initialize kernel process region
		mov	esi,[?ProcListPtr]
		call	MM_GetMCB
		jc	short .Exit
		mov	word [ebx+tMCB.Signature],MCBSIG_SHARED
		mov	word [ebx+tMCB.Flags],MCBFL_LOCKED
		mov	byte [ebx+tMCB.Type],REGTYPE_KERNEL
		mov	word [ebx+tMCB.Count],1
		mov	eax,1000h
		mov	[ebx+tMCB.Addr],eax
		mov	ecx,[KH_Top]
		sub	ecx,eax
		mov	[ebx+tMCB.Len],ecx

		clc
.Exit:		mpop	edi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MM_AllocBlock - allocate memory block.
		; Input: ESI=PCB address,
		;	 ECX=block size,
		;	 DL=0 - load CR3 with process page directory,
		;	 DL=1 - don't load CR3;
		;	 DH=block attributes (PG_USERMODE or/and PG_WRITEABLE).
		; Output: CF=0 - OK:
		;		     EAX=address of MCB,
		;		     EBX=block physical address;
		;	  CF=1 - error, AX=error code.
proc MM_AllocBlock
%define	.mcbaddr	ebp-4
%define	.flags		ebp-8

		prologue 8
		mpush	ecx,edx,esi,edi

		mIsKernProc esi				; ESI=PCB address
		mov	[.flags],edx			; Keep attributes

		or	dl,dl
		jnz	short .CR3Loaded
		mov	eax,cr3
		push	eax
		mov	eax,[ebx+tProcDesc.PageDir]
		mov	cr3,eax
		jmp	short $+2

.CR3Loaded:	call	MM_GetMCB			; Get a MCB
		jc	short .Exit			; and keep its address
		mov	[.mcbaddr],ebx
		mov	edi,ebx

		mov	[ebx+tMCB.Len],ecx		; Keep block length
		add	ecx,PageSize-1			; Calculate number of
		and	ecx,~ADDR_OFSMASK		; pages to hold the data


		call	MM_FindRegion			; Search a region
		jc	short .FreeMCB			; If OK - EBX=linear
							; address of region
		mov	[edi+tMCB.Addr],ebx		; Fill MCB 'Addr' field
		shr	ecx,PAGESHIFT			; ECX=number of pages
							; to allocate
		mov	eax,ERR_MEM_BadBlockSize
		jecxz	.FreeMCB
.Loop:		mov	dl,1				; Allocate one page
		call	PG_Alloc			; of physical or virtual
		jc	short .FreePages		; memory
		mov	edx,eax				; Keep its physical addr
		mov	eax,[esi+tProcDesc.PID]
		call	PG_GetPTEaddr			; Store physical address
		jc	short .FreePages		; in PTE
		or	edx,PG_ALLOCATED
		or	dl,[.flags+1]
		mov	[edi],edx
		add	ebx,PageSize
		loop	.Loop

		mov	eax,[.mcbaddr]
		mov	ebx,[eax+tMCB.Addr]
		clc

.Exit:		mov	edx,eax
		lahf
		cmp	byte [.flags],0
		jne	short .Exit1
		pop	ecx				; Restore CR3
		mov	cr3,ecx
		jmp	short $+2

.Exit1:		sahf					; Restore error code
		mov	eax,edx
.Exit2:		mpop	edi,esi,edx,ecx
		epilogue
		ret

.FreeMCB:	push	eax				; Free MCB if error
		mov	ebx,[.mcbaddr]
		call	MM_FreeMCB
		pop	eax
		stc
		jmp	.Exit

.FreePages:	push	eax				; Keep error code
		mov	ebx,[.mcbaddr]
		mov	eax,ecx
		mov	ecx,[ebx+tMCB.Len]
		add	ecx,PageSize-1
		shr	ecx,PAGESHIFT
		sub	ecx,eax
		jecxz	.NoDeall
		mov	ebx,[ebx+tMCB.Addr]

.DeallLoop:	mov	eax,[esi+tProcDesc.PID]
		call	PG_GetPTEaddr
		and	dword [edi],~PG_ALLOCATED
		mov	eax,[edi]
		call	PG_Dealloc
		add	ebx,PageSize
		loop	.DeallLoop
.NoDeall:	pop	eax				; Restore error code
		jmp	.FreeMCB
endp		;---------------------------------------------------------------


		; MM_FreeBlock - free memory block.
		; Input: ESI=PCB address,
		;	 EBX=block address (if EDI=0),
		;	 DL=0 - load CR3 with process page directory,
		;	 DL=1 - don't load CR3;
		;	 EDI=0 - use block address in EBX,
		;	 EDI!=0 - EDI=MCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreeBlock
%define	.mcbaddr	ebp-4
%define	.loadcr3	ebp-8

		prologue 8
		mpush	ebx,edx,esi,edi
		
		mIsKernProc esi				; ESI=PCB address

		mov	[.loadcr3],dl
		xchg	edi,ebx

		or	dl,dl				; Load CR3?
		jnz	short .CR3Loaded
		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax
		jmp	short $+2

.CR3Loaded:	or	ebx,ebx				; Got MCB address?
		jz	short .GotMCBaddr
		mov	ebx,edi				; Find the MCB by addr
		call	MM_FindMCB
		jc	short .Exit

.GotMCBaddr:	test	word [ebx+tMCB.Flags],MCBFL_LOCKED	; Locked region?
		jnz	short .Err
		mov	[.mcbaddr],ebx
		mov	ecx,[ebx+tMCB.Len]
		add	ecx,PageSize-1
		shr	ecx,PAGESHIFT
		mov	ebx,edi				; EBX=block address

.Loop:		mov	eax,[esi+tProcDesc.PID]
		call	PG_GetPTEaddr
		jc	short .Exit
		and	dword [edi],~PG_ALLOCATED
		mov	eax,[edi]
		call	PG_Dealloc
		add	ebx,PageSize
		loop	.Loop

		mov	ebx,[.mcbaddr]
		call	MM_FreeMCB

.Exit:		mov	edx,eax				; Save error code
		lahf
		cmp	byte [.loadcr3],0
		jne	short .Exit1
		pop	ecx				; Restore CR3
		mov	cr3,ecx
		jmp	short $+2

.Exit1:		sahf					; Restore error code
		mov	eax,edx
		mpop	edi,esi,edx,ebx
		epilogue
		ret

.Err:		mov	ax,ERR_MEM_RegionLocked
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MM_GetSharedMem - allocate shared memory block.
		; Input: ECX=block size.
		; Output: CF=0 - OK; EBX=block physical address;
		;	  CF=1 - error, AX=error code.
proc MM_GetSharedMem
		ret
endp		;---------------------------------------------------------------


		; MM_DisposeSharedMem - dispose shared memory block.
		; Input: EBX=physical address of block.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_DisposeSharedMem
		ret
endp		;---------------------------------------------------------------


		; MM_AllocPages - allocate memory pages.
		; Input: ESI=PCB address,
		;	 ECX=number of pages.
		; Output: CF=0 - OK, ESI=address of first allocated page;
		;	  CF=1 - error, AX=error code.
proc MM_AllocPages
		ret
endp		;---------------------------------------------------------------


		; MM_FreePages - free memory pages.
		; Input: ESI=address of first page,
		;	 ECX=number of pages.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreePages
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; MM_AllocEnoughPages - allocate enough pages
		;			to hold the data.
		; Input: EAX=block size.
		; Output: CF=0 - OK, EAX=number of allocated pages;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set to user pages directory.
proc MM_AllocEnoughPages
		mpush	ecx,edi
		add	eax,PageSize-1		; Calculate number of pages
		shr	eax,PAGESHIFT
		mpop	edi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_FindRegion - find a linear memory region.
		; Input: ESI=address of PCB,
		;	 ECX=required size.
		; Output: CF=0 - OK, EBX=region address;
		;	  CF=1 - error, AX=error code.
proc MM_FindRegion
%define	.regionsize	ebp-4

		prologue 4
		mpush	edx,edi

		mov	dword [.regionsize],0

		mov	ebx,[HeapBegin]
		or	ebx,ebx
		jz	short .Empty
		mov	edx,ebx

.Loop:		mov	eax,[TotalMemPages]
		shl	eax,PAGESHIFT
		add	eax,StartOfExtMem
		cmp	ebx,eax
		jae	short .Err
		mov	eax,[esi+tProcDesc.PID]
		call	PG_GetPTEaddr
		jc	short .Exit
		cmp	dword [edi],PG_DISABLE
		je	short .Err
		test	dword [edi],PG_ALLOCATED
		jnz	short .Used
		add	dword [.regionsize],PageSize
		cmp	[.regionsize],ecx
		jae	short .Found
		add	ebx,PageSize
		jmp	.Loop

.Used:		add	ebx,PageSize
		mov	edx,ebx
		mov	dword [.regionsize],0
		jmp	.Loop

.Found:		mov	ebx,edx
		clc

.Exit:		mpop	edi,edx
		epilogue
		ret

.Empty:		mov	ax,ERR_MEM_EmptyHeap
		stc
		jmp	.Exit

.Err:		mov	ax,ERR_MEM_NoMemory
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MM_GetMCB - get a new MCB.
		; Input:  ESI=address of PCB.
		; Output: CF=0 - OK, EBX=linear address of MCB;
		;	  CF=1 - error, AX=error code.
proc MM_GetMCB
		mpush	ecx,edx,esi,edi
		mov	ebx,MM_MCBAREABEG
		xor	ecx,ecx				; Start with first MCB

.Scan:		cmp	ecx,MM_MCBAREASIZE
		jae	short .Err
		mov	eax,[esi+tProcDesc.PID]
		call	PG_GetPTEaddr
		jc	short .Exit
		test	dword [edi],PG_ALLOCATED	; MCB page allocated?
		jnz	short .CheckMCB			; Yes, check MCB

		xor	edx,edx
		call	PG_Alloc			; Else allocate one page
		jc	short .Exit			; of physical memory
		or	eax,PG_ALLOCATED		; Store address of page
		mov	[edi],eax			; in PTE
		mov	word [ebx+tMCB.Signature],0

.CheckMCB:	cmp	word [ebx+tMCB.Signature],0
		je	short .Found

		add	ebx,MCBSIZE
		add	ecx,MCBSIZE
		jmp	.Scan

.Found:		mov	word [ebx+tMCB.Signature],MCBSIG_PRIVATE
		mov	byte [ebx+tMCB.Type],REGTYPE_DATA
		cmp	dword [esi+tProcDesc.FirstMCB],0 ; 'First' field initialized?
		jne	short .ChkLast
		mov	[esi+tProcDesc.FirstMCB],ebx

.ChkLast:	mov	eax,[esi+tProcDesc.LastMCB]
		or	eax,eax
		jz	short .InitPtrs
		mov	[eax+tMCB.Next],ebx		; Last->Next=EBX

.InitPtrs:	mov	dword [ebx+tMCB.Next],0		; EBX->Next=0
		mov	[ebx+tMCB.Prev],eax		; EBX->Prev=Last
		mov	[esi+tProcDesc.LastMCB],ebx	; Last=EBX
		clc

.Exit:		mpop	edi,esi,edx,ecx
		ret

.Err:		mov	ax,ERR_MEM_NoMCBs
		stc
		jmp	.Err
endp		;---------------------------------------------------------------


		; MM_FreeMCB - free a MCB.
		; Input: EBX=linear address of MCB,
		;	 ESI=PCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set on the process page directory.
proc MM_FreeMCB
		push	edx
		mov	word [ebx+tMCB.Signature],0
		mov	eax,[ebx+tMCB.Prev]		; Pointer manipulations..
		or	eax,eax
		mov	edx,[ebx+tMCB.Next]
		jz	short .NoPrev
		mov	[eax+tMCB.Next],edx
.NoPrev:	or	edx,edx
		jz	short .CheckLast
		mov	[edx+tMCB.Prev],eax

.CheckLast:	cmp	ebx,[esi+tProcDesc.LastMCB]
		jne	short .CheckFirst
		mov	[esi+tProcDesc.LastMCB],eax

.CheckFirst:	cmp	ebx,[esi+tProcDesc.FirstMCB]
		jne	short .Exit
		mov	[esi+tProcDesc.FirstMCB],edx

.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; MM_PrepareMCBarea - prepare MCB area to use.
		; Input: none.
		; Output: none.
proc MM_PrepareMCBarea
		mpush	ecx,edi
		mov	edi,MM_MCBAREABEG
		mov	ecx,MM_MCBAREASIZE/4
		xor	eax,eax
		cld
		rep	stosd
		mpop	edi,ecx
		ret
endp		;---------------------------------------------------------------


		; MM_FreeMCBarea - free MCB area of process.
		; Input: ESI=address of PCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set on the process page directory.
proc MM_FreeMCBarea
		mpush	ebx,ecx,edi
		mov	ebx,MM_MCBAREABEG
		mov	ecx,MM_MCBAREASIZE/PageSize

.Loop:		mov	eax,[esi+tProcDesc.PID]
		call	PG_GetPTEaddr
		jc	short .Exit
		mov	eax,[edi]
		test	eax,PG_ALLOCATED
		jz	short .Next
		and	eax,~ADDR_OFSMASK
		call	PG_Dealloc
		mov	dword [edi],(~ADDR_OFSMASK)+PG_PRESENT
.Next:		add	ebx,PageSize
		loop	.Loop

.OK:		clc
.Exit:		mpop	edi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MM_FindMCB - find MCB by block address.
		; Input: EBX=block address,
		;	 ESI=address of PCB.
		; Output: CF=0 - OK, EBX=MCB address;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set on the process page directory.
proc MM_FindMCB
		mpush	ecx,edx
		mov	edx,ebx
		mov	ebx,[esi+tProcDesc.FirstMCB]

.Loop:		cmp	[ebx+tMCB.Addr],edx		; If found - ZF=0
		je	short .Exit			; and CF=0
		mov	ebx,[ebx+tMCB.Next]		; Next MCB
		or	ebx,ebx
		jnz	.Loop

.Err:		mov	ax,ERR_MEM_MCBnotFound
		stc
		jmp	.Exit

.Exit:		mpop	edx,ecx
		ret
endp		;---------------------------------------------------------------
