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

publicproc TM_InitMemman, MM_FindRegion
publicproc MM_AllocPagesAt, MM_FreePagesAt
publicproc MM_AllocBlock, MM_FreeBlock, MM_ReallocBlock

externproc PageAlloc, PageDealloc, AllocPTifNecessary, GetPTEaddr
externproc PoolInit, PoolAllocChunk, PoolFreeChunk
externproc TM_SetMHfromTable
externdata MemMsgHandlers
externdata ?ProcListPtr


section .bss

?MaxMCBs	RESD	1
?NumUsedMCBs	RESD	1
?MCBpool	RESB	tMasterPool_size


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

		mov	esi,MemMsgHandlers
		call	TM_SetMHfromTable
.Exit:		ret
endp		;---------------------------------------------------------------


		; MM_AllocPagesAt - allocate pages at a given address.
		; Input: AL=page attributes (PG_WRITABLE),
		;	 EBX=linear address,
		;	 ECX=number of pages,
		;	 EDX=page directory address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_AllocPagesAt
		locals	pgattr
		
		jecxz	.Err
		prologue
		mpush	ebx,ecx,esi,edi
		mov	[%$pgattr],al
.Loop:		mov	dl,1				; In upper memory
		call	PageAlloc
		jc	.Exit
		xor	dl,dl
		mov	esi,eax				; Save its physical addr
		mov	ah,PG_USERMODE | PG_WRITABLE
		call	AllocPTifNecessary
		jc	.Exit
		call	GetPTEaddr
		jc	.Exit
		mov	eax,esi
		or	eax,PG_USERMODE | PG_ALLOCATED
		or	al,[%$pgattr]			; Store physical address
		mov	[edi],eax			; in PTE
		add	ebx,PAGESIZE
		loop	.Loop
.Exit:		mpop	edi,esi,ecx,ebx
		epilogue
		ret

.Err:		mov	eax,ERR_MEM_BadBlockSize
		stc
		ret
endp		;---------------------------------------------------------------


		; MM_FreePagesAt - free pages that were allocated at
		;		   given address.
		; Input: EBX=linear address,
		;	 ECX=number of pages,
		;	 EDX=page directory address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreePagesAt
		jecxz	.Err
		mpush	ebx,ecx,edi
.Loop:		call	GetPTEaddr
		mov	eax,[edi]
		mov	dword [edi],PG_DISABLE
		call	PageDealloc
		add	ebx,PAGESIZE
		loop	.Loop
		mpop	edi,ecx,ebx
		ret

.Err:		mov	eax,ERR_MEM_BadBlockSize
		stc
		ret
endp		;---------------------------------------------------------------


		; MM_AllocBlock - allocate memory block.
		; Input: ESI=PCB address,
		;	 ECX=block size.
		;	 AL=block attributes (PG_WRITABLE).
		; Output: CF=0 - OK, EBX=block address (user);
		;	  CF=1 - error, AX=error code.
proc MM_AllocBlock
		locals	attr, pcbaddr, mcbaddr
		prologue
		mpush	ecx,edx,esi,edi

		mov	[%$pcbaddr],esi
		mov	[%$attr],al
		mov	edx,[esi+tProcDesc.PageDir]

		; Get a MCB and save its address
		call	MM_GetMCB
		jc	.Exit
		mov	[%$mcbaddr],ebx
		mov	edi,ebx

		; Store block size and round it up by PAGESIZE
		mov	[edi+tMCB.Len],ecx
		mAlignOnPage ecx

		; Find a linear region in the process's heap
		call	MM_FindRegion
		jc	.FreeMCB
		mov	[edi+tMCB.Addr],ebx

		; Allocate pages at this address
		shr	ecx,PAGESHIFT
		mov	al,[%$attr]
		call	MM_AllocPagesAt
		jc	.FreePages
		
		; Make the address visible for user program
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

.FreePages:	push	eax				; Keep error code
		call	MM_FreePagesAt
		pop	eax
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
		mov	ebx,USERAREASTART
		mov	eax,[esi+tProcDesc.Module]
		add	ebx,[eax+tModule.Size]
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
		mpush	ecx,edi
		mov	eax,[?NumUsedMCBs]
		cmp	eax,[?MaxMCBs]
		je	.Err

		mov	ebx,?MCBpool
		push	esi
		call	PoolAllocChunk
		mov	ebx,esi
		pop	esi
		jc	.Exit
		mov	edi,ebx
		xor	ecx,ecx
		mov	cl,tMCB_size / 4
		xor	eax,eax
		cld
		rep	stosd

		mov	word [ebx+tMCB.Signature],MCBSIG_PRIVATE
		mov	byte [ebx+tMCB.Type],REGTYPE_DATA
		inc	dword [?NumUsedMCBs]
		mEnqueue dword [esi+tProcDesc.MCBlist], Next, Prev, ebx, tMCB, edi
		clc

.Exit:		mpop	edi,ecx
		ret

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
		mpush	esi,edi
		mDequeue dword [esi+tProcDesc.MCBlist], Next, Prev, ebx, tMCB, edi
		mov	esi,ebx
		call	PoolFreeChunk
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; MM_FindMCB - find MCB by block address.
		; Input: EBX=block address,
		;	 ESI=process descriptor address.
		; Output: CF=0 - OK, EBX=MCB address;
		;	  CF=1 - error, AX=error code.
proc MM_FindMCB
		push	edi
		mov	edi,ebx
		mov	ebx,[esi+tProcDesc.MCBlist]

.Loop:		or	ebx,ebx
		jz	.NotFound
		cmp	[ebx+tMCB.Addr],edi		; If found - ZF=0
		je	.Exit				; and CF=0
		mov	eax,ebx
		mov	ebx,[ebx+tMCB.Next]		; Next MCB
		cmp	ebx,eax
		jne	.Loop

.NotFound:	mov	ax,ERR_MEM_MCBnotFound
		stc
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------
