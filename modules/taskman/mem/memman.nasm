;*******************************************************************************
; memman.nasm - RadiOS memory management.
; Copyright (c) 1999-2002 RET & COM Research.
;*******************************************************************************

module tm.memman

%include "sys.ah"
%include "parameters.ah"
%include "errors.ah"
%include "pool.ah"
%include "module.ah"
%include "cpu/paging.ah"
%include "tm/process.ah"
%include "tm/memman.ah"

publicproc TM_InitMemman
publicproc MM_AllocBlock, MM_FreeBlock, MM_ReallocBlock

externproc PageAlloc, PageDealloc, AllocPTifNecessary, GetPTEaddr
externproc PoolInit, PoolAllocChunk, PoolFreeChunk
externdata ?ProcListPtr


; --- Variables ---

section .bss

?MaxMCBs	RESD	1
?NumUsedMCBs	RESD	1
?MCBpool	RESB	tMasterPool_size


; --- Procedures ---

section .text

		; TM_InitMemman - initialize memory management.
		; Input: EAX=maximum number of MCBs (system-wide).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_InitMemman
		mov	[?MaxMCBs],eax
		xor	ecx,ecx
		xor	edx,edx
		mov	[?NumUsedMCBs],ecx
		mov	ebx,?MCBpool
		mov	cl,tMCB_size
		call	PoolInit
		jc	.Exit
.Exit:		ret
endp		;---------------------------------------------------------------


		; MM_AllocBlock - allocate memory block.
		; Input: ESI=PCB address,
		;	 ECX=block size.
		;	 AH=block attributes (PG_WRITABLE).
		; Output: CF=0 - OK:
		;		     EAX=address of MCB,
		;		     EBX=block address;
		;	  CF=1 - error, AX=error code.
proc MM_AllocBlock
		locals	flags, pcbaddr, mcbaddr
		prologue
		mpush	ecx,edx,esi,edi

		mov	[%$pcbaddr],esi
		mov	[%$flags],eax
		mov	edx,[esi+tProcDesc.PageDir]

		call	MM_GetMCB			; Get a MCB
		jc	.Exit				; and save its address
		mov	[%$mcbaddr],ebx
		mov	edi,ebx

		mov	[edi+tMCB.Len],ecx		; Keep block length
		add	ecx,PAGESIZE-1			; Calculate number of
		and	ecx,~ADDR_OFSMASK		; pages to hold the data

		call	MM_FindRegion			; Search a region
		jc	.FreeMCB			; If OK - EBX=linear
							; address of region
		mov	[edi+tMCB.Addr],ebx		; Fill MCB 'Addr' field
		shr	ecx,PAGESHIFT			; ECX=number of pages
							; to allocate
		mov	eax,ERR_MEM_BadBlockSize
		jecxz	.FreeMCB
.Loop:		push	edx
		mov	dl,1				; Request one page
		call	PageAlloc			; of physical or virtual
		pop	edx
		jc	.FreePages			; memory
		mov	esi,eax				; Save its physical addr
		mov	ah,PG_USERMODE | PG_WRITABLE
		call	AllocPTifNecessary
		jc	.FreePages
		call	GetPTEaddr
		jc	.FreePages
		mov	eax,esi
		or	eax,PG_USERMODE | PG_ALLOCATED
		or	al,[%$flags+1]			; Store physical address
		mov	[edi],eax			; in PTE
		add	ebx,PAGESIZE
		loop	.Loop

		mov	eax,[%$mcbaddr]
		mov	ebx,[eax+tMCB.Addr]
		sub	ebx,USERAREASTART
		clc

.Exit:		mpop	edi,esi,edx,ecx
		epilogue
		ret

.FreeMCB:	push	eax				; Free MCB if error
		mov	ebx,[%$mcbaddr]
		mov	esi,[%$pcbaddr]
		call	MM_FreeMCB
		pop	eax
		stc
		jmp	.Exit

.FreePages:	push	eax				; Save error code
		mov	ebx,[%$mcbaddr]
		mov	eax,ecx
		mov	ecx,[ebx+tMCB.Len]
		add	ecx,PAGESIZE-1
		shr	ecx,PAGESHIFT
		sub	ecx,eax
		jecxz	.NoDeall
		mov	ebx,[ebx+tMCB.Addr]

.DeallLoop:	call	GetPTEaddr
		and	dword [edi],~PG_ALLOCATED
		mov	eax,[edi]
		call	PageDealloc
		add	ebx,PAGESIZE
		loop	.DeallLoop
.NoDeall:	pop	eax				; Restore error code
		jmp	.FreeMCB
endp		;---------------------------------------------------------------


		; MM_FreeBlock - free memory block.
		; Input: ESI=PCB address,
		;	 EBX=block address (if EDI=0),
		;	 EDI=0 - use block address in EBX,
		;	 EDI!=0 - EDI=MCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreeBlock
		locals	mcbaddr
		prologue
		mpush	ebx,edx,esi,edi
		
		xchg	edi,ebx
		or	ebx,ebx				; Got MCB address?
		jnz	.GotMCBaddr
		mov	ebx,edi				; Find the MCB by addr
		call	MM_FindMCB
		jc	.Exit

.GotMCBaddr:	test	word [ebx+tMCB.Flags],MCBFL_LOCKED	; Locked region?
		jnz	.Err
		mov	[%$mcbaddr],ebx
		mov	ecx,[ebx+tMCB.Len]
		add	ecx,PAGESIZE-1
		shr	ecx,PAGESHIFT
		mov	ebx,edi				; EBX=block address

		mov	edx,[esi+tProcDesc.PageDir]
.Loop:		call	GetPTEaddr
		and	dword [edi],~PG_ALLOCATED
		mov	eax,[edi]
		call	PageDealloc
		add	ebx,PAGESIZE
		loop	.Loop

		mov	ebx,[%$mcbaddr]
		call	MM_FreeMCB

.Exit:		mpop	edi,esi,edx,ebx
		epilogue
		ret

.Err:		mov	ax,ERR_MEM_RegionLocked
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MM_ReallocBlock - reallocate block.
		; Input: EBX=old block address,
		;	 ECX=new size.
		; Output: CF=0 - OK, EBX=new block address;
		;	  CF=1 - error, AX=error code.
proc MM_ReallocBlock
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; MM_FindRegion - find a linear memory region.
		; Input: ESI=address of PCB,
		;	 ECX=required size.
		; Output: CF=0 - OK, EBX=region address;
		;	  CF=1 - error, AX=error code.
proc MM_FindRegion
		locals	regionsize,regionaddr,linearend
		prologue
		mpush	edx,edi

		mov	dword [%$regionsize],0
		mov	eax,[esi+tProcDesc.Module]
		mov	ebx,[eax+tModule.CodeStart]
		add	ebx,[eax+tModule.Size]
		add	ebx,USERAREASTART
		mov	[%$regionaddr],ebx
		lea	eax,[ebx+MAXHEAPSIZE]
		mov	[%$linearend],eax
		mov	edx,[esi+tProcDesc.PageDir]		; For PG_GetPTEaddr

.Loop:		cmp	ebx,[%$linearend]
		jae	.Err1
		mov	ah,PG_USERMODE | PG_WRITABLE
		call	AllocPTifNecessary
		jc	.Exit
		call	GetPTEaddr
		jc	.Exit
		cmp	dword [edi],PG_DISABLE
		jne	.Used
		add	dword [%$regionsize],PAGESIZE
		cmp	[%$regionsize],ecx
		jae	.Found
		add	ebx,PAGESIZE
		jmp	.Loop

.Used:		add	ebx,PAGESIZE
		mov	[%$regionaddr],ebx
		mov	dword [%$regionsize],0
		jmp	.Loop

.Found:		mov	ebx,[%$regionaddr]
		clc

.Exit:		mpop	edi,edx
		epilogue
		ret

.Empty:		mov	ax,ERR_MEM_EmptyHeap
.Err:		stc
		jmp	.Exit
.Err1:		mov	ax,ERR_MEM_NoMemory
		jmp	.Err
.Err2:		mov	ax,ERR_MEM_InvAreaLoc
		jmp	.Err
endp		;---------------------------------------------------------------


		; MM_GetMCB - get a new MCB.
		; Input:  ESI=process descriptor address.
		; Output: CF=0 - OK, EBX=MCB address;
		;	  CF=1 - error, AX=error code.
proc MM_GetMCB
		mov	eax,[?NumUsedMCBs]
		cmp	eax,[?MaxMCBs]
		je	.Err
		mov	ebx,?MCBpool
		push	esi
		call	PoolAllocChunk
		mov	ebx,esi
		pop	esi
		jc	.Exit

		mov	word [ebx+tMCB.Signature],MCBSIG_PRIVATE
		mov	byte [ebx+tMCB.Type],REGTYPE_DATA
		inc	dword [?NumUsedMCBs]
		mEnqueue dword [esi+tProcDesc.MCBlist], Next, Prev, ebx, tMCB
		clc

.Exit:		ret

.Err:		mov	ax,ERR_MEM_NoMCBs
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MM_FreeMCB - free a MCB.
		; Input: EBX=MCB address,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreeMCB
		push	esi
		mDequeue dword [esi+tProcDesc.MCBlist], Next, Prev, ebx, tMCB
		mov	esi,ebx
		call	PoolFreeChunk
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; MM_FindMCB - find MCB by block address.
		; Input: EBX=block address,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK, EBX=MCB address;
		;	  CF=1 - error, AX=error code.
proc MM_FindMCB
		mov	eax,ebx
		mov	ebx,[esi+tProcDesc.MCBlist]

.Loop:		or	ebx,ebx
		jz	.NotFound
		cmp	[ebx+tMCB.Addr],eax		; If found - ZF=0
		je	.Exit				; and CF=0
		mov	ebx,[ebx+tMCB.Next]		; Next MCB
		jmp	.Loop

.NotFound:	mov	ax,ERR_MEM_MCBnotFound
		stc
.Exit:		ret
endp		;---------------------------------------------------------------

%include "region.nasm"
