;-------------------------------------------------------------------------------
; cfs_misc.asm - miscellaneous routines.
;-------------------------------------------------------------------------------


		; CFS_SetCurrentLP - set current file system linkpoint.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_SetCurrentLP near
		push	ebx
		call	CFS_LPtoFSdrvID
		jc	short @@Exit
		mov	[CFS_CurrLP],dl
		clc
@@Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_LPtoDevID - get device ID from FS linkpoint number.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EDX=device ID;
		;	  CF=1 - error, AX=error code.
		; Note: if device is not linked - returns error.
proc CFS_LPtoDevID near
		push	ebx
		call	CFS_GetLPStructAddr
		mov	edx,[ebx+tCFSLinkPoint.DevID]
		or	edx,edx
		jz	short @@Err
		clc
		jmp	short @@Exit

@@Err:		mov	ax,ERR_FS_NotLinked
		stc
@@Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_LPtoFSdrvID - get file system driver ID
		;		    from FS linkpoint number.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EBX=FS driver ID;
		;	  CF=1 - error, AX=error code.
		; Note: if file system is not linked - returns error.
proc CFS_LPtoFSdrvID near
		call	CFS_GetLPStructAddr
		mov	ebx,[ebx+tCFSLinkPoint.FSdrvID]
		or	ebx,ebx
		jz	short @@Err
		clc
		ret

@@Err:		mov	ax,ERR_FS_NotLinked
		stc
		ret
endp		;---------------------------------------------------------------


		; CFS_CheckDevLink - check whether device is linked or not.
		; Input: EDX=device ID.
		; Output: CF=0 - not linked,
		;	  CF=1 - linked.
proc CFS_CheckDevLink near
		push	eax ebx
		mov	eax,[CFS_LPtableAddr]
		xor	bl,bl
@@Loop:		cmp	edx,[eax+tCFSLinkPoint.DevID]
		je	short @@Linked
		inc	bl
		cmp	bl,[CFS_NumOfLPs]
		je	short @@OK
		add	eax,size tCFSLinkPoint
		jmp	@@Loop
@@OK:		clc
		jmp	short @@Exit
@@Linked:	stc
@@Exit:		pop	ebx eax
		ret
endp		;---------------------------------------------------------------


		; CFS_GetLPStructAddr - get file system linkpoint structure
		;			address.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EBX=structure address;
		;	  CF=1 - error, AX=error code.
proc CFS_GetLPStructAddr near
		cmp	dl,[CFS_NumOfLPs]
		jae	short @@Err
		xor	ebx,ebx
		mov	bl,dl
		shl	ebx,4
		add	ebx,[CFS_LPtableAddr]
		clc
		ret
@@Err:		mov	ax,ERR_FS_BadLP
		stc
		ret
endp		;---------------------------------------------------------------


		; CFS_GetFHndStructAddr - get address of file handle structure.
		; Input: EAX=PID (0 for kernel),
		;	 EBX=file handle.
		; Output: CF=0 - OK, EDX=structure address;
		;	  CF=1 - error, AX=error code.
proc CFS_GetFHndStructAddr near
		push	ebx
		mov	dl,bl
		call	K_GetProcDescAddr
		jc	short @@Exit
		mov	ebx,[ebx+tProcDesc.FHandlesAddr]
		or	ebx,ebx
		jc	short @@Err1
		cmp	dl,[ebx+tProcDesc.NumFHandles]
		jae	short @@Err2
		and	edx,0FFh
		shl	edx,FHANDLESHIFT
		add	edx,ebx
		clc
@@Exit:		pop	ebx
		ret

@@Err1:		mov	ax,ERR_FS_BadFHandleTable
		jmp	short @@Error
@@Err2:		mov	ax,ERR_FS_InvFileHandle
@@Error:	stc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_FindFreeFH - find free file handle.
		; Input: EAX=PID.
		; Output: CF=0 - OK:
		;		    EBX=handle,
		;		    EDX=address of file handle structure;
		;	  CF=1 - error, AX=error code.
proc CFS_FindFreeFH near
		push	edi
		call	K_GetProcDescAddr		; Get address
		jc	short @@Exit			; of process descriptor
		mov	edi,ebx				; Keep it
		mov	edx,[ebx+tProcDesc.FHandlesAddr]
		add	edx,(size tCFS_FHandle)*(CFS_STDERR+1)
		xor	ebx,ebx
		mov	bl,CFS_STDERR+1

@@Loop:		cmp	[edx+tCFS_FHandle.FSLP],-1
		je	short @@OK
		inc	bl
		cmp	bl,[edi+tProcDesc.NumFHandles]
		je	short @@Err
		add	edx,size tCFS_FHandle
		jmp	@@Loop
@@OK:		clc
@@Exit:		pop	edi
		ret

@@Err:		mov	ax,ERR_FS_NoFreeHandles
		stc
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; CFS_LPisLinked - check whether linkpoint linked or not.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, linked;
		;	  CF=1 - error, AX=error code (not linked).
proc CFS_LPisLinked near
		push	ebx
		call	CFS_GetLPStructAddr		; Get structure address
		jc	short @@Exit
		cmp	[ebx+tCFSLinkPoint.FSdrvID],0	; Get FS driver ID
		je	short @@Err
		clc
		jmp	short @@Exit

@@Err:		mov	ax,ERR_FS_NotLinked
		stc
@@Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------
