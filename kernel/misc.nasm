;-------------------------------------------------------------------------------
; misc.nasm - miscellaneous kernel routines.
;-------------------------------------------------------------------------------

module kernel.misc

%include "sys.ah"
%include "errors.ah"
%include "biosdata.ah"
%include "pool.ah"
%include "cpu/paging.ah"

publicproc sys_CPUpageGet, sys_CPUpageSet
exportproc K_AllocateID, K_ReleaseID, K_InitIDbmap

externproc MemSet, PG_AllocContBlock

section .text

		; K_TableSearch - search in table.
		; Input: EBX=table address,
		;	 ECX=number of elements in table,
		;	 EAX=searching mask,
		;	 DL=size of table element,
		;	 DH=offset to target field in table element.
		; Output: CF=0 - OK:
		;	   EDX=element number,
		;	   EBX=element address;
		;	  CF=1 - not found.
proc K_TableSearch
		mpush	edx,esi,edi
		movzx	esi,dl
		movzx	edi,dh
		xor	edx,edx
.Loop:		test	[ebx+edi],eax
		jz	.Found
		add	ebx,esi
		inc	edx
		cmp	edx,ecx
		je	.NotFound
		jmp	.Loop
.Found:		clc
.Exit:		mpop	edi,esi,edx
		ret
.NotFound:	stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Initialize the ID bitmap.
		; Input: ECX=maximum number of IDs,
		;	 EBX=address of bitmap descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc K_InitIDbmap
		push	edi
		mov	edi,ebx
		mov	[edi+tIDbmapDesc.MaxIDs],ecx
		shr	ecx,3				; 8 bits per byte
		xor	dl,dl
		call	PG_AllocContBlock
		jc	.Exit
		mov	[edi+tIDbmapDesc.BMstart],ebx
		
		mov	al,0FFh				; All PIDs are free
		call	MemSet

.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; K_AllocateID - allocate a new ID from bitmap.
		; Input: EBX=address of bitmap descriptor.
		; Output: EAX=ID.
proc K_AllocateID
		mpush	ecx,esi
		mov	ecx,[ebx+tIDbmapDesc.MaxIDs]
		shr	ecx,5				; # of dwords
		mov	esi,[ebx+tIDbmapDesc.BMstart]
		sub	esi,byte 4
		
.Loop:		add	esi,byte 4
		bsf	eax,[esi]			; Look for free ID
		loopz	.Loop
		jz	.Err
		btr	[esi],eax
		sub	esi,[ebx+tIDbmapDesc.BMstart]
		shl	esi,3
		add	eax,esi
		clc
		
.Exit:		mpop	esi,ecx
		ret
		
.Err:		mov	ax,ERR_NoFreeID
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; K_ReleaseID - release ID.
		; Input: EBX=address of bitmap descriptor,
		;	 EAX=ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_ReleaseID
		cmp	eax,[ebx+tIDbmapDesc.MaxIDs]
		jae	.Err
		push	esi
		mov	esi,[ebx+tIDbmapDesc.BMstart]
		bts	[esi],eax
		pop	esi
		clc
		ret
		
.Err:		mov	ax,ERR_BadID
		stc
		ret
endp		;--------------------------------------------------------------


		; Get the information from CPU page
proc sys_CPUpageGet
		ret
endp		;--------------------------------------------------------------


		; Set the information in the CPU page
proc sys_CPUpageSet
		ret
endp		;--------------------------------------------------------------
