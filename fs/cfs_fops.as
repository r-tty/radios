;-------------------------------------------------------------------------------
;  cfs_fops.asm - file operations.
;-------------------------------------------------------------------------------

; --- Exports ---

global CFS_CreateFile, CFS_Open, CFS_Close, CFS_Read, CFS_Write
global CFS_RemoveFile, CFS_MoveFile, CFS_Truncate
global CFS_SetPos, CFS_GetPos
global CFS_OpenByIndex


; --- Imports ---

library kernel
extern K_CurrPID


		; CFS_CreateFile - create a file.
		; Input: EAX=PID (0 for kernel),
		;	 ESI=pointer to name,
		;	 DX=creation flags.
		; Output: CF=0 - OK, EBX=file handle;
		;	  CF=1 - error, AX=error code.
proc CFS_CreateFile
		mov	cl,FOP_Create
		call	CFS_CreateOrOpen
		ret
endp		;---------------------------------------------------------------


		; CFS_Open - open file.
		; Input: EAX=PID (0 for kernel),
		;	 ESI=pointer to name,
		;	 DX=opening flags.
		; Output: CF=0 - OK, EBX=file handle;
		;	  CF=1 - error, AX=error code.
proc CFS_Open
		mov	cl,FOP_Open
		call	CFS_CreateOrOpen
		ret
endp		;---------------------------------------------------------------


		; CFS_Close - close a file.
		; Input: EBX=file handle.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc CFS_Close
		mpush	ebx,edx,edi
		mov	eax,[K_CurrPID]
		call	CFS_GetFHndStructAddr		; Get FH struc addr.
		jc	short .Exit
		mov	edi,edx				; Keep it in EDI

		mov	eax,[edx+tCFS_FHandle.Handle]	; EAX=private FH
		or	eax,eax				; File opened?
		jz	short .Err
		mov	dl,[edx+tCFS_FHandle.FSLP]	; DL=FSLP
		call	CFS_LPtoFSdrvID			; Get FS driver ID
		jc	short .Exit
		xchg	eax,ebx

		mCallDriverCtrl eax,FOP_Close		; Do close
		jc	short .Exit
		xor	eax,eax				; Release file handle
		dec	eax
		mov	[edi+tCFS_FHandle.Handle],eax
		mov	[edi+tCFS_FHandle.FSLP],al
		inc	eax
		jmp	short .Exit

.Err:		mov	ax,ERR_FS_FileNotOpened
		stc
.Exit:		mpop	edi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_Read - read from file.
		; Input: EBX=file handle,
		;	 ECX=number of bytes to read,
		;	 FS:ESI=buffer address.
		; Output: CF=0 - OK, EAX=number of read bytes;
		;	  CF=1 - error, AX=error code.
proc CFS_Read
		push	edx
		mov	dl,FOP_Read
		call	CFS_ReadOrWrite
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; CFS_Write - write to file.
		; Input: EBX=file handle,
		;	 ECX=number of bytes to write,
		;	 FS:ESI=buffer address.
		; Output: CF=0 - OK, EAX=number of written bytes;
		;	  CF=1 - error, AX=error code.
proc CFS_Write
		push	edx
		mov	dl,FOP_Write
		call	CFS_ReadOrWrite
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; CFS_RemoveFile - remove link to file.
		; Input: EAX=PID (0 for kernel),
		;	 ESI=pointer to file name.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc CFS_RemoveFile
		mpush	ebx,edx
		push	esi
		call	CFS_GetLPbyName
		pop	esi
		jc	short .Exit
		call	CFS_LPtoFSdrvID
		jc	short .Exit
		mCallDriverCtrl ebx,FOP_RemoveFile

.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_MoveFile - move or rename file.
		; Input: EAX=PID (0 for kernel),
		;	 ESI=old name,
		;	 EDI=new name.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc CFS_MoveFile
		mpush	ebx,edx
		push	esi
		call	CFS_GetLPbyName
		pop	esi
		jc	short .Exit
		call	CFS_LPtoFSdrvID
		jc	short .Exit
		mCallDriverCtrl ebx,FOP_MoveFile
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_Truncate - truncate file.
		; Input: EBX=file handle.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_Truncate
		mpush	ebx,edx,edi
		call	CFS_GetFHndStructAddr		; Get FH struc addr.
		jc	short .Exit
		mov	edi,edx				; Keep it in EDI

		mov	eax,[edx+tCFS_FHandle.Handle]	; EAX=private FH
		or	eax,eax				; File opened?
		jz	short .Err
		mov	dl,[edx+tCFS_FHandle.FSLP]	; DL=FSLP
		call	CFS_LPtoFSdrvID			; Get FS driver ID
		jc	short .Exit
		xchg	eax,ebx

		mCallDriverCtrl eax,FOP_TruncateFile	; Truncate
		jmp	short .Exit

.Err:		mov	ax,ERR_FS_FileNotOpened
		stc
.Exit:		mpop	edi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_SetPos - set file position.
		; Input: EBX=file handle,
		;	 ECX=offset,
		;	 DL=origin (0=begin, 1=current position, 2=end).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_SetPos
		push	edx
		mov	dh,FOP_SetPos
		call	CFS_SetGetPos
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; CFS_GetPos - get file position.
		; Input: EBX=file handle.
		; Output: CF=0 - OK, ECX=file position;
		;	  CF=1 - error, AX=error code.
proc CFS_GetPos
		push	edx
		mov	dh,FOP_GetPos
		call	CFS_SetGetPos
		pop	edx
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; CFS_CreateOrOpen - create or open file.
		; Input: EAX=PID (0 for kernel),
		;	 ESI=pointer to name,
		;	 DX=creation flags,
		;	 CL=function code (FOP_Create or FOP_Open).
		; Output: CF=0 - OK, EBX=file handle;
		;	  CF=1 - error, AX=error code.
proc CFS_CreateOrOpen
		mpush	ecx,edx,edi
		mov	edi,eax				; Keep PID
		shl	ecx,24				; Keep function code
		mov	cx,dx				; Keep creation flags
		push	esi
		call	CFS_GetLPbyName
		pop	esi
		jc	short .Exit
		call	CFS_LPtoFSdrvID			; Get FS driver ID
		jc	short .Exit

		mov	eax,ecx
		shr	eax,24				; AL=function code.
		push	ebx				; FS Driver ID
		push	dword DRVF_Control		; Function
		mov	[esp+2],ax			; Subfunction
		call	DRV_CallDriver
		jc	short .Exit

		mov	cl,dl				; Keep FSLP
		xchg	eax,edi				; Keep private FH
		call	CFS_FindFreeFH
		jc	short .Exit
		xchg	eax,edi

		mov	[edx+tCFS_FHandle.FSLP],cl	; FSLP
		mov	[edx+tCFS_FHandle.Handle],eax	; Private handle
		clc
.Exit:		mpop	edi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; CFS_OpenByIndex - open file by index.
		; Input: EBX=index.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_OpenByIndex
		ret
endp		;---------------------------------------------------------------


		; CFS_ReadOrWrite - read or frite a file.
		; Input: EBX=file handle,
		;	 ECX=number of bytes to write,
		;	 FS:ESI=buffer address,
		;	 DL=function code (FOP_Read or FOP_Write).
		; Output: CF=0 - OK, EAX=number of read/written bytes;
		;	  CF=1 - error, AX=error code.
proc CFS_ReadOrWrite
%define	.function	ebp-4

		prologue 4
		mov	[.function],dl

		mpush	ebx,ecx,edi
		mov	eax,[K_CurrPID]
		call	CFS_GetFHndStructAddr		; Get FH struc addr.
		jc	short .Exit

		mov	ebx,[edx+tCFS_FHandle.Handle]
		cmp	ebx,-1				; File opened?
		je	short .Err
		mov	dl,[edx+tCFS_FHandle.FSLP]	; DL=FSLP
		push	ebx
		call	CFS_GetLPStructAddr
		mov	edi,[ebx+tCFSLinkPoint.FSdrvID]	; EDI=FS driver ID
		pop	ebx
		jc	short .Exit

		push	edi				; FS Driver ID
		push	dword DRVF_Control		; Function
		mov	al,[.function]			; Subfunction
		xor	ah,ah
		mov	[esp+2],ax
		call	DRV_CallDriver
		jc	short .Exit
		mov	eax,ecx				; EAX=number of R/W bytes

.Exit:		mpop	edi,ecx,ebx
		epilogue
		ret

.Err:		mov	ax,ERR_FS_InvFileHandle
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; CFS_SetGetPos - set/get file position.
		; Input: EBX=file handle,
		;	 ECX=new position (if set),
		;	 DL=origin (if set),
		;	 DH=function code (FOP_SetPos or FOP_GetPos).
		; Output: CF=0 - OK, ECX=position (if get);
		;	  CF=1 - error, AX=error code.
proc CFS_SetGetPos
%define	.organdfun	ebp-4

		prologue 4
		mpush	ebx,edi

		mov	[.organdfun],edx		; Keep origin and fun
		mov	eax,[K_CurrPID]
		call	CFS_GetFHndStructAddr		; Get FH struc addr.
		jc	short .Exit

		mov	ebx,[edx+tCFS_FHandle.Handle]
		cmp	ebx,-1				; File opened?
		je	short .Err
		mov	dl,[edx+tCFS_FHandle.FSLP]	; DL=FSLP
		push	ebx
		call	CFS_GetLPStructAddr
		mov	edi,[ebx+tCFSLinkPoint.FSdrvID]	; EDI=FS driver ID
		pop	ebx
		jc	short .Exit

		push	edi				; FS Driver ID
		push	dword DRVF_Control		; Function
		mov	edx,[.organdfun]		; Subfunction and origin
		mov	[esp+2],dh
		call	DRV_CallDriver
		jc	short .Exit

.Exit:		mpop	edi,ebx
		epilogue
		ret

.Err:		mov	ax,ERR_FS_InvFileHandle
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------
