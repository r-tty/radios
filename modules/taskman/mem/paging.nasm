;-------------------------------------------------------------------------------
; paging.nasm - routines for manipulating page tables.
;-------------------------------------------------------------------------------

module tm.memman.paging

%include "sys.ah"
%include "errors.ah"
%include "tm/process.ah"
%include "cpu/paging.ah"

publicproc NewPageDir, FreePageDir
publicproc GetPTEaddr, AllocPTifNecessary, MapArea

externproc PageAlloc, PageDealloc
externdata ?KernPCB

section .text

		; Make a copy of the kernel page directory.
		; Input: none.
		; Output: CF=0 - OK, EDX=new directory address;
		;	  CF=1 - error, AX=error code.
proc NewPageDir
		mpush	ebx,ecx,esi,edi
		
		; Allocate a page for a new directory
		mov	dl,1				; In upper memory
		call	PageAlloc
		jc	.Exit
		and	eax,PGENTRY_ADDRMASK
		mov	ebx,eax				; EBX=new dir addr
		
		; Copy contents
		mov	edi,ebx
		mov	eax,[?KernPCB]
		mov	esi,[eax+tProcDesc.PageDir]
		mov	ecx,PG_ITEMSPERTABLE
		cld
		rep	movsd
		mov	edx,ebx
		clc

.Exit:		mpop	edi,esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; Free a page directory and all user page tables.
		; Input: EDX=directory address.
		; Output: none.
proc FreePageDir
		push	ecx
		mov	ecx,PG_ITEMSPERTABLE / 2	; Start from user mem
.ChkPDE:	mov	eax,[edx+ecx*4]			; First we free all
		test	eax,PG_PRESENT			;  page tables
		jz	.NextPDE
		call	PageDealloc
		
.NextPDE:	inc	ecx
		cmp	ecx,PG_ITEMSPERTABLE
		jb	.ChkPDE
		
		mov	eax,edx				; Free directory page
		call	PageDealloc
		
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; For given linear address, get a physical address of PTE.
		; Input: EBX=linear address,
		;	 EDX=directory address.
		; Output: CF=0 - OK, EDI=physical address of PTE;
		;	  CF=1 - error, AX=error code.
proc GetPTEaddr
		mpush	ebx,edx
		mov	eax,ebx
		shr	eax,PAGEDIRSHIFT		; EAX=PDE number
		mov	edx,[edx+eax*4]			; EDX=page table addr.
		cmp	edx,PG_DISABLE			; Page table present?
		je	.Err				; No, bad address
		and	edx,PGENTRY_ADDRMASK		; Mask control bits
		and	ebx,ADDR_PTEMASK
		shr	ebx,PAGESHIFT			; EBX=PTE number
		lea	edi,[edx+ebx*4]			; EDI=PTE address
		clc
.Exit:		mpop	edx,ebx
		ret

.Err:		mov	eax,ERR_PG_BadLinearAddr
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Initialize all PTEs with default value (PG_DISABLE).
		; Input: EAX=page table address.
		; Output: none.
proc InitPTEs
		mpush	eax,ecx,edi
		mov	edi,eax
		and	edi,~ADDR_OFSMASK
		mov	ecx,PAGESIZE / 4
		mov	eax,PG_DISABLE
		cld
		rep	stosd
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; Allocate a page table for given address if it is not
		; allocated yet.
		; Input: EBX=address,
		;	 EDX=page directory address,
		;	 AH=page table attributes (PG_USERMODE, PG_WRITABLE).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc AllocPTifNecessary
		mpush	ecx,edi
		mov	edi,ebx
		mov	cl,ah
		shr	edi,PAGEDIRSHIFT		; EDI=PDE number
		cmp	dword [edx+edi*4],PG_DISABLE	; Page table present?
		jne	.OK				; If yes, exit
		push	edx				; No, allocate new one
		mov	dl,1				; in upper memory
		call	PageAlloc
		pop	edx
		jc	.Exit
		or	al,cl
		mov	[edx+edi*4],eax
		call	InitPTEs

.OK:		clc
.Exit:		mpop	edi,ecx
		ret
endp		;---------------------------------------------------------------


		; MapArea - map arbitrary area of physical memory.
		; Input: AH=page directory attributes (ORed with existing),
		;	 AL=page enry attributes,
		;	 ECX=area size,
		;	 EDX=page directory address,
		;	 ESI=physical address of mapped area,
		;	 EDI=virtual address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MapArea
		locals	attrs,numpages,pte
		prologue

		mpush	ebx,ecx,edx,esi,edi
		or	ecx,ecx
		jz	near .Exit
		mov	[%$attrs],eax
		mAlignOnPage ecx
		shr	ecx,PAGESHIFT
		mov	[%$numpages],ecx
		shr	ecx,PAGEDIRSHIFT-PAGESHIFT	; Number of page dirs

		and	esi,PGENTRY_ADDRMASK
		mov	ebx,edx
		mov	eax,edi
		and	eax,ADDR_PTEMASK
		shr	eax,PAGESHIFT			; EAX=PTE#
		mov	[%$pte],eax
		shr	edi,PAGEDIRSHIFT		; EDI=PDE#
		
.PDloop:	mov	dx,[%$attrs]
		mov	eax,[ebx+edi*4]
		cmp	eax,PG_DISABLE			; Is page table missing?
		jne	.SetPDEattr			; No, just set attrs
		mov	dl,1				; Else allocate a new one
		call	PageAlloc
		jc	.Exit
		call	InitPTEs
.SetPDEattr:	or	al,dh
		mov	[ebx+edi*4],eax
		
		; Do actual mapping and initialize page attributes
.InitPT:	push	edi
		mov	edi,eax
		and	edi,PGENTRY_ADDRMASK
		movzx	eax,byte [%$attrs]
		or	eax,PG_MAPPED
		or	esi,eax
		mov	eax,[%$pte]
.PTloop:	mov	[edi+eax*4],esi
		dec	dword [%$numpages]
		jz	.InitPTdone
		add	esi,PAGESIZE
		inc	eax
		cmp	eax,PG_ITEMSPERTABLE
		jne	.PTloop
		xor	eax,eax				; Next dir - PTE #0
.InitPTdone:	mov	[%$pte],eax
		pop	edi

		inc	edi
		jecxz	.OK
		loop	.PDloop
.OK:		clc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------
