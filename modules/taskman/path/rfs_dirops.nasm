;-------------------------------------------------------------------------------
; rfs_dirops.nasm - directory operations.
;-------------------------------------------------------------------------------

module tm.pathman.rfs_dirops

%include "errors.ah"
%include "time.ah"
%include "tm/inode.ah"
%include "tm/rfs.ah"
%include "rm/stat.ah"

publicdata DirName_Root, DirName_Curr, DirName_Parent
externproc RFS_AllocDirBlock, RFS_DeallocBlock
externproc RFS_SearchForFileName
externproc RFS_InsertFileName, RFS_DeleteFileName
externproc RFS_GetNumOfFiles

library $libc
importproc _strncmp, _ClockTime

section .data

DirName_Root	DB	"/"
		TIMES	RFS_FILENAMELEN-1 DB ' '
		DB	0
DirName_Curr	DB	"."
		TIMES	RFS_FILENAMELEN-1 DB ' '
		DB	0
DirName_Parent	DB	".."
		TIMES	RFS_FILENAMELEN-2 DB ' '
		DB	0



section .text

		; RFS_CreateDir - create a directory.
		; Input: EBX=head directory node,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK, EBX=index of created directory;
		;	  CF=1 - error, AX=error code.
proc RFS_CreateDir
		locals	headnode
		locauto	timestamp, Qword_size
		locauto	direntry, tDirEntry_size

		prologue
		mpush	ecx,edx,esi,edi

		mov	[%$headnode],ebx		; Save head node
		mov	ecx,RFS_FILENAMELEN
		lea	edi,[%$direntry]		; Move name to stack
	;	call	MoveNameToStack			; XXX
		jc	near .Exit

		; Check if trying to create '.' or '..'
		Ccall	_strncmp, DirName_Curr, edi, RFS_FILENAMELEN
		or	eax,eax
		jz	near .Err1
		Ccall	_strncmp, DirName_Parent, edi, RFS_FILENAMELEN
		or	eax,eax
		jz	.Err1
		
		mov	esi,edi
		call	RFS_SearchForFileName		; See if name exists
		jnc	short .Err2			; If exists - error
		cmp	ax,ENOENT			; Else see if not found
		jne	short .Error			; No, service other errors
		call	RFS_AllocDirBlock		; Else allocate
		jc	.Exit				; the directory node
		mov	ebx,eax

		bts	dword [esi+tDirNode.Flags],RFS_DFL_LEAF	; Mark as leaf
		or	word [esi+tDirNode.Type],ST_MODE_IFDIR	; and directory
		lea	eax,[%$timestamp]
		Ccall	_ClockTime, CLOCK_REALTIME, 0, eax
		mov	eax,[%$timestamp]
		mov	[esi+tDirNode.IAttr+tInodeAttr.LWtime],eax
		mov	eax,[%$timestamp+4]
		mov	[esi+tDirNode.IAttr+tInodeAttr.LWtime+4],eax
		mov	eax,[%$headnode]
		mov	[esi+tDirNode.Parent],eax	; Store parent dir

		lea	edi,[esi+tDirNode.Name]		; Move directory name
		lea	esi,[%$direntry]		; to allocated page
		push	esi
		mov	ecx,RFS_FILENAMELEN / 4
		rep	movsd
		pop	esi				; Save created dir page
		mov	[esi+tDirEntry.Entry],ebx	; in entry
		mov	dword [esi+tDirEntry.More],0

		mov	ebx,[%$headnode]
		push	esi
		call	RFS_InsertFileName		; Go insert the file name
.Exit:		mpop	edi,esi,edx,ecx
		epilogue
		ret

.Err1:		mov	ax,EINVAL
.Error:		stc
		jmp	.Exit
.Err2:		mov	ax,EEXIST
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_RemoveDir - remove a directory.
		; Input: EDX=file system address,
		;	 EBX=head directory node,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: removes only empty directories.
proc RFS_RemoveDir
		locals	headnode
		locauto	direntry,tDirEntry_size		; Name buffer

		prologue
		mpush	ecx,edx,esi,edi
		mov	[%$headnode],ebx		; Keep owning dir index
		mov	ecx,RFS_FILENAMELEN
		lea	edi,[%$direntry]		; Move name to stack
	;	call	CFS_MoveNameToStack		; XXX
		jc	.Exit

		Ccall	_strncmp, DirName_Curr, edi, RFS_FILENAMELEN
		or	eax,eax
		jz	.Err1
		Ccall	_strncmp, DirName_Parent, edi, RFS_FILENAMELEN
		or	eax,eax
		jz	.Err1

		mov	esi,edi
		call	RFS_SearchForFileName		; See if name exists
		jc	short .Exit			; Err if doesn't exist
		mov	ebx,eax

		mBseek
		test	word [esi+tDirNode.Type],ST_MODE_IFDIR	; Directory?
		jz	short .Err3
		call	RFS_GetNumOfFiles		; Get number of files
		jc	short .Exit			; in directory
		or	eax,eax				; Empty?
		jnz	short .Err2

                mov	eax,ebx
		call	RFS_DeallocBlock
		jc	short .Exit

		mov	ebx,[%$headnode]
		xor	eax,eax
		push	eax
		lea	esi,[%$direntry]
		push	esi
		call	RFS_DeleteFileName		; Delete directory name
		jc	.Exit
		xor	eax,eax

.Exit:		mpop	edi,esi,edx,ecx
		epilogue
		ret

.Err1:		mov	ax,EINVAL
		stc
		jmp	.Exit
.Err2:		mov	ax,ENOTEMPTY
		stc
		jmp	.Exit
.Err3:		mov	ax,ENOTDIR
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_ChangeDir - change a directory.
		; Input: EBX=up-level directory disk index,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ChangeDir

		ret
endp		;---------------------------------------------------------------

