;*******************************************************************************
; pages.nasm - RadiOS memory paging primitives.
; Copyright (c) 2001, 2002 RET & COM Research.
;*******************************************************************************

module kernel.paging

%include "sys.ah"
%include "errors.ah"
%include "bootdefs.ah"
%include "module.ah"
%include "cpu/paging.ah"
%include "cpu/stkframe.ah"

publicproc PG_Init, PG_StartPaging
publicproc PG_GetPTEaddr, PG_GetNumFreePages
publicdata ?KernPagePool, ?KernPgPoolEnd

exportproc PG_Alloc, PG_Dealloc
exportproc PG_AllocContBlock, PG_AllocAreaTables

externdata ?UpperMemPages

section .bss

?PgBitmapAddr	RESD	1			; Page bitmap address
?PgBitmapSize	RESD	1			; Page bitmap size (bytes)
?KernPagePool	RESD	1			; Start of kernel pages pool
?KernPgPoolEnd	RESD	1			; End of kernel pages pool
?NumPgsKernPool	RESD	1			; Number of pages in kernel pool
?KernPageDir	RESD	1			; Kernel page directory address
?PTsPerProc	RESD	1			; Page tables per process


section .text

		; PG_Init - initialize page bitmap.
		; Input: EBX=begin of kernel free memory,
		;	 EDX=end of kernel free memory,
		;	 ECX=size of extended memory in kilobytes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PG_Init
		; Store page bitmap address
		mov	[?PgBitmapAddr],ebx

		; Calculate the size of page bitmap
		; Size := max. memory in kilobytes / 4 KB per page / 8 bits
		mov	eax,ecx
		add	eax,PG_BMAPSPARE * 1024
		shr	eax,5					; >>2 and >>3
		mov	[?PgBitmapSize],eax
		
		; Store start and end addresses of kernel page pool
		add	eax,ebx
		mAlignOnPage eax
		mov	[?KernPagePool],eax
		mov	[?KernPgPoolEnd],edx
		
		; Kernel sections pages and bitmap pages are used
		shr	eax,PAGESHIFT
		mov	ecx,eax
		xor	eax,eax
.KernArea:	btr	[ebx],eax
		inc	eax
		loop	.KernArea
		
		; Now mark pages in kernel page pool as free
		mov	ecx,edx
		shr	ecx,PAGESHIFT
		sub	ecx,eax
		mov	[?NumPgsKernPool],ecx
.KernPgPool:	bts	[ebx],eax
		inc	eax
		loop	.KernPgPool
		
		; Mark all pages above kernel pool up to start of extended
		; memory as used
		mov	ecx,UPPERMEMSTART / PAGESIZE
		sub	ecx,eax
.ReservedMem:	btr	[ebx],eax
		inc	eax
		loop	.ReservedMem
		
		; Mark all memory above 1 MB as used
		mov	ecx,[?PgBitmapSize]
		shl	ecx,3
		sub	ecx,eax
.UpperMem:	btr	[ebx],eax
		inc	eax
		loop	.UpperMem
		
		; BZero kernel page pool
		mov	edi,[?KernPagePool]
		mov	ecx,[?NumPgsKernPool]
		shl	ecx,PAGESHIFT-2
		xor	eax,eax
		cld
		rep	stosd
		
		ret
endp		;---------------------------------------------------------------


		; PG_StartPaging - initialize kernel page directory and tables,
		;		   then enable paging.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PG_StartPaging
		locals	AllPages
		prologue

		; HMA area is used by BTL
		mov	edi,[?PgBitmapAddr]
		mov	ecx,HMASTART / PAGESIZE
		mov	eax,[?UpperMemPages]
		add	eax,ecx
		mov	[%$AllPages],eax
		add	ecx,HMASIZE / PAGESIZE
		dec	ecx

		; Find free pages. Page is free when it is not used by some
		; boot module and it's not marked as "reserved" in the BIOS
		; memory map.
.FreeLoop:	inc	ecx
		cmp	ecx,[%$AllPages]
		je	.BuildTables
		mov	ebx,ecx
		shl	ebx,PAGESHIFT
		call	PG_IsBusyBootMod
		jc	.FreeLoop
		call	PG_IsPageReserved
		jc	.FreeLoop
		bts	[edi],ecx
		jmp	.FreeLoop
		
		; Now construct kernel page directory and tables
.BuildTables: 	mov	eax,[?UpperMemPages]		; First get size of
		add	eax,PG_ITEMSPERTABLE-1		; page tables for one dir
		shr	eax,PG_ITEMSPERTBLSHIFT		; EAX=number of page tables
		mov	[?PTsPerProc],eax		; per directory
		inc	eax				; +page directory
		shl	eax,PG_ITEMSPERTBLSHIFT+2	; EAX=bytes in dir & tables

		mov	ecx,eax
		mov	dl,1				; Allocate block
		call	PG_AllocContBlock		; above 1 MB
		jc	near .Exit
		mov	[?KernPageDir],ebx
		xor	ecx,ecx
		mov	eax,ebx

		; Fill in page directory
.FillPageDir:	add	eax,PAGESIZE
		cmp	ecx,[?PTsPerProc]
		jae	.Absent
		mov	[ebx+4*ecx],eax
		or	byte [ebx+4*ecx],PG_PRESENT | PG_WRITABLE
		jmp	.ChkPDENum
.Absent:	mov	dword [ebx+4*ecx],PG_DISABLE
.ChkPDENum:	inc	ecx
		cmp	ecx,PG_ITEMSPERTABLE
		jb	.FillPageDir

		; Provide 1:1 mapping of available physical memory
		lea	esi,[ebx+PAGESIZE]
		mov	ebx,PG_PRESENT | PG_WRITABLE
		xor	eax,eax
		mov	ecx,[?UpperMemPages]
		add	ecx,UPPERMEMSTART / PAGESIZE
.FillPT:	mov	[esi+4*eax],ebx
		add	ebx,PAGESIZE
		inc	eax
		loop	.FillPT

		; Enable paging
		mov	eax,[?KernPageDir]
		mov	cr3,eax
		mPagingOn
		
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; PG_AllocContBlock - allocate continuous block of memory.
		; Input: ECX=block size (in bytes),
		;	 DL=0 - in kernel space;
		;	 DL=1 - out kernel space.
		; Output: CF=0 - OK, EBX=block address;
		;	  CF=1 - error, AX=error code.
proc PG_AllocContBlock
		locals	blockpages
		prologue
		mpush	ecx,edx,esi,edi

		mAlignOnPage ecx
		jecxz	.Err1
		shr	ecx,PAGESHIFT
		mov	[%$blockpages],ecx
		mov	esi,[?PgBitmapAddr]
		sub	esi,byte 4			; We add 4 later
		or	dl,dl				; Kernel area?
		jnz	short .ExtMemory
		mov	ecx,[?NumPgsKernPool]
		shr	ecx,5				; 32 bits in dword
		jmp	short .FindFirst

.ExtMemory:	add	esi,UPPERMEMSTART / PAGESIZE / 8
		mov	ecx,[?UpperMemPages]
		shr	ecx,5

.FindFirst:	add	esi,byte 4
		bsf	eax,[esi]
		loopz	.FindFirst
		jz	.Err2

		; We found free page, now check whether the rest of
		; pages which immediately follow are free
		mov	edx,[%$blockpages]
		mov	edi,eax
.FindRest:	dec	edx
		jz	short .GotOK
		inc	eax
		bt	[esi],eax
		jc	.FindRest
		jmp	.FindFirst

		; Got enough pages, mark them as used
.GotOK: 	mov	eax,edi
		mov	edx,[%$blockpages]
.MarkUsed:	btr	[esi],eax
		inc	eax
		dec	edx
		jnz	.MarkUsed
		
		; Finally, count the address of allocated block
		mov	ebx,esi
		sub	ebx,[?PgBitmapAddr]
		shl	ebx,3				; 8 bits per byte
		add	ebx,edi				; EBX=first page number
		shl	ebx,PAGESHIFT			; EBX=first page address
		clc

.Done:		mpop	edi,esi,edx,ecx
		epilogue
		ret

.Err1:		mov	ax,ERR_PG_BadBlockSize
		stc
		jmp	short .Done
.Err2:		mov	ax,ERR_PG_NoFreePage
		stc
		jmp	short .Done
endp		;---------------------------------------------------------------


		; PG_Alloc - allocate a page.
		; Input: DL=0 - in kernel space;
		;	 DL=1 - out of kernel space.
		; Output: CF=0 - OK, EAX=page address+control bits;
		;	  CF=1 - error, AX=error code.
proc PG_Alloc
		mpush	ebx,ecx,esi
		mov	esi,[?PgBitmapAddr]
		sub	esi,byte 4			; Will add 4 later
		or	dl,dl
		jnz	short .UserPages
		mov	eax,[?KernPagePool]
		shr	eax,PAGESHIFT+3			; 8 bits in byte
		add	esi,eax
		mov	ecx,[?NumPgsKernPool]
		shr	ecx,byte 5			; 32 bits in dword
		jmp	short .Loop
		
.UserPages:	add	esi,UPPERMEMSTART / PAGESIZE / 8
		mov	ecx,[?UpperMemPages]
		shr	ecx,byte 5

.Loop:		add	esi,byte 4			; Next dword
		bsf	eax,[esi]			; See if any bits set
		loopz	.Loop				; Loop while not
		jz	short .Err			; Quit if no memory
		btr	[esi],eax			; Else reset the bit
		sub	esi,[?PgBitmapAddr]		; Find the dword address
		mov	ebx,esi				; Make it a relative bit #
		shl	ebx,3				; EBX is 32 * dword #
		add	eax,ebx				; Add the bit within the word
		shl	eax,PAGESHIFT			; Make it an address
		or	eax,PG_PRESENT			; Mark as present
		clc
		
.Exit:		mpop	esi,ecx,ebx
		ret

.Err:		mov	ax,ERR_PG_NoFreePage
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; PG_Dealloc - deallocate a page.
		; Input: EAX=page address.
		; Output: none.
proc PG_Dealloc
		mpush	eax,ebx
		shr	eax,PAGESHIFT
		mov	ebx,[?PgBitmapAddr]
		bts	[ebx],eax
		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


		; PG_GetNumFreePages - get number of free pages.
		; Input: none.
		; Output: ECX=number of pages.
proc PG_GetNumFreePages
		mpush	edx,esi
		mov	esi,[?PgBitmapAddr]
		mov	ecx,[?PgBitmapSize]
		shl	ecx,3				; 8 bits per byte
		xor	eax,eax
		xor	edx,edx
.Loop:		bt	[esi],edx
		jnc	short .Next
		inc	eax
.Next:		inc	edx
		cmp	edx,ecx
		jb	.Loop
		mov	ecx,eax
		xor	eax,eax
		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------


		; PG_AllocAreaTables - allocate page tables for mapping
		;			specific area.
		; Input: EBX=area start address,
		;	 ECX=number of tables,
		;	 EDX=page directory address,
		;	 AH=page table attributes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: this routine allocates page tables (if they are not
		;	allocated yet) and initializes PTEs with PG_DISABLE.
proc PG_AllocAreaTables
		mpush	ebx,ecx,edx,esi,edi
		jecxz	.Exit
		mov	esi,ebx
		mov	edi,edx
		shr	ebx,PAGEDIRSHIFT			; EBX=PDE#
		mov	dl,1
		mov	dh,ah
.Loop:		cmp	dword [edi+ebx*4],PG_DISABLE
		jne	.Next
		call	PG_Alloc
		jc	.Exit
		or	al,dh
		mov	[edi+ebx*4],eax
		call	.InitPTattrs
.Next:		inc	ebx
		loop	.Loop
		clc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret
		
		; Subroutine: initialize page table attributes
.InitPTattrs:	push	ecx
		xor	ecx,ecx
.InitAttrLoop:	and	eax,PGENTRY_ADDRMASK
		mov	dword [eax+ecx*4],PG_DISABLE
		add	esi,PAGESIZE
		inc	ecx
		cmp	ecx,PG_ITEMSPERTABLE
		jne	.InitAttrLoop
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; PG_GetPTEaddr - get physical address of PTE.
		; Input: EBX=linear address,
		;	 EDX=directory address.
		; Output: CF=0 - OK, EDI=physical address of PTE;
		;	  CF=1 - error, AX=error code.
proc PG_GetPTEaddr
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


		; PG_IsBusyBootMod - check whether a page belongs to some boot
		;		   module (i.e. can it be marked as free
		;		   during initialization).
		; Input: EBX=page address.
		; Output: CF=0 - page is free;
		;	  CF=1 - page is busy by some boot module.
		; Note: modifies EDX.
proc PG_IsBusyBootMod
		mov	edx,[BOOTPARM(BMDmodules)]
		or	edx,edx
		jz	.Exit
.Loop:		mov	eax,[edx+tModule.CodeStart]
		cmp	ebx,eax
		jb	.Next
		add	eax,[edx+tModule.Size]
		cmp	ebx,eax
		jc	.Exit
.Next:		add	edx,byte tModule_size
		cmp	dword [edx],0
		jne	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; PG_IsPageReserved - check whether a page belongs to
		;		reserved memory area in BIOS memory map.
		; Input: EBX=page address.
		; Output: CF=0 - page is free;
		;	  CF=1 - page is busy by some boot module.
		; Notes: modifies EDX;
		;	 memory sizes more than 4G are not currenly supported :)
proc PG_IsPageReserved
		mov	edx,[BOOTPARM(MemMapAddr)]
		or	edx,edx
		jnz	.MemMapPresent
		ret
		
.MemMapPresent:	push	ecx
		mov	ecx,[BOOTPARM(MemMapSize)]
.Loop:		cmp	dword [edx+tAddrRangeDesc.Type],1
		jz	.Next
		mov	eax,[edx+tAddrRangeDesc.BaseAddrLow]
		cmp	ebx,eax
		jb	.Next
		add	eax,[edx+tAddrRangeDesc.LengthLow]
		cmp	ebx,eax
		jc	.Exit
.Next:		mov	eax,[edx+tAddrRangeDesc.Size]
		add	eax,byte 4
		add	edx,eax
		sub	ecx,eax
		jnz	.Loop
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------
