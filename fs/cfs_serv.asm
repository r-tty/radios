;-------------------------------------------------------------------------------
;  cfs_serv.asm - service file system operations.
;-------------------------------------------------------------------------------

		; CFS_MakeFS - make file system.
		; Input: ESI=pointer to string with linkpoint,
		;	     or if ESI=0 - DL=linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_MakeFS near
		push	ebx edx edi
		or	esi,esi				; Need to count FSLP?
		jz	short @@Do			; No, it already in DL
		mov	edi,esi				; Else check FSLP name
		call	StrLen
		cmp	ecx,2
		jne	short @@Err1
		cmp	[byte esi+1],':'
		jne     short @@Err1
                call	CFS_GetLPfromName
		jc	short @@Exit
		mov	esi,edi				; Restore ESI

@@Do:		call	CFS_LPtoFSdrvID
		jc	short @@Exit
		mCallDriverCtrl ebx,FSF_MakeFS
		jc	short @@Exit

		mov	edi,ebx				; Store root dir index
		call	CFS_GetLPStructAddr
		jc	short @@Exit
		mov	[ebx+tCFSLinkPoint.RootIndex],edi
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_FS_InvFSLPname
@@Error:	stc
@@Exit:		pop	edi edx ebx
		ret
endp		;---------------------------------------------------------------
