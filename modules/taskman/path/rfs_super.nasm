;-------------------------------------------------------------------------------
; rfs_super.nasm - routines for manipulating RFS super block.
;-------------------------------------------------------------------------------

module tm.pathman.rfs_super

%include "tm/rfs.ah"
%include "rm/stat.ah"

publicproc RFS_MakeFS, RFS_CheckFSid

externproc RFS_MakeBAMs, RFS_AllocDirBlock
externproc RFS_InsertFileName
externdata DirName_Root, DirName_Curr

; --- Data ---

section .data

string RFS_ID, {"RFS1     ", 0}


section .text
		; RFS_MakeFS - initialize a RAM file system.
		; Input: EDX=address of RAM-disk,
		;	 ECX=size of RAM-disk.
		; Output: CF=0 - OK, EBX=root directory inode;
		;	  CF=1 - error, AX=error code.
proc RFS_MakeFS
		locauto	dotdirent, tDirEntry_size

		prologue
		mpush	ecx,esi,edi

		shr	ecx,RFS_BLOCKSHIFT
		call	RFS_MakeBAMs			; Create BAMs
		jc	.Exit
		call	RFS_MakeMasterBlock		; Create master block
		jc	.Exit
		call	RFS_CreateRootDir		; Create root directory
		jc	.Exit

		mov	esi,DirName_Curr		; Create '.' entry
		lea	edi,[%$dotdirent+tDirEntry.Name]
		mov	ecx,RFS_FILENAMELEN/4
		cld
		push	edi
		rep	movsd
		pop	edi

		mov	[edi+tDirEntry.Entry],eax	; Save root dir block
		mov	ebx,eax
		xor	eax,eax
		mov	[edi+tDirEntry.Spare],eax
		mov	[edi+tDirEntry.More],eax
		push	edi
		call	RFS_InsertFileName

.Exit:		mpop	edi,esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_MakeMasterBlock - make the master block.
		; Input: EAX=number of BAMs,
		;	 ECX=total number of blocks in device,
		;	 EDX=file system address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc RFS_MakeMasterBlock
		mpush	esi,edi
		push	ecx
		push	eax
		mov	edi,edx
		mov	ecx,RFS_BLOCKSIZE / 4
		xor	eax,eax				; Fill it with zeros
		cld
		rep	stosd

		mov	esi,RFS_ID			; Copy the FS ident
		lea	edi,[edx+tMasterBlock.ID]	; into the ident field
		mov	ecx,RFS_ID_size
		cld
		rep	movsb

		; Put in a jump instruction
		mov	word [edx+tMasterBlock.JmpAround],JMPinst+(BootJMP << 8)
		; Put in a number of BAMs
		pop	eax
		mov	[edx+tMasterBlock.NumBAMs],eax
		; And total number of blocks
		pop	ecx
		mov	[edx+tMasterBlock.TotalBlocks],ecx
		; Version field and "kilobytes per BAM"
		xor	eax,eax
		mov	[edx+tMasterBlock.Ver],eax
		inc	eax
		mov	[edx+tMasterBlock.KBperBAM],eax

		clc
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; RFS_CreateRootDir - create root directory.
		; Input: EDX=file system address.
		; Output: CF=0 - OK, EAX=root directory block number;
		;	  CF=1 - error, AX=error code.
proc RFS_CreateRootDir
		mpush	ebx,esi
		mov	esi,DirName_Root
		call	RFS_AllocDirBlock
		jc	.Exit
		mov	[edx+tMasterBlock.RootDir],eax
		bts	dword [esi+tDirNode.Flags],RFS_DFL_LEAF | RFS_DFL_HEAD
		mov	word [esi+tDirNode.Type],ST_MODE_IFDIR
		clc

.Exit:		mpop	esi,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_CheckFSid - check if a file system contains correct ID.
		; Input: EDX=file system address.
		; Output: CF=0 - OK, RFS found;
		;	  CF=1 - error, RFS not found.
proc RFS_CheckFSid
		mpush	ecx,esi,edi
		lea	esi,[edx+tMasterBlock.ID]
		mov	edi,RFS_ID			; Check FS ID
		mov	ecx,RFS_ID_size
		cld
		repe	cmpsb
		clc
		jz	.Exit
		stc
.Exit:		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------
