;*******************************************************************************
;  commonfs.asm - common file system routines and data.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module kernel.fs

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "sema.ah"
%include "pool.ah"
%include "process.ah"
%include "commonfs.ah"

%ifdef DEBUG
%include "kconio.ah"

library kernel.kconio
extern PrintChar:near, PrintString:near 
extern PrintByteHex:near, PrintDwordHex:near
%endif

; --- Exports ---

global CFS_Init, CFS_LinkFS, CFS_UnlinkFS
global CFS_MoveNameToStack, CFS_GetLPbyName

global CFS_LPtable


; --- Imports ---

library kernel.mt
extern ?ProcListPtr

; --- Data ---

section .data

CFS_PathSepar	DB	'/'
CFS_UpLevelDir	DB	".."
CFS_ThisDir	DB	"."


; --- Variables ---

section .bss

CFS_NumIndexes	RESD	1			; Number of indexes
CFS_IndTblAddr	RESD	1			; Address of indexes table

CFS_LPtable	RESB	CFS_MaxLinkPoints*tCFSLinkPoint_size


; --- Procedures ---

section .text

%include "diskbuf.as"
%include "cfs_fops.as"
%include "cfs_dops.as"
%include "cfs_serv.as"
%include "cfs_misc.as"
%include "perm.as"
%include "index.as"
%include "path.as"


;-------------- Initialization and file system linking functions ---------------

		; CFS_Init - initialize common file system structures.
		; Input: ECX=maximum number of indexes.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc CFS_Init
		push	ecx

		call	IND_Grow			; Allocate memory
		jc	short .Done			; for indexes

		mov	ecx,HASH_NUMBER
		call	IND_InitHashTable		; Intialize hash table

.Done:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; CFS_LinkFS - link filesystem with device.
		; Input: ESI=filesystem driver ID,
		;	 EDI=block device driver ID,
		;	 DL=linkpoint number,
		;	 DH=linking mode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_LinkFS
		mpush	ecx,edx
		cmp	dl,CFS_MaxLinkPoints
		jae	short .Err1

		mov	eax,esi
		call	DRV_GetFlags			; Filesystem driver?
		jc	short .Error
		test	ax,DRVFL_FS
		jz	short .Err2

		mov	eax,edi
		and	eax,0FFFFh			; Mask minor number
		call	DRV_GetFlags			; Block device?
		jc	short .Error
		test	ax,DRVFL_Block
		jz	short .Err3

		call	CFS_CheckDevLink		; Device already linked?
		jc	short .Err4

		mov	ecx,edx				; Keep FSLP and mode
		and	edx,0FFh			; Count linkpoint addr.
		shl	edx,tCFSLP_shift
		add	edx,CFS_LPtable
		mov	[edx+tCFSLinkPoint.FSdrvID],esi
		mov	[edx+tCFSLinkPoint.DevID],edi
		mov	[edx+tCFSLinkPoint.Mode],ch	; CH=Mode

		mov	edx,ecx				; Restore FSLP and mode
		test	dh,flFSL_NoInitFS		; Initialize FS driver?
		clc
		jnz	short .Exit
		mCallDriver esi,byte DRVF_Open		; Call FS driver (open)
		jmp	short .Exit

.Err1:		mov	ax,ERR_FS_BadLP
		jmp	short .Error
.Err2:		mov	ax,ERR_FS_NoFSdriver
		jmp	short .Error
.Err3:		mov	ax,ERR_FS_NoBlockDev
		jmp	short .Error
.Err4:		mov	ax,ERR_FS_DevLinked
.Error:		stc
.Exit:		mpop	edx,ecx
		ret
endp		;---------------------------------------------------------------


		; CFS_UnlinkFS - unlink filesystem from device.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc CFS_UnlinkFS
		mpush	edx,esi
		cmp	dl,CFS_MaxLinkPoints
		jae	short .Err1
		and	edx,0FFh			; Count linkpoint addr.
		shl	edx,tCFSLP_shift
		add	edx,CFS_LPtable
		mov	esi,[edx+tCFSLinkPoint.FSdrvID]
		or	esi,esi
		jz	short .Err2
		push	edx
		mCallDriver esi, byte DRVF_Close	; Call FS driver (close)
		pop	edx
		jc	short .Exit
		xor	eax,eax
		mov	[edx+tCFSLinkPoint.FSdrvID],eax
		mov	[edx+tCFSLinkPoint.DevID],eax
		jmp	short .Exit

.Err1:		mov	ax,ERR_FS_BadLP
		jmp	short .Error
.Err2:		mov	ax,ERR_FS_NotLinked
.Error:		stc
.Exit:		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------


;------------------------ File name parsing functions --------------------------

		; CFS_GetLPbyName - get FSLP by the file name.
		; Input: EAX=PID;
		;	 ESI=pointer to name.
		; Output: CF=0 - OK, DL=file system linkpoint number;
		;	  CF=1 - error, AX=error code.
		; Note: if linkpoint prefix is specified, sets ESI after it,
		;	otherwise returns current linkpoint and doesn't
		;	change ESI.
proc CFS_GetLPbyName
		cmp	byte [esi+1],':'	; Have a linkpoint spec?
		jne	.UseCurr		; No, go
		mov	dl,[esi]		; Get linkpoint spec
		and	dl,~20h			; Make uppercase
		cmp	dl,'A'
		jb	short .Err
		sub	dl,'A'			; Convert to int
		cmp	dl,CFS_MaxLinkPoints
		jae	short .Err		; Error if out range
		inc	esi                     ; Update file name pointer
		inc	esi
		clc
		ret

.UseCurr:	push	ebx
		mPID2PDA
		mov	dl,[ebx+tProcDesc.FSLP]
		pop	ebx
		ret

.Err:		mov	ax,ERR_FS_BadLP
		stc
		ret
endp		;---------------------------------------------------------------


		; CFS_MoveNameToStack - move file name to caller stack.
		; Input: EAX=PID,
		;	 CL=max. file name length,
		;	 ESI=name pointer,
		;	 EDI=address of buffer in caller stack.
		; Output: CF=0 - OK:
		;		  DL=file system linkpoint number,
		;		  EBX=owning directory index,
		;		  ESI=updated file name pointer;
		;	  CF=1 - error, AX=error code.
proc CFS_MoveNameToStack
%define	.pid	ebp-4

		prologue 4
		mpush	ecx,edi

		mov	[.pid],eax
		call	CFS_GetLPbyName
		jc	.Done
		mov	eax,[.pid]
		call	CFS_Path2Index
		jc	.Done

		call	CFS_LPisLinked
		jc	.Done

.Loop:		mov	al,[esi]			; Get a char
		inc	esi
		or	al,al				; If zero, go do padding
		jz	short .Fill
		mov	[edi],al			; Else save char
		inc	edi
		dec	cl
		jnz	.Loop
		jmp	short .OK

.Fill:		mov	al,' '				; Fill rest of buffer
		cld					; with spaces
		rep	stosb
.OK:		clc
.Done:		mpop	edi,ecx
		epilogue
		ret

.Err:		mov	ax,ERR_FS_NotLinked
		stc
		jmp	short .Done
endp		;---------------------------------------------------------------
