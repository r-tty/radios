;-------------------------------------------------------------------------------
;  dirops.nasm - directory operations.
;-------------------------------------------------------------------------------

; --- Exports ---

library kernel.misc
extern StrLComp


section .data

DirName_Curr	DB	"."
		TIMES	FILENAMELEN-1 DB ' '
		DB	0
DirName_Parent	DB	".."
		TIMES	FILENAMELEN-2 DB ' '
		DB	0



section .text

		; RFS_CreateDir - create a directory.
		; Input: EBX=owning directory disk index,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK, EBX=index of created directory;
		;	  CF=1 - error, AX=error code.
proc RFS_CreateDir
%define	.owningdir	ebp-4
%define	.direntry	ebp-4-DIRENTRYSIZE		; Name buffer

		prologue 4+DIRENTRYSIZE			; Save space
		mpush	ecx,edx,esi,edi			; for directory entry

		mov	[.owningdir],ebx		; Save owning dir index
		mov	ecx,FILENAMELEN
		lea	edi,[.direntry]			; Move name to stack
		call	CFS_MoveNameToStack
		jc	near .Exit

		xor	ecx,ecx
		mov	cl,FILENAMELEN
		mov	esi,DirName_Curr		; Check for '.' and '..'
		call	StrLComp
		or	al,al
		jz	short .Err1
		mov	esi,DirName_Parent
		call	StrLComp
		or	al,al
		jz	short .Err1

		mov	esi,edi
		call	RFS_SearchForFileName		; See if name exists
		jnc	short .Err2			; If exists - error
		cmp	ax,ERR_FS_FileNotFound		; Else see if not found
		jne	short .Error			; No, service other errors

		call	RFS_AllocDirBlock		; Else allocate
		jc	short .Exit			; the directory page
		mov	ebx,eax
		call	BUF_MarkDirty			; Dirty buffer

		bts	dword [esi+tDirPage.Flags],DFL_LEAF	; Mark as leaf
		or	word [esi+tDirPage.Type],FT_DIR		; and directory
		call	RFS_CompressTime
		mov	[esi+tDirPage.IAttr+tCFS_IndexAttrs.LWtime],eax
		mov	eax,[.owningdir]
		mov	[esi+tDirPage.Parent],eax	; Store parent dir

		lea	edi,[esi+tDirPage.NM]		; Move directory name
		lea	esi,[.direntry]			; to allocated page
		push	esi
		mov	ecx,FILENAMELEN / 4
		rep	movsd
		pop	esi				; Save created dir page
		mov	[esi+tDirEntry.Entry],ebx	; in entry
		mov	dword [esi+tDirEntry.UU],0	; Clear other dir params
		mov	dword [esi+tDirEntry.More],0

		mov	ebx,[.owningdir]
		push	esi
		call	RFS_InsertFileName		; Go insert the file name
		jmp	short .Exit

.Err1:		mov	ax,ERR_FS_InvDirName
		jmp	short .Error
.Err2:		mov	ax,ERR_FS_DirExists
.Error:		stc
.Exit:		mpop	edi,esi,edx,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_RemoveDir - remove a directory.
		; Input: EBX=owning directory disk index,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: removes only empty directories.
proc RFS_RemoveDir
%define	.owningdir	ebp-4
%define	.fslp		ebp-8
%define	.direntry	ebp-8-DIRENTRYSIZE		; Name buffer

		prologue 8+DIRENTRYSIZE			; Save space
		mpush	ecx,edx,esi,edi			; for directory entry
		mov	[.owningdir],ebx		; Keep owning dir index
		mov	ecx,FILENAMELEN
		lea	edi,[.direntry]			; Move name to stack
		call	CFS_MoveNameToStack
		jc	.Exit

		xor	ecx,ecx
		mov	cl,FILENAMELEN
		mov	esi,DirName_Curr		; Check for '.' and '..'
		call	StrLComp
		or	al,al
		jz	short .Err1
		mov	esi,DirName_Parent
		call	StrLComp
		or	al,al
		jz	short .Err1

		mov	esi,edi
		call	RFS_SearchForFileName		; See if name exists
		jc	short .Exit			; If don't exists - error
		mov	ebx,eax

		mov	[.fslp],dl			; Keep FSLP
		call	CFS_LPtoDevID
		jc	short .Exit
		call	BUF_ReadBlock
		jc	short .Exit
		test	word [esi+tDirPage.Type],FT_DIR	; Directory?
		jz	short .Err3
		call	RFS_GetNumOfFiles		; Get number of files
		jc	short .Exit			; in directory
		or	eax,eax				; Empty?
		jnz	short .Err2

		mov	dl,[.fslp]
                mov	eax,ebx
		call	RFS_DeallocBlock
		jc	short .Exit

		mov	ebx,[.owningdir]
		xor	eax,eax
		push	eax
		lea	esi,[.direntry]
		push	esi
		call	RFS_DeleteFileName		; Delete directory name
		jc	short .Exit
		call	BUF_FlushAll			; Flush buffers
		xor	eax,eax

.Exit:		mpop	edi,esi,edx,ecx
		epilogue
		ret

.Err1:		mov	ax,ERR_FS_InvDirName
		stc
		jmp	.Exit
.Err2:		mov	ax,ERR_FS_DirNotEmpty
		stc
		jmp	.Exit
.Err3:		mov	ax,ERR_FS_NotDirectory
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; CLFS_ChangeDir - change a directory.
		; Input: EBX=up-level directory disk index,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ChangeDir

		ret
endp		;---------------------------------------------------------------

