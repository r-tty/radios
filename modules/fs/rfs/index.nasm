;-------------------------------------------------------------------------------
;  index.nasm - disk index read/write routines.
;-------------------------------------------------------------------------------

; --- Interface procedures ---

section .text

		; RFS_ReadIndex - read index.
		; Input: ESI=index address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ReadIndex
		mpush	ebx,ecx,edx,esi
		mov	ecx,esi				; Keep index address

		mov	dl,[esi+tCFS_Index.FSLP]
		call	CFS_LPtoDevID			; Get device ID
		jc	short .Exit
		mov	ebx,[esi+tCFS_Index.Block]	; Load file or
		call	BUF_ReadBlock			; directory page
		jc	short .Exit

		test	word [esi+DISKINDEX_TYPE],FT_DIR ; Directory?
		jnz	short .Dir

		mov	ax,[esi+tFilePage.AR]		; Else assume a file
		mov	[ecx+tCFS_Index.AR],ax		; Copy access rights
		lea	esi,[esi+tFilePage.IAttr]
		jmp	short .CopyAttrs

.Dir:		mov	ax,[esi+tDirPage.AR]
		mov	[ecx+tCFS_Index.AR],ax		; Copy access rights
		lea	esi,[esi+tDirPage.IAttr]

.CopyAttrs:	lea	edi,[ecx+tCFS_Index.Attr]	; Copy attributes
		mov	ecx,INDEXATTRSIZE/4
		cld
		rep	movsd

.Exit:		mpop	esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_WriteIndex - write index to disk.
		; Input: ESI=index address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_WriteIndex
		mpush	ebx,ecx,edx,esi
		mov	ecx,esi				; Keep index address

		mov	dl,[esi+tCFS_Index.FSLP]
		call	CFS_LPtoDevID			; Get device ID
		jc	short .Exit
		mov	ebx,[esi+tCFS_Index.Block]	; Load file or
		call	BUF_ReadBlock			; directory page
		jc	short .Exit

		test	word [esi+DISKINDEX_TYPE],FT_DIR ; Directory?
		jnz	short .Dir

		mov	ax,[ecx+tCFS_Index.AR]		; Else assume a file
		mov	[esi+tFilePage.AR],ax		; Copy access rights
		lea	edi,[esi+tFilePage.IAttr]
		jmp	short .CopyAttrs

.Dir:		mov	ax,[ecx+tCFS_Index.AR]
		mov	[esi+tDirPage.AR],ax		; Copy access rights
		lea	edi,[esi+tDirPage.IAttr]

.CopyAttrs:	push	esi				; Keep buffer address
		lea	esi,[ecx+tCFS_Index.Attr]	; Copy attributes
		mov	ecx,INDEXATTRSIZE/4
		cld
		rep	movsd
		pop	esi				; Mark buffer
		call	BUF_MarkDirty			; as dirty

.Exit:		mpop	esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_AllocIndex - allocate index block.
		; Input: ESI=index address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_AllocIndex
		ret
endp		;---------------------------------------------------------------


		; RFS_ReleaseIndex - release index block.
		; Input: ESI=index address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ReleaseIndex
		ret
endp		;---------------------------------------------------------------

