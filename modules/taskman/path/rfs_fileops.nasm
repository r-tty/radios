;-------------------------------------------------------------------------------
; rfs_fileops.nasm - basic file operations.
;-------------------------------------------------------------------------------

module tm.pathman.rfs_fileops

%include "errors.ah"
%include "pool.ah"
%include "time.ah"
%include "tm/inode.ah"
%include "tm/rfs.ah"
%include "rm/stat.ah"

publicproc RFS_InitOCBpool

externproc PoolInit, PoolAllocChunk, PoolChunkNumber, PoolChunkAddr
externproc RFS_SearchForFileName
externproc RFS_InsertFileName, RFS_DeleteFileName
externproc RFS_AllocBlock, RFS_DeallocBlock

library $libc
importproc _ClockTime

section .bss

?MaxOCBs	RESD	1
?OCBpool	RESB	tMasterPool_size


section .text

		; RFS_InitOCBpool - initialize OCB pool.
		; Input: EAX=maximum number of OCBs.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_InitOCBpool
		mov	[?MaxOCBs],eax
		xor	ecx,ecx
		mov	ebx,?OCBpool
		mov	cl,tRFSOCB_size
		call	PoolInit
		ret
endp		;---------------------------------------------------------------


		; RFS_CreateFile - create a file.
		; Input: ESI=pointer to name.
		; Output: CF=0 - OK, EAX=file descriptor;
		;	  CF=1 - error, AX=error code.
proc RFS_CreateFile
		locauto	timestamp, Qword_size
		locauto	dirent, tDirEntry_size		; Name buffer

		prologue
		mpush	ebx,ecx,edx,esi,edi

		mov	ecx,RFS_FILENAMELEN		; Move name to stack
		lea	edi,[%$dirent]
	;	call	MoveNameToStack			; XXX
	;	jc	near .Error

		lea	esi,[%$dirent]
		call	RFS_SearchForFileName		; See if name exists
		jnc	near .ExistingFile		; Yes, go truncate it
		cmp	ax,ENOENT			; Else see if not found
		jne	near .Error			; No, service other errors
		call	RFS_AllocBlock			; Else allocate the file block
		jc	near .Error

		mov	ebx,eax
		mBseek
		mov	edi,esi				; Blank it to zeros
		xor	eax,eax
		mov	ecx,RFS_BLOCKSIZE/4
		rep	stosd
		push	esi				; Move the name to it
		lea	edi,[esi+tFileNode.Name]
		lea	esi,[%$dirent]
		push	esi
		mov	ecx,RFS_FILENAMELEN / 4
		rep	movsd
		pop	esi				; Save file node
		mov	[esi+tDirEntry.Entry],ebx	; in directory entry
		mov	byte [esi+tDirEntry.Flags],0
		mov	dword [esi+tDirEntry.More],0

		xchg	esi,[esp]
		mov	word [esi+tFileNode.Sig],RFS_FNSignature

		lea	eax,[%$timestamp]
		Ccall	_ClockTime, CLOCK_REALTIME, 0, eax
		mov	eax,[%$timestamp]
		mov	[esi+tFileNode.IAttr+tInodeAttr.LWtime],eax
		mov	eax,[%$timestamp+4]
		mov	[esi+tFileNode.IAttr+tInodeAttr.LWtime+4],eax
		
		call	RFS_InsertFileName		; Go insert the file name
		jc	.Exit

.OpenFile:	lea	esi,[%$dirent]			; Open the file
		call	RFS_OpenFile
		jmp	.Exit

.ExistingFile:	lea	esi,[%$dirent]			; Existing file, open it
		call	RFS_OpenFile
		mov	ebx,eax				; Save filedes
		jc	.Exit
		push	eax
		call	RFS_TruncateFile		; Truncate it
		pop	ebx
		jnc	.OK
		push	ebx
		push	eax
		call	RFS_CloseFile
		pop	ebx				; Doing a swap with pops
		pop	eax
		jmp	.Error

.OK:		mov	eax,ebx
		jmp	short .Exit

.Error:		stc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_OpenFile - open a file.
		; Input: ESI=pointer to name.
		; Output: CF=0 - OK, EAX=file descriptor;
		;	  CF=1 - error, AX=error code.
proc RFS_OpenFile
		locauto	dirent, tDirEntry_size		; Name buffer

		prologue
		mpush	ebx,ecx,edx,esi,edi

		mov	ecx,RFS_FILENAMELEN
		lea	edi,[%$dirent]			; Get name to stack
	;	call	MoveNameToStack			; XXX
	;	jc	.Error
		call	RFS_GetOCB			; Find a free OCB
		jc	short .Error

		lea	esi,[%$dirent]			; Search for file
		push	edi
		call	RFS_SearchForFileName
		pop	edi
		jc	.Error

		mov	ebx,eax
		mBseek					; Seek to a file block

		mov	eax,[esi+tFileNode.Len]		; Get length to OCB
		mov	[edi+tRFSOCB.Bytes],eax
		and	dword [edi+tRFSOCB.Bytes],RFS_BLOCKSIZE-1
		shr	eax,RFS_BLOCKSHIFT
		mov	[edi+tRFSOCB.Pages],eax
		mov	[edi+tRFSOCB.FSaddr],edx	; FS address to OCB
		mov	[edi+tRFSOCB.Page],ebx		; File page to OCB
		xor	eax,eax
		mov	[edi+tRFSOCB.PosBytes],eax	; Position = start of file
		mov	[edi+tRFSOCB.PosPages],eax
		mov	[edi+tRFSOCB.CurrPage],eax	; Current page not loaded
		
		mov	esi,edi				; Calculate filedes
		call	PoolChunkNumber
		jc	.Exit

.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret

.Error:		mov	dword [edi+tRFSOCB.Page],0
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_CloseFile - close a file.
		; Input: EBX=file descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_CloseFile
		mpush	ebx,edx,esi,edi
		call	RFS_CalcOCB			; Calculate OCB address
		jc	.Exit
		mov	ebx,[edi+tRFSOCB.Page]		; Seek at file page
		mov	edx,[edi+tRFSOCB.FSaddr]
		mBseek
		mov	eax,[edi+tRFSOCB.Bytes]		; Update file length
		mov	ebx,[edi+tRFSOCB.Pages]
		shl	ebx,RFS_BLOCKSHIFT
		add	eax,ebx
		mov	[esi+tFileNode.Len],eax
		mov	dword [edi+tRFSOCB.Page],0	; Release OCB
.Exit:		mpop	edi,esi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_Delete - delete a file.
		; Input: ESI=pointer to file name.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_DeleteFile
		locauto	dirent, tDirEntry_size		; Name buffer

		prologue
		mpush	ebx,ecx,edx,esi,edi

		mov	ecx,RFS_FILENAMELEN		; Move name to stack
		lea	edi,[%$dirent]
	;	call	MoveNameToStack			; XXX
	;	jc	.Exit

		lea	esi,[%$dirent]			; Search for name
		call	RFS_SearchForFileName
		jc	.Exit
		mov	ebx,eax				; Truncate the file
		call	DoTruncate
		jc	.Exit

		mov	eax,ebx				; Deallocate file page
		call	RFS_DeallocBlock
		jc	.Exit
		pushimm	0				; Delete the name
		lea	edi,[%$dirent]			; from the directory
		push	edi
		call	RFS_DeleteFileName
		jc	.Exit
		xor	eax,eax

.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret

.Error:		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_TruncateFile - truncate a file.
		; Input: EBX=file descriptor.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_TruncateFile
		mpush	ebx,ecx,edx,esi,edi
		call	RFS_CalcOCB			; Get OCB
		jc	.Exit
		mov	edx,[edi+tRFSOCB.FSaddr]
		mov	ebx,[edi+tRFSOCB.Page]		; Truncate
		call	DoTruncate
		jc	.Exit
		xor	eax,eax
		mov	[edi+tRFSOCB.Pages],eax		; Reset position
		mov	[edi+tRFSOCB.PosPages],eax	; and length
		mov	[edi+tRFSOCB.Bytes],eax
		mov	[edi+tRFSOCB.PosBytes],eax
.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_RenameFile - rename a file.
		; Input: ESI=old name,
		;	 EDI=new name.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc RFS_RenameFile
		locauto	newdirent, tDirEntry_size		; New name
		locauto	olddirent, tDirEntry_size		; Old name

		prologue
		mpush	ebx,ecx,edx,esi,edi

		mov	ecx,RFS_FILENAMELEN			; Move names to stack
		push	edi
		lea	edi,[%$olddirent]
	;	call	MoveNameToStack
		pop	edi
	;	jc	.Error

		mov	esi,edi
		lea	edi,[%$newdirent]
	;	call	CFS_MoveNameToStack
	;	jc	.Error

		xor	eax,eax
		mov	[%$newdirent+tDirEntry.Flags],al	; Set params
		mov	[%$newdirent+tDirEntry.More],eax	; of new entry
		lea	esi,[%$olddirent]			; Get old entry file page
		call	RFS_SearchForFileName
		jc	.Exit

		mov	[%$newdirent+tDirEntry.Entry],eax ; Save in new entry
		lea	edi,[%$newdirent]			; Insert new file name
		push	edi
		call	RFS_InsertFileName
		jc	.Exit

		pushimm	0				; Delete old file name
		lea	edi,[%$olddirent]
		push	edi
		call	RFS_DeleteFileName
		jc	.Exit
		mov	ebx,[%$newdirent+tDirEntry.Entry]	; Get the file page
		mBseek
		lea	edi,[esi+tFileNode.Name]	; Change the name
		lea	esi,[%$newdirent]		; in the file page
		mov	ecx,RFS_FILENAMELEN/4
		rep	movsd

.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_ReadLong - read large number of bytes.
		; Input: EBX=file descriptor,
		;	 ECX=number of bytes to read,
		;	 ESI=address of buffer to read.
		; Output: CF=0 - OK, ECX=number of read bytes;
		;	  CF=1 - error, AX=error code.
proc RFS_ReadLong
		locals	bytes

		prologue
		mpush	ebx,edx,esi,edi

		mov	dword [%$bytes],0	; Bytes read = 0

.Loop:		cmp	ecx,RFS_BLOCKSIZE	; Just one block?
		jc	.Last			; Yes, go do it
		push	ecx			; Save count and position
		push	esi
		mov	ecx,RFS_BLOCKSIZE	; Read in a block
		push	edx
		call	ReadShort
		pop	edx
		jc	.Exit
		add	[%$bytes],ecx		; Update read count
		pop	esi			; Update position
		add	esi,ecx
		cmp	ecx,RFS_BLOCKSIZE	; See if full read
		pop	ecx
		jnz	short .OK		; Get out if not
		sub	ecx,RFS_BLOCKSIZE	; Decrement amount left
		jmp	.Loop			; Loop again

.Last:		call	ReadShort		; Read last block.  Block routine
						; Checks for 0 bytes
		jc	.Exit			; Error, exit
		add	[%$bytes],ecx		; Add number of bytes read to rv

.OK:		clc
.Exit:		mov	ecx,[%$bytes]
		mpop	edi,esi,edx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_WriteLong - write large number of bytes.
		; Input: EBX=file descriptor,
		;	 ECX=number of bytes,
		;	 ESI=address of buffer to write.
		; Output: CF=0 - OK, ECX=number of bytes written;
		;	  CF=1 - error, AX=error code.
proc RFS_WriteLong
		locals	bytes

		prologue
		mpush	ebx,edx,esi,edi

		mov	dword [%$bytes],0	; Bytes written = 0
.Loop:		cmp	ecx,RFS_BLOCKSIZE	; Just one block?
		jc	.Last			; Yeah, go do it

		push	ecx			; Save count and position
		push	esi
		mov	ecx,RFS_BLOCKSIZE	; Write in a block
		call	WriteShort
		jc	.Exit			; Exit if error
		add	[%$bytes],ecx		; Else update write count
		pop	esi			; Update position
		add	esi,ecx
		pop	ecx			; Decrement amount left
		sub	ecx,RFS_BLOCKSIZE
		jmp	.Loop			; Loop again

.Last:		call	WriteShort		; Write last block.  Block routine
						; Checks for 0 bytes
		jc	short .Exit		; Error, get out
		add	[%$bytes],ecx		; Add number of bytes Written to rv
		clc

.Exit:   	mov	ecx,[%$bytes]
		mpop	edi,esi,edx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_SetFilePos - set file position.
		; Input: EBX=file descriptor,
		;	 ECX=offset,
		;	 DL=origin (0=begin, 1=current position, 2=end).
		; Output: CF=0 - OK, EAX=new position;
		;	  CF=1 - error, AX=error code.
proc RFS_SetFilePos
		push	ecx
		call	RFS_CalcOCB			; Calculate OCB
		jc	.Exit
		or	dl,dl		
		jz	.FromBegin
		dec	dl
		jnz	.FromEnd
		mov	eax,[edi+tRFSOCB.PosPages]		; Get org position
		shl	eax,RFS_BLOCKSHIFT
		or	eax,[edi+tRFSOCB.PosBytes]
		add	ecx,eax
		jmp	.FromBegin
.FromEnd:	mov	eax,[edi+tRFSOCB.Pages]		; Get org position
		shl	eax,RFS_BLOCKSHIFT
		or	eax,[edi+tRFSOCB.Bytes]
		add	ecx,eax
.FromBegin:	mov	eax,[edi+tRFSOCB.Pages]		; Get org position
		shl	eax,RFS_BLOCKSHIFT
		or	eax,[edi+tRFSOCB.Bytes]
		cmp	ecx,eax
		jb	.DoLoad
		mov	ecx,eax
.DoLoad:	mov	[edi+tRFSOCB.PosBytes],ecx	; Set new position
		and	dword [edi+tRFSOCB.PosBytes],RFS_BLOCKSIZE-1
		shr	ecx,RFS_BLOCKSHIFT
		mov	[edi+tRFSOCB.PosPages],ecx
		mov	dword [edi+tRFSOCB.CurrPage],0
		mov	eax,ecx
		clc
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_GetFilePos - get file position.
		; Input: EBX=file descriptor.
		; Output: CF=0 - OK, ECX=file position;
		;	  CF=1 - error, AX=error code.
proc RFS_GetFilePos
		call	RFS_CalcOCB			; Get OCB address
		jc	.Exit
		mov	ecx,[edi+tRFSOCB.PosPages]		; Load position
		shl	ecx,RFS_BLOCKSHIFT
		or	ecx,[edi+tRFSOCB.PosBytes]
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_GoEOF - Go to end of file.
		; Input: EBX=file descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_GoEOF
		call	RFS_CalcOCB			; Calculate OCB
		jc	.Exit
		mov	eax,[edi+tRFSOCB.Page]		; Position to end
		mov	[edi+tRFSOCB.PosPages],eax
		mov	eax,[edi+tRFSOCB.Bytes]
		mov	[edi+tRFSOCB.PosBytes],eax
.Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_SetFileAttr - set file attributes.
		; Input:
		; Output:
proc RFS_SetFileAttr
		ret
endp		;---------------------------------------------------------------


		; RFS_GetFileAttr - set file attributes.
		; Input:
		; Output:
proc RFS_GetFileAttr
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---


		; Get an OCB.
		; Input: none.
		; Output: CF=0 - OK, EDI=OCB address;
		;	  CF=1 - error, AX=error code.
proc RFS_GetOCB
		push	ebx
		mov	ebx,?OCBpool
		call	PoolAllocChunk
		jc	.Exit
		mov	edi,esi
.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_CalcOCB - calculate OCB address from file descriptor.
		; Input: EBX=file descriptor.
		; Output: CF=0 - OK, EDI=OCB address;
		;	  CF=1 - error, AX=error code.
proc RFS_CalcOCB
		mpush	ebx,esi
		mov	eax,ebx
		mov	ebx,?OCBpool
		call	PoolChunkAddr
		jc	.Exit
		mov	edi,esi
.Exit:		mpop	esi,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_CalcBlock - calculate block to read or write at.
		; Input: EDI=OCB address.
		; Output: CF=0 - OK, ESI=block address;
		;	  CF=1 - error, AX=error code.
proc RFS_CalcBlock
		mov	ebx,[edi+tRFSOCB.Page]		; Read file page
		mov	edx,[edi+tRFSOCB.FSaddr]
		mBseek
		mov	eax,[edi+tRFSOCB.PosPages]	; See if within direct entries
		cmp	eax,RFS_FNDirectEntries
		jc	.Single				; Yes - get block directly
		sub	eax,RFS_FNDirectEntries		; Else offset to first indir entry
		push	eax
		shr	eax,RFS_BLOCKSHIFT-2		; Divide by Entries per page
		mov	ebx,[esi+eax*4+tFileNode.Doubles] ; Find indir page
		mBseek
		pop	eax
		and	eax,RFS_BLOCKSIZE/4-1		; Mod is entry this page
		mov	ebx,[esi+eax*4]			; Target is indicated page
		jmp	.ReadTarget
.Single:	mov	ebx,[esi+eax*4+tFileNode.Singles] ; Read from direct entry table
.ReadTarget:	mov	[edi+tRFSOCB.CurrPage],ebx	; Save as current page
		mBseek
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Truncate a file.
		; Input: EDX=file system address,linkpoint number,
		;	 EBX=file page starting block number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc DoTruncate
		push	ecx
		mBseek
		mov	dword [esi+tFileNode.Len],0	; Mark len 0
		mov	ecx,RFS_FNDirectEntries-1	; Number of direct entries to run through

.Singles:	mov	eax,[esi+4*ecx+tFileNode.Singles] ; Current entry
		or	eax,eax				; Zero entry is unallocated
		jz	.SNoDeall
		mov	dword [esi+4*ecx+tFileNode.Singles],0	; Else mark unallocated
		call    RFS_DeallocBlock		; Deallocate
		jc	.Exit

.SNoDeall:	dec	ecx				; Next entry
		jns	.Singles
		mov	ecx,RFS_FNIndirEntries-1	; Number of indirect entries to run through

.Doubles:	mpush	ebx,ecx			; Save file page
		mov	ebx,[esi+4*ecx+tFileNode.Doubles] ; Get a double
		or	ebx,ebx				; If none allocated -
		jz	short .NoDoubleDeall		; don't deallocate
		mov	dword [esi+4*ecx+tFileNode.Doubles],0	; Get entry

		mBseek
		mov	eax,ebx				; Deallocate the block itself
		call	RFS_DeallocBlock
		jc	.Exit
		mov	ecx,RFS_BLOCKSIZE/4		; Number of items in a block

.DoubleDeall:	mov	eax,[esi+4*ecx]		; Get one
		or	eax,eax
		jz	short .TNoDeall		; Don't deallocate if not allocated
		mov	dword [esi+4*ecx],0	; Else mark deallocated
		call	RFS_DeallocBlock	; And deallocate it
		jc	.Exit

.TNoDeall:	dec	ecx             	; Next item this block
		jns	.DoubleDeall

.NoDoubleDeall:	mpop	ecx,ebx			; Back to file page
		mBseek
		dec	ecx			; Next indirect buffer
		jns	.Doubles
		clc
		jmp	short .Exit

.Exit:		push	ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_CalcPosLen - calculate position to read or write at,
		;		   and length to read or write.
		; Input: EDI=pointer to OCB.
		; Output: CF=0 - OK:
		;		    ESI=position (address),
		;		    ECX=length;
		;	  CF=1 - error, AX=error code.
proc RFS_CalcPosLen
		mpush	ebx,edi

		mov	ebx,[edi+tRFSOCB.CurrPage]	; Page number cached?
		or	ebx,ebx
		jz	.ReadPage			; No - go calculate
		mov	edx,[edi+tRFSOCB.FSaddr]	; Else read cached page
		mBseek
		jmp	.GotPage

.ReadPage:	call	RFS_CalcBlock			; Calculate page
		jc	.Exit

.GotPage:	add	esi,[edi+tRFSOCB.PosBytes]	; Calculate amount left
		mov	eax,RFS_BLOCKSIZE
		sub	eax,[edi+tRFSOCB.PosBytes]
		cmp	eax,ecx				; Greater than request?
		jc	.RestOfBuf
		mov	eax,ecx				; Yes, use request

.RestOfBuf:	add	[edi+tRFSOCB.PosBytes],eax		; Update position
		cmp	dword [edi+tRFSOCB.PosBytes],RFS_BLOCKSIZE	; See if at end
		jc	.NotNew
		mov	dword [edi+tRFSOCB.CurrPage],0		; No cached page
		sub	dword [edi+tRFSOCB.PosBytes],RFS_BLOCKSIZE	; Update position
		inc	dword [edi+tRFSOCB.PosPages]		; to next block

.NotNew:	clc
.Exit:		mpop	edi,ebx
		ret
endp		;---------------------------------------------------------------


		; Read from file <=RFS_BLOCKSIZE bytes.
		; Input: EBX=file descriptor,
		;	 ECX=number of bytes to read,
		;	 ESI=address of buffer where to read.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ReadShort
		cmp	ecx,RFS_BLOCKSIZE		; Exit if request too big
		ja	.Error1
		or	ecx,ecx
		jz	.Done2
		call	RFS_CalcOCB			; Calculate OCB
		jc	.Error

		push	ebx
		mov	ebx,[edi+tRFSOCB.PosPages]	; Calculate amount left
		shl	ebx,RFS_BLOCKSHIFT
		or	ebx,[edi+tRFSOCB.PosBytes]
		mov	eax,[edi+tRFSOCB.Pages]
		shl	eax,RFS_BLOCKSHIFT
		or	eax,[edi+tRFSOCB.Bytes]
		sub	eax,ebx
		pop	ebx

		cmp	eax,ecx				; See if enough
		jnc	.SizeOK				; to satisfy request
		mov	ecx,eax				; No, lower request

.SizeOK:	or	ecx,ecx				; See if any to get
		jz	.EOF				; EOF if none
		mov	ebx,esi
		push	ecx				; Push total length
		call	RFS_CalcPosLen			; Get position
		jc	.Error2
		
		mpush	ecx,edi				; Move to user buffer
		mov	ecx,eax
		mov	edi,ebx
		rep	movsb
		mpop	edi,ecx
		sub	ecx,eax				; Subtract length moved
		jz	.Done				; Quit if done
		call	RFS_CalcPosLen			; Get position to read from
		jc	.Error2
		
		mov	edi,ebx				; Move to user buffer
		mov	ecx,eax
		rep	movsb

.Done:		pop	ecx				; Restore length of request
.Done2:		clc
		ret

.Error2:	pop	ecx
		jmp	short .Error
.Error1:	mov	ax,EINVAL
.Error:		stc
		ret
.EOF:		xor	ecx,ecx				; EOF returns a zero count
		ret
endp		;---------------------------------------------------------------


        	; Write to file <=RFS_BLOCKSIZE bytes.
		; Input: EBX=file descriptor,
		;	 ECX=number of bytes to read.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc WriteShort
		locals	len, ueof			; Extending EOF if true

		prologue
		mpush	ebx,edx

		cmp	ecx,RFS_BLOCKSIZE		; Get out if too big request
		ja	near .Err1
		mov	dword [%$ueof],0		; Assume not extending EOF
		mov	[%$len],ecx
		or	ecx,ecx         		; Quit if no request
		jz	near .Done
		call	RFS_CalcOCB			; Calculate OCB
		jc	near .Exit

		mov	edx,[edi+tRFSOCB.FSaddr]
		mov	eax,[edi+tRFSOCB.Pages]		; See if extending
		shl	eax,RFS_BLOCKSHIFT
		add	eax,[edi+tRFSOCB.Bytes]
		mov	ebx,[edi+tRFSOCB.PosPages]
		shl	ebx,RFS_BLOCKSHIFT
		add	ebx,[edi+tRFSOCB.PosBytes]
		add	ebx,ecx
		cmp	eax,ebx
		jnc	.ToMiddle			; No, write to middle
		inc	byte [%$ueof]			; Else extending EOF
		push	dword [edi+tRFSOCB.PosPages]	; Save position
		push	dword [edi+tRFSOCB.PosBytes]
		mov	eax,[edi+tRFSOCB.PosBytes]
		add	[edi+tRFSOCB.PosBytes],ecx	; Find last page
		or	eax,eax
		jz	.Alloc
		cmp	dword [edi+tRFSOCB.PosBytes],RFS_BLOCKSIZE
		cmc
		jae	short .NoAlloc
		inc	dword [edi+tRFSOCB.PosPages]

.Alloc:		call	RFS_ExtendFile			; Allocate the page

.NoAlloc:	pop	dword [edi+tRFSOCB.PosBytes]	; Restore position
		pop	dword [edi+tRFSOCB.PosPages]
		jc	.Exit

.ToMiddle:	mov	ebx,esi
		call	RFS_CalcPosLen			; Get position to write to
		jc	.Exit

		mpush	ecx,esi,edi			; Move data from user buffer
		mov	edi,esi
		mov	esi,ebx
		mov	ecx,eax
		rep	movsb
		mpop	edi,esi,ecx

		sub	ecx,eax				; Subtract amount moved
		jz	.Done				; Get out if done
		call	RFS_CalcPosLen			; Get position to write to
		jc	.Exit
		mpush	esi,edi
		mov	ecx,eax				; Write data from user buffer
		mov	edi,esi
		mov	esi,ebx
		rep	movsb
		mpop	edi,esi

.Done:		mov	ecx,[%$len]			; Get length moved
		test	byte [%$ueof],-1		; See if changing EOF
		jz	.OK				; No, exit
		mov	ebx,[edi+tRFSOCB.Page]		; Read file page
		mBseek
		mov	eax,[edi+tRFSOCB.PosPages]	; Get final position
		mov	[edi+tRFSOCB.Pages],eax		; Update OCB len
		mov	ebx,eax
		shl	ebx,RFS_BLOCKSHIFT
		mov	eax,[edi+tRFSOCB.PosBytes]
		mov	[edi+tRFSOCB.Bytes],eax
		or	ebx,eax
		mov	[esi+tFileNode.Len],ebx		; Update file page len

.OK:		clc
.Exit:		mpop	edx,ebx
		epilogue
		ret

.Err1:		mov	ax,EINVAL
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_ExtendFile - extend a file by one page.
		; Input: EDI=address of OCB.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_ExtendFile
		locals	ieofs
		prologue

		mpush	ebx,ecx,esi
		mov	ebx,[edi+tRFSOCB.Page]		; Read file page
		mov	edx,[edi+tRFSOCB.FSaddr]
		mBseek
		mov	eax,[edi+tRFSOCB.PosPages]	; Get position to allocate at
		cmp	eax,RFS_FNDirectEntries		; See if in direct entries
		jc	.Single

		sub	eax,RFS_FNDirectEntries		; No, offset to first indir entry
		mov	[%$ieofs],eax
		shr	eax,RFS_BLOCKSHIFT-2
		lea	ebx,[esi+eax*4+tFileNode.Doubles] ; Point at relevant indir entry
		test	dword [ebx],-1			; See if allocated
		jnz	.NoAlloc			; Yes, don't allocate
		call	RFS_AllocBlock			; No, allocate
		jc	.Exit
		mov	[ebx],eax			; Save allocated
		mov	ebx,eax				; Get allocated page
		mpush	ecx,edi
		mov	edi,esi				; Zero it out
		xor	eax,eax
		mov	ecx,RFS_BLOCKSIZE/4
		rep	stosd
		mpop	edi,ecx
		jmp	.NoAlloc2

.NoAlloc:	mov	ebx,[ebx]			; Get previously allocated indir block
.NoAlloc2:	mBseek					; Seek at it
		mov	eax,[%$ieofs]
		and	eax,RFS_BLOCKSIZE/4-1		; Find the entry in it
		lea	ebx,[esi+eax*4]			; Point to it
		jmp	.ReadTarget

.Single:	lea	ebx,[esi+eax*4+tFileNode.Singles] ; Point to singles entry
.ReadTarget:	mov	eax,[ebx]			; Get it
		or	eax,eax				; Already allocated?
		jnz	.OK				; Yes - get out

		call	RFS_AllocBlock			; Otherwise allocate
		mov	[ebx],eax			; Save allocated block

.OK:		clc
.Exit:		mpop	esi,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------
