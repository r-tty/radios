;-------------------------------------------------------------------------------
;  cfs_dops.asm - directory operations.
;-------------------------------------------------------------------------------

		; CFS_CreateDir - create a directory.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_CreateDir near
		mov	cl,DOP_MkDir
		call	CFS_DirectoryOperation
		ret
endp		;---------------------------------------------------------------


		; CFS_ChangeDir - change directory.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ChangeDir near
		mov	cl,DOP_ChDir
		call	CFS_DirectoryOperation
		ret
endp		;---------------------------------------------------------------


		; CFS_RemoveDir - remove directory.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_RemoveDir near
		mov	cl,DOP_RmDir
		call	CFS_DirectoryOperation
		ret
endp		;---------------------------------------------------------------


; --- Working routines ---

		; CFS_DirectoryOperation - perform directory operation.
		; Input: EAX=PID,
		;	 ESI=pointer to directory name,
		;	 CL=operation code.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_DirectoryOperation near
		push	ebx edx
		push	esi
		call	CFS_GetLPfromName
		pop	esi
		jc	short @@Exit
		call	CFS_LPtoFSdrvID
		jc	short @@Exit

		xor	ch,ch
		push	ebx
		push	DRVF_Control
		mov	[esp+2],cx
		call	DRV_CallDriver

@@Exit:		pop	edx ebx
		ret
endp		;---------------------------------------------------------------
