;*******************************************************************************
;  paging.as - RadiOS memory paging primitives.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

module kernel.paging

%include "sys.ah"
%include "errors.ah"
%include "i386/paging.ah"
%include "boot/bootdefs.ah"
%include "boot/mb_info.ah"


; --- Exports ---

global PG_Init, PG_InitPageTables, PG_Alloc, PG_Dealloc
global PG_AllocContBlock, PG_GetNumFreePages
global PG_GetPTEaddr, PG_Prepare
global AllocPhysMem
global ?KernPagePool, ?KernPgPoolEnd


; --- Imports ---

library kernel
extern ?PhysMemPages, ?VirtMemPages, ?TotalMemPages


; Macro to test alignment on page boundary
%macro mAlignOnPage 1
	test	%1,PAGESIZE-1
	jz	short %%1
	add	%1,PAGESIZE-1
	and	%1,~ADDR_OFSMASK
%%1:
%endmacro


; --- Variables ---

?PgBitmapAddr	RESD	1			; Page bitmap address
?PgBitmapSize	RESD	1			; Page bitmap size (bytes)
?KernPagePool	RESD	1			; Start of kernel pages pool
?KernPgPoolEnd	RESD	1			; End of kernel pages pool
?NumPgsKernPool	RESD	1			; Number of pages in kernel pool
?MaxPageDirs	RESD	1			; Maximum number of page dirs
?StartPgTables	RESD	1			; Start address of page tables
?PTsPerProc	RESD	1			; Page tables per process

; --- Code ---

section .text

		; PG_Init - initialize paging.
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
		add	eax,PG_BMAPSPARE * 1000000h
		shr	eax,PAGESHIFT+3
		mov	[?PgBitmapSize],eax
		
		; Store start and end addresses of kernel page pool
		add	eax,ebx
		mAlignOnPage eax
		mov	[?KernPagePool],eax
		mov	[?KernPgPoolEnd],edx
		
		; Initialize page bitmap.
		; First mark all pages which belong to loader area, kernel
		; sections, syscall tables and page bitmap itself as used.
		shr	eax,PAGESHIFT
		mov	ecx,eax
		xor	eax,eax
.KernArea:	btr	[ebx],eax
		inc	eax
		loop	.KernArea
		
		; Now mark pages in kernel page pool as free.
		mov	ecx,edx
		shr	ecx,PAGESHIFT
		sub	ecx,eax
		mov	[?NumPgsKernPool],ecx
.KernPgPool:	bts	[ebx],eax
		inc	eax
		loop	.KernPgPool
		
		; Mark all pages above kernel pool up to start of extended
		; memory as used.
		mov	ecx,StartOfExtMem / PAGESIZE
		sub	ecx,eax
.ReservedMem:	btr	[ebx],eax
		inc	eax
		loop	.ReservedMem
		
		; Mark all memory above 1 MB as used
		mov	ecx,[?PgBitmapSize]
		shl	ecx,3
		sub	ecx,eax
.ExtendedMem:	btr	[ebx],eax
		inc	eax
		loop	.ExtendedMem
		
		; BZero kernel page pool.
		mov	edi,[?KernPagePool]
		mov	ecx,[?NumPgsKernPool]
		shl	ecx,(PAGESHIFT >> 2)
		xor	eax,eax
		cld
		rep	stosd
		
		ret
endp		;---------------------------------------------------------------


		; PG_InitPageTables - initialize page tables.
		; Input: ECX=maximum number of page directories.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PG_InitPageTables
%define	.AllPages	ebp-4

		prologue 4
		mov	[?MaxPageDirs],ecx

		; First, mark all physical pages except those which belong
		; to boot modules as free.
		mov	edi,[?PgBitmapAddr]
		mov	ecx,StartOfExtMem / PAGESIZE
		mov	eax,[?TotalMemPages]
		add	eax,ecx
		mov	[.AllPages],eax
		
.FreeLoop:	cmp	ecx,[.AllPages]
		je	short .BuildTables
		cmp	dword [BootModulesCount],0
		je	short .MarkFree
		mov	esi,ecx
		shl	esi,PAGESHIFT			; ESI=current address
		mov	edx,[BootModulesListAddr]	; Is it within
		cmp	esi,[edx+tModList.Start]	; modules area?
		jb	short .MarkFree
		mov	eax,[BootModulesCount]
		dec	eax
		shl	eax,MODLIST_SHIFT
		cmp	esi,[edx+eax+tModList.End]
		ja	short .MarkFree
		inc	ecx				; Yes, don't mark it
		jmp	.FreeLoop			; as free
			
.MarkFree:	bts	[edi],ecx
		inc	ecx
		jmp	.FreeLoop
		
		; Now construct page directories and tables
.BuildTables: 	mov	eax,[?TotalMemPages]		; First get size of
		add	eax,PG_ITEMSPERTABLE-1		; page tables for one die
		shr	eax,PG_ITEMSPERTBLSHIFT		; EAX=number of page tables
		mov	[?PTsPerProc],eax		; per directory
		inc	eax				; +page directory
		shl	eax,PG_ITEMSPERTBLSHIFT+2	; EAX=bytes in dir & tables
		
		mov	ecx,[?MaxPageDirs]		; ECX=total number of dirs
                mul	ecx				; Get amount of memory
		mov	ecx,eax				; for all tables
		mov	dl,1				; Allocate block
		call	PG_AllocContBlock		; above 1 MB
		jc	.Exit
		mov	[?StartPgTables],ebx

		; Fill in page directories and tables with initial values
		xor	edx,edx				; EDX will keep dir #
		mov	ebx,[?StartPgTables]

.Fill:		mov	eax,edx				; EAX=directory #
		call	PG_GetDirAddr			; Get its address
		mov	eax,ebx				; Begin to fill the
		xor	ecx,ecx				; page directory

.FillPageDir:	add	eax,PAGESIZE
		cmp	ecx,[?PTsPerProc]
		jae	short .Absent
		mov	[ebx+4*ecx],eax
		or	byte [ebx+4*ecx],PG_PRESENT	; Mark as present
		jmp	short .ChkDirNum
.Absent:	mov	dword [ebx+4*ecx],PG_DISABLE
.ChkDirNum:	inc	ecx
		cmp	ecx,PG_ITEMSPERTABLE
		jb	.FillPageDir

		add	ebx,PAGESIZE			; Begin to fill
		xor	eax,eax				; the page table
		xor	ecx,ecx
.FillPT:	mov	[ebx+4*ecx],eax
		add	eax,PAGESIZE
		mov	edi,[?PhysMemPages]
		add	edi,StartOfExtMem / PAGESIZE	; Add number of pages
		cmp	ecx,edi				; in first megabyte
		jae	short .Virtual
		or	byte [ebx+4*ecx],PG_PRESENT	; Mark as present
.Virtual:	inc	ecx
		add	edi,[?VirtMemPages]
		cmp	ecx,edi
		jne	.FillPT

		inc	edx				; Increase direcotry #
		cmp	edx,[?MaxPageDirs]
		jne	.Fill

		; Enable paging
		xor	eax,eax
		call	PG_GetDirAddr
		mov	cr3,ebx
		mPagingOn

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; PG_Prepare - prepare global heap to use.
		; Input:
		; Output: none.
proc PG_Prepare
		ret
endp		;---------------------------------------------------------------


		; PG_AllocContBlock - allocate continuous block of memory.
		; Input: ECX=block size (in bytes),
		;	 DL=0 - in kernel space;
		;	 DL=1 - out kernel space.
		; Output: CF=0 - OK, EBX=block address;
		;	  CF=1 - error, AX=error code.
proc PG_AllocContBlock
%define	.blockpages	ebp-4

		prologue 4
		mpush	ecx,edx,esi,edi
		mAlignOnPage ecx
		jecxz	.Err1
		shr	ecx,PAGESHIFT
		mov	[.blockpages],ecx
		mov	esi,[?PgBitmapAddr]
		sub	esi,byte 4			; We add 4 later
		or	dl,dl				; Kernel area?
		jnz	short .ExtMemory
		mov	ecx,[?NumPgsKernPool]
		shr	ecx,byte 5			; 32 bits in dword
		jmp	short .FindFirst

.ExtMemory:	add	esi,StartOfExtMem / PAGESIZE / 8
		mov	ecx,[?TotalMemPages]
		shr	ecx,byte 5

.FindFirst:	add	esi,byte 4
		bsf	eax,[esi]
		loopz	.FindFirst
		jz	short .Err2

		; We found free page, now check whether the rest of
		; pages which immediately follow are free
		mov	edx,[.blockpages]
		mov	edi,eax
.FindRest:	dec	edx
		jz	short .GotOK
		inc	eax
		bt	[esi],eax
		jc	.FindRest
		jmp	.FindFirst

		; Got enough pages, mark them as used
.GotOK: 	mov	eax,edi
		mov	edx,[.blockpages]
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

.Err1:		mov	ax,ERR_MEM_BadBlockSize
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
int3
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
		
.UserPages:	add	esi,StartOfExtMem/PAGESIZE/8
		mov	ecx,[?TotalMemPages]
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
		shr	ecx,3				; 8 bits per byte
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


		; PG_AllocDir - find a free page directory.
		; Input: none.
		; Output: CF=0 - OK:
		;		     EAX=directory number,
		;		     EBX=directory address;
		;	  CF=1 - error, AX=error code.
proc PG_AllocDir
		mpush	ecx,edx
		
		; Count size (in bytes) of one page directory and all its
		; page tables
		mov	edx,[?PTsPerProc]
		inc	edx
		shl	edx,PG_ITEMSPERTBLSHIFT+2
		
		; Find a free directory by checking PG_ALLOCATED bit in a
		; first entry of each page directory.
		mov	ecx,[?MaxPageDirs]
		mov	ebx,[?StartPgTables]
		xor	eax,eax
		
.Loop:		test	dword [ebx],PG_ALLOCATED
		jnz	short .Found
		add	ebx,edx
		inc	eax
		loop	.Loop
		
		mov	ax,ERR_PG_NoFreeDir			; Error
		stc
		jmp	short .Exit
		
.Found:		clc
		
.Exit:		mpop	edx,ecx
		ret
endp		;---------------------------------------------------------------


		; PG_DeallocDir - free a page directory.
		; Input: EBX=directory address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PG_DeallocDir
		ret
endp		;---------------------------------------------------------------


		; PG_GetDirAddr - get page directory address.
		; Input: EAX=directory number.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc PG_GetDirAddr
		cmp	eax,[?MaxPageDirs]
		jb	short .Do
		mov	ax,ERR_PG_BadDirNum
		stc
		ret

.Do:		mpush	eax,edx
		mov	ebx,[?PTsPerProc]		; Page tables per process
		inc	ebx				; + page directory
		shl	ebx,PG_ITEMSPERTBLSHIFT+2
		mul	ebx
		add	eax,[?StartPgTables]
		mov	ebx,eax
		mpop	edx,eax
		ret
endp		;---------------------------------------------------------------


		; PG_GetPTEaddr - get physical address of PTE.
		; Input: EAX=directory number,
		;	 EBX=linear address.
		; Output: CF=0 - OK, EDI=physical address of PTE;
		;	  CF=1 - error, AX=error code.
proc PG_GetPTEaddr
		mpush	ebx,esi
		mov	esi,ebx				; Save linear address
		call	PG_GetDirAddr
		jc	short .Exit
		mov	eax,esi
		shr	eax,22				; EAX=PDE number
		mov	ebx,[ebx+eax*4]
		cmp	ebx,PG_DISABLE			; Page table present?
		je	short .Err			; No, bad address
		and	ebx,PGENTRY_ADDRMASK		; Mask control bits
		and	esi,ADDR_PTEMASK
		shr	esi,12
		lea	edi,[ebx+esi*4]
		clc
.Exit:		mpop	esi,ebx
		ret

.Err:		mov	eax,ERR_PG_BadLinearAddr
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; AllocPhysMem - driver helper (simply calls PG_AllocContBlock).
proc AllocPhysMem
		jmp	PG_AllocContBlock
endp		;---------------------------------------------------------------
