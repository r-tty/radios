;-------------------------------------------------------------------------------
;  files.asm - RFS file operations.
;  WARNING: Not tested for LARGE files.
;           Limits files to about 24 MB.
;-------------------------------------------------------------------------------

; --- Variables ---

segment KVARS
NumOfFCBs	DB	?				; Maximum number of FCBs
FCBstart	DD	?				; Begin address of FCBs
SemFile		DD	1				; Semaphore
ends


segment KCODE

; --- Interface routines ---

		; RFS_CreateFile - create a file.
		; Input: ESI=pointer to name.
		; Output: CF=0 - OK, EAX=file handle;
		;	  CF=1 - error, AX=error code.
proc RFS_CreateFile near
@@fslp		EQU	ebp-4
@@name		EQU	ebp-4-DIRENTRYSIZE		; Name buffer
		push	ebp
		mov	ebp,esp				; Save space
		sub	esp,DIRENTRYSIZE+4		; for variables

		push	ebx ecx edx esi edi		; Move name to stack
		mov	ecx,FILENAMELEN
		lea	edi,[@@name]
		call	CFS_MoveNameToStack
		jc	@@Error
		and	edx,0FFh
		mov	[@@fslp],edx			; Keep FSLP

		lea	esi,[@@name]
		call	RFS_SearchForFileName		; See if name exists
		jnc	@@OldFile			; Yes, go truncate it
		cmp	ax,ERR_FS_FileNotFound		; Else see if not found
		jne	@@Error				; No, service other errors
		call	RFS_AllocBlock			; Else allocate the file block
		jc	@@Error

		call	CFS_LPtoDevID			; Get device ID
		mov	ebx,eax				; Read it in
		call	BUF_ReadBlock
		jc	short @@Error
		call	BUF_MarkDirty			; Dirty buffer
		mov	edi,esi				; Blank it to zeros
		xor	eax,eax
		mov	ecx,BLOCKSIZE/4
		rep	stosd
		push	esi				; Move the name to it
		lea	edi,[esi+tFilePage.NM]
		lea	esi,[@@name]
		push	esi
		mov	ecx,FILENAMELEN / 4
		rep	movsd
		pop	esi				; Save file page
		mov	[esi+tDirEntry.Entry],ebx	; in directory entry
		mov	[dword esi+tDirEntry.UU],0	; Clear other dir params
		mov	[byte esi+tDirEntry.Flags],0
		mov	[dword esi+tDirEntry.More],0
		xchg	esi,[esp]

		call	RFS_CompressTime		; Get compressed time
		mov	[esi+tFilePage.IAttr.LWtime],eax ; Fill in time
		mov	[esi+tFilePage.Sig],FPSignature	; and signature
		mov	edx,[@@fslp]

		call	RFS_InsertFileName		; Go insert the file name
		jc	short @@Exit

@@OpenFile:	lea	esi,[@@name]			; Open the file
		call	RFS_OpenFile
		jmp	short @@Exit

@@OldFile:	lea	esi,[@@name]			; Old file, open it
		call	RFS_OpenFile
		mov	ebx,eax				; Keep handle
		jc	short @@Exit
		push	eax
		call	RFS_TruncateFile		; Truncate it
		pop	ebx
		jnc	short @@OK
		push	ebx
		push	eax
		call	RFS_CloseFile
		pop	ebx			; Doing a swap with pops
		pop	eax
		jmp	short @@Error

@@OK:		mov	eax,ebx
		jmp	short @@Exit

@@Error:	stc
@@Exit:		pop	edi esi edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_OpenFile - open a file.
		; Input: ESI=pointer to name.
		; Output: CF=0 - OK, EAX=file handle;
		;	  CF=1 - error, AX=error code.
proc RFS_OpenFile near
@@fslp		EQU	ebp-4				; FSLP
@@name		EQU	ebp-4-DIRENTRYSIZE		; Name buffer

		push	ebp
		mov	ebp,esp
		sub	esp,DIRENTRYSIZE+4		; Leave space
		push	ebx ecx edx esi edi

		mov	ecx,FILENAMELEN
		lea	edi,[@@name]			; Get name to stack
		call	CFS_MoveNameToStack
		jc	short @@Error
		mov	[@@fslp],dl			; Keep FSLP
		call	RFS_GetFCB			; Find a free FCB
		jc	short @@Error

		lea	esi,[@@name]			; Search for file
		push	edi
		call	RFS_SearchForFileName
		pop	edi
		jc	short @@Error

		call	CFS_LPtoDevID			; Get device ID
		mov	ebx,eax				; Read the file block
		call	BUF_ReadBlock
		jc	short @@Error

		mov	eax,[esi+tFilePage.Len]		; Get length to FCB
		mov	[edi+tFCB.Bytes],eax
		and	[edi+tFCB.Bytes],BLOCKSIZE-1
		shr	eax,BLOCKSHIFT
		mov	[edi+tFCB.Pages],eax
		mov	[edi+tFCB.Device],edx		; Device to FCB
		mov	[edi+tFCB.Page],ebx		; File page to FCB
		mov	[edi+tFCB.PosBytes],0		; Position = start of file
		mov	[edi+tFCB.PosPages],0
		mov	[edi+tFCB.CurrPage],0		; Current page not loaded
		mov	eax,edi				; Calculate file handle
		sub	eax,[FCBstart]
		xor	edx,edx
		mov	edi,size tFCB
		div	edi
		add	eax,BaseFCBs			; Convert to file handle
		clc
		jmp	short @@Exit

@@Error:	mov	[dword edi+tFCB.Page],0
@@Exit:		pop	edi esi edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_CloseFile - close a file.
		; Input: EBX=file handle.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_CloseFile near
		push	ebx edx esi edi
		call	RFS_CalcFCB			; Calculate FCB address
		jc	short @@Exit
		mov	edi,eax
		mov	ebx,[edi+tFCB.Page]		; Read file page
		mov	edx,[edi+tFCB.Device]
		call	BUF_ReadBlock
		jc	short @@Exit
		call	BUF_MarkDirty			; Dirty it
		mov	eax,[edi+tFCB.Bytes]		; Update file length
		mov	ebx,[edi+tFCB.Pages]
		shl	ebx,BLOCKSHIFT
		add	eax,ebx
		mov	[esi+tFilePage.Len],eax
		mov	[edi+tFCB.Page],0		; Release FCB
		call	BUF_FlushAll			; Flush buffers on close
@@Exit:		pop	edi esi edx ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_Delete - delete a file.
		; Input: ESI=pointer to file name.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_DeleteFile near
@@fslp		EQU	ebp-4				; FSLP
@@name		EQU	ebp-4-DIRENTRYSIZE		; Name buffer

		push	ebp
		mov	ebp,esp				; Save space
		sub	esp,DIRENTRYSIZE+4		; for variables
		push	ebx ecx edx esi edi

		mov	ecx,FILENAMELEN			; Move name to stack
		lea	edi,[@@name]
		call	CFS_MoveNameToStack
		jc	short @@Exit
		mov	[@@fslp],dl			; Store FSLP

		lea	esi,[@@name]			; Search for name
		call	RFS_SearchForFileName
		jc	short @@Exit
		mov	ebx,eax				; Truncate the file
		call	RFS_DoTruncate
		jc	short @@Exit

		mov	eax,ebx				; Deallocate file page
		call	RFS_DeallocBlock
		jc	short @@Exit
		push	0				; Delete the name
		lea	edi,[@@name]			; from the directory
		push	edi
		call	RFS_DeleteFileName
		jc	short @@Exit
		call	BUF_FlushAll			; Flush buffers
		xor	eax,eax

@@Exit:		pop	edi esi edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret

@@Error:	stc
		jmp	short @@Exit
endp		;---------------------------------------------------------------


		; RFS_TruncateFile - truncate a file.
		; Input: DL=FSLP,
		;	 EBX=file handle.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_TruncateFile near
		push	ebx ecx edx esi edi
		call	RFS_CalcFCB			; Get FCB
		jc	short @@Exit
		mov	ebx,[edi+tFCB.Page]		; Truncate
		call	RFS_DoTruncate
		jc	short @@Exit
		mov	[dword edi+tFCB.Pages],0	; Reset position
		mov	[dword edi+tFCB.PosPages],0	; and length
		mov	[dword edi+tFCB.Bytes],0
		mov	[dword edi+tFCB.PosBytes],0
		xor	eax,eax
@@Exit:		pop	edi esi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_RenameFile - rename a file.
		; Input: ESI=old name,
		;	 EDI=new name.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_RenameFile near
@@fslp		EQU	ebp-4				; FSLP
@@newname	EQU	ebp-4-DIRENTRYSIZE		; New name
@@oldname	EQU	ebp-4-DIRENTRYSIZE*2		; Old name

		push	ebp
		mov	ebp,esp				; Save space
		sub	esp,DIRENTRYSIZE*2+4		; for variables
		push	ebx ecx edx esi edi

		mov	ecx,FILENAMELEN			; Move names to stack
		push	edi
		lea	edi,[@@oldname]
		call	CFS_MoveNameToStack
		pop	edi
		jc	short @@Error
		mov	[@@fslp],dl

		mov	esi,edi
		lea	edi,[@@newname]
		call	CFS_MoveNameToStack
		jc	short @@Error
		cmp	dl,[@@fslp]			; Cross-device?
		jne	short @@Error1			; Yes, error

		mov	[@@newname+tDirEntry.Flags],0	; Set params
		mov	[@@newname+tDirEntry.More],0	; of new entry
		lea	esi,[@@oldname]			; Get old entry file page
		call	RFS_SearchForFileName
		jc	short @@Error

		mov	[@@newname+tDirEntry.Entry],eax ; Save in new entry
		lea	edi,[@@newname]			; Insert new file name
		push	edi
		call	RFS_InsertFileName
		jc	short @@Error

		push	0				; Delete old file name
		lea	edi,[@@oldname]
		push	edi
		call	RFS_DeleteFileName
		jc	short @@Error
		mov	ebx,[@@newname+tDirEntry.Entry]	; Get the file page
		call	CFS_LPtoDevID			; Get device ID
		call	BUF_ReadBlock
		jc	short @@Error
		call	BUF_MarkDirty			; Dirty it
		lea	edi,[esi+tFilePage.NM]		; Change the name
		lea	esi,[@@newname]			; in the file page
		mov	ecx,FILENAMELEN/4
		rep	movsd
		call	BUF_FlushAll			; Flush to disk
		jmp	short @@Exit

@@Error1:	mov	ax,ERR_FS_CrossDev
@@Error:	stc
@@Exit:		pop	edi esi edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_ReadLong - read large number of bytes.
		; Input: EBX=file handle,
		;	 ECX=number of bytes to read,
		;	 FS:ESI=address of buffer to read.
		; Output: CF=0 - OK, ECX=number of read bytes;
		;	  CF=1 - error, AX=error code.
proc RFS_ReadLong near
@@bytes		EQU	ebp-4

		push	ebp
		mov	ebp,esp
		sub	esp,4
		push	ebx edx esi edi

		mov	[dword @@bytes],0	; Bytes read = 0

@@Loop:		cmp	ecx,BLOCKSIZE		; Just one block?
		jc	@@Last			; Yes, go do it
		push	ecx			; Save count and position
		push	esi
		mov	ecx,BLOCKSIZE		; Read in a block
		push	edx
		call	RFS_ReadShort
		pop	edx
		jc	short @@Exit
		add	[@@bytes],ecx		; Update read count
		pop	esi			; Update position
		add	esi,ecx
		cmp	ecx,BLOCKSIZE		; See if full read
		pop	ecx
		jnz	short @@OK		; Get out if not
		sub	ecx,BLOCKSIZE		; Decrement amount left
		jmp	@@Loop			; Loop again

@@Last:		call	RFS_ReadShort		; Read last block.  Block routine
						; Checks for 0 bytes
		jc	short @@Exit		; Error, exit
		add	[@@bytes],ecx		; Add number of bytes read to rv

@@OK:		clc
@@Exit:		mov	ecx,[@@bytes]
		pop	edi esi edx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_WriteLong - write large number of bytes.
		; Input: DL=file system linkpoint number,
		;	 EBX=file handle,
		;	 ECX=number of bytes,
		;	 FS:ESI=address of buffer to write.
		; Output: CF=0 - OK, ECX=number of written bytes;
		;	  CF=1 - error, AX=error code.
proc RFS_WriteLong near
@@bytes		EQU	ebp-4

		push	ebp
		mov	ebp,esp
		sub	esp,4
		push	ebx edx esi edi

		mov	[word @@bytes],0	; Bytes written = 0
@@Loop:		cmp	ecx,BLOCKSIZE		; Just one block?
		jc	short @@Last		; Yeah, go do it

		push	ecx			; Save count and position
		push	esi
		mov	ecx,BLOCKSIZE		; Write in a block
		call	RFS_WriteShort
		jc	short @@Exit		; Exit if error
		add	[@@bytes],ecx		; Else update write count
		pop	esi			; Update position
		add	esi,ecx
		pop	ecx			; Decrement amount left
		sub	ecx,BLOCKSIZE
		jmp	@@Loop			; Loop again

@@Last:		call	RFS_WriteShort		; Write last block.  Block routine
						; Checks for 0 bytes
		jc	short @@Exit		; Error, get out
		add	[@@bytes],ecx		; Add number of bytes Written to rv
		clc

@@Exit:   	mov	ecx,[@@bytes]
		pop	edi esi edx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_SetFilePos - set file position.
		; Input: EBX=file handle,
		;	 ECX=offset,
		;	 DL=origin (0=begin, 1=current position, 2=end).
		; Output: CF=0 - OK, EAX=new position;
		;	  CF=1 - error, AX=error code.
proc RFS_SetFilePos near
		push	ecx
		call	RFS_CalcFCB			; Calculate FCB
		jc	short @@Exit
		or	dl,dl		
		jz	short @@FromBegin
		dec	dl
		jnz	short @@FromEnd
		mov	eax,[edi+tFCB.PosPages]		; Get org position
		shl	eax,BLOCKSHIFT
		or	eax,[edi+tFCB.PosBytes]
		add	ecx,eax
		jmp	short @@FromBegin
@@FromEnd:	mov	eax,[edi+tFCB.Pages]		; Get org position
		shl	eax,BLOCKSHIFT
		or	eax,[edi+tFCB.Bytes]
		add	ecx,eax
@@FromBegin:	mov	eax,[edi+tFCB.Pages]		; Get org position
		shl	eax,BLOCKSHIFT
		or	eax,[edi+tFCB.Bytes]
		cmp	ecx,eax
		jb	short @@DoLoad
		mov	ecx,eax
@@DoLoad:	mov	[edi+tFCB.PosBytes],ecx		; Set new position
		and	[edi+tFCB.PosBytes],BLOCKSIZE-1
		shr	ecx,BLOCKSHIFT
		mov	[edi+tFCB.PosPages],ecx
		mov	[edi+tFCB.CurrPage],0
		mov	eax,ecx
		clc
@@Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_GetFilePos - get file position.
		; Input: EBX=file handle.
		; Output: CF=0 - OK, ECX=file position;
		;	  CF=1 - error, AX=error code.
proc RFS_GetFilePos near
		call	RFS_CalcFCB			; Get FCB address
		jc	short @@Exit
		mov	ecx,[edi+tFCB.PosPages]		; Load position
		shl	ecx,BLOCKSHIFT
		or	ecx,[edi+tFCB.PosBytes]
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_GoEOF - Go to end of file.
		; Input: EBX=file handle.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_GoEOF near
		call	RFS_CalcFCB			; Calculate FCB
		jc	short @@Exit
		mov	eax,[edi+tFCB.Page]		; Position to end
		mov	[edi+tFCB.PosPages],eax
		mov	eax,[edi+tFCB.Bytes]
		mov	[edi+tFCB.PosBytes],eax
@@Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_SetFileAttr - set file attributes.
		; Input:
		; Output:
proc RFS_SetFileAttr near
		ret
endp		;---------------------------------------------------------------


		; RFS_GetFileAttr - set file attributes.
		; Input:
		; Output:
proc RFS_GetFileAttr near
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; RFS_ClearFCBs - initialize FCBs to the empty state.
		; Input: none.
		; Output: none.
proc RFS_ClearFCBs near
		push	ecx
		movzx	ecx,[NumOfFCBs]			; Number of FCBs
		mov	edi,[FCBstart]
@@Loop:		mov	[edi+tFCB.Page],0		; Set page to 0
		add	edi,size tFCB			; Next FCB
		loop	@@Loop				; Loop till done
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_GetFCB - find a free FCB.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_GetFCB near
		push	ecx				; Save ECX
		movzx	ecx,[NumOfFCBs]			; Number of FCBs
		mov	edi,[FCBstart]			; and FCB base

@@Loop:		test	[dword edi+tFCB.Page],-1	; See if alloctaed
		jz	short @@Got			; No, get it
		add	edi,size tFCB
		loop	@@Loop				; Loop till found
		jmp	short @@Err

@@Got:		clc
		jmp	short @@Exit

@@Err:		stc					; None found, error
		mov	ax,ERR_RFS_NoFCBs
@@Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_CalcFCB - calculate FCB address from file handle.
		; Input: EBX=file handle.
		; Output: CF=0 - OK, EAX=EDI=FCB address;
		;	  CF=1 - error, AX=error code.
proc RFS_CalcFCB near
		sub	ebx,BaseFCBs		; Subtract out basic FCB
		movzx	eax,[NumOfFCBs]
		cmp	ebx,eax			; See if too big
		jae	short @@Err		; Error if so
		mov	eax,ebx			; Else Mul by size
		mov	ebx,size tFCB
		push	edx
		mul	ebx
		pop	edx
		add	eax,[FCBstart]		; Add to start
		test	[dword eax],-1		; See if in use
		jz	short @@Err		; No, error
		mov	edi,eax
		clc
		ret

@@Err:		mov	ax,ERR_RFS_BadFCB
		stc
		ret
endp		;---------------------------------------------------------------


		; RFS_CalcBlock - calculate block to read or write at.
		; Input: EDI=pointer to FCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_CalcBlock near
		mov	ebx,[edi+tFCB.Page]		; Read file page
		mov	edx,[edi+tFCB.Device]
		call	BUF_ReadBlock
		jc	short @@Exit
		mov	eax,[edi+tFCB.PosPages]		; See if within direct entries
		cmp	eax,FPDirectEntries
		jc	short @@Single			; Yes- get block directly
		sub	eax,FPDirectEntries		; Else offset to first indir entry
		push	eax
		shr	eax,BLOCKSHIFT-2		; Divide by Entries per page
		mov	ebx,[esi+eax*4+tFilePage.Doubles] ; Find indir page
		call	BUF_ReadBlock			; Read it
		jnc	short @@GotIndir
		add	esp,4				; Keep error code
		stc
		jmp	short @@Exit
@@GotIndir:	pop	eax
		and	eax,BLOCKSIZE/4-1		; Mod is entry this page
		mov	ebx,[esi+eax*4]			; Target is indicated page
		jmp	short @@ReadTarget

@@Single:	mov	ebx,[esi+eax*4+tFilePage.Singles] ; Read from direct entry table
@@ReadTarget:	mov	[edi+tFCB.CurrPage],ebx		; Save as current page
		call	BUF_ReadBlock			; Read block
		jc	short @@Exit
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_DoTruncate - truncate a file (working routine).
		; Input: DL=file system linkpoint number,
		;	 EBX=file page begin block number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_DoTruncate near
@@fslp		EQU	ebp-4
@@deviceid	EQU	ebp-8

		push	ebp
		mov	ebp,esp
		sub	esp,8

		mov	[@@fslp],edx
		call	CFS_LPtoDevID
		jc	@@Error
		mov	[@@deviceid],edx
		call	BUF_ReadBlock		; Read file page
		jc	@@Error

		mov	[dword esi+tFilePage.Len],0 ; Mark len 0
		call	BUF_MarkDirty		; Dirty buffer
		mov	ecx,FPDirectEntries-1	; Number of direct entries to run through
		mov	dl,[@@fslp]

@@Singles:	mov	eax,[esi+4*ecx+tFilePage.Singles] ; Current entry
		or	eax,eax			; Zero entry is unallocated
		jz	short @@SNoDeall
		mov	[esi+4*ecx+tFilePage.Singles],0	; Else mark unallocated
		call    RFS_DeallocBlock	; Deallocate
		jc	short @@Error

@@SNoDeall:	dec	ecx			; Next entry
		jns	@@Singles
		mov	ecx,FPInDirEntries-1	; Number of indirect entries to run through

@@Doubles:	push	ebx ecx			; Save file page
		mov	ebx,[esi+4*ecx+tFilePage.Doubles] ; Get a double
		or	ebx,ebx				; If none allocated -
		jz	short @@NoDoubleDeall		; don't deallocate
		mov	[esi+4*ecx+tFilePage.Doubles],0	; Get entry

		mov	edx,[@@deviceid]
		call	BUF_ReadBlock		; Read the block
		jc	short @@Error
		call	BUF_MarkDirty		; Dirty it
		mov	eax,ebx			; Deallocate the block itself
		mov	dl,[@@fslp]
		call	RFS_DeallocBlock
		jc	short @@Error
		mov	ecx,BLOCKSIZE/4		; Number of items in a block

@@DoubleDeall:	mov	eax,[esi+4*ecx]		; Get one
		or	eax,eax
		jz	short @@TNoDeall	; Don't deallocate if not allocated
		mov	[dword esi+4*ecx],0	; Else mark deallocated
		call	RFS_DeallocBlock	; And deallocate it
		jc	short @@Error

@@TNoDeall:	dec	ecx             	; Next item this block
		jns	@@DoubleDeall

@@NoDoubleDeall:pop	ecx ebx			; Back to file page
		mov	edx,[@@deviceid]
		call	BUF_ReadBlock
		jc	short @@Error
		call	BUF_MarkDirty		; Dirty it
		dec	ecx			; Next indirect buffer
		jns	@@Doubles
		clc
		jmp	short @@Exit

@@Error:	stc
@@Exit:		mov	edx,[@@fslp]		; Restore FSLP
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_GetPosBuffer - calculate position to read or write at,
		;		      and length to read or write.
		; Input: [ESP+4]: TRUE if should dirty buffer (write),
		;		  FALSE otherwise
		;	 EBX=pointer to FCB.
		; Output:
		; Note: pascal-style call.
proc RFS_GetPosBuffer near
@@writing	EQU	ebp+8			; True if should dirty buffer

		push	ebp
		mov	ebp,esp

		push	ebx edi
		mov	edi,ebx
		mov	ebx,[edi+tFCB.CurrPage]		; Page number cached?
		or	ebx,ebx
		jz	short @@ReadPage		; No- go calculate
		mov	edx,[edi+tFCB.Device]		; Else read cached page
		call	BUF_ReadBlock
		jc	short @@Exit
		jmp	short @@GotPage

@@ReadPage:	call	RFS_CalcBlock			; Calculate page
		jc	short @@Exit

@@GotPage:	test	[byte @@writing],-1		; See if writing
		jz	short @@NotWriting		; No, don't dirty
		call	BUF_MarkDirty			; Else dirty

@@NotWriting:	add	esi,[edi+tFCB.PosBytes]		; Calculate amount left
		mov	eax,BLOCKSIZE
		sub	eax,[edi+tFCB.PosBytes]
		cmp	eax,ecx				; Greater than request?
		jc	short @@RestOfBuf
		mov	eax,ecx				; Yes, use request

@@RestOfBuf:	add	[edi+tFCB.PosBytes],eax		; Update position
		cmp	[dword edi+tFCB.PosBytes],BLOCKSIZE	; See if at end
		jc	short @@NotNew
		mov	[dword edi+tFCB.CurrPage],0		; No cached page
		sub	[dword edi+tFCB.PosBytes],BLOCKSIZE	; Update position
		inc	[dword edi+tFCB.PosPages]		; to next block

@@NotNew:	clc
@@Exit:		pop	edi ebx
		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_ReadShort - read from file <=BLOCKSIZE bytes
		;		(working routine).
		; Input: EBX=file handle,
		;	 ECX=number of bytes to read,
		;	 FS:ESI=address of buffer.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ReadShort near
		cmp	ecx,BLOCKSIZE			; Exit if request too big
		ja	short @@Error1
		or	ecx,ecx
		jz	short @@Done2
		call	RFS_CalcFCB			; Calculate FCB
		jc	short @@Error

		push	ebx
		mov	ebx,[edi+tFCB.PosPages]		; Calculate amount left
		shl	ebx,BLOCKSHIFT
		or	ebx,[edi+tFCB.PosBytes]
		mov	eax,[edi+tFCB.Pages]
		shl	eax,BLOCKSHIFT
		or	eax,[edi+tFCB.Bytes]
		sub	eax,ebx
		pop	ebx

		cmp	eax,ecx				; See if enough
		jnc	short @@OK			; to satisfy request
		mov	ecx,eax				; No, lower request

@@OK:		or	ecx,ecx				; See if any to get
		jz	short @@EOF			; EOF if none
		push	ecx				; Push total length
		mov	ebx,edi				; EBX = FCB
		mov	edi,esi
		push	FALSE				; Reading
		call	RFS_GetPosBuffer		; Get position
		jc	@@Error2
		push	es				; Move to user buffer
		push	fs
		pop	es
		push	ecx
		mov	ecx,eax
		rep	movsb
		pop	ecx
		sub	ecx,eax				; Subtract length moved
		pop	es
		jz	short @@Done			; Quit if done
		push	FALSE				; Else reading again
		call	RFS_GetPosBuffer		; Get position to read from
		jc	short @@Error2
		push	es            			; Move to user buffer
		push	fs
		pop	es
		push	ecx
		mov	ecx,eax
		rep	movsb
		pop	ecx
		pop	es

@@Done:		pop	ecx				; Restore length of request
@@Done2:	clc
		ret

@@Error2:	pop	ecx
		jmp	short @@Error
@@Error1:	mov	ax,ERR_FS_InvRWLen
@@Error:	stc
		ret
@@EOF:		xor	ecx,ecx				; EOF returns a zero count
		ret
endp		;---------------------------------------------------------------


        	; RFS_WriteShort - write to file <=BLOCKSIZE bytes
		;		(working routine).
		; Input: DL=file system linkpoint number,
		;	 EBX=file handle,
		;	 ECX=number of bytes to read.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_WriteShort near
@@fslp		EQU	ebp-4
@@ueof		EQU	ebp-8				; Extending EOF if true

		push	ebp
		mov	ebp,esp
		sub	esp,8
		push	ebx edx

		mov	[@@fslp],dl
		cmp	ecx,BLOCKSIZE			; Get out if too big request
		ja	@@Error1
		mov	[dword @@ueof],0		; Assume not extending EOF
		push	ecx
		or	ecx,ecx         		; Quit if no request
		jz	@@Done
		call	RFS_CalcFCB			; Calculate FCB
		jc	@@Error2

		mov	eax,[edi+tFCB.Pages]		; See if extending
		shl	eax,BLOCKSHIFT
		add	eax,[edi+tFCB.Bytes]
		mov	ebx,[edi+tFCB.PosPages]
		shl	ebx,BLOCKSHIFT
		add	ebx,[edi+tFCB.PosBytes]
		add	ebx,ecx
		cmp	eax,ebx
		jnc	short @@ToMiddle		; No, write to middle
		inc	[byte @@ueof]			; Else extending EOF
		push	[dword edi+tFCB.PosPages]	; Save position
		push	[dword edi+tFCB.PosBytes]
		mov	eax,[edi+tFCB.PosBytes]
		add	[edi+tFCB.PosBytes],ecx		; Find last page
		or	eax,eax
		jz	short @@Alloc
		cmp	[dword edi+tFCB.PosBytes],BLOCKSIZE
		jbe	short @@NoAlloc
		inc	[dword edi+tFCB.PosPages]

@@Alloc:	push	edx esi				; Allocate the page
		mov	dl,[@@fslp]
		call	RFS_ExtendFile
		pop	esi edx
		pop	[dword edi+tFCB.PosBytes]	; Restore position
		pop	[dword edi+tFCB.PosPages]
		jnc	short @@ToMiddle
		pop	ecx
		jmp	short @@Exit

@@NoAlloc:	pop	[dword edi+tFCB.PosBytes]	; Restore position
		pop	[dword edi+tFCB.PosPages]

@@ToMiddle:	mov	ebx,edi
		mov	edi,esi
		push	TRUE				; Writing
		call	RFS_GetPosBuffer		; Get position to write to
		jc	short @@Error2
		push	ds				; Move data from user buffer
		push	fs
		pop	ds
		xchg	esi,edi
		push	ecx
		mov	ecx,eax
		rep	movsb
		pop	ecx
		xchg	esi,edi
		pop	ds
		sub	ecx,eax				; Subtract amount moved
		jz	short @@Done			; Get out if done
		push	TRUE				; Writing
		call	RFS_GetPosBuffer		; Get position to write to
		jc	short @@Error2
		push	ds				; Write data from user buffer
		push	fs
		pop	ds
		xchg	esi,edi
		mov	ecx,eax
		rep	movsb
		pop	ds

@@Done:		pop	ecx				; Get length moved
		mov	edi,ebx
		test	[byte @@ueof],-1		; See if changing EOF
		jz	short @@NoUpdateEOF		; No, exit
		mov	ebx,[edi+tFCB.Page]		; Read file page
		call	BUF_ReadBlock
		jc	short @@Error
		call	BUF_MarkDirty			; Dirty it
		mov	eax,[edi+tFCB.PosPages]		; Get final position
		mov	[edi+tFCB.Pages],eax		; Update FCB len
		mov	ebx,eax
		shl	ebx,BLOCKSHIFT
		mov	eax,[edi+tFCB.PosBytes]
		mov	[edi+tFCB.Bytes],eax
		or	ebx,eax
		mov	[esi+tFilePage.Len],ebx		; Update file page len

@@NoUpdateEOF:	clc
		jmp	short @@Exit

@@Error2:	pop	ecx
		jmp	short @@Error
@@Error1:	mov	ax,ERR_FS_InvRWLen
@@Error:	stc
@@Exit:		pop	edx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_ExtendFile - extend a file by one page.
		; Input: DL=file system linkpoint number,
		;	 EDI=pointer to FCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ExtendFile near
@@fslp		EQU	ebp-4

		push	ebp
		mov	ebp,esp
		sub	esp,4

		mov	[@@fslp],edx
		mov	ebx,[edi+tFCB.Page]		; Read file page
		mov	edx,[edi+tFCB.Device]
		call	BUF_ReadBlock
		jc	@@Exit
		mov	eax,[edi+tFCB.PosPages]		; Get position to allocate at
		cmp	eax,FPDirectEntries		; See if in direct entries
		jc	short @@Single

		sub	eax,FPDirectEntries		; No, offset to first indir entry
		push	eax
		shr	eax,BLOCKSHIFT-2
		lea	ebx,[esi+eax*4+tFilePage.Doubles] ; Point at relevant indir entry
		test	[dword ebx],-1			; See if allocated
		jnz	short @@NoAlloc			; Yes, don't allocate
		push	edx				; No, allocate
		mov	dl,[@@fslp]
		call	RFS_AllocBlock
		pop	edx
		jc	short @@Error
		call	BUF_MarkDirty			; Dirty file page
		mov	[ebx],eax			; Save allocated
		mov	ebx,eax				; Get allocated page
		call	BUF_Write			; Going to wipe it out
		jc	short @@Error
		call	BUF_MarkDirty			; Dirty it
		push	ecx edi
		mov	edi,esi				; Zero it out
		xor	eax,eax
		mov	ecx,BLOCKSIZE/4
		rep	stosd
		pop	edi ecx
		jmp	short @@NoAlloc2

@@NoAlloc:	mov	ebx,[ebx]			; Get previously allocated indir block
@@NoAlloc2:	call	BUF_ReadBlock			; Read it
		jc	short @@Error
		pop	eax
		and	eax,BLOCKSIZE/4-1		; Find the entry in it
		lea	ebx,[esi+eax*4]			; Point to it
		jmp	short @@ReadTarget

@@Single:	lea	ebx,[esi+eax*4+tFilePage.Singles] ; Point to singles entry
@@ReadTarget:	mov	eax,[ebx]			; Get it
		or	eax,eax				; Already allocated?
		jnz	short @@OK			; yes- Get out

		push	edx				; Otherwise allocated
		mov	dl,[@@fslp]
		call	RFS_AllocBlock
		pop	edx
		jc	short @@Exit
		call	BUF_MarkDirty			; Dirty the buffer
		mov	[ebx],eax			; Save allocated block

@@OK:		clc
		jmp	short @@Exit
@@Error:	add	esp,4
		stc
@@Exit: 	mov	edx,[@@fslp]
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_CompressTime - get current date and time
		;		      and compress it into double word.
		; Input: none.
		; Output: EAX=compressed time.
proc RFS_CompressTime near
		push	ebx ecx
		call	K_GetDate		; Get date
		xor	eax,eax
		mov	al,bh			; EAX = month : 4
		shl	eax,5
		or	al,bl			; OR day : 5
		shl	eax,7                   ; OR year : 7
		and	cl,07Fh
		or	al,cl

		call	K_GetTime		; Get time
		shl	eax,5			; OR Hours : 5
		or	al,bh
		shl	eax,6			; OR Mins : 6
		or	al,bl
		shr	cl,1			; OR Seconds : 5
		shl	eax,5
		or	al,cl
		pop	ecx ebx
		ret
endp		;---------------------------------------------------------------

ends