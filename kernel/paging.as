;*******************************************************************************
;  paging.as - memory paging routines.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module kernel.paging

%include "sys.ah"
%include "errors.ah"
%include "process.ah"
%include "i386/paging.ah"


; --- Exports ---

global PG_Init, PG_GetNumFreePages, PG_GetPTEaddr
global PG_Prepare, PG_Alloc, PG_Dealloc


; --- Imports ---

library kernel
extern ExtMemPages, VirtMemPages, TotalMemPages

library kernel.kheap
extern KH_Alloc:near

library kernel.mt
extern ?MaxNumOfProc, ?ProcListPtr

library kernel.driver
extern EDRV_AllocData:near


; --- Variables ---

section .bss

?MemMapAddr	RESD	1			; Address of memory map
?PgTablesBeg	RESD	1			; Begin of page tables
?PTsPerProc	RESD	1			; Page tables per process


; --- Procedures ---

section .text

		; PG_Init - initialize paging structures.
		; Input: ECX=size of virtual memory (in KB).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PG_Init
		mpush	ebx,ecx,edx,edi
		shr	ecx,2				; ECX=number of VM pages
		mov	[VirtMemPages],ecx
		add	ecx,[ExtMemPages]
		mov	[TotalMemPages],ecx
		add	ecx,7				; Calculate number of
		shr	ecx,3				; bytes in memory map
		call	KH_Alloc			; Allocate space for it
		jc	near .Exit			; in kernel heap
		mov	[?MemMapAddr],ebx		; Store map address
		mov	edi,ebx
		shr	ecx,2				; Mark all pages
		xor	eax,eax				; as used
		cld
		rep	stosd

		; Allocate memory for page tables
		mov	eax,[TotalMemPages]		; First get size of
		add	eax,PG_ITEMSPERTABLE-1		; page tables for one process
		shr	eax,PG_ITEMSPERTBLSHIFT		; EAX=number of page tables
		mov	[?PTsPerProc],eax		; per process
		inc	eax				; +PDE
		shl	eax,PG_ITEMSPERTBLSHIFT+2	; EAX=bytes in PDE & PTEs
		mov	ecx,[?MaxNumOfProc]		; ECX=number of processes
		inc	ecx				; +system tables
                mul	ecx				; Get amount of memory
		mov	ecx,eax				; for all tables
		call	EDRV_AllocData			; Allocate
		jc	near .Exit
		test	ebx,0FFFh			; Alignment required?
		jz	short .NoAlign			; No, continue
		mov	eax,ebx
		shr	eax,PAGESHIFT			; Else align by page
		inc	eax
		shl	eax,PAGESHIFT
		mov	ecx,eax
		sub	ecx,ebx
		push	eax
		call	EDRV_AllocData			; Allocate rest of page
		pop	ebx
		jc	near .Exit

.NoAlign:	mov	[?PgTablesBeg],ebx

		; Fill page directories and tables with initial values
		xor	edx,edx				; Initialize system
		dec	edx				; page tables
		mov	ebx,[?PgTablesBeg]
		jmp	short .1
.Fill:		mov	eax,edx
		call	PG_GetPageDirAddr		; Get address of
							; process page dir
		shl	eax,PROCDESCSHIFT		; Fill 'PDE' field in
		add	eax,[?ProcListPtr]		; process descriptor
		mov	[eax+tProcDesc.PageDir],ebx

.1:		mov	eax,ebx				; Begin to fill the
		xor	ecx,ecx				; page directory

.FillPageDir:	add	eax,PageSize
		cmp	ecx,[?PTsPerProc]
		jae	short .Absent
		mov	[ebx+4*ecx],eax
		or	byte [ebx+4*ecx],PG_PRESENT	; Mark as present
		jmp	short .ChkDirNum
.Absent:	mov	dword [ebx+4*ecx],PG_DISABLE
.ChkDirNum:	inc	ecx
		cmp	ecx,PG_ITEMSPERTABLE
		jb	.FillPageDir

		add	ebx,PageSize			; Begin to fill
		xor	eax,eax				; the page table
		xor	ecx,ecx
.FillPT:	mov	[ebx+4*ecx],eax
		add	eax,PageSize
		mov	edi,[ExtMemPages]
		add	edi,256				; Add number of pages
		cmp	ecx,edi				; in first megabyte
		jae	short .Virtual
		or	byte [ebx+4*ecx],PG_PRESENT	; Mark as present
.Virtual:	inc	ecx
		add	edi,[VirtMemPages]
		cmp	ecx,edi
		jne	.FillPT

		inc	edx				; Increase PID
		cmp	edx,[?MaxNumOfProc]
		jne	.Fill

		; Enable paging
		xor	eax,eax
		call	PG_GetPageDirAddr
		mov	cr3,ebx
		mPagingOn

.Exit:		mpop	edi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; PG_Prepare - prepare global heap to use.
		; Input: EBX=address of heap begin.
		; Output: none.
proc PG_Prepare
		mpush	ebx,ecx
		mov	eax,ebx
		sub	ebx,StartOfExtMem		; Count begin
		shr     ebx,PAGESHIFT			; page number
		mov	ecx,[TotalMemPages]		; Count number of
		sub	ecx,ebx				; heap pages

.Loop:		call	PG_Dealloc			; Prepare page
		add	eax,PageSize
		loop	.Loop
		xor	eax,eax
		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; PG_Alloc - allocate one page.
		; Input: DL=0 - physical page only;
		;	 DL=1 - physical or virtual page;
		;	 DL=2 - virtual page only.
		; Output: CF=0 - OK, EAX=page address+control bits.
		;	  CF=1 - error, AX=error code.
proc PG_Alloc
		mpush	ebx,ecx,esi
		mov	esi,[?MemMapAddr]
		sub	esi,byte 4
		mov	ecx,[TotalMemPages]
		shr	ecx,byte 5

.Loop:		add	esi,byte 4			; Next dword
		bsf	eax,[esi]			; See if any bits set
		loopz	.Loop				; Loop while not
		jz	short .Err			; Quit if no memory
		btr	[esi],eax			; Else reset the bit
		sub	esi,[?MemMapAddr]		; Find the dword address
		mov	ebx,esi				; Make it a relative bit #
		shl	ebx,3				; EBX is 32 * dword #
		add	eax,ebx				; Add the bit within the word
		shl	eax,PAGESHIFT			; Make it an address
		add	eax,StartOfExtMem

		mov	ecx,[ExtMemPages]
		shl	ecx,PAGESHIFT
		add	ecx,StartOfExtMem
		cmp	eax,ecx
		jae	short .Virtual
		cmp	dl,2				; Virtual page requested?
		je	short .NoMem			; Yes, no virtual memory
		or	eax,PG_PRESENT			; Mark as present
		jmp	short .OK

.Virtual:	or	dl,dl				; Physical page requested?
		jz	short .NoMem			; Yes, no physical memory

.OK:		clc
.Exit:		mpop	esi,ecx,ebx
		ret

.NoMem:		call	PG_Dealloc
.Err:		mov	ax,ERR_PG_NoFreePage
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; PG_Dealloc - deallocate a page.
		; Input: EAX=page address.
		; Output: none.
proc PG_Dealloc
		mpush	eax,ebx
		sub	eax,StartOfExtMem
		shr	eax,PAGESHIFT
		mov	ebx,[?MemMapAddr]
		bts	[ebx],eax
		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


		; PG_GetNumFreePages - get number of free pages.
		; Input: none.
		; Output: ECX=number of pages.
proc PG_GetNumFreePages
		mpush	edx,esi
		mov	esi,[?MemMapAddr]
		xor	ecx,ecx
		xor	edx,edx
.Loop:		bt	[esi],edx
		jnc	short .Next
		inc	ecx
.Next:		inc	edx
		cmp	edx,[TotalMemPages]
		jb	.Loop
		clc
		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------


		; PG_GetPageDirAddr - get page directory address.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc PG_GetPageDirAddr
		cmp	eax,[?MaxNumOfProc]
		jb	short .Do
		mov	ax,ERR_MT_BadPID
		stc
		ret

.Do:		mpush	eax,edx
		inc	eax				; Omit system tables
		mov	ebx,[?PTsPerProc]		; Page tables per process
		inc	ebx				; + page directory
		shl	ebx,PG_ITEMSPERTBLSHIFT+2
		mul	ebx
		add	eax,[?PgTablesBeg]
		mov	ebx,eax
		mpop	edx,eax
		ret
endp		;---------------------------------------------------------------


		; PG_GetPTEaddr - get physical address of PTE.
		; Input: EAX=PID,
		;	 EBX=linear address.
		; Output: CF=0 - OK, EDI=physical address of PTE;
		;	  CF=1 - error, AX=error code.
proc PG_GetPTEaddr
		mpush	ebx,esi
		mov	esi,ebx				; Keep linear address
		call	PG_GetPageDirAddr
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
