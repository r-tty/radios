;-------------------------------------------------------------------------------
;  path.asm - path to index conversion routines.
;-------------------------------------------------------------------------------

		; CFS_Path2Index - convert path to index.
		; Input: EAX=PID,
		;	 ESI=pointer to path.
		; Output: CF=0 - OK, ESI=index address;
		;	  CF=1 - error, AX=error code.
proc CFS_Path2Index near
@@pid		EQU	ebp-4
@@fsdrvid	EQU	ebp-8

		push	ebp
		mov	ebp,esp
		sub	esp,4
		push	ebx ecx edx edi

		mov	[@@pid],eax
		call	CFS_GetLPfromName		; Get FSLP in DL
		jc	short @@Exit

		xor	ebx,ebx				; For root index=0
		mov	al,[esi]
		cmp	al,[CFS_PathSepar]		; Start from root?
		je	short @@GetRootInd

		mov	eax,[@@pid]
		call	K_GetProcDescAddr
		jc	short @@Exit
		mov	ebx,[ebx+tProcDesc.CurrDirIndex] ; Get current dir index
		jmp	short @@Begin

@@GetRootInd:   call	CFS_GetLPStructAddr
                and	edx,0FFh
		mov	ebx,[ebx+tCFSLinkPoint.RootIndex]

@@Begin:	call	CFS_GetIndex
		jc	short @@Exit


@@Exit:		pop	edi edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------
