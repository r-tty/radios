;*******************************************************************************
;  kheap.asm - kernel internal heap routines.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module kernel.kheap

%include "sys.ah"
%include "errors.ah"

%define	RSRVBASEMEM	64		; Size of reserved base memory area (KB)
%define	MAXKHBLOCKS	256

; Kernel heap memory block structure
struc tKHB
.Handle		RESW	1
.Size		RESD	1
.Next		RESD	1
.Prev		RESD	1
.Attr		RESW	1
endstruc


; --- Exports ---

global KH_Init, KH_Alloc, KH_Free, KH_FillWithFF
global KH_Bottom, KH_Top


; --- Imports ---


; --- Variables ---

section .bss

KH_Bottom	RESD	1
KH_Top		RESD	1
KH_FstBlAddr	RESD	1



; --- Procedures ---

section .text

		; KH_Init - initialize kernel heap.
		; Input: EBX=address of heap bottom,
		;	 EDX=address of heap top.
		; Output: none.
proc KH_Init
		mov	[KH_Bottom],ebx
		mov	[KH_Top],edx
		mov	dword [KH_FstBlAddr],0
		ret
endp		;---------------------------------------------------------------


		; KH_FindLast - find last allocated block.
		; Input: none.
		; Output: CF=0 - OK: AX=last block handle,
		;		     EBX=last block address.
		;	  CF=1 - error, AX=error code,
		;
proc KH_FindLast
		mov	eax,[KH_FstBlAddr]
		or	eax,eax
		jz	short .Err1		; Error 1: heap is empty
		mov	ebx,eax

.Search:	mov	eax,[eax+tKHB.Next]
		or	eax,eax
		jz	short .Found
                cmp	eax,[KH_Top]
                jae	short .Err2		; Error 2: heap destroyed
		mov	ebx,eax
		jmp	.Search

.Found:		mov	ax,[ebx+tKHB.Handle]
		clc
		ret

.Err1:		mov	ax,ERR_KH_Empty
		jmp	short .Error
.Err2:		mov	ax,ERR_KH_Destroyed
.Error:		stc
		ret
endp		;---------------------------------------------------------------


		; KH_GetHdrAddr - get block header address.
		; Input: AX=block handle.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc KH_GetHdrAddr
		mov	ebx,[KH_FstBlAddr]
		or	ebx,ebx
		jz	short .Err1		; Error 1: heap is empty

.Search:	cmp	ax,[ebx+tKHB.Handle]
		je	.Found
		mov	ebx,[ebx+tKHB.Next]
		or	ebx,ebx
		jz	short .Err2		; Error 2: block not found
		cmp	eax,[KH_Top]
		jae	short .Err3		; Error 3: heap destroyed
		jmp	.Search

.Found:		clc
		ret

.Err1:		mov	ax,ERR_KH_Empty
		jmp	short .Error
.Err2:		mov	ax,ERR_KH_BlNotFound
		jmp	short .Error
.Err3:		mov	ax,ERR_KH_Destroyed
.Error:		stc
		ret
endp		;---------------------------------------------------------------


		; KH_Alloc - allocate memory block in heap.
		; Input: ECX - block size.
		; Output: CF=0 - OK:
		;		  AX=block handle,
		;		  EBX=block begin address (without header!),
		;		  ECX=aligned size (para);
		;	  CF=1 - error, AX=error code.
proc KH_Alloc
		push	edx
		call	KH_FindLast			; Get ptr to last block
		jnc	short .NotFirst		; Continue if no errors
		cmp	ax,ERR_KH_Empty			; Heap is empty?
		jne	short .Error			; No, another error
		mov	ebx,[KH_Bottom]			; Set first block addr
		mov	[KH_FstBlAddr],ebx
		mov	ax,1				; handle
		xor	edx,edx				; previous address
		jmp	short .SetFields

.NotFirst:	inc	ax				; AX=new block handle
		cmp	ax,MAXKHBLOCKS
		je	short .Err1			; Error: no mem handle
		mov	edx,ebx				; EDX=prev block addr
		add	ebx,[ebx+tKHB.Size]
		add	ebx,tKHB_size
		mov	[edx+tKHB.Next],ebx

.SetFields:	test	ecx,0Fh				; Align size?
		jz	short .NoSzCorr
		shr	ecx,4				; Paragraph correction
		inc	ecx
		shl	ecx,4
.NoSzCorr:	mov	[ebx+tKHB.Handle],ax
		mov	[ebx+tKHB.Size],ecx
		mov	dword [ebx+tKHB.Next],0
		mov	[ebx+tKHB.Prev],edx
		mov	word [ebx+tKHB.Attr],0
		add	ebx,tKHB_size
		clc
		jmp	short .Exit

.Err1:		mov	ax,ERR_KH_NoHandles
.Error:		stc
.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; KH_Free - free block space.
		; Input: AX=block handle.
                ; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc KH_Free
		mpush	ebx,edx
		call	KH_GetHdrAddr
		jc	.Exit

		cmp	dword [ebx+tKHB.Prev],0		; First block?
		jne	short .NotFirst
		cmp	dword [ebx+tKHB.Next],0		; Only one block?
		jne	short .NotFirst

		mov	dword [KH_FstBlAddr],0
		jmp	short .OK

.NotFirst:	mov	edx,[ebx+tKHB.Prev]
		push	dword [ebx+tKHB.Next]
		pop	dword [edx+tKHB.Next]
		cmp	dword [ebx+tKHB.Next],0
		je	short .OK
		mov	edx,[ebx+tKHB.Next]
		push	dword [ebx+tKHB.Prev]
		pop	dword [edx+tKHB.Prev]
.OK:		clc
		jmp	short .Exit

.Error:	stc
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; KH_GetState - get kernel heap state.
		; Input: none.
		; Output: CF=0 - OK:
		;		  ECX=total allocated space;
		;		  EDX=total number of allocated blocks.
		;	  CF=1 - error, AX=error code.
proc KH_GetState
		push	ebx
		mov	ebx,[KH_FstBlAddr]
                xor	ecx,ecx			; Initialize counters
		xor	edx,edx

.Loop:		or	ebx,ebx
		jz	short .OK
		add	ecx,[ebx+tKHB.Size]
		add	ecx,tKHB_size
		inc	dx
		mov	ebx,[ebx+tKHB.Next]
		cmp	ebx,[KH_Top]
		jae	short .Err		; Error: heap destroyed
		jmp	.Loop
.OK:		clc
		jmp	short .Exit

.Err:		mov	ax,ERR_KH_Destroyed
		stc
.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; KH_GetFreeSpace - get kernel heap free space.
		; Input: none.
		; Output: CF=0 - OK, ECX=free space;
		;	  CF=1 - error, AX=error code.
proc KH_GetFreeSpace
		mpush	ebx,edx
		call	KH_GetState
		jc	.Exit
		mov	edx,ecx
		mov	ecx,[KH_Top]
		sub	ecx,[KH_Bottom]
		sub	ecx,edx
		clc
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; KH_FillWithFF - fill memory block with -1.
		; Input: EBX=block address,
		;	 ECX=block size.
		; Output: none.
proc KH_FillWithFF
		mpush	eax,ecx,edi
		mov	edi,ebx
		xor	eax,eax
		dec	eax
		cld
		shr	ecx,1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------

