;*******************************************************************************
; mem.nasm - routines related to kernel memory management.
; Copyright (c) 2003 RET & COM Research.
;*******************************************************************************

module kernel.mem

%include "sys.ah"
%include "errors.ah"
%include "cpu/paging.ah"
%include "bootdefs.ah"

publicproc K_InitMem
publicproc K_CopyIn, K_CopyOut, K_CopyFromAct, K_CopyToAct
publicdata ?UpperMemPages, ?ResvdMemPages
exportproc MemSet, BZero
exportdata ?LowerMemSize, ?UpperMemSize


section .bss

?LowerMemSize	RESD	1			; In kilobytes
?UpperMemSize	RESD	1			; In kilobytes

?UpperMemPages	RESD	1
?ResvdMemPages	RESD	1


section .text

		; K_InitMem - find out how much memory we have, and if
		;	      there is a BIOS memory map - arrange it.
		; Input: none.
		; Output: CF=1 - error;
		;	  CF=0 - OK.
proc K_InitMem
		mov	eax,[BOOTPARM(MemLower)]
		mov	[?LowerMemSize],eax
		mov	eax,[BOOTPARM(MemUpper)]
		mov	[?UpperMemSize],eax

		; If BIOS supplied us a memory map - go through it
		mov	esi,[BOOTPARM(MemMapAddr)]
		or	esi,esi
		jnz	.BIOSmmap

		; Otherwise just scan the memory. CMOS method is unreliable.
		call	K_ProbeMem			
		jmp	.OK

.BIOSmmap:	mov	ecx,[BOOTPARM(MemMapSize)]
.Loop:		mov	ebx,[esi+tAddrRangeDesc.LengthLow]
		shr	ebx,PAGESHIFT
		cmp	dword [esi+tAddrRangeDesc.Type],1
		jz	.Present
		add	[?ResvdMemPages],ebx
		jmp	.Next
.Present	cmp	dword [esi+tAddrRangeDesc.BaseAddrLow],UPPERMEMSTART
		jb	.Next
		add	[?UpperMemPages],ebx
.Next:		mov	eax,[esi+tAddrRangeDesc.Size]
		add	eax,byte 4
		add	esi,eax
		sub	ecx,eax
		jnz	.Loop
	
.OK:		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; K_ProbeMem - get memory size from CMOS and test upper memory.
		;	       This routine is called if there's no BIOS memmap.
		; Input: none.
		; Output: CF=0 - OK, ECX=size of extended memory in KB;
		;	  CF=1 - error, AX=error code.
proc K_ProbeMem
		xor	eax,eax			; Prepare to test
		mov	[?UpperMemPages],eax	; extended memory
		mov	esi,UPPERMEMSTART

.Loop2:		mov	ah,[esi]		; Get byte
		mov	byte [esi],0AAh		; Replace it with this
		cmp	byte [esi],0AAh		; Make sure it stuck
		mov	[esi],ah		; Restore byte
		jne	.StopScan		; Quit if failed
		mov	byte [esi],055h		; Otherwise replace it with this
		cmp	byte [esi],055h		; Make sure it stuck
		mov	[esi],ah		; Restore original value
		jne	.StopScan		; Quit if failed
		inc	dword [?UpperMemPages]	; Found a page
		add	esi,PAGESIZE		; Go to next page
		jmp	.Loop2

.StopScan:	mov	ecx,[?UpperMemPages]
		shl	ecx,2
		mov	[?UpperMemSize],ecx
		clc
		ret
endp		;---------------------------------------------------------------


		; Copy the data from active address space to another.
		; Input: ESI=source address (user's view),
		;	 EDI=destination address (user's view),
		;	 ECX=number of bytes,
		;	 EDX=target page directory.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, EAX=number of bytes haven't been copied.
		; Note: modifies EBX, ECX, ESI and EDI.
proc K_CopyFromAct
		push	ebp

		; Make sure that destination is a user address
		add	edi,USERAREASTART
		jc	.Exit

		; K_CopyIn preserves EAX, so we can use it as a global counter
		mov	eax,ecx

		; Check if we need to copy first non-aligned part
		mov	ecx,PAGESIZE
		mov	ebx,edi
		and	ebx,ADDR_OFSMASK
		sub	ecx,ebx
		jmp	.Check

		; Do actual copying
.Loop:		mov	ecx,PAGESIZE
.Check:		cmp	eax,ecx
		jae	.DoCopy
		mov	ecx,eax
.DoCopy:	call	.CopySmall
		jc	.Exit
		jnz	.Loop

.Exit:		pop	ebp
		ret


		; Subroutine: copy ECX bytes within one page.
		; Updates ESI, EDI and EAX and sets ZF if EAX==0.
.CopySmall:	call	.GetPhysAddr
		jc	.Ret
		mov	ebp,edi
		mov	edi,ebx
		call	K_CopyIn
		jc	.Ret
		sub	edi,ebx			; EDI=number of bytes copied
		add	ebp,edi			; dest += size
		sub	eax,edi			; counter -= size
		mov	edi,ebp			; Restore dest. address
.Ret:		ret


		; Subroutine: for linear address in EDI compute a physical
		; address and put it in EBX. EDX must contain page dir address.
.GetPhysAddr:	push	edi
		mov	ebp,edi
		and	ebp,ADDR_OFSMASK		; EBP=offset
		mov	ebx,edi
		shr	ebx,PAGEDIRSHIFT		; EBX=PDE number
		mov	ebx,[edx+ebx*4]			; EBX=page table addr.
		cmp	ebx,PG_DISABLE			; Page table present?
		stc
		je	.Quit				; No, bad address
		and	ebx,PGENTRY_ADDRMASK		; Mask control bits
		and	edi,ADDR_PTEMASK
		shr	edi,PAGESHIFT			; EDI=PTE number
		mov	ebx,[ebx+edi*4]			; EBX=page address
		cmp	ebx,PG_DISABLE			; Is a page present?
		stc
		je	.Quit				; No, bad address
		and	ebx,PGENTRY_ADDRMASK		; Mask control bits
		add	ebx,ebp				; EBX=physical address
		clc
.Quit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; Copy the data to active address space from another.
		; Input: ESI=source address (user's view),
		;	 EDI=destination address (user's view),
		;	 ECX=number of bytes,
		;	 EDX=source page directory.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, EAX=number of bytes haven't been copied.
		; Note: modifies EBX, ECX, ESI and EDI.
proc K_CopyToAct
		push	ebp

		; Make sure that source is a user address
		add	esi,USERAREASTART
		jc	.Exit

		; K_CopyOut preserves EAX, so we can use it as a global counter
		mov	eax,ecx

		; Check if we need to copy first non-aligned part
		mov	ecx,PAGESIZE
		mov	ebx,esi
		and	ebx,ADDR_OFSMASK
		sub	ecx,ebx
		jmp	.Check

		; Do actual copying
.Loop:		mov	ecx,PAGESIZE
.Check:		cmp	eax,ecx
		jae	.DoCopy
		mov	ecx,eax
.DoCopy:	call	.CopySmall
		jc	.Exit
		jnz	.Loop

.Exit:		pop	ebp
		ret


		; Subroutine: copy ECX bytes within one page.
		; Updates ESI, EDI and EAX and sets ZF if EAX==0.
.CopySmall:	call	.GetPhysAddr
		jc	.Ret
		mov	ebp,esi
		mov	esi,ebx
		call	K_CopyOut
		jc	.Ret
		sub	esi,ebx			; ESI=number of bytes copied
		add	ebp,esi			; source += size
		sub	eax,esi			; counter -= size
		mov	esi,ebp			; Restore source address
.Ret:		ret


		; Subroutine: for linear address in ESI compute a physical
		; address and put it in EBX. EDX must contain page dir address.
.GetPhysAddr:	push	esi
		mov	ebp,esi
		and	ebp,ADDR_OFSMASK		; EBP=offset
		mov	ebx,esi
		shr	ebx,PAGEDIRSHIFT		; EBX=PDE number
		mov	ebx,[edx+ebx*4]			; EBX=page table addr.
		cmp	ebx,PG_DISABLE			; Page table present?
		stc
		je	.Quit				; No, bad address
		and	ebx,PGENTRY_ADDRMASK		; Mask control bits
		and	esi,ADDR_PTEMASK
		shr	esi,PAGESHIFT			; ESI=PTE number
		mov	ebx,[ebx+esi*4]			; EBX=page address
		cmp	ebx,PG_DISABLE			; Is a page present?
		stc
		je	.Quit				; No, bad address
		and	ebx,PGENTRY_ADDRMASK		; Mask control bits
		add	ebx,ebp				; EBX=physical address
		clc
.Quit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; K_CopyIn - copy data from user to kernel space.
		; Input: ESI=source address,
		;	 ECX=size in bytes,
		;	 EDI=destination address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc K_CopyIn
		push	eax
		add	esi,USERAREASTART
		jc	CpFailed
		mov	eax,ecx
		cmp	eax,40000000h
		jae	CpFailed
		add	eax,esi
		jc	CpFailed
		shr	ecx,2
		rep	movsd
		sub	eax,esi
		jnz	CpAlign
		pop	eax
		ret

CpFailed:	pop	eax
		stc
		ret
endp		;---------------------------------------------------------------


		; K_CopyOut - copy data from kernel to user space.
		; Input: ESI=source address,
		;	 ECX=size in bytes,
		;	 EDI=destination address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc K_CopyOut
		push	eax
		add	edi,USERAREASTART
		jc	CpFailed
		mov	eax,ecx
		cmp	eax,40000000h
		jae	CpFailed
		add	eax,edi
		jc	CpFailed
		shr	ecx,2
		rep	movsd
		sub	eax,edi
		jnz	CpAlign
		pop	eax
		ret

		; Handle the last parts of the unaligned data
CpAlign:	test	eax,2
		jz	.1
		movsw
.1:		test	eax,1
		jz	.2
		movsb
.2:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; MemSet - fill memory with a constant byte.
		; Input: EBX=block address,
		;	 ECX=block size,
		;	 AL=value.
		; Output: none.
proc MemSet
		mpush	eax,ecx,edi
		mov	edi,ebx
		mov	ah,al
		cld
		shr	ecx,byte 1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; BZero - fill memory with a NULL.
		; Input: EBX=block address,
		;	 ECX=block size.
		; Output: none.
proc BZero
		mpush	eax,ecx,edi
		mov	edi,ebx
		xor	eax,eax
		cld
		shr	ecx,1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------
