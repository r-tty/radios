;*******************************************************************************
;  kheap.asm - kernel internal heap routines.
;  Copyright (c) 1998 RET & COM Research.
;*******************************************************************************

RSRVBASEMEM	EQU	64		; Size of reserved base memory area (KB)
MAXKHBLOCKS	EQU	256

; Kernel heap memory block structure
struc tKHB
 Handle		DW	?
 Size		DD	?
 Next		DD	?
 Prev		DD	?
 Attr		DW	?
ends

		; KH_Init - initialize kernel heap.
		; Input: EBX=address of heap bottom,
		;	 EDX=address of heap top.
		; Output: none.
proc KH_Init near
		mov	[KH_Bottom],ebx
		mov	[KH_Top],edx
		mov	[KH_FstBlAddr],0
		ret
endp		;---------------------------------------------------------------


		; KH_FindLast - find last allocated block.
		; Input: none.
		; Output: CF=0 - OK: AX=last block handle,
		;		     EBX=last block address.
		;	  CF=1 - error, AX=error code,
		;
proc KH_FindLast near
		mov	eax,[KH_FstBlAddr]
		or	eax,eax
		jz	short @@Err1		; Error 1: heap is empty
		mov	ebx,eax

@@Search:	mov	eax,[eax+tKHB.Next]
		or	eax,eax
		jz	short @@Found
                cmp	eax,[KH_Top]
                jae	short @@Err2		; Error 2: heap destroyed
		mov	ebx,eax
		jmp	@@Search

@@Found:	mov	ax,[ebx+tKHB.Handle]
		clc
		ret

@@Err1:		mov	ax,ERR_KH_Empty
		jmp	short @@Error
@@Err2:		mov	ax,ERR_KH_Destroyed
@@Error:	stc
		ret
endp		;---------------------------------------------------------------


		; KH_GetHdrAddr - get block header address.
		; Input: AX=block handle.
		; Output: CF=0 - OK, EBX=address;
		;	  CF=1 - error, AX=error code.
proc KH_GetHdrAddr near
		mov	ebx,[KH_FstBlAddr]
		or	ebx,ebx
		jz	short @@Err1		; Error 1: heap is empty

@@Search:	cmp	ax,[ebx+tKHB.Handle]
		je	@@Found
		mov	ebx,[ebx+tKHB.Next]
		or	ebx,ebx
		jz	short @@Err2		; Error 2: block not found
		cmp	eax,[KH_Top]
		jae	short @@Err3		; Error 3: heap destroyed
		jmp	@@Search

@@Found:	clc
		ret

@@Err1:		mov	ax,ERR_KH_Empty
		jmp	short @@Error
@@Err2:		mov	ax,ERR_KH_BlNotFound
		jmp	short @@Error
@@Err3:		mov	ax,ERR_KH_Destroyed
@@Error:	stc
		ret
endp		;---------------------------------------------------------------


		; KH_Alloc - allocate memory block in heap.
		; Input: ECX - block size.
		; Output: CF=0 - OK:
		;		  AX=block handle,
		;		  EBX=block begin address (without header!),
		;		  ECX=aligned size (para);
		;	  CF=1 - error, AX=error code.
proc KH_Alloc near
		push	edx
		call	KH_FindLast			; Get ptr to last block
		jnc	short @@NotFirst		; Continue if no errors
		cmp	ax,ERR_KH_Empty			; Heap is empty?
		jne	short @@Error			; No, another error
		mov	ebx,[KH_Bottom]			; Set first block addr
		mov	[KH_FstBlAddr],ebx
		mov	ax,1				; handle
		xor	edx,edx				; previous address
		jmp	short @@SetFields

@@NotFirst:	inc	ax				; AX=new block handle
		cmp	ax,MAXKHBLOCKS
		je	short @@Err1			; Error: no mem handle
		mov	edx,ebx				; EDX=prev block addr
		add	ebx,[ebx+tKHB.Size]
		add	ebx,size tKHB
		mov	[edx+tKHB.Next],ebx

@@SetFields:	test	ecx,0Fh				; Align size?
		jz	short @@NoSzCorr
		shr	ecx,4				; Paragraph correction
		inc	ecx
		shl	ecx,4
@@NoSzCorr:	mov	[ebx+tKHB.Handle],ax
		mov	[ebx+tKHB.Size],ecx
		mov	[ebx+tKHB.Next],0
		mov	[ebx+tKHB.Prev],edx
		mov	[ebx+tKHB.Attr],0
		add	ebx,size tKHB
		clc
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_KH_NoHandles
@@Error:	stc
@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; KH_Free - free block space.
		; Input: AX=block handle.
                ; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc KH_Free near
		push	ebx edx
		call	KH_GetHdrAddr
		jc	@@Exit

		cmp	[ebx+tKHB.Prev],0		; First block?
		jne	short @@NotFirst
		cmp	[ebx+tKHB.Next],0		; Only one block?
		jne	short @@NotFirst

		mov	[KH_FstBlAddr],0
		jmp	short @@OK

@@NotFirst:	mov	edx,[ebx+tKHB.Prev]
		push	[ebx+tKHB.Next]
		pop	[edx+tKHB.Next]
		cmp	[ebx+tKHB.Next],0
		je	short @@OK
		mov	edx,[ebx+tKHB.Next]
		push	[ebx+tKHB.Prev]
		pop	[edx+tKHB.Prev]
@@OK:		clc
		jmp	short @@Exit

@@Error:	stc
@@Exit:		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; KH_GetState - get kernel heap state.
		; Input: none.
		; Output: CF=0 - OK:
		;		  ECX=total allocated space;
		;		  EDX=total number of allocated blocks.
		;	  CF=1 - error, AX=error code.
proc KH_GetState near
		push	ebx
		mov	ebx,[KH_FstBlAddr]
                xor	ecx,ecx			; Initialize counters
		xor	edx,edx

@@Loop:		or	ebx,ebx
		jz	short @@OK
		add	ecx,[ebx+tKHB.Size]
		add	ecx,size tKHB
		inc	dx
		mov	ebx,[ebx+tKHB.Next]
		cmp	ebx,[KH_Top]
		jae	short @@Err		; Error: heap destroyed
		jmp	@@Loop
@@OK:		clc
		jmp	short @@Exit

@@Err:		mov	ax,ERR_KH_Destroyed
		stc
@@Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; KH_GetFreeSpace - get kernel heap free space.
		; Input: none.
		; Output: CF=0 - OK, ECX=free space;
		;	  CF=1 - error, AX=error code.
proc KH_GetFreeSpace near
		push	ebx edx
		call	KH_GetState
		jc	@@Exit
		mov	edx,ecx
		mov	ecx,[KH_Top]
		sub	ecx,[KH_Bottom]
		sub	ecx,edx
		clc
@@Exit:		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; KH_FillZero - fill memory block with zeroes.
		; Input: EBX=block address,
		;	 ECX=block size.
		; Output: none.
proc KH_FillZero near
		push	eax ecx edi
		mov	edi,ebx
		xor	eax,eax
		cld
		shr	ecx,1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		pop	edi ecx eax
		ret
endp		;---------------------------------------------------------------


		; KH_FillWithFF - fill memory block with -1.
		; Input: EBX=block address,
		;	 ECX=block size.
		; Output: none.
proc KH_FillWithFF near
		push	eax ecx edi
		mov	edi,ebx
		xor	eax,eax
		dec	eax
		cld
		shr	ecx,1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		pop	edi ecx eax
		ret
endp		;---------------------------------------------------------------

IFDEF DEBUG
public KH_Debug
proc KH_Debug near
	mov	eax,[KH_Bottom]
	call	PrintDwordHex
	mWrChar ' '
	mov	eax,[KH_Top]
	call	PrintDwordHex
	ret
endp
ENDIF
