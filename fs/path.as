;-------------------------------------------------------------------------------
;  path.asm - path to index conversion routines.
;-------------------------------------------------------------------------------

; --- Exports ---

global CFS_Path2Index


; --- Procedures ---

		; CFS_Path2Index - convert path to index.
		; Input: EAX=PID,
		;	 ESI=pointer to path.
		; Output: CF=0 - OK, ESI=index address;
		;	  CF=1 - error, AX=error code.
proc CFS_Path2Index
%define	.pid		ebp-4
%define	.fsdrvid	ebp-8

		prologue 8
		mpush	ebx,ecx,edx,edi

		mov	[.pid],eax
		call	CFS_GetLPbyName			; Get FSLP in DL
		jc	short .Exit

		xor	ebx,ebx				; For root index=0
		mov	al,[esi]
		cmp	al,[CFS_PathSepar]		; Start from root?
		je	short .GetRootInd

		mov	eax,[.pid]
		call	K_GetProcDescAddr
		jc	short .Exit
		mov	ebx,[ebx+tProcDesc.CurrDirIndex] ; Get current dir index
		jmp	short .Begin

.GetRootInd:	call	CFS_GetLPStructAddr
		mov	ebx,[ebx+tCFSLinkPoint.RootIndex]

.Begin:		call	CFS_GetIndex
		jc	short .Exit


.Exit:		mpop	edi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------
