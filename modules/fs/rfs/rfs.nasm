;*******************************************************************************
;  rfs.asm - RadiOS File System driver.
;  Based upon David Lindauer's OS-32 file system (c) 1995 David Lindauer.
;  RadiOS version (c) 1999,2000 Yuri Zaporogets.
;*******************************************************************************

module fs.rfs

%define extcall near

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "asciictl.ah"
%include "commonfs.ah"

%include "rfs.ah"


; --- Exports ---

global DrvRFS


; --- Imports ---

library kernel.kheap
extern KH_Alloc:extcall, KH_FillWithFF:extcall

library kernel.mm
extern AllocPhysMem:extcall

library kernel.misc
extern StrCopy:extcall, StrEnd:extcall, StrAppend:extcall
extern DecD2Str:extcall



; --- Data ---

section .data

DrvRFS		DB	"%RFS"
		TIMES	16-$+DrvRFS DB 0
		DD	DrvRFS_ET
		DW	DRVFL_FS

DrvRFS_ET	DD	RFS_Init
		DD	RFS_HandleEv
		DD	RFS_Open
		DD	RFS_Close
		DD	NULL
		DD	NULL
		DD	NULL
		DD	DrvRFS_Ctrl

DrvRFS_Ctrl	DD	RFS_GetISS
		DD	RFS_GetParameters
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL

		; File operations
		DD      RFS_CreateFile
		DD	RFS_OpenFile
		DD	RFS_CloseFile
		DD	RFS_DeleteFile
		DD	RFS_TruncateFile
		DD	RFS_RenameFile
		DD	RFS_ReadLong
		DD	RFS_WriteLong
		DD	RFS_SetFilePos
		DD	RFS_GetFilePos
		DD	RFS_GoEOF
		DD	RFS_SetFileAttr
		DD	RFS_GetFileAttr

		; Directory operations
		DD      RFS_ChangeDir
		DD	RFS_CreateDir
		DD	RFS_RemoveDir

		; Master, etc. operations
		DD      RFS_ReadIndex
		DD	RFS_WriteIndex
		DD	RFS_AllocIndex
		DD	RFS_ReleaseIndex

		DD	RFS_MakeFS
		DD	RFS_LookFSysOnDev

Str_FCBs	DB	" FCBs allocated",NL,0



; --- Variables ---

section .bss

NumBAMsTblAddr	RESD	1		; Address of "number of BAMs" table


; --- Procedures ---

section .text

%include "master.as"
%include "files.as"
%include "dirs.as"
%include "dirops.as"
%include "index.as"


		; RFS_Init - initialize RFS driver.
		; Input: CL=number of FCBs,
		;	 ESI=pointer to buffer for init status string.
		; Output: CF=0 - OK, AX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_Init
		mpush	ebx,ecx,edx
		mov	edx,ecx			; Keep number of FCBs
		mov	ecx,CFS_MaxLinkPoints*4
		call	KH_Alloc		; Allocate memory
		jc	near .Exit		; for 'NumBAMs' table
		mov	[NumBAMsTblAddr],ebx
		call	KH_FillWithFF		; Fill table with -1

		mov	ecx,edx
		and	ecx,0FFh		; ECX=number of FCBs
		mov	[NumOfFCBs],cl
		mov	eax,tFCB_size		; Count amount of memory
		push	edx			; for FCBs
		mul	ecx
		pop	edx
		mov	ecx,eax

		call	AllocPhysMem		; Allocate memory
		jc	short .Exit
		mov	[FCBstart],ebx		; Store begin address of FCBs

		call	RFS_GetISS
		xor	eax,eax

.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_HandleEv - handle FS specific events.
		; Input: EAX=event code.
		; Output: none.
proc RFS_HandleEv
		ret
endp		;---------------------------------------------------------------


		; RFS_Open - link filesystem to device.
		; Input: DL=FSLP,
		;	 DH=linking mode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_Open
		call	RFS_LoadNumBAMs
		ret
endp		;---------------------------------------------------------------


		; RFS_Close - unlink filesystem from device.
		; Input: DL=FSLP.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_Close
		ret
endp		;---------------------------------------------------------------


		; RFS_GetISS - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc RFS_GetISS
		mpush	esi,edi
		mov	edi,esi
		mov	esi,DrvRFS			; Copy driver name
		call	StrCopy
		call	StrEnd
		mov	eax,"		: "
		stosd
		movzx	eax,byte [NumOfFCBs]
		xchg	esi,edi
		call	DecD2Str
		xchg	esi,edi
		mov	esi,Str_FCBs
		call	StrAppend
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; RFS_GetParameters - get parameters of file system.
		; Input: none.
		; Output:
proc RFS_GetParameters
		ret
endp		;---------------------------------------------------------------


		; RFS_MakeFS - make filesystem on device.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK, EBX=disk index of root directory;
		;	  CF=1 - error, AX=error code.
proc RFS_MakeFS
%define	.name		ebp-DIRENTRYSIZE

		prologue DIRENTRYSIZE
		mpush	ecx,esi,edi

		call	RFS_MakeBAMs		; Create BAMs
		jc	short .Exit
		call	RFS_MakeBBBs		; Create bad block bitmaps
		jc	.Exit
		call	RFS_MakeMasterBlock	; Create master block
		jc	short .Exit
		call	RFS_CreateRootDir	; Create root directory
		jc	short .Exit

		mov	esi,offset DirName_Curr		; Create '.' link
		lea	edi,[.name]
		mov	ecx,FILENAMELEN/4
		cld
		push	edi
		rep	movsd
		pop	edi
		mov	[edi+tDirEntry.Entry],ebx	; Save root dir index
		mov	dword [edi+tDirEntry.UU],0
		mov	dword [edi+tDirEntry.More],0
		push	edi
		call	RFS_InsertFileName
		jc	short .Exit

		call	BUF_FlushAll			; Flush buffers
.Exit:		mpop	edi,esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_LookFSysOnDev - look of RFS presence on device.
		; Input: EDX=device ID.
		; Output: CF=0 - OK, RFS found;
		;	  CF=1 - error, RFS not found.
proc RFS_LookFSysOnDev
		mpush	ebx,ecx,esi,edi
		xor	ebx,ebx				; Read master block
		call	BUF_ReadBlock
		jc	short .Exit
		lea	esi,[esi+tMasterBlock.ID]
		mov	edi,RFS_ID			; Check FS ID
		mov	ecx,RFS_ID_size
		cld
		repe	cmpsb
		clc
		jz	short .Exit
		stc
.Exit:		mpop	edi,esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


;--- Debugging stuff -----------------------------------------------------------

%ifdef DEBUG

%include "kconio.ah"
%include "asciictl.ah"

library kernel.kconio
extern PrintChar:extcall, PrintString:extcall, PrintDwordDec:extcall

library kernel
extern DrvId_RD

global rfs_ls

proc do_ls
 pushad
 mPrintChar NL
 mov edx,[DrvId_RD]					; Driver ID
 call BUF_ReadBlock
 jc short .exit
 mov edi,esi
 mov ecx,MAXDIRITEMS
 add esi,FIRSTDIRENTRY

.loop:
 push esi
 mov dl,FILENAMELEN

.print:
 lodsb
 cmp al,32
 je .endprint
 mPrintChar
 dec dl
 jnz .print

.endprint:
 pop esi
 mov ebx,[esi+tDirEntry.More]
 or ebx,ebx
 jz .nextde
 call do_ls

.nextde:
 mPrintChar HTAB
 add esi,DIRENTRYSIZE
 cmp dword [esi+tDirEntry.Entry],-1
 je .less
 loop .loop


.less:
 mov esi,edi
 mov ebx,[esi+tDirPage.PageLess]
 or ebx,ebx
 je .exit
 call do_ls
 
.exit:
 popad
 ret
endp

proc rfs_ls
 mPrintString _MSG_total
 mov dl,5
 call RFS_LoadRootDir
 jc short .exit
 call CFS_LPtoDevID
 jc short .exit
 call RFS_GetNumOfFiles
 jc short .exit
 call PrintDwordDec
 mPrintChar NL
 call do_ls

.exit:
 ret
endp

section .data
_MSG_total	DB NL,NL,"total ",0

%endif
