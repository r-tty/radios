;*******************************************************************************
;  rfs.asm - RadiOS File System driver.
;  Written by Yuri Zaporogets from David Lindauer's OS-32 file system.
;  (c) 1995 David Lindauer.
;  (c) 1999 Yuri Zaporogets.
;*******************************************************************************

.386
Ideal

include "macros.ah"
include "errdefs.ah"
include "segments.ah"
include "sysdata.ah"
include "kernel.ah"
include "drivers.ah"
include "drvctrl.ah"
include "misc.ah"
include "asciictl.ah"
include "strings.ah"
include "diskbuf.ah"
include "commonfs.ah"
include "cfs_func.ah"

include "rfs.ah"

segment KDATA
DrvRFS		tDriver	<"%RFS            ",DrvRFS_ET,DRVFL_FS>
DrvRFS_ET	tDrvEntries < RFS_Init,\
			      RFS_HandleEv,\
			      RFS_Open,\
			      RFS_Close,\
			      DrvNULL,\
			      DrvNULL,\
			      RFS_Done,\
			      DrvRFS_Ctrl >

DrvRFS_Ctrl	DD	RFS_MakeFS
		DD	RFS_LookFSysOnDev
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL

		tFileOperations \
		      < RFS_CreateFile,\
			RFS_OpenFile,\
			RFS_CloseFile,\
			RFS_DeleteFile,\
			RFS_TruncateFile,\
			RFS_RenameFile,\
			RFS_ReadLong,\
			RFS_WriteLong,\
			RFS_SetFilePos,\
			RFS_GetFilePos,\
			RFS_GoEOF,\
			RFS_SetFileAttr,\
			RFS_GetFileAttr >

		tDirectoryOperations \
		      < RFS_ChangeDir,\
			RFS_CreateDir,\
			RFS_RemoveDir >

		tMasterOperations \
		      < RFS_ReadIndex,\
			RFS_WriteIndex,\
			RFS_AllocIndex, \
			RFS_ReleaseIndex >

Str_FCBs	DB	" FCBs allocated",NL,0
ends

segment KVARS
RFS_MemBlHnd	DW	?		; Memory block handle
RFS_MemBlAddr	DD	?		; and address

NumBAMsTblAddr	DD	?		; Address of "number of BAMs" table
RootsTblAddr	DD	?		; Address of "root pointers" table
ends

include "master.asm"
include "files.asm"
include "dirs.asm"
include "dirops.asm"
include "index.asm"

segment KCODE

		; RFS_Init - initialize RFS driver.
		; Input: AL=maximum number of FS linkpoints,
		;	 CL=number of FCBs,
		;	 ESI=pointer to buffer for init status string.
		; Output: CF=0 - OK, AX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_Init near
		cmp	al,CFS_MaxLinkPoints
		jbe	short @@Do
		mov	ax,ERR_FS_InitTooManyLP
		stc
		ret
@@Do:		push	ebx ecx edx esi edi
		mov	edx,ecx			; Keep number of FCBs
		movzx	ecx,al
		shl	ecx,3			; Allocate memory
		call	KH_Alloc		; for tables
		jc	@@Exit
		mov	[RFS_MemBlHnd],ax	; Store block handle
		mov	[RFS_MemBlAddr],ebx	; and address
		mov	[NumBAMsTblAddr],ebx
		push	ecx			; Fill allocated block with -1
		shr	ecx,2
		mov	edi,ebx
		xor	eax,eax
		not	eax
		cld
		rep	stosd
		pop	ecx
		shr	ecx,1
		add	ebx,ecx
		mov	[RootsTblAddr],ebx	; Store roots table address

		mov	ecx,edx
		and	ecx,0FFh		; ECX=number of FCBs
		mov	[NumOfFCBs],cl
		mov	eax,size tFCB		; Count amount of memory
		push	edx			; for FCBs
		mul	ecx
		pop	edx
		mov	ecx,eax

		call	EDRV_AllocData		; Allocate memory
		jc	short @@Exit
		mov	[FCBstart],ebx		; Store begin address of FCBs

		mov	edi,esi
		mov	esi,offset DrvRFS	; Copy "%RFS"
		call	StrCopy
		call	StrEnd
		mov	eax,203A0909h		; Tabs and ':'
		stosd
		movzx	eax,[NumOfFCBs]
		xchg	esi,edi
		call	K_DecD2Str
		xchg	esi,edi
		mov	esi,offset Str_FCBs
		call	StrAppend

		xor	ax,ax
@@Exit:		pop	edi esi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_Done - release all memory blocks used by driver.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_Done near
		mov	ax,[RFS_MemBlHnd]
		call	KH_Free
endp		;---------------------------------------------------------------


		; RFS_HandleEv - handle FS specific events.
		; Input: EAX=event code.
		; Output: none.
proc RFS_HandleEv near
		ret
endp		;---------------------------------------------------------------


		; RFS_Open - link filesystem to device.
		; Input: EDI=device ID,
		;	 DH=linking mode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_Open near
		ret
endp		;---------------------------------------------------------------


		; RFS_Close - unlink filesystem from device.
		; Input: EAX=device ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_Close near
		ret
endp		;---------------------------------------------------------------


		; RFS_MakeFS - make filesystem on device.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK, EBX=disk index of root directory;
		;	  CF=1 - error, AX=error code.
proc RFS_MakeFS near
@@name		EQU	ebp-DIRENTRYSIZE

		enter	DIRENTRYSIZE,0
		push	ecx esi edi

		call	RFS_MakeBAMs		; Create BAMs
		jc	short @@Exit
		call	RFS_MakeMasterBlock	; Create master block
		jc	short @@Exit
		call	RFS_CreateRootDir	; Create root directory
		jc	short @@Exit

		mov	esi,offset DirName_Curr		; Create '.' link
		lea	edi,[@@name]
		mov	ecx,FILENAMELEN/4
		cld
		push	edi
		rep	movsd
		pop	edi
		mov	[edi+tDirEntry.Entry],ebx	; Save root dir index
		mov	[dword edi+tDirEntry.UU],0
		mov	[edi+tDirEntry.More],0
		push	edi
		call	RFS_InsertFileName
		jc	short @@Exit

		call	BUF_FlushAll			; Flush buffers
@@Exit:		pop	edi esi ecx
		leave
		ret
endp		;---------------------------------------------------------------


		; RFS_LookFSysOnDev - look of RFS presence on device.
		; Input: EDX=device ID.
		; Output: CF=0 - OK, RFS found;
		;	  CF=1 - error, RFS not found.
proc RFS_LookFSysOnDev near
		push	ebx ecx esi edi
		xor	ebx,ebx				; Read master block
		call	BUF_ReadBlock
		jc	short @@Exit
		lea	esi,[esi+tMasterBlock.ID]
		mov	edi,offset RFS_ID		; Check FS ID
		mov	ecx,size RFS_ID
		cld
		repe	cmpsb
		clc
		jz	short @@Exit
		stc
@@Exit:		pop	edi esi ecx ebx
		ret
endp		;---------------------------------------------------------------

public rfs_ls

proc do_ls near
 pushad
 mWrChar NL
 mov edx,[DrvId_RD]					; Driver ID
 call BUF_ReadBlock
 jc short @@exit
 mov edi,esi
 mov ecx,MAXDIRITEMS
 add esi,FIRSTDIRENTRY

@@loop:
 push esi
 mov dl,FILENAMELEN

@@print:
 lodsb
 cmp al,32
 je short @@endprint
 mCallDriver [DrvId_Con],DRVF_Write
 dec dl
 jnz @@print

@@endprint:
 pop esi
 mov ebx,[esi+tDirEntry.More]
 or ebx,ebx
 jz @@nextde
 call do_ls

@@nextde:
 mWrChar 9
 add esi,DIRENTRYSIZE
 cmp [esi+tDirEntry.Entry],-1
 je @@less
 loop @@loop


@@less:
 mov esi,edi
 mov ebx,[esi+tDirPage.PageLess]
 or ebx,ebx
 je @@exit
 call do_ls
 
@@exit:
 popad
 ret
endp

proc rfs_ls near
 mWrString _MSG_total
 mov dl,5
 call RFS_LoadRootDir
 jc short @@exit
 call CFS_LPtoDevID
 jc short @@exit
 call RFS_GetNumOfFiles
 jc short @@exit
 call PrintDwordDec
 mWrChar NL
 call do_ls

@@exit:
 ret
endp

_MSG_total	DB NL,NL,"total ",0

ends

end
