;*******************************************************************************
;  memman.asm - RadiOS memory management routines.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

include "memman.ah"

; --- Definitions ---
MM_MCBAREABEG		EQU	100000h			; Begin of MCB area
MM_MCBAREASIZE		EQU	10000h			; Size of MCB area

; --- Variables ---
segment KVARS
PagesPerProc	DD	?				; Pages per process
ends

include "MEMMAN\region.asm"

; --- Interface procedures ---

		; MM_Init - initialize memory management.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_Init near
		push	ebx ecx edx edi
		mov	dx,USERCODE
		call	K_DescriptorAddress
		call	K_GetDescriptorBase
		mov	ebx,edi
		call	PG_Prepare

		; Initialize kernel MCB area
		call	MM_PrepareMCBarea
		mov	ebx,MM_MCBAREABEG
		mov	ecx,MM_MCBAREASIZE/PageSize

@@Loop:		call	PG_GetPTEaddr
		jc	short @@Exit
		or	[dword edi],PG_ALLOCATED
		add	ebx,PageSize
		loop	@@Loop

		; Initialize kernel process region
		xor	eax,eax
		mov	esi,[MT_ProcTblAddr]
		call	MM_GetMCB
		jc	short @@Exit
		mov	[ebx+tMCB.Signature],MCBSIG_SHARED
		mov	[ebx+tMCB.Flags],MCBFL_LOCKED
		mov	[ebx+tMCB.Type],REGTYPE_KERNEL
		mov	[ebx+tMCB.Count],1
		mov	eax,1000h
		mov	[ebx+tMCB.Addr],eax
		mov	ecx,[KH_Top]
		sub	ecx,eax
		mov	[ebx+tMCB.Len],ecx

		clc
@@Exit:		pop	edi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; MM_AllocBlock - allocate memory block.
		; Input: EAX=PID,
		;	 ECX=block size,
		;	 DL=0 - load CR3 with process page directory,
		;	 DL=1 - don't load CR3;
		;	 DH=block attributes (PG_USERMODE or/and PG_WRITEABLE).
		; Output: CF=0 - OK:
		;		     EAX=address of MCB,
		;		     EBX=block physical address;
		;	  CF=1 - error, AX=error code.
proc MM_AllocBlock near
@@pid		EQU	ebp-4
@@mcbaddr	EQU	ebp-8
@@flags		EQU	ebp-12

		push	ebp
		mov	ebp,esp
		sub	esp,12
		push	ecx edx esi edi

		mov	[@@pid],eax			; Keep PID
		mov	[@@flags],edx			; and attributes
		call	K_GetProcDescAddr
		jc	@@Exit2

		mov	esi,ebx
		or	dl,dl
		jnz	short @@CR3Loaded
		mov	eax,cr3
		push	eax
		mov	eax,[ebx+tProcDesc.PageDir]
		mov	cr3,eax
		jmp	short $+2

@@CR3Loaded:	mov	eax,[@@pid]
		call	MM_GetMCB			; Get a MCB
		jc	short @@Exit			; and keep it address
		mov	[@@mcbaddr],ebx
		mov	edi,ebx

		mov	[ebx+tMCB.Len],ecx		; Keep block length
		add	ecx,PageSize-1			; Calculate number of
		and	ecx,not ADDR_OFSMASK		; pages to hold the data

		mov	eax,[@@pid]			; Search a region
		call	MM_FindRegion			; If OK - EBX=linear
		jc	short @@FreeMCB			; address of region

		mov	[edi+tMCB.Addr],ebx		; Fill MCB 'Addr' field
		shr	ecx,PAGESHIFT			; ECX=number of pages
							; to allocate
		mov	eax,ERR_MEM_BadBlockSize
		jecxz	@@FreeMCB
@@Loop:		mov	dl,1				; Allocate one page
		call	PG_Alloc			; of physical or virtual
		jc	short @@FreePages		; memory
		mov	edx,eax				; Keep it physical addr
		mov	eax,[@@pid]
		call	PG_GetPTEaddr			; Store physical address
		jc	short @@FreePages		; in PTE
		or	edx,PG_ALLOCATED
		or	dl,[@@flags+1]
		mov	[edi],edx
		add	ebx,PageSize
		loop	@@Loop

		mov	eax,[@@mcbaddr]
		mov	ebx,[eax+tMCB.Addr]
		clc

@@Exit:		mov	edx,eax
		lahf
		cmp	[byte @@flags],0
		jne	short @@Exit1
		pop	ecx				; Restore CR3
		mov	cr3,ecx
		jmp	short $+2

@@Exit1:	sahf					; Restore error code
		mov	eax,edx
@@Exit2:	pop	edi esi edx ecx
		mov	esp,ebp
		pop	ebp
		ret

@@FreeMCB:	push	eax				; Free MCB if error
		mov	ebx,[@@mcbaddr]
		call	MM_FreeMCB
		pop	eax
		stc
		jmp	@@Exit

@@FreePages:	push	eax				; Keep error code
		mov	ebx,[@@mcbaddr]
		mov	eax,ecx
		mov	ecx,[ebx+tMCB.Len]
		add	ecx,PageSize-1
		shr	ecx,PAGESHIFT
		sub	ecx,eax
		jecxz	@@NoDeall
		mov	ebx,[ebx+tMCB.Addr]

@@DeallLoop:	mov	eax,[@@pid]
		call	PG_GetPTEaddr
		and	[dword edi],not PG_ALLOCATED
		mov	eax,[edi]
		call	PG_Dealloc
		add	ebx,PageSize
		loop	@@DeallLoop
@@NoDeall:	pop	eax				; Restore error code
		jmp	@@FreeMCB
endp		;---------------------------------------------------------------


		; MM_FreeBlock - free memory block.
		; Input: EAX=PID,
		;	 EBX=block address (if EDI=0),
		;	 DL=0 - load CR3 with process page directory,
		;	 DL=1 - don't load CR3;
		;	 EDI=0 - use block address in EBX,
		;	 EDI!=0 - EDI=MCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreeBlock near
@@pid		EQU	ebp-4
@@mcbaddr	EQU	ebp-8
@@loadcr3	EQU	ebp-12

		push	ebp
		mov	ebp,esp
		sub	esp,12
		push	ebx edx esi edi

		mov	[@@pid],eax
		mov	[@@loadcr3],dl
		xchg	edi,ebx
		call	K_GetProcDescAddr		; Get process descriptor
		jc	short @@Exit1			; address and keep it
		mov	esi,ebx				; in ESI

		or	dl,dl
		jnz	short @@CR3Loaded
		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax
		jmp	short $+2

@@CR3Loaded:	or	ebx,ebx				; Got MCB address?
		jz	short @@GotMCBaddr
		mov	ebx,edi				; Find the MCB by addr
		call	MM_FindMCB
		jc	short @@Exit

@@GotMCBaddr:	test	[ebx+tMCB.Flags],MCBFL_LOCKED	; Locked region?
		jnz	short @@Err
		mov	[@@mcbaddr],ebx
		mov	ecx,[ebx+tMCB.Len]
		add	ecx,PageSize-1
		shr	ecx,PAGESHIFT
		mov	ebx,edi

@@Loop:		mov	eax,[@@pid]
		call	PG_GetPTEaddr
		jc	short @@Exit
		and	[dword edi],not PG_ALLOCATED
		mov	eax,[edi]
		call	PG_Dealloc
		add	ebx,PageSize
		loop	@@Loop

		mov	ebx,[@@mcbaddr]
		call	MM_FreeMCB

@@Exit:		mov	edx,eax				; Save error code
		lahf
		cmp	[byte @@loadcr3],0
		jne	short @@Exit1
		pop	ecx				; Restore CR3
		mov	cr3,ecx
		jmp	short $+2

@@Exit1:	sahf					; Restore error code
		mov	eax,edx
		pop	edi esi edx ebx
		mov	esp,ebp
		pop	ebp
		ret

@@Err:		mov	ax,ERR_MEM_RegionLocked
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MM_GetSharedMem - allocate shared memory block.
		; Input: ECX=block size.
		; Output: CF=0 - OK; EBX=block physical address;
		;	  CF=1 - error, AX=error code.
proc MM_GetSharedMem near
		ret
endp		;---------------------------------------------------------------


		; MM_DisposeSharedMem - dispose shared memory block.
		; Input: EBX=physical address of block.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_DisposeSharedMem near
		ret
endp		;---------------------------------------------------------------


		; MM_AllocPages - allocate memory pages.
		; Input: EAX=PID,
		;	 ECX=number of pages.
		; Output: CF=0 - OK, ESI=address of first allocated page;
		;	  CF=1 - error, AX=error code.
proc MM_AllocPages near
		ret
endp		;---------------------------------------------------------------


		; MM_FreePages - free memory pages.
		; Input: ESI=address of first page,
		;	 ECX=number of pages.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreePages near
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; MM_AllocEnoughPages - allocate enough pages
		;			to hold the data.
		; Input: EAX=block size.
		; Output: CF=0 - OK, EAX=number of allocated pages;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set to user pages directory.
proc MM_AllocEnoughPages near
		push	ecx edi
		add	eax,PageSize-1		; Calculate number of pages
		shr	eax,PAGESHIFT
		pop	edi ecx
		ret
endp		;---------------------------------------------------------------


		; MM_FindRegion - find a linear memory region.
		; Input: EAX=PID,
		;	 ECX=required size.
		; Output: CF=0 - OK, EBX=region address;
		;	  CF=1 - error, AX=error code.
proc MM_FindRegion near
@@pid		EQU	ebp-4
@@regionsize	EQU	ebp-8

		push	ebp
		mov	ebp,esp
		sub	esp,8
		push	edx edi

		mov	[@@pid],eax
		mov	[dword @@regionsize],0

		mov	ebx,[HeapBegin]
		or	ebx,ebx
		jz	short @@Empty
		mov	edx,ebx

@@Loop:		mov	eax,[TotalMemPages]
		shl	eax,PAGESHIFT
		add	eax,StartOfExtMem
		cmp	ebx,eax
		jae	short @@Err
		mov	eax,[@@pid]
		call	PG_GetPTEaddr
		jc	short @@Exit
		cmp	[dword edi],PG_DISABLE
		je	short @@Err
		test	[dword edi],PG_ALLOCATED
		jnz	short @@Used
		add	[dword @@regionsize],PageSize
		cmp	[@@regionsize],ecx
		jae	short @@Found
		add	ebx,PageSize
		jmp	@@Loop

@@Used:		add	ebx,PageSize
		mov	edx,ebx
		mov	[dword @@regionsize],0
		jmp	@@Loop

@@Found:	mov	ebx,edx
		clc

@@Exit:		pop	edi edx
		mov	esp,ebp
		pop	ebp
		ret

@@Empty:	mov	ax,ERR_MEM_EmptyHeap
		stc
		jmp	@@Exit

@@Err:		mov	ax,ERR_MEM_NoMemory
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MM_GetMCB - get a new MCB.
		; Input: EAX=PID,
		;	 ESI=pointer to process descriptor.
		; Output: CF=0 - OK, EBX=linear address of MCB;
		;	  CF=1 - error, AX=error code.
proc MM_GetMCB near
		push	ecx edx esi edi
		mov	edx,eax				; Keep PID
		mov	ebx,MM_MCBAREABEG
		xor	ecx,ecx				; Start with first MCB

@@Scan:		cmp	ecx,MM_MCBAREASIZE
		jae	short @@Err
		mov	eax,edx
		call	PG_GetPTEaddr
		jc	short @@Exit
		test	[dword edi],PG_ALLOCATED	; MCB page allocated?
		jnz	short @@CheckMCB		; Yes, check MCB

		push	edx
		xor	edx,edx
		call	PG_Alloc			; Else allocate one page
		pop	edx				; of physical memory
		jc	short @@Exit
		or	eax,PG_ALLOCATED		; Store address of page
		mov	[edi],eax			; in PTE
		mov	[ebx+tMCB.Signature],0

@@CheckMCB:	cmp	[ebx+tMCB.Signature],0
		je	short @@Found

		add	ebx,MCBSIZE
		add	ecx,MCBSIZE
		jmp	@@Scan

@@Found:	mov	[ebx+tMCB.Signature],MCBSIG_PRIVATE
		mov	[ebx+tMCB.Type],REGTYPE_DATA
		cmp	[esi+tProcDesc.FirstMCB],0	; 'First' field initialized?
		jne	short @@ChkLast
		mov	[esi+tProcDesc.FirstMCB],ebx

@@ChkLast:	mov	eax,[esi+tProcDesc.LastMCB]
		or	eax,eax
		jz	short @@InitPtrs
		mov	[eax+tMCB.Next],ebx		; Last->Next=EBX

@@InitPtrs:	mov	[ebx+tMCB.Next],0		; EBX->Next=0
		mov	[ebx+tMCB.Prev],eax		; EBX->Prev=Last
		mov	[esi+tProcDesc.LastMCB],ebx	; Last=EBX
		clc

@@Exit:		pop	edi esi edx ecx
		ret

@@Err:		mov	ax,ERR_MEM_NoMCBs
		stc
		jmp	@@Err
endp		;---------------------------------------------------------------


		; MM_FreeMCB - free a MCB.
		; Input: EBX=linear address of MCB,
		;	 ESI=pointer to process descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set on the process page directory.
proc MM_FreeMCB near
		push	edx
		mov	[ebx+tMCB.Signature],0
		mov	eax,[ebx+tMCB.Prev]		; Pointer manipulations..
		or	eax,eax
		mov	edx,[ebx+tMCB.Next]
		jz	short @@NoPrev
		mov	[eax+tMCB.Next],edx
@@NoPrev:	or	edx,edx
		jz	short @@CheckLast
		mov	[edx+tMCB.Prev],eax

@@CheckLast:	cmp	ebx,[esi+tProcDesc.LastMCB]
		jne	short @@CheckFirst
		mov	[esi+tProcDesc.LastMCB],eax

@@CheckFirst:	cmp	ebx,[esi+tProcDesc.FirstMCB]
		jne	short @@Exit
		mov	[esi+tProcDesc.FirstMCB],edx

@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; MM_PrepareMCBarea - prepare MCB area to use.
		; Input: none.
		; Output: none.
proc MM_PrepareMCBarea near
		push	ecx edi
		mov	edi,MM_MCBAREABEG
		mov	ecx,MM_MCBAREASIZE/4
		xor	eax,eax
		cld
		rep	stosd
		pop	edi ecx
		ret
endp		;---------------------------------------------------------------


		; MM_FreeMCBarea - free MCB area of process.
		; Input: EAX=PID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set on the process page directory.
proc MM_FreeMCBarea near
		push	ebx ecx edx edi
		mov	edx,eax
		mov	ebx,MM_MCBAREABEG
		mov	ecx,MM_MCBAREASIZE/PageSize

@@Loop:		mov	eax,edx
		call	PG_GetPTEaddr
		jc	short @@Exit
		mov	eax,[edi]
		test	eax,PG_ALLOCATED
		jz	short @@Next
		and	eax,not ADDR_OFSMASK
		call	PG_Dealloc
		mov	[dword edi],(not ADDR_OFSMASK)+PG_PRESENT
@@Next:		add	ebx,PageSize
		loop	@@Loop

@@OK:		clc
@@Exit:		pop	edi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; MM_FindMCB - find MCB by block address.
		; Input: EBX=block address,
		;	 ESI=pointer to process descriptor.
		; Output: CF=0 - OK, EBX=MCB address;
		;	  CF=1 - error, AX=error code.
		; Note: CR3 must be set on the process page directory.
proc MM_FindMCB near
		push	ecx edx
		mov	edx,ebx
		mov	ebx,[esi+tProcDesc.FirstMCB]

@@Loop:		cmp	[ebx+tMCB.Addr],edx		; If found - ZF=0
		je	short @@Exit			; and CF=0
		mov	ebx,[ebx+tMCB.Next]		; Next MCB
		or	ebx,ebx
		jnz	@@Loop

@@Err:		mov	ax,ERR_MEM_MCBnotFound
		stc
		jmp	@@Exit

@@Exit:		pop	edx ecx
		ret
endp		;---------------------------------------------------------------
