;-------------------------------------------------------------------------------
; cfs_misc.asm - miscellaneous routines.
;-------------------------------------------------------------------------------

; --- Exports ---

global CFS_LPtoDevID, CFS_SetCurrentLP
global CFS_GetRootIndex, CFS_SetRootIndex
global CFS_GetCurrentIndex, CFS_SetCurrentIndex


; --- Imports ---


; --- Code ---

		; CFS_SetCurrentLP - set current file system link point
		;		     for process.
		; Input: EAX=PID,
		;	 DL=linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_SetCurrentLP
		push	ebx
		mPID2PDA
		push	ebx
		call	CFS_LPtoFSdrvID
		pop	ebx
		jc	.Done
		mov	[ebx+tProcDesc.FSLP],dl
		clc
.Done:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_LPtoDevID - get device ID from FS linkpoint number.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EDX=device ID;
		;	  CF=1 - error, AX=error code.
		; Note: if device is not linked - returns error.
proc CFS_LPtoDevID
		push	ebx
		call	CFS_GetLPStructAddr
		jc	.Done
		mov	edx,[ebx+tCFSLinkPoint.DevID]
		or	edx,edx
		jz	.Err
		clc
		jmp	short .Done

.Err:		mov	ax,ERR_FS_NotLinked
		stc
.Done:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_LPtoFSdrvID - get file system driver ID
		;		    from FS linkpoint number.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EBX=FS driver ID;
		;	  CF=1 - error, AX=error code.
		; Note: if file system is not linked - returns error.
proc CFS_LPtoFSdrvID
		call	CFS_GetLPStructAddr
		jc	.Done
		mov	ebx,[ebx+tCFSLinkPoint.FSdrvID]
		or	ebx,ebx
		jz	.Err
		clc
		ret

.Err:		mov	ax,ERR_FS_NotLinked
		stc
.Done:		ret
endp		;---------------------------------------------------------------


		; CFS_GetRootIndex - get a root index by FSLP.
		; Input: DL=FSLP.
		; Output: CF=0 - OK, EBX=index;
		;	  CF=1 - error, AX=error code.
proc CFS_GetRootIndex
		call	CFS_GetLPStructAddr
		jc	.Done
		mov	ebx,[ebx+tCFSLinkPoint.RootIndex]
		clc
.Done:		ret
endp		;---------------------------------------------------------------


		; CFS_SetRootIndex - Set root index for FSLP.
		; Input: DL=FSLP,
		;	 EBX=new index.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_SetRootIndex
		mpush	ebx,ecx
		mov	ecx,ebx
		call	CFS_GetLPStructAddr
		jc	.Done
		mov	[ebx+tCFSLinkPoint.RootIndex],ecx
.Done:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_GetCurrentIndex - get current disk index for process.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=index;
		;	  CF=1 - error, AX=error code.
proc CFS_GetCurrentIndex
		mPID2PDA
		mov	ebx,[ebx+tProcDesc.CurrDirIndex]
		ret
endp		;---------------------------------------------------------------


		; CFS_SetCurrentIndex - set current disk index for process.
		; Input: EAX=PID,
		;	 EBX=index.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_SetCurrentIndex
		push	edx
		mov	edx,ebx
		mPID2PDA
		mov	[ebx+tProcDesc.CurrDirIndex],edx
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; CFS_CheckDevLink - check whether device is linked or not.
		; Input: EDX=device ID.
		; Output: CF=0 - not linked,
		;	  CF=1 - linked.
proc CFS_CheckDevLink
		mpush	eax,ebx
		mov	eax,CFS_LPtable
		xor	bl,bl
.Loop:		cmp	edx,[eax+tCFSLinkPoint.DevID]
		je	short .Linked
		inc	bl
		cmp	bl,CFS_MaxLinkPoints
		je	short .OK
		add	eax,tCFSLinkPoint_size
		jmp	.Loop
.OK:		clc
		jmp	short .Exit
.Linked:	stc
.Exit:		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


		; CFS_GetLPStructAddr - get file system linkpoint structure
		;			address.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EBX=structure address;
		;	  CF=1 - error, AX=error code.
proc CFS_GetLPStructAddr
		cmp	dl,CFS_MaxLinkPoints
		jae	short .Err
		xor	ebx,ebx
		mov	bl,dl
		shl	ebx,tCFSLP_shift
		add	ebx,CFS_LPtable
		clc
		ret
.Err:		mov	ax,ERR_FS_BadLP
		stc
		ret
endp		;---------------------------------------------------------------


		; CFS_GetFHndStructAddr - get address of file handle structure.
		; Input: EAX=PID (0 for kernel),
		;	 EBX=file handle.
		; Output: CF=0 - OK, EDX=structure address;
		;	  CF=1 - error, AX=error code.
proc CFS_GetFHndStructAddr
		push	ebx
		mov	dl,bl
		mPID2PDA
		mov	ebx,[ebx+tProcDesc.FHandlesAddr]
		or	ebx,ebx
		jc	short .Err1
		cmp	dl,[ebx+tProcDesc.NumFHandles]
		jae	short .Err2
		and	edx,0FFh
		shl	edx,FHANDLESHIFT
		add	edx,ebx
		clc
		pop	ebx
		ret

.Err1:		mov	ax,ERR_FS_BadFHandleTable
		jmp	short .Error
.Err2:		mov	ax,ERR_FS_InvFileHandle
.Error:		stc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_FindFreeFH - find free file handle.
		; Input: EAX=PID.
		; Output: CF=0 - OK:
		;		    EBX=handle,
		;		    EDX=address of file handle structure;
		;	  CF=1 - error, AX=error code.
proc CFS_FindFreeFH
		push	edi
		mPID2PDA				; Get PDA address
		mov	edi,ebx				; Keep it
		mov	edx,[ebx+tProcDesc.FHandlesAddr]
		add	edx,(tCFS_FHandle_size)*(STDERR+1)
		xor	ebx,ebx
		mov	bl,STDERR+1

.Loop:		cmp	byte [edx+tCFS_FHandle.FSLP],-1
		je	short .OK
		inc	bl
		cmp	bl,[edi+tProcDesc.NumFHandles]
		je	short .Err
		add	edx,tCFS_FHandle_size
		jmp	.Loop
.OK:		clc
		pop	edi
		ret

.Err:		mov	ax,ERR_FS_NoFreeHandles
		stc
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; CFS_LPisLinked - check whether linkpoint linked or not.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, linked;
		;	  CF=1 - error, AX=error code (not linked).
proc CFS_LPisLinked
		push	ebx
		call	CFS_GetLPStructAddr		; Get structure address
		jc	short .Exit
		cmp	dword [ebx+tCFSLinkPoint.FSdrvID],0 ; Get FS driver ID
		je	short .Err
		clc
		jmp	short .Exit

.Err:		mov	ax,ERR_FS_NotLinked
		stc
.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------
