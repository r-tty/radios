;*******************************************************************************
;  dirs.nasm - RFS directory manipulations;
;		the B-TREE directory structure handling;
;		handles inserts, deletes, balancing.
;*******************************************************************************


; --- Procedures ---

section .text

		; RFS_CompareName - compare two names.
		; Input: EDX=first name,
		;	 EBX=second name.
		; Output: ZF=1 - equal;
		;	  ZF=0 - not equal.
proc RFS_CompareName
		mpush	ecx,esi,edi
		mov	ecx,FILENAMELEN		; Name length
		mov	esi,ebx			; File to compare in edx
		mov	edi,eax			; Buffered file name in eax
		cld
		repe	cmpsb
		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_FindEntry - find the position an entry would be inserted
		;		  into in this block (binary search).
		; Input: EBX=pointer to directory entry,
		;	 ESI=pointer to directory page.
		; Output: CF=0 - OK, ESI=pointer to entry;
		;	  CF=1 - error (position not found).
proc RFS_FindEntry
		push	edi
		movzx	ecx,byte [esi+tDirPage.Items]	; Get total items
		add	esi,FIRSTDIRENTRY		; Point at first entry
		or	ecx,ecx				; Quit if no items
		jz	short .Err
		mov	edi,esi				; EDI point beyond last entry
		shl	ecx,DIRENTRYSHIFT
		add	edi,ecx

.Loop:		mov	eax,edi				; Find out if converged
		sub	eax,esi
		cmp	eax,DIRENTRYSIZE		; Quit if no midpoint
		je	short .GotEntry
		bt	eax,DIRENTRYSHIFT
		mov	eax,0
		jnc	short .IsEven			; Else make sure we are
		mov	al,DIRENTRYSIZE			; Going to be on an even

.IsEven:	add	eax,esi				; boundary when divide by 2
		add	eax,edi				; Find midpoint
		shr	eax,1
		call	RFS_CompareName			; Compare
		jz	short .IsEqual			; If equal, get out
		jl	short .MoveDown			; Else decide which way to go
		mov	esi,eax				; Move bottom up
		jmp	.Loop				; Next test

.MoveDown:	mov	edi,eax				; Move bottom down
		jmp	.Loop				; Next test

.IsEqual:	mov	esi,eax				; Found it, get out
		clc
		jmp	short .Exit

.GotEntry:	mov	eax,esi				; Not in block,
		call	RFS_CompareName			; See which is bigger
		clc
		jle	short .Exit			; Leave ESI
		mov	esi,edi				; pointing above
		jmp	short .Exit
.Err:		stc
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; RFS_InsertEntry - insert an entry in this block.
		; Input: ESI=address of position an entry would be inserted,
		;	 EDI=address of directory page,
		;	 EBX=address of data.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc RFS_InsertEntry
		cmp	byte [edi+tDirPage.Items],MAXDIRITEMS	; See if full
		je	short .Err				; Get out if so
		mpush	ecx,edi,esi
		add	edi,BLOCKSIZE			; Find top
		mov	ecx,edi				; Get len to move
		sub	ecx,esi
		sub	ecx,DIRENTRYSIZE
		shr	ecx,2				; 4 bytes / move
		sub	edi,4				; Point at first word to move
		mov	esi,edi				; Find source of move
		sub	esi,DIRENTRYSIZE
		std					; Move down
		rep	movsd
		cld
		pop	edi				; Get position to insert
		push	edi
		mov	esi,ebx				; Data to move in
		mov	ecx,DIRENTRYSIZE		; Length of data
		shr	ecx,2				; Moving words
		rep	movsd				; Move
		mpop	esi,edi,ecx			; Restore regs
		inc	byte [edi+tDirPage.Items]	; Inc count
		clc					; Get out
		ret
.Err:		stc					; Error
		ret
endp		;---------------------------------------------------------------


		; RFS_DeleteEntry - delete an entry in block.
		; Input: EDI=directory page address,
		;	 ESI=entry address
		; Output: ZF=0 - number of entries!=0;
		;	  ZF=1 - number of entries==0.
proc RFS_DeleteEntry
		dec	byte [edi+tDirPage.Items]	; Decrement items
		pushfd
		mpush	ecx,esi,edi
		mov	ecx,edi				; ECX will have len to move
		add	ecx,BLOCKSIZE
		mov	edi,esi				; Find source
		add	esi,DIRENTRYSIZE
		sub	ecx,esi				; Calculate len
		shr	ecx,2				; Moving words
		rep	movsd
		pop	edi				; Get buffer
		push	edi
		add	edi,BLOCKSIZE-DIRENTRYSIZE	; Point at last entry in buffer
		mov	ecx,DIRENTRYSIZE/4		; Fill it with FFs
		sub	eax,eax
		dec	eax
		rep	stosd
		mpop	edi,esi,ecx
		popfd					; Get status of decrement
		clc
		ret
endp		;---------------------------------------------------------------


		; RFS_AdjustDirIndex - adjust directory index if it was changed.
		; Input: EAX=owning directory index,
		;	 EBX=new index,
		;	 DL=FSLP.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_AdjustDirIndex
		mpush	ebx,ecx,esi,edi
		mov	edi,eax				; Save indexes
		mov	ecx,ebx
		call	CFS_GetRootIndex
		jc	.Done
		cmp	ebx,edi				; Owning dir is root?
		je	.AdjustRoot			; Yes, change root

		mov	ebx,edi
		push	edx
		call	CFS_LPtoDevID			; Else read owning
		call	BUF_ReadBlock			; directory page
		pop	edx				; and read owning dir
		jc	.Done				; from it
		mov	ebx,[esi+tDirPage.Parent]	; Search in parent dir
		lea	esi,[esi+tDirPage.NM]		; ESI=directory name
		call	RFS_SearchForFileName		; Search it
		jc	.Err1				; If not found - error
		mov	[eax+tDirEntry.Entry],ecx	; Save new index
		mov	esi,edi				; in directory entry
		call	BUF_MarkDirty			; and mark buffer dirty
		jmp	.Done

.AdjustRoot:	mov	ebx,ecx				; Set new root index
		call	CFS_SetRootIndex		; in FSLP table

		call	CFS_LPtoDevID
		xor	ebx,ebx				; Read master block
		call	BUF_ReadBlock
		jc	.Done
		mov	[esi+tMasterBlock.RootDir],ecx	; Save new root index
		call	BUF_MarkDirty			; in master block

.Done:		mpop	edi,esi,ecx,ebx
		ret

.Err1:		mov	ax,ERR_RFS_Internal
		stc
		jmp	.Done
endp		;---------------------------------------------------------------


		; RFS_SplitBlock - split a block into two blocks
		;		   if an insert overflows.
		; Input: EBX=block number,
		;	 DL=file system linkpoint number,
		;	 ESI=buffer offset,
		;	 EDI=directory page address,
		;	 [ESP+4] - pointer to new directory,
		;	 [ESP+8] - owning directory index
		; Output:
proc RFS_SplitBlock
%define	.owndirindex	ebp+12				; Owning directory index
%define	.newdir		ebp+8				; Directory to add
%define	.oldblock	ebp-4				; Original block
%define	.bufferofs	ebp-8				; Offset to insertion point
%define	.buffer		ebp-12				; Original buffer
%define	.newblock	ebp-16				; New block
%define	.newbuffer	ebp-20				; New buffer
%define	.movelen	ebp-24				; Amount to move
%define	.insertblock	ebp-28				; Place to insert overflow entry
%define	.oldcount	ebp-32				; Items in orig block
%define	.newcount	ebp-36				; Items in new block
%define	.deviceid	ebp-40				; Device ID
%define	.fslp		ebp-44				; FSLP
%define	.insertdata	ebp-44-DIRENTRYSIZE		; Data to insert

		prologue 44+DIRENTRYSIZE		; Space for params
		sub	esi,edi				; Get buffer offset
		mov	[.bufferofs],esi		; Save offset
		mov	[.oldblock],ebx			; Save orig block
		and	edx,0FFh
		mov	[.fslp],edx			; Save FLSP
		call	RFS_AllocDirBlock		; Allocate a new block
		jc	short .Err			; Error if cant
		call	BUF_MarkDirty			; Make it dirty
		mov	[.newblock],eax			; Save block number
		mov	[.newbuffer],esi		; And new buffer address

		mov	ebx,[.oldblock]			; Read the original block
		call	CFS_LPtoDevID			; Get device ID
		mov	[.deviceid],edx
		call	BUF_ReadBlock
		jc	short .Err
		call	BUF_MarkDirty			; Make it dirty

		mov	[.buffer],esi			; Save buffer
		mov	edi,[.newbuffer]
		mov	ecx,FIRSTDIRENTRY/4             ; Copy the block header
		cld
		rep	movsd

		; See if inserting right at middle
		cmp	dword [.bufferofs],FIRSTDIRENTRY+(BLOCKSIZE-FIRSTDIRENTRY)/2
		je	near .PromoteNewDir		; Yes, promote it

		pushfd
		mov	esi,[.newdir]			; Move the new directory
		lea	edi,[.insertdata]		; To local area
		mov	ecx,DIRENTRYSIZE/4
		rep	movsd
		popfd
		jc	short .InsertInOld		; Branch if it goes in orig dir

.InsertInNew:	mov	dword [.movelen],DIRENTRYSIZE*(DIRORDER-1)/4	; amount to move
		mov	dword [.newcount],DIRORDER-1	; Items in new after copy
		mov	dword [.oldcount],DIRORDER	; Items in old after copy
		mov	eax,[.newblock]		; Get block to insert in
		mov	esi,[.buffer]			; Source buffer
		add	esi,FIRSTDIRENTRY+DIRENTRYSIZE*DIRORDER ; Point at what to move up
		jmp	short .InsertCommon

.Err:		jmp	.Exit

.InsertInOld:	mov	dword [.movelen],DIRENTRYSIZE*DIRORDER/4	; Amount to move
		mov	dword [.newcount],DIRORDER	; Items in new after copy
		mov	dword [.oldcount],DIRORDER-1	; Items in old after copy
		mov	eax,[.oldblock]			; Block to insert in
		mov	esi,[.buffer]			; Source buffer
		add	esi,FIRSTDIRENTRY+DIRENTRYSIZE*(DIRORDER-1) ; Point at what to move up

.InsertCommon:	mov	[.insertblock],eax		; Save insert block
		mov	edi,[.newdir]			; Copy move up name to callers param
		mov	ecx,DIRENTRYSIZE/4
		cld
		push	edi
		rep	movsd
		push	esi				; Starting position to move from
		sub	esi,[.buffer]			; Save buffer offset
		mov	[.bufferofs],esi
		pop	esi
		mov	eax,[esi+LESS]	 		; NEWPAGE.PAGELESS is the
		mov	edi,[.newbuffer]		; MOVEDUP.More
		mov	[edi+tDirPage.PageLess],eax
		pop	edi
		mov	eax,[.newblock]		; Movedup.More is the new block
		mov	[edi+tDirEntry.More],eax	;  just created
		jmp	short .Copy

.PromoteNewDir:	mov	edi,[.newdir]			; EDI = new directory
		mov	esi,[.newbuffer]		; ESI = new buffer
		mov	eax,[edi+tDirEntry.More]	; NewPage.PageLess is
		mov	[esi + tDirPage.PageLess],eax	; NewEntry.More
		mov	eax,[.newblock]		; NewEntry.More is our newblock
		mov	[edi+tDirEntry.More],eax
		mov	dword [.movelen],DIRENTRYSIZE*DIRORDER/4 ; Amount to move
		mov	dword [.newcount],DIRORDER	; New counts after move
		mov	dword [.oldcount],DIRORDER
		mov	dword [.insertblock],0	; Nothing to insert
		mov	dword [.bufferofs],FIRSTDIRENTRY +DIRENTRYSIZE*DIRORDER ; Position to move from

.Copy:		mov	esi,[.buffer]			; Original buffer
		mov	eax,[.oldcount]			; Count to put in it
		mov	byte [esi+tDirPage.Items],al	;
		add	esi,[.bufferofs]		; Position to move from
		mov	edi,[.newbuffer]		; New buffer
		mov	eax,[.newcount]			; Count to put in it
		mov	[edi+tDirPage.Items],al
		add	edi,FIRSTDIRENTRY		; Position to move to
		mov	ecx,[.movelen]			; Amount to move
		cld					; Do move
		rep	movsd
		mov	edi,[.buffer]			; Position to wipe at
		add	edi,[.bufferofs]
		mov	ecx,[.movelen]			; Amount to wipe
		test	dword [.insertblock],-1		; See if promoting new entry
		jz	short .NoDirAdj			; Yes, don't wipe promoted
		sub	edi,DIRENTRYSIZE		; Else wipe promoted entry
		add	ecx,DIRENTRYSIZE/4

.NoDirAdj:	xor	eax,eax				; Value to wipe with = -1
		dec	eax
		rep	stosd				; Do wipe
		test	dword [.insertblock],-1		; See if promoting new entry
		jz	.CheckOwnDir			; Yes, see if owning dir
		mov	eax,[.insertblock]		; Else find out where to insert it
		cmp	eax,[.oldblock]			; Old block?
		mov	esi,[.buffer]			; Assume so
		jz	short .InsOld			; Yes!
		mov	esi,[.newbuffer]		; Else new block

.InsOld:	mov	edi,esi				; EDI = buffer
		lea	ebx,[.insertdata]		; Data to insert
		call	RFS_FindEntry			; Find insert position
		call	RFS_InsertEntry			; Do insert

.CheckOwnDir:	mov	eax,[.oldblock]			; Now see if original
		cmp	eax,[.owndirindex]		; block was owning dir
		jne	.OK
		mov	edx,[.fslp]
		call	RFS_AllocDirBlock		; Allocate new dir
		jc	near .Err			; directory block
		mov	byte [esi+tDirPage.Items],1	; with one item
		mov	eax,[.oldblock]			; PAGELESS is old
		mov	[esi+tDirPage.PageLess],eax	; owning dir
		mov	edi,esi				; Copy new entry
		mov	esi,[.newdir]			; to owning dir
		add	edi,FIRSTDIRENTRY
		mov	ecx,DIRENTRYSIZE
		cld
		rep	movsb

		mov	edx,[.deviceid]
		call	RFS_AdjustDirIndex

.OK:		clc
.Exit:		mov	eax,[.newdir]			; Return new directory
		epilogue
		ret	8
endp		;---------------------------------------------------------------


		; RFS_ConcatBlock - deleting, concatenate two blocks.
		; Input: [ESP+4] - pointer to new directory,
		;	 DL=file system linkpoint number,
		;	 EBX=left block number,
		;	 EAX=right block number.
		; Output:
proc RFS_ConcatBlock
%define	.newdir		ebp+8

		prologue 0
		push	edx				; Keep FSLP

		call	CFS_LPtoDevID			; Get device ID
		push	eax				; Read the left block
		call	BUF_ReadBlock
		jc	short .Err
		call	BUF_MarkDirty			; Make it dirty
		mov	edi,esi				; EDI = left
		pop	ebx
		push	ebx				; Read the right block
		call	BUF_ReadBlock
		jc	short .Err
		call	BUF_MarkDirty			; Make it dirty
		push	edi
		push	esi
		movzx	ecx,byte [edi+tDirPage.Items]	; Point after data of left
		shl	ecx,DIRENTRYSHIFT
		add	edi,ecx
		add	edi,FIRSTDIRENTRY
		movzx	ecx,byte [esi+tDirPage.Items]	; Get amount to move in DWORDS
		shl	ecx,DIRENTRYSHIFT-2
		add	esi,FIRSTDIRENTRY		; Get start position
		cld
		rep	movsd				; Do move
		pop	esi
		mov	eax,[esi+tDirPage.PageLess]	; CENTERENTRY.More = RIGHT.PAGELESS
		mov	edi,[.newdir]
		mov	[edi+tDirEntry.More],eax
		mov	edi,esi				; Wipe out right block
		mov	ecx,BLOCKSIZE/4
		xor	eax,eax
		dec	eax
		rep	stosd
		pop	edi                             ; Get left buffer
		mov	byte [edi+tDirPage.Items],MAXDIRITEMS-1	; Almost full
		mov	esi,edi				; ESI = EDI
		mov	ebx,[.newdir]			; Data to insert is in EBX
		call	RFS_FindEntry			; Find entry
		call	RFS_InsertEntry			; Insert entry
		mpop	eax,edx				; Deallocate right block
		call	RFS_DeallocBlock
		jmp	short .Exit

.Err:		mpop	edx,edx				; AX=error code here
.Exit:		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_RollRightBlock - delete underflow : roll data right.
		; Input: [ESP+4] - rolling entry,
		;	 EDI=pointer to rolling buffer,
		;	 EAX=right block,
		;	 EBX=left block,
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_RollRightBlock
%define	.dir		ebp+8					; Rolling entry
%define	.dirbuf		ebp-4					; Buffer rolling entry is in
%define	.dest		ebp-8					; Right buffer

		prologue 8
		mov	[.dirbuf],edi
		mov	[.dest],eax
		push	edx
		call	CFS_LPtoDevID
		jc	near .Exit
		push	eax				; Read left
		call	BUF_ReadBlock
		pop	ebx
		jc	near .Exit

		call	BUF_MarkDirty			; Dirty it
		mov	edi,esi
		call	BUF_ReadBlock			; Read right
		jc	short .Exit

		call	BUF_MarkDirty			; Dirty it
		xchg	esi,edi				; LEFT in ESI, RIGHT in EDI
		mov	ebx,[.dir]			; Rolling.More = RIGHT.PAGELESS
		mov	eax,[edi+tDirPage.PageLess]
		mov	[ebx+tDirEntry.More],eax

		push	edi
		push	esi				; Insert ROLLING in RIGHT
		mov	esi,edi
		add	esi,FIRSTDIRENTRY
		call	RFS_InsertEntry
		mov	edi,[.dirbuf]			; Delete ROLLING
		mov	esi,ebx
		call	RFS_DeleteEntry
		pop	esi				;
		mov	edi,esi				; Point to last entry in left
		movzx	ecx,byte [esi+tDirPage.Items]
		dec	ecx
		shl	ecx,DIRENTRYSHIFT
		add	edi,ecx
		add	edi,FIRSTDIRENTRY
		mov	eax,[edi+tDirEntry.More]	; MOVUP.More->RIGHT.PAGELESS
		xchg	[esp],edi
		mov	[edi+tDirPage.PageLess],eax
		mov	edi,[esp]
		mov	eax,[.dest]			; RIGHT->MOVEUP.More
		mov	[edi+tDirEntry.More],eax
		mov	ebx,edi
		push	esi                             ; Insert Moveup where ROLLING was
		mov	esi,[.dir]
		mov	edi,[.dirbuf]
		xchg	esi,edi
		call	BUF_MarkDirty			; Dirty buffer
		xchg	esi,edi
		call	RFS_InsertEntry
		pop	edi				; Now delete it from left
		pop	esi
		call	RFS_DeleteEntry

.Exit:		pop	edx
		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_RollLeftBlock - delete underflow: roll left.
		; Input: [ESP+4] - rolling entry,
		;	 EDI=pointer to rolling buffer,
		;	 EAX=right block,
		;	 EBX=left block,
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_RollLeftBlock
%define	.dir		ebp+8				; Rolling entry
%define	.dirbuf		ebp-4				; Buffer rolling entry is in
%define	.dest		ebp-8				; Right buffer

		prologue 8
		mov	[.dirbuf],edi			; Save Rolling buffer
		mov	[.dest],eax			; And right block
		push	edx
		call	CFS_LPtoDevID
		jc	near .Exit
		push	eax				; Read left
		call	BUF_ReadBlock
		pop	ebx
		jc	short .Exit
		call	BUF_MarkDirty			; Dirty it
		mov	edi,esi				;
		call	BUF_ReadBlock			; Read right
		jc	short .Exit
		call	BUF_MarkDirty			; Dirty it
		mov	ebx,[.dir]			; RIGHT.PageLess->ROLLING.More
		mov	eax,[esi+tDirPage.PageLess]
		mov	[ebx+tDirEntry.More],eax
		push	esi
		mov	esi,edi				; Move to end of left
		movzx	ecx,byte [esi+tDirPage.Items]
		shl	ecx,DIRENTRYSHIFT
		add	esi,ecx
		add	esi,FIRSTDIRENTRY
		call	RFS_InsertEntry		; Move rolling to left
		mov	edi,[.dirbuf]
		mov	esi,ebx
		call	RFS_DeleteEntry		; Delete rolling from its buffer
		pop	esi
		mov	edi,esi
		add	edi,FIRSTDIRENTRY
		push	edi				; FIRSTRIGHT.More->RIGHT.PageLess
		mov	eax,[edi+tDirEntry.More]
		mov	[esi+tDirPage.PageLess],eax
		mov	eax,[.dest]			; RIGHT-> FIRSTRIGHT.More
		mov	[edi + tDirEntry.More],eax
		mov	ebx,edi
		push	esi
		mov	esi,[.dir]			; Insert Firstright where rolling was
		mov	edi,[.dirbuf]
		xchg	esi,edi
		call	BUF_MarkDirty			; Dirty rolling buffer
		xchg	esi,edi
		call	RFS_InsertEntry
		pop	edi
		pop	esi
		call	RFS_DeleteEntry		; Delete firstright from orig pos

.Exit:		pop	edx
		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_MoveBottomEntry - delete from middle: roll bottom up
		; Input: [ESP+4] -
		;	 EBX=
		;	 ESI=
		;	 EDI=
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_MoveBottomEntry
%define	.dest		ebp+8

		prologue 0
		push	edx				; Keep FSLP

		call	CFS_LPtoDevID			; Get device ID
		jc	short .Exit
		push	ebx				; Save block and offset
		sub	esi,edi				; to move into
		push	esi
		add	esi,edi

.GetLp:		mov	ebx,[esi+LESS]			; Grab what is less
		call	BUF_ReadBlock			; Read the block
		jc	short .Error
		mov	edi,esi
		movzx	eax,byte [esi+tDirPage.Items]	; Point at end
	      	shl	eax,DIRENTRYSHIFT
		add	eax,FIRSTDIRENTRY
		add	esi,eax
		bt	dword [edi+tDirPage.Flags],DFL_LEAF	; See if bottom
		jnc	short .GetLp			; Loop if not
		sub	esi,DIRENTRYSIZE		; Point at last entry
		mov	ecx,esi
		pop	edi				; Restore block and offset
		pop	ebx				; to move into
		call	BUF_ReadBlock
		jc	short .Exit
		push	esi
		push	edi
		add	edi,esi				; Move the entry there,
		mov	esi,ecx				; Keeping MORE intact
		push	esi
		mov	ecx,(DIRENTRYSIZE/4)-1
		rep	movsd
		pop	esi
		mov	edi,[.dest]			; Move the entry into caller's
		mov	ecx,DIRENTRYSIZE/4		; Buffer for recursive delete
		rep	movsd
		pop	edi
		pop	esi
		add	edi,esi				; Restore esi and edi
		xchg	esi,edi
		jmp	short .Exit

.Error:		mpop	edi,ebx
.Exit:		pop	edx
		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_InsertFileName - insert a file name.
		; Input: [ESP+4]=pointer to directory entry,
		;	 EBX=owning directory index,
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: pascal-style call.
proc RFS_InsertFileName
%define	.newdir		ebp+8				; What to insert
%define	.block		ebp-4				; Block we are analyzing
%define	.deviceid	ebp-8				; Device ID
%define	.fslp		ebp-12				; FSLP
%define	.owndirindex	ebp-16				; Owning directory index
%define	.name		ebp-16-DIRENTRYSIZE		; Current name for recursion

		prologue 16+DIRENTRYSIZE		; Save space for vars

		mpush	ebx,edx
		and	edx,0FFh
		mov	[.fslp],edx			; Save FSLP
		mov	[.owndirindex],ebx

		mov	esi,[.newdir]			; Copy name to local area
		lea	edi,[.name]
		mov	[.newdir],edi			; Pointing param at local
		mov	ecx,DIRENTRYSIZE/4
		cld
		rep	movsd

		mov	eax,ebx				; EAX=directory index
		call	CFS_LPtoDevID			; Get device ID
		jc	near .Error
		mov	[.deviceid],edx			; Keep device ID
		jmp	short .2

.Entry2:	enter	16,0				; Come here for recursion
		mov	[.owndirindex],ebx		; Save owning dir index
		mov	[.fslp],edx			; Save FSLP in local stack
		call	CFS_LPtoDevID			; Keep device ID
		jc	near .Exit			; in local stack
		mov	[.deviceid],edx

.2:		mov	ebx,eax				; Get this block
		mov	[.block],eax			; Save it
		call	BUF_ReadBlock			; Read it
		jc	short .Error

		mov	edi,esi				; Find the entry
		mov	ebx,[.newdir]
		call	RFS_FindEntry
		jc	short .Insert			; Empty root, just insert
		jz	short .FileExist		; Exists, go proclaim error

		bt	dword [edi+tDirPage.Flags],DFL_LEAF ; See if bottom
		jc	short .Insert			; Yes, just insert
		mov	eax,[esi+LESS]			; Else recurse on less
		mov	edx,[.fslp]
		mov	ebx,[.owndirindex]
		push	dword [.newdir]
		call	.Entry2
		jc	short .Error

		mov	edi,[.newdir]			; See if to recurse
		test	byte [edi],-1
		jz	short .Exit			; No, get out
		mov	ebx,[.block]			; Else reread block
		mov	edx,[.deviceid]
		call	BUF_ReadBlock
		jc	short .Error
		mov	edi,esi				; Find the entry
		mov	ebx,[.newdir]
		call	RFS_FindEntry

.Insert:	call	RFS_InsertEntry			; Insert here
		jc	short .Split			; Split if too full
		mov	esi,edi
		call	BUF_MarkDirty			; Else just dirty buffer
		mov	edi,[.newdir]			; And mark done
		mov	byte [edi],0
		jmp	short .Exit

.Split:		mov	ebx,[.block]			; Splitting, call splitter
		mov	edx,[.fslp]
		push	dword [.owndirindex]
		push	dword [.newdir]
		call	RFS_SplitBlock
		jc	short .Error
		jmp	short .Exit

.FileExist:	mov	ax,ERR_FS_FileExists
.Error:		stc
.Exit:		mpop	edx,ebx
		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_DeleteFileName - delete file name.
		; Input: [ESP+8]=0,
		;	 [ESP+4]=pointer to name to delete,
		;	 EBX=owning directory index,
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_DeleteFileName
%define	.shift		ebp+12			; Location of flag for recursion: 0 for top level
%define	.dir		ebp+8			; Name to delete
%define	.toshift	ebp-4			; Set true if recursion necessary
%define	.deviceid	ebp-8			; Device ID
%define	.fslp		ebp-12			; FSLP
%define	.owndirindex	ebp-16
%define	.name		ebp-16-DIRENTRYSIZE	; Local buffer for recursion

		prologue 16+DIRENTRYSIZE

		push	edx
		and	edx,0FFh
		mov	[.fslp],edx			; Save FSLP
		mov	[.owndirindex],ebx		; and owning dir index

		mov	esi,[.dir]			; Move file name
		lea	edi,[.name]			; to local buffer
		mov	[.dir],edi
		mov	ecx,DIRENTRYSIZE/4
		cld
		rep	movsd

		mov	eax,ebx				; EAX=directory index
		call	CFS_LPtoDevID			; Get device ID
		jc	near .Exit
		mov	[.deviceid],edx			; Keep device ID
		jmp	short .2

.Entry2:	enter	16,0				; Recursion comes here
		mov	[.owndirindex],eax		; Save owning dir index
		mov	[.fslp],edx			; Save FSLP in local stack
		call	CFS_LPtoDevID			; Save device ID
		jc	near .Exit			; in local stack
		mov	[.deviceid],edx

.2:		mov	dword [.toshift],0		; Assume no upward shift
		call	BUF_ReadBlock			; Read current block
		jc	near .Exit

		mov	edi,esi				; Find entry in block
		push	ebx
		mov	ebx,[.dir]
		call	RFS_FindEntry
		pop	ebx
		jnz	short .NotFound		; No match, possibly recurse

		push	esi				; Else dirty the buffer
		mov	esi,edi
		call	BUF_MarkDirty
		pop	esi

		bt	dword [edi+tDirPage.Flags],DFL_LEAF	; If this is not a leaf
		jnc	short .MoveToMiddle			; Move to middle
		call	RFS_DeleteEntry			; Delete leaf entry
		jz	near .ClearDir			; Killed root, exit

		cmp	byte [edi+tDirPage.Items],DIRORDER	; See if underflow
		jnc	short .NoUnderflow			; No, get out
		mov	edi,[.shift]				; See if top level
		or	edi,edi
		jz	short .NoUnderflow			; Allowed to underflow root
		inc	byte [edi]			; Else there will be a higher-level
.NoUnderflow:	jmp	.Exit				;  concatenation or roll

.MoveToMiddle:	mov	dl,[.fslp]
		mov	eax,[.dir]			; Move bottom entry to middle
		push	eax				;  leaves name of bottom entry in buffer
		call	RFS_MoveBottomEntry
		jc	near .Exit

.NotFound:	bt	dword [edi+tDirPage.Flags],DFL_LEAF ; If a leaf, file doesn't exist
		jc	near .None
		mpush	esi,edi,ebx			; Else recurse on less
		mov	eax,[.owndirindex]
		mov	ebx,[esi+LESS]
		mov	edx,[.fslp]
		lea	edi,[.toshift]
		push	edi
		push	dword [.dir]
		call	.Entry2
		mpop	ebx,edi,esi
		jc	near .Exit
		test	dword [.toshift],-1		; See if there was an underflow
		jz	near .Exit			; Quit if not
		sub	esi,edi				; Else read current block
		mov	edi,esi
		mov	edx,[.deviceid]
		call	BUF_ReadBlock
		jc	near .Exit
		xchg	esi,edi				; See if pointing past last entry
		mov	eax,esi
		add	esi,edi
		sub	eax,FIRSTDIRENTRY
		shr	eax,DIRENTRYSHIFT
		cmp	al,[edi+tDirPage.Items]
		jc	short .NoAdjust
		sub	esi,DIRENTRYSIZE		; Yes, point to last entry

.NoAdjust:	mov	edx,[.deviceid]
		push	esi
                mov	ebx,[esi+LESS]			; Load LESS block
		call	BUF_ReadBlock
		movzx	ecx,byte [esi+tDirPage.Items]	; Get items in it
		pop	esi
		jc	near .Error2

		mpush	esi,ecx
		mov	ebx,[esi+tDirEntry.More]	; Load MORE block
		call	BUF_ReadBlock
		pop	ecx
		pushfd
		movzx	eax,byte [esi+tDirPage.Items]	; Get items in it
		add	cl,[esi+tDirPage.Items]		; Get total items
		popfd
		pop	esi
		jc	near .Error2

		cmp	cl,MAXDIRITEMS			; If can't be concatted we roll
		jnc	near .Roll
		mov	ebx,[esi+LESS]			; Get params for concat

		mov	eax,[esi+tDirEntry.More]
		mpush	edi,esi				; Central dir entry goes in buffer
		mov	edi,[.dir]
		cld
		mov	ecx,DIRENTRYSIZE/4
		rep	movsd
		pop	esi
		push	esi
		mov	dl,[.fslp]
		mov	edi,[.dir]
		push	edi				; Parameter for RFS_ConcatBlock
		call	RFS_ConcatBlock			; Do concat
		mpop	esi,edi
		jc	near .Exit

		mov	eax,[.shift]			; Now if this isn't top level
		or	eax,eax
		jz	short .ConcTop
		inc	dword [eax]			; We have to delete the central entry
		jmp	short .Exit			;   recursively

.ConcTop:	cmp	byte [edi+tDirPage.Items],1	; Else see if we will empty it
		je	.NewOwnDir			; Yes, new root

.DelOwnDirEnt:	call	RFS_DeleteEntry			; Else just delete
		mov	esi,edi				; owning dir entry
		call	BUF_MarkDirty			; Mark dirty
		jmp	short .Exit			; Get out

.NewOwnDir:	bts	dword [edi+tDirPage.Flags],DFL_LEAF ; See if it is a leaf
		jc	.DelOwnDirEnt			; Yes, just delete the last file
		mov	esi,edi				; Else dirty buffer
		call	BUF_MarkDirty			;
		mov	ebx,[edi+tDirPage.PageLess]	; Get the pageless entry

		xor	eax,eax				; Wipe the block out
		dec	eax
		mov	ecx,BLOCKSIZE/4
		rep	stosb

		mov	eax,[.owndirindex]
		push	eax
		call	RFS_AdjustDirIndex
		pop	eax
		call	RFS_DeallocBlock
		jmp	short .Exit

.Roll:		cmp	al,DIRORDER			; See which way to roll
		mov	ebx,[esi+LESS]			; Roll params
		mov	eax,[esi+tDirEntry.More]
		mov	dl,[.fslp]
		jc	short .DoRight
		push	esi
		call	RFS_RollLeftBlock		; Left roll
		jmp	short .Exit

.DoRight:	push	esi				; Right roll
		call	RFS_RollRightBlock

.ClearDir:
.Exit:		pop	edx
		epilogue
		ret	8

.None:		mov	ax,ERR_FS_FileNotFound
		stc
		jmp	short .Exit

.Error2:	pop	esi
		jmp	short .Exit
endp		;---------------------------------------------------------------


		; RFS_SearchForFileName - search for file name.
		; Input: EBX=directory index,
		;	 ESI=pointer to name,
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK:
		;		    EAX=directory entry,
		;		    EDI=pointer to directory page containing
		;			this entry
		;	  CF=1 - error, AX=error code.
proc RFS_SearchForFileName
%define	.name		ebp-4				; Name to search for
%define	.deviceid	ebp-8

		prologue 8
		push	edx

		mov	[.name],esi			; Save name
		call	CFS_LPtoDevID			; Get device ID
		jc	short .Exit
		mov	[.deviceid],edx

.Loop:		mov	edx,[.deviceid]
		call	BUF_ReadBlock			; Read block
		jc	short .Exit
		mov	edi,esi				; Find entry
		mov	ebx,[.name]
		call	RFS_FindEntry
		jc	short .NoEntry			; Empty root, no entry
		jz	short .GotEntry			; Else got it if match
		bt	dword [edi+tDirPage.Flags],DFL_LEAF ; Check for leaf
		jc	short .NoEntry			; No entry if it is
		mov	ebx,[esi+LESS]			; Else recurse on the less
		jmp	short .Loop

.NoEntry:	mov	ax,ERR_FS_FileNotFound
		stc
		jmp	short .Exit

.GotEntry:	mov	eax,[esi+tDirEntry.Entry]	; Pull file block entry
		clc

.Exit:		pop	edx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_GetNumOfFiles - get total number of files in directory.
		; Input: EDX=device ID,
		;	 EBX=directory index.
		; Output: CF=0 - OK, EAX=number of files;
		;	  CF=1 - error, AX=error code.
		; Note: recursive procedure.
proc RFS_GetNumOfFiles
%define	.count		ebp-4

		prologue 4
		mpush	ebx,ecx,edx,esi,edi

		call	BUF_ReadBlock
		jc	short .Exit

		xor	eax,eax
		mov	al,[esi+tDirPage.Items]
		mov	[.count],eax
		bt	dword [esi+tDirPage.Flags],DFL_LEAF
		jc	short .OK
		mov	edi,esi
		add	esi,FIRSTDIRENTRY
		mov	cl,al
		or	cl,cl
		jz	short .CheckLess

.Loop:		mov	ebx,[esi+tDirEntry.More]
		or	ebx,ebx
		jz	.NextDirEnt
		call	RFS_GetNumOfFiles
		add	[.count],eax

.NextDirEnt:	add	esi,DIRENTRYSIZE
		dec	cl
		jnz	.Loop

.CheckLess:	mov	ebx,[edi+tDirPage.PageLess]
		or	ebx,ebx
		je	short .OK
		call	RFS_GetNumOfFiles
		add	[.count],eax
.OK:		mov	eax,[.count]
		clc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------
