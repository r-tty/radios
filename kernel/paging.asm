;-------------------------------------------------------------------------------
;  paging.asm - memory paging routines.
;-------------------------------------------------------------------------------

; --- Definitions ---

PG_ITEMSPERTABLE	EQU	1024
PG_ITEMSPERTBLSHIFT	EQU	10
PG_MBPERTABLE		EQU	4
PG_MBPERTBLSHIFT	EQU	2

PG_DISABLE		EQU	0FFFFFFFEh
PG_ATTRIBUTES		EQU	7
PG_USERMODE		EQU	4			; Standard attrs
PG_WRITEABLE		EQU	2
PG_PRESENT		EQU	1

PG_PWT			EQU	8
PG_PCD			EQU	32
PG_ACCESSED		EQU	32
PG_DIRTY		EQU	64

PG_ALLOCATED		EQU	512			; "User" PTE bits

PGENTRY_ADDRMASK	EQU	0FFFFF000h

ADDR_PDEMASK		EQU	0FFC00000h
ADDR_PTEMASK		EQU	3FF000h
ADDR_OFSMASK		EQU	0FFFh

macro mPagingOn
	cli
	mov	eax,cr0
	or	eax,CR0_PG
	mov	cr0,eax
	jmp	short $+2
	sti
endm

macro mPagingOff
	cli
	mov	eax,cr0
	and	eax,not CR0_PG
	mov	cr0,eax
	jmp	short $+2
	sti
endm

macro mReinitTLB
	mov	eax,cr3
	mov	cr3,eax
endm

; --- Variables ---
segment KVARS
MemMapAddr	DD	?			; Address of memory map
PgTablesBeg	DD	?			; Begin of page tables
PTsPerProc	DD	?			; PTEs per process
ends


; --- Procedures ---

		; PG_Init - initialize paging structures.
		; Input: ECX=size of virtual memory (in KB).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: called from MM_Init.
proc PG_Init near
		push	ebx ecx edx edi
		shr	ecx,2				; ECX=number of VM pages
		mov	[VirtMemPages],ecx
		add	ecx,[ExtMemPages]
		mov	[TotalMemPages],ecx
		add	ecx,7				; Calculate number of
		shr	ecx,3				; bytes in memory map
		call	KH_Alloc			; Allocate space for it
		jc	@@Exit				; in kernel heap
		mov	[MemMapAddr],ebx		; Store map address
		mov	edi,ebx
		shr	ecx,2				; Mark all pages
		xor	eax,eax				; as used
		cld
		rep	stosd

		; Allocate memory for page tables
		mov	eax,[TotalMemPages]		; First get size of
		add	eax,PG_ITEMSPERTABLE-1		; page tables for one process
		shr	eax,PG_ITEMSPERTBLSHIFT		; EAX=number of page tables
		mov	[PTsPerProc],eax		; per process
		inc	eax				; +PDE
		shl	eax,PG_ITEMSPERTBLSHIFT+2	; EAX=bytes in PDE & PTEs
		mov	ecx,[MT_MaxProcQuan]		; ECX=number of processes
		inc	ecx				; +system tables
                mul	ecx				; Get amount of memory
		mov	ecx,eax				; for all tables
		call	EDRV_AllocData			; Allocate
		jc	@@Exit
		test	ebx,0FFFh			; Alignment required?
		jz	short @@NoAlign			; No, continue
		mov	eax,ebx
		shr	eax,PAGESHIFT			; Else align by page
		inc	eax
		shl	eax,PAGESHIFT
		mov	ecx,eax
		sub	ecx,ebx
		push	eax
		call	EDRV_AllocData			; Allocate rest of page
		pop	ebx
		jc	@@Exit

@@NoAlign:	mov	[PgTablesBeg],ebx

		; Fill page directories and tables with initial values
		xor	edx,edx				; Initialize system
		dec	edx				; page tables
		mov	ebx,[PgTablesBeg]
		jmp	short @@1
@@Fill:		mov	eax,edx
		call	PG_GetPageDirAddr		; Get address of
							; process page dir
		shl	eax,PROCDESCSHIFT		; Fill 'PDE' field in
		add	eax,[MT_ProcTblAddr]		; process descriptor
		mov	[eax+tProcDesc.PageDir],ebx

@@1:		mov	eax,ebx				; Begin to fill the
		xor	ecx,ecx				; page directory

@@FillPageDir:	add	eax,PageSize
		cmp	ecx,[PTsPerProc]
		jae	short @@Absent
		mov	[ebx+4*ecx],eax
		or	[byte ebx+4*ecx],PG_PRESENT	; Mark as present
		jmp	short @@ChkDirNum
@@Absent:	mov	[dword ebx+4*ecx],PG_DISABLE
@@ChkDirNum:	inc	ecx
		cmp	ecx,PG_ITEMSPERTABLE
		jb	@@FillPageDir

		add	ebx,PageSize			; Begin to fill
		xor	eax,eax				; the page table
		xor	ecx,ecx
@@FillPT:	mov	[ebx+4*ecx],eax
		add	eax,PageSize
		mov	edi,[ExtMemPages]
		add	edi,256				; Add number of pages
		cmp	ecx,edi				; in first megabyte
		jae	short @@Virtual
		or	[byte ebx+4*ecx],PG_PRESENT	; Mark as present
@@Virtual:	inc	ecx
		add	edi,[VirtMemPages]
		cmp	ecx,edi
		jne	@@FillPT

		inc	edx				; Increase PID
		cmp	edx,[MT_MaxProcQuan]
		jne	@@Fill

		; Enable paging
		xor	eax,eax
		call	PG_GetPageDirAddr
		mov	cr3,ebx
		mPagingOn

@@Exit:		pop	edi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; PG_Prepare - prepare global heap to use.
		; Input: EBX=address of heap begin.
		; Output: none.
proc PG_Prepare near
		push	ebx ecx
		mov	eax,ebx
		sub	ebx,StartOfExtMem		; Count begin
		shr     ebx,PAGESHIFT			; page number
		mov	ecx,[TotalMemPages]		; Count number of
		sub	ecx,ebx				; heap pages

@@Loop:		call	PG_Dealloc			; Prepare page
		add	eax,PageSize
		loop	@@Loop
		xor	eax,eax
		pop	ecx ebx
		ret
endp		;---------------------------------------------------------------


		; PG_Alloc - allocate one page.
		; Input: DL=0 - physical page only;
		;	 DL=1 - physical or virtual page;
		;	 DL=2 - virtual page only.
		; Output: CF=0 - OK, EAX=page address+control bits.
		;	  CF=1 - error, AX=error code.
proc PG_Alloc near
		push	ebx ecx esi
		mov	esi,[MemMapAddr]
		sub	esi,4
		mov	ecx,[TotalMemPages]
		shr	ecx,5

@@Loop:		add	esi,4				; Next dword
		bsf	eax,[esi]			; See if any bits set
		loopz	@@Loop				; Loop while not
		jz	short @@Err			; Quit if no memory
		btr	[esi],eax			; Else reset the bit
		sub	esi,[MemMapAddr]		; Find the dword address
		mov	ebx,esi				; Make it a relative bit #
		shl	ebx,3				; EBX is 32 * dword #
		add	eax,ebx				; Add the bit within the word
		shl	eax,PAGESHIFT			; Make it an address
		add	eax,StartOfExtMem

		mov	ecx,[ExtMemPages]
		shl	ecx,PAGESHIFT
		add	ecx,StartOfExtMem
		cmp	eax,ecx
		jae	short @@Virtual
		cmp	dl,2				; Virtual page requested?
		je	short @@NoMem			; Yes, no virtual memory
		or	eax,PG_PRESENT			; Mark as present
		jmp	short @@OK

@@Virtual:	or	dl,dl				; Physical page requested?
		jz	short @@NoMem			; Yes, no physical memory

@@OK:		clc
@@Exit:		pop	esi ecx ebx
		ret

@@NoMem:	call	PG_Dealloc
@@Err:		mov	ax,ERR_PG_NoFreePage
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; PG_Dealloc - deallocate a page.
		; Input: EAX=page address.
		; Output: none.
proc PG_Dealloc near
		push	eax ebx
		sub	eax,StartOfExtMem
		shr	eax,PAGESHIFT
		mov	ebx,[MemMapAddr]
		bts	[ebx],eax
		pop	ebx eax
		ret
endp		;---------------------------------------------------------------


		; PG_GetNumFreePages - get number of free pages.
		; Input: none.
		; Output: ECX=number of pages.
proc PG_GetNumFreePages near
		push	edx esi
		mov	esi,[MemMapAddr]
		xor	ecx,ecx
		xor	edx,edx
@@Loop:		bt	[esi],edx
		jnc	short @@Next
		inc	ecx
@@Next:		inc	edx
		cmp	edx,[TotalMemPages]
		jb	@@Loop
		clc
		pop	esi edx
		ret
endp		;---------------------------------------------------------------


		; PG_GetPageDirAddr - get page directory address.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc PG_GetPageDirAddr near
		cmp	eax,[MT_MaxProcQuan]
		jb	short @@Do
		mov	ax,ERR_MT_BadPID
		stc
		ret

@@Do:		push	eax edx
		inc	eax				; Omit system tables
		mov	ebx,[PTsPerProc]		; Page tables per process
		inc	ebx				; + page directory
		shl	ebx,PG_ITEMSPERTBLSHIFT+2
		mul	ebx
		add	eax,[PgTablesBeg]
		mov	ebx,eax
		pop	edx eax
		ret
endp		;---------------------------------------------------------------


		; PG_GetPTEaddr - get physical address of PTE.
		; Input: EAX=PID,
		;	 EBX=linear address.
		; Output: CF=0 - OK, EDI=physical address of PTE;
		;	  CF=1 - error, AX=error code.
proc PG_GetPTEaddr near
		push	ebx esi
		mov	esi,ebx				; Keep linear address
		call	PG_GetPageDirAddr
		jc	short @@Exit
		mov	eax,esi
		shr	eax,22				; EAX=PDE number
		mov	ebx,[ebx+eax*4]
		cmp	ebx,PG_DISABLE			; Page table present?
		je	short @@Err			; No, bad address
		and	ebx,PGENTRY_ADDRMASK		; Mask control bits
		and	esi,ADDR_PTEMASK
		shr	esi,12
		lea	edi,[ebx+esi*4]
		clc
@@Exit:		pop	esi ebx
		ret

@@Err:		mov	eax,ERR_PG_BadLinearAddr
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------
