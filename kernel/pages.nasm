;*******************************************************************************
; pages.nasm - RadiOS memory paging primitives.
; Copyright (c) 2001,2002 RET & COM Research.
;*******************************************************************************

module kernel.paging

%include "sys.ah"
%include "errors.ah"
%include "bootdefs.ah"
%include "module.ah"
%include "serventry.ah"
%include "cpu/paging.ah"
%include "cpu/stkframe.ah"

%define PFDEBUG

; --- Exports ---

publicproc PG_Init, PG_StartPaging
publicproc PG_GetNumFreePages, PG_FaultHandler

exportproc PG_Alloc, PG_Dealloc
exportproc PG_AllocContBlock, PG_AllocAreaTables

publicdata ?KernPagePool, ?KernPgPoolEnd
publicdata ?KernPageDir


; --- Imports ---

library kernel
externdata ?PhysMemPages, ?VirtMemPages, ?TotalMemPages


; --- Data ---

section .data
%ifdef PFDEBUG
TxtPageFault	DB	"Page fault: CR2=",0
TxtErrCode	DB	", errcode=",0
%endif

; --- Variables ---

section .bss

?PgBitmapAddr	RESD	1			; Page bitmap address
?PgBitmapSize	RESD	1			; Page bitmap size (bytes)
?KernPagePool	RESD	1			; Start of kernel pages pool
?KernPgPoolEnd	RESD	1			; End of kernel pages pool
?NumPgsKernPool	RESD	1			; Number of pages in kernel pool
?KernPageDir	RESD	1			; Kernel page directory address
?PTsPerProc	RESD	1			; Page tables per process

; --- Code ---

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
		
		; Initialize page bitmap.
		; First mark all pages which belong to BTL area, kernel
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
		mov	ecx,UPPERMEMSTART / PAGESIZE
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

		; First, mark all physical pages except those which belong
		; to boot modules and reserved area (HMA) as free.
		mov	edi,[?PgBitmapAddr]
		mov	ecx,HMASTART / PAGESIZE
		mov	eax,[?TotalMemPages]
		add	eax,ecx
		mov	[%$AllPages],eax
		add	ecx,HMASIZE / PAGESIZE		; # of pages in HMA

.FreeLoop:	cmp	ecx,[%$AllPages]
		je	.BuildTables
		mov	ebx,ecx
		shl	ebx,PAGESHIFT
		call	PG_IsBusyBootMod
		jc	.PageBusy
		bts	[edi],ecx
.PageBusy:	inc	ecx
		jmp	.FreeLoop
		
		; Now construct kernel page directory and tables
.BuildTables: 	mov	eax,[?TotalMemPages]		; First get size of
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

		; Fill in page directory and tables with initial values
		xor	ecx,ecx
		mov	eax,ebx

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

		add	ebx,PAGESIZE			; Begin to fill
		xor	eax,eax				; the page table
		xor	ecx,ecx
.FillPT:	mov	[ebx+4*ecx],eax
		add	eax,PAGESIZE
		mov	edi,[?PhysMemPages]
		add	edi,UPPERMEMSTART / PAGESIZE	; Add number of pages
		cmp	ecx,edi				; in first megabyte
		jae	short .Virtual
		or	byte [ebx+4*ecx],PG_PRESENT | PG_WRITABLE
.Virtual:	inc	ecx
		add	edi,[?VirtMemPages]
		cmp	ecx,edi
		jne	.FillPT

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
		shr	ecx,byte 5			; 32 bits in dword
		jmp	short .FindFirst

.ExtMemory:	add	esi,UPPERMEMSTART / PAGESIZE / 8
		mov	ecx,[?TotalMemPages]
		shr	ecx,byte 5

.FindFirst:	add	esi,byte 4
		bsf	eax,[esi]
		loopz	.FindFirst
		jz	short .Err2

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
		;	 ECX=area size (will be rounded up by PAGESIZE),
		;	 EDX=directory address,
		;	 AH=page table attributes.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: this routine allocates page tables (if they are not
		;	allocated yet) initializes PTEs with PG_DISABLE.
proc PG_AllocAreaTables
		mpush	ebx,ecx,edx,esi,edi
		mAlignOnPage ecx
		shr	ecx,PAGESHIFT
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
		je	short .Err			; No, bad address
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
proc PG_IsBusyBootMod
		push	esi
		mov	esi,[BOOTPARM(BMDmodules)]
		or	esi,esi
		jz	.Exit
.Loop:		mov	eax,[esi+tModule.CodeStart]
		cmp	ebx,eax
		jb	.Next
		add	eax,[esi+tModule.Size]
		cmp	ebx,eax
		jc	.Exit
.Next:		add	esi,byte tModule_size
		cmp	dword [esi],0
		jne	.Loop
.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; PG_FaultHandler - handle page faults.
		; Input: none.
		; Output: none.
		; Note: frame with error code is on the stack
proc PG_FaultHandler
		arg	frame
		prologue

		; Get fault address, then let interrupts back in.  This
		; minimizes latency on kernel preemption, while still keeping
		; a preempting task from hosing our CR2 value.
		mov	ebx,cr2
		sti
		mov	dl,[%$frame+tStackFrame.Err]
		and	dl,PG_ATTRIBUTES
%ifdef PFDEBUG
		mServPrintStr TxtPageFault
		mServPrint32h ebx
		mServPrintStr TxtErrCode
		mServPrint8h dl
		mServPrintChar 10
%endif
		test	dl,PG_PRESENT			; Protection violation?
		jnz	.Violation

.Violation:	jmp	$
		epilogue
		ret
endp		;---------------------------------------------------------------
