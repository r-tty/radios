;-------------------------------------------------------------------------------
;  cfs_dops.asm - directory operations.
;-------------------------------------------------------------------------------

; --- Exports ---

global CFS_CreateDir, CFS_ChangeDir, CFS_RemoveDir

		; CFS_CreateDir - create a directory.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_CreateDir
		mov	cl,DOP_MkDir
		call	CFS_DirectoryOperation
		ret
endp		;---------------------------------------------------------------


		; CFS_ChangeDir - change directory.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ChangeDir
		mov	cl,DOP_ChDir
		call	CFS_DirectoryOperation
		ret
endp		;---------------------------------------------------------------


		; CFS_RemoveDir - remove directory.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_RemoveDir
		mov	cl,DOP_RmDir
		call	CFS_DirectoryOperation
		ret
endp		;---------------------------------------------------------------


		; CFS_OpenDir - open a directory for reading.
		; Input: ESI=pointer to directory name.
		; Output: CF=0 - OK, EBX=directory handle;
		;	  CF=1 - error, AX=error code.
proc CFS_OpenDir
		ret
endp		;---------------------------------------------------------------


		; CFS_ReadDir - read one directory item.
		; Input: EBX=directory handle,
		;	 EDI=pointer to buffer.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ReadDir
		ret
endp		;---------------------------------------------------------------


		; CFS_SeekDir - set directory position.
		; Input: EBX=directory handle,
		;	 ECX=new position (from begin).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_SeekDir
		ret
endp		;---------------------------------------------------------------


		; CFS_CloseDir - close a directory.
		; Input: EBX=directory handle.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_CloseDir
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; CFS_DirectoryOperation - perform directory operation.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name,
		;	 CL=operation code.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_DirectoryOperation
		mpush	ebx,edx
		push	esi
		call	CFS_GetLPbyName
		pop	esi
		jc	short .Exit
		call	CFS_LPtoFSdrvID
		jc	short .Exit

		xor	ch,ch
		push	ebx
		push	dword DRVF_Control
		mov	[esp+2],cx
		call	DRV_CallDriver

.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------
