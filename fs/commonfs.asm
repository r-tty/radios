;*******************************************************************************
;  commonfs.asm - common file system routines and data.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

.386
Ideal

;DEBUG=1

include "segments.ah"
include "errdefs.ah"
include "macros.ah"
include "strings.ah"
include "drivers.ah"
include "kernel.ah"
include "process.ah"
include "sysdata.ah"
include "drvctrl.ah"

include "cfs_func.ah"
include "commonfs.ah"

IFDEF DEBUG
include "misc.ah"
ENDIF

; --- Variables ---
segment KVARS
CFS_LPtableHnd	DW	?			; Linkpoints table handle
CFS_LPtableAddr	DD	?			; Table address
CFS_NumOfLPs	DB	?			; Number of allocated linkpoints

CFS_NumIndexes	DD	?			; Number of indexes
CFS_IndTblAddr	DD	?			; Address of indexes table

CFS_CurrLP	DB	?			; Current file system linkpoint

CFS_PathSepar	DB	'/'
CFS_UpLevelDir	DB	".."
CFS_ThisDir	DB	"."
ends


; --- Procedures ---
segment KCODE

include "diskbuf.asm"
include "cfs_fops.asm"
include "cfs_dops.asm"
include "cfs_serv.asm"
include "cfs_misc.asm"
include "perm.asm"
include "index.asm"
include "path.asm"


;-------------- Initialization and file system linking functions ---------------

		; CFS_Init - initialize common file system structures.
		; Input: AL=maximum number of FS linkpoints,
		;	 ECX=maximum number of indexes.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc CFS_Init near
		push	ebx ecx edx edi
		cmp	al,CFS_MaxLinkPoints
		ja	short @@Error1
		mov	[CFS_NumOfLPs],al
		mov	edx,ecx				; Keep number of indexes
		movzx	ecx,al
		shl	ecx,4				; Allocate memory
		call	KH_Alloc			; for link points table
		jc	short @@Exit
		mov	[CFS_LPtableHnd],ax		; Store block handle
		mov	[CFS_LPtableAddr],ebx		; Store block address
		call	KH_FillZero			; Clear table

		mov	ecx,edx				; Allocate memory
		call	IND_Grow			; for indexes
		jc	short @@Exit

		mov	ecx,HASH_NUMBER
		call	IND_InitHashTable		; Intialize hash table

@@Exit:		pop	edi edx ecx ebx
		ret

@@Error1:	mov	ax,ERR_FS_InitTooManyLP
		stc
		jmp	@@Exit
@@Error2:	mov	ax,ERR_FS_InitTooManyKFH
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; CFS_Done - release CFS structures.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_Done near
		mov	ax,[CFS_LPtableHnd]
		call	KH_Free
		ret
endp		;---------------------------------------------------------------


		; CFS_LinkFS - link filesystem with device.
		; Input: ESI=filesystem driver ID,
		;	 EDI=block device driver ID,
		;	 DL=linkpoint number,
		;	 DH=linking mode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_LinkFS near
		push	ecx edx
		cmp	dl,CFS_MaxLinkPoints
		jae	short @@Err1

		mov	eax,esi
		call	DRV_GetFlags			; Filesystem driver?
		jc	short @@Error
		test	ax,DRVFL_FS
		jz	short @@Err2

		mov	eax,edi
		and	eax,0FFFFh			; Mask minor number
		call	DRV_GetFlags			; Block device?
		jc	short @@Error
		test	ax,DRVFL_Block
		jz	short @@Err3

		call	CFS_CheckDevLink		; Device already linked?
		jc	short @@Err4

		mov	ecx,edx				; Keep FSLP and mode
		and	edx,0FFh			; Count linkpoint addr.
		shl	edx,4
		add	edx,[CFS_LPtableAddr]
		mov	[edx+tCFSLinkPoint.FSdrvID],esi
		mov	[edx+tCFSLinkPoint.DevID],edi
		mov	[edx+tCFSLinkPoint.Mode],ch	; CH=Mode

		mov	edx,ecx				; Restore FSLP and mode
		test	dh,flFSL_NoInitFS		; Initialize FS driver?
		clc
		jz	short @@Exit
		mCallDriver esi,DRVF_Open		; Call FS driver (open)
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_FS_BadLP
		jmp	short @@Error
@@Err2:		mov	ax,ERR_FS_NoFSdriver
		jmp	short @@Error
@@Err3:		mov	ax,ERR_FS_NoBlockDev
		jmp	short @@Error
@@Err4:		mov	ax,ERR_FS_DevLinked
@@Error:	stc
@@Exit:		pop	edx ecx
		ret
endp		;---------------------------------------------------------------


		; CFS_UnlinkFS - unlink filesystem from device.
		; Input: DL=linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_UnlinkFS near
		push	edx esi
		cmp	dl,CFS_MaxLinkPoints
		jae	short @@Err1
		and	edx,0FFh			; Count linkpoint addr.
		shl	edx,4
		add	edx,[CFS_LPtableAddr]
		mov	esi,[edx+tCFSLinkPoint.FSdrvID]
		or	esi,esi
		jz	short @@Err2
		push	edx
		mCallDriver esi,DRVF_Close		; Call FS driver (close)
		pop	edx
		jc	short @@Exit
		mov	[edx+tCFSLinkPoint.FSdrvID],0
		mov	[edx+tCFSLinkPoint.DevID],0
		clc
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_FS_BadLP
		jmp	short @@Error
@@Err2:		mov	ax,ERR_FS_NotLinked
@@Error:	stc
@@Exit:		pop	esi edx
		ret
endp		;---------------------------------------------------------------


;------------------------ File name parsing functions --------------------------

		; CFS_GetLPfromName - get FSLP from file name.
		; Input: ESI=pointer to name.
		; Output: CF=0 - OK, DL=file system linkpoint number;
		;	  CF=1 - error, AX=error code.
		; Note: if linkpoint prefix is specified, sets ESI after it,
		;	otherwise returns current linkpoint and doesn't
		;	change ESI.
proc CFS_GetLPfromName near
		cmp	[byte esi+1],':'	; Have a linkpoint spec?
		jne	short @@UseCurr		; No, go
		mov	dl,[esi]		; Get linkpoint spec
		and	dl,not 20h		; Make uppercase
		cmp	dl,'A'
		jb	short @@Err
		sub	dl,'A'			; Convert to int
		cmp	dl,[CFS_NumOfLPs]
		jae	short @@Err		; Error if out range
		inc	esi                     ; Update file name pointer
		inc	esi
		clc
		ret

@@UseCurr:	mov	dl,[CFS_CurrLP]
		clc
		ret

@@Err:		mov	ax,ERR_FS_BadLP
		stc
		ret
endp		;---------------------------------------------------------------


		; CFS_MoveNameToStack - move file name to caller stack.
		; Input: CL=max. file name length,
		;	 ESI=name pointer,
		;	 EDI=address of buffer in caller stack.
		; Output: CF=0 - OK:
		;		  DL=file system linkpoint number,
		;		  ESI=updated file name pointer;
		;	  CF=1 - error, AX=error code.
proc CFS_MoveNameToStack near
		push	ecx edi
		call	CFS_GetLPfromName
		jc	short @@Exit

		call	CFS_LPisLinked
		jc	short @@Exit

@@Loop:		mov	al,[esi]			; Get a char
		inc	esi
		or	al,al				; If zero, go do padding
		jz	short @@Fill
		mov	[edi],al			; Else save char
		inc	edi
		dec	cl
		jnz	@@Loop
		jmp	short @@OK

@@Fill:		mov	al,' '				; Fill rest of buffer
		cld					; with spaces
		rep	stosb
		jmp	short @@OK

@@Err:		mov	ax,ERR_FS_NotLinked
		stc
		jmp	short @@Exit
@@OK:		clc
@@Exit:		pop	edi ecx
		ret
endp		;---------------------------------------------------------------

ends

end
