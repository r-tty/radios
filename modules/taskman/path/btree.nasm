;-------------------------------------------------------------------------------
; btree.nasm - B-tree routines (insertion, deletion, balancing).
; Based on David Lindauer's OS-32 kernel.
;-------------------------------------------------------------------------------

module tm.pathman.btree

%include "errors.ah"
%include "tm/rfs.ah"

externproc RFS_AllocDirBlock, RFS_DeallocBlock

publicproc RFS_InsertFileName, RFS_DeleteFileName
publicproc RFS_SearchForFileName, RFS_GetNumOfFiles

; --- Procedures ---

section .text

		; RFS_CompareName - compare two names.
		; Input: EBX=first name,
		;	 EAX=second name.
		; Output: ZF=1 - equal;
		;	  ZF=0 - not equal.
proc RFS_CompareName
		mpush	ecx,esi,edi
		mov	ecx,RFS_FILENAMELEN
		mov	esi,ebx
		mov	edi,eax
		cld
		repe	cmpsb
		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_FindEntry - find the position an entry would be inserted
		;		  into in this block (binary search).
		; Input: EBX=pointer to directory entry,
		;	 ESI=pointer to directory node.
		; Output: CF=0 - OK, ESI=pointer to entry;
		;	  CF=1 - error (position not found).
proc RFS_FindEntry
		push	edi
		movzx	ecx,byte [esi+tDirNode.Items]	; Get total items
		add	esi,RFS_FIRSTDIRENTRY		; Point at first entry
		or	ecx,ecx				; Quit if no items
		jz	.Err
		mov	edi,esi				; EDI point beyond last entry
		shl	ecx,RFS_DIRENTRYSHIFT
		add	edi,ecx

.Loop:		mov	eax,edi				; Find out if converged
		sub	eax,esi
		cmp	eax,tDirEntry_size		; Quit if no midpoint
		je	.GotEntry
		bt	eax,RFS_DIRENTRYSHIFT
		mov	eax,0
		jnc	.IsEven				; Else make sure we are
		mov	al,tDirEntry_size		; Going to be on an even

.IsEven:	add	eax,esi				; boundary when divide by 2
		add	eax,edi				; Find midpoint
		shr	eax,1
		call	RFS_CompareName			; Compare
		jz	.IsEqual			; If equal, get out
		jl	.MoveDown			; Else decide which way to go
		mov	esi,eax				; Move bottom up
		jmp	.Loop				; Next test

.MoveDown:	mov	edi,eax				; Move bottom down
		jmp	.Loop				; Next test

.IsEqual:	mov	esi,eax				; Found it, get out
		clc
		jmp	.Exit

.GotEntry:	mov	eax,esi				; Not in block,
		call	RFS_CompareName			; See which is bigger
		clc
		jle	.Exit				; Leave ESI
		mov	esi,edi				; pointing above
		jmp	.Exit
.Err:		stc
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; RFS_InsertEntry - insert an entry in the block.
		; Input: ESI=address of position an entry would be inserted,
		;	 EDI=address of directory node,
		;	 EBX=address of data.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc RFS_InsertEntry
		cmp	byte [edi+tDirNode.Items],RFS_MAXDIRITEMS ; See if full
		je	 .Err				; Get out if so
		mpush	ecx,edi,esi
		add	edi,RFS_BLOCKSIZE		; Find top
		mov	ecx,edi				; Get len to move
		sub	ecx,esi
		sub	ecx,tDirEntry_size
		shr	ecx,2				; 4 bytes / move
		sub	edi,4				; Point at first word to move
		mov	esi,edi				; Find source of move
		sub	esi,tDirEntry_size
		std					; Move down
		rep	movsd
		cld
		pop	edi				; Get position to insert
		push	edi
		mov	esi,ebx				; Data to move in
		mov	ecx,tDirEntry_size		; Length of data
		shr	ecx,2				; Moving words
		rep	movsd				; Move
		mpop	esi,edi,ecx			; Restore regs
		inc	byte [edi+tDirNode.Items]	; Inc count
		clc					; Get out
		ret
.Err:		stc					; Error
		ret
endp		;---------------------------------------------------------------


		; RFS_DeleteEntry - delete an entry from directory node.
		; Input: EDI=directory node address,
		;	 ESI=entry address
		; Output: ZF=0 - number of entries != 0;
		;	  ZF=1 - number of entries == 0.
proc RFS_DeleteEntry
		dec	byte [edi+tDirNode.Items]	; Decrement items
		sahf
		mpush	eax,ecx,esi,edi
		mov	ecx,edi				; ECX will have len to move
		add	ecx,RFS_BLOCKSIZE
		mov	edi,esi				; Find source
		add	esi,tDirEntry_size
		sub	ecx,esi				; Calculate len
		shr	ecx,2				; Moving words
		rep	movsd
		pop	edi				; Get buffer
		push	edi
		add	edi,RFS_BLOCKSIZE-tDirEntry_size	; Point at last entry in buffer
		mov	ecx,tDirEntry_size/4		; Fill it with FFs
		xor	eax,eax
		dec	eax
		rep	stosd
		mpop	edi,esi,ecx,eax
		lahf					; Get status of decrement
		ret
endp		;---------------------------------------------------------------


		; RFS_SplitBlock - split a block into two blocks if an insert
		;		   overflows.
		; Input: EBX=block number,
		;	 EDX=file system address,
		;	 ESI=block address,
		;	 EDI=directory node address,
		;	 [ESP+4] - new directory entry address,
		;	 [ESP+8] - head directory node.
		; Output: CF=0 - OK, EAX=new directory entry;
		;	  CF=1 - error, AX=error code.
		; Note: Pascal-type (removes arguments from the stack).
proc RFS_SplitBlock
		arg	headnode, newdir
		locals	oldblocknum			; Original block number
		locals	oldblockaddr			; Original block address
		locals	bufferofs			; Offset to insertion point
		locals	newblocknum			; New block number
		locals	newblockaddr			; New block address
		locals	movelen				; Amount to move
		locals	insertblock			; Place to insert overflow entry
		locals	oldcount			; Items in orig block
		locals	newcount			; Items in new block
		locauto	insertdata, tDirEntry_size	; Data to insert

		prologue
		mov	[%$oldblocknum],ebx		; Save orig block
		sub	esi,edi				; Get buffer offset
		mov	[%$bufferofs],esi		; Save offset
		lea	esi,[edi+tDirNode.Name]
		call	RFS_AllocDirBlock		; Allocate a new block
		jc	near .Exit
		mov	[%$newblocknum],eax		; Save block number
		mov	[%$newblockaddr],esi		;  and its address

		mov	ebx,[%$oldblocknum]		; Seek at original block
		mBseek
		mov	[%$oldblockaddr],esi
		mov	edi,[%$newblockaddr]
		mov	ecx,RFS_FIRSTDIRENTRY/4		; Copy the block header
		cld
		rep	movsd

		; See if inserting right at middle
		cmp	dword [%$bufferofs],RFS_FIRSTDIRENTRY+(RFS_BLOCKSIZE-RFS_FIRSTDIRENTRY)/2
		je	near .PromoteNewDir		; Yes, promote it

		mov	esi,[%$newdir]			; Move the new directory
		lea	edi,[%$insertdata]		; To local area
		mov	ecx,tDirEntry_size/4
		sahf
		rep	movsd
		lahf
		jc	.InsertInOld			; Branch if it goes in orig dir

.InsertInNew:	mov	dword [%$movelen],tDirEntry_size*(RFS_DIRORDER-1)/4	; Amount to move
		mov	dword [%$newcount],RFS_DIRORDER-1	; Items in new after copy
		mov	dword [%$oldcount],RFS_DIRORDER	; Items in old after copy
		mov	eax,[%$newblocknum]		; Block to insert in
		mov	esi,[%$oldblockaddr]		; Source block address
		add	esi,RFS_FIRSTDIRENTRY+tDirEntry_size*RFS_DIRORDER ; Point at what to move up
		jmp	.InsertCommon

.InsertInOld:	mov	dword [%$movelen],tDirEntry_size*RFS_DIRORDER/4	; Amount to move
		mov	dword [%$newcount],RFS_DIRORDER	; Items in new after copy
		mov	dword [%$oldcount],RFS_DIRORDER-1	; Items in old after copy
		mov	eax,[%$oldblocknum]		; Block to insert in
		mov	esi,[%$oldblockaddr]		; Source block address
		add	esi,RFS_FIRSTDIRENTRY+tDirEntry_size*(RFS_DIRORDER-1) ; Point at what to move up

.InsertCommon:	mov	[%$insertblock],eax		; Save insert block
		mov	edi,[%$newdir]			; Copy move up name to callers param
		mov	ecx,tDirEntry_size/4
		cld
		push	edi
		rep	movsd
		push	esi				; Starting position to move from
		sub	esi,[%$oldblockaddr]		; Save buffer offset
		mov	[%$bufferofs],esi
		pop	esi
		mov	eax,[esi-4]
		mov	edi,[%$newblockaddr]
		mov	[edi+tDirNode.PageLess],eax
		pop	edi
		mov	eax,[%$newblocknum]		; Movedup.More is the new block
		mov	[edi+tDirEntry.More],eax	;  just created
		jmp	.Copy

.PromoteNewDir:	mov	edi,[%$newdir]
		mov	esi,[%$newblockaddr]
		mov	eax,[edi+tDirEntry.More]	; NewPage.PageLess is
		mov	[esi+tDirNode.PageLess],eax	; NewEntry.More
		mov	eax,[%$newblocknum]		; NewEntry.More is our newblock
		mov	[edi+tDirEntry.More],eax
		mov	dword [%$movelen],tDirEntry_size*RFS_DIRORDER/4
		mov	dword [%$newcount],RFS_DIRORDER	; New counts after move
		mov	dword [%$oldcount],RFS_DIRORDER
		mov	dword [%$insertblock],0		; Nothing to insert
		mov	dword [%$bufferofs],RFS_FIRSTDIRENTRY+tDirEntry_size*RFS_DIRORDER ; Position to move from

.Copy:		mov	esi,[%$oldblockaddr]		; Original block addr
		mov	eax,[%$oldcount]		; Count to put in it
		mov	byte [esi+tDirNode.Items],al	;
		add	esi,[%$bufferofs]		; Position to move from
		mov	edi,[%$newblockaddr]		; New buffer
		mov	eax,[%$newcount]		; Count to put in it
		mov	[edi+tDirNode.Items],al
		add	edi,RFS_FIRSTDIRENTRY		; Position to move to
		mov	ecx,[%$movelen]			; Amount to move
		cld					; Do move
		rep	movsd
		mov	edi,[%$oldblockaddr]		; Position to wipe at
		add	edi,[%$bufferofs]
		mov	ecx,[%$movelen]			; Amount to wipe
		test	dword [%$insertblock],-1	; See if promoting new entry
		jz	.NoDirAdj			; Yes, don't wipe promoted
		sub	edi,tDirEntry_size		; Else wipe promoted entry
		add	ecx,tDirEntry_size/4

.NoDirAdj:	xor	eax,eax				; Value to wipe with = -1
		dec	eax
		rep	stosd				; Do wipe
		test	dword [%$insertblock],-1	; See if promoting new entry
		jz	.CheckHeadDir			; Yes, see if head dir
		mov	esi,[%$oldblockaddr]
		mov	eax,[%$insertblock]		; Else find out where to insert it
		cmp	eax,[%$oldblocknum]		; Old block?
		jz	.InsEntry
		mov	esi,[%$newblockaddr]		; Else new block

.InsEntry:	mov	edi,esi				; EDI = buffer
		lea	ebx,[%$insertdata]		; Data to insert
		call	RFS_FindEntry			; Find insert position
		call	RFS_InsertEntry			; Do insert

.CheckHeadDir:	mov	eax,[%$oldblocknum]		; Now see if original
		cmp	eax,[%$headnode]		; block was head dir node
		jne	.OK
		mBseek	eax
		lea	esi,[esi+tDirNode.Name]
		call	RFS_AllocDirBlock		; Allocate new dir
		jc	.Exit				; directory block
		mov	byte [esi+tDirNode.Items],1	; with one item
		mov	eax,[%$oldblocknum]		; PageLess is old head node
		mov	[esi+tDirNode.PageLess],eax
		mov	edi,esi				; Copy new entry
		mov	esi,[%$newdir]			; to head dir node
		add	edi,RFS_FIRSTDIRENTRY
		mov	ecx,tDirEntry_size
		cld
		rep	movsb
		call	RFS_AdjustDirNode

.OK:		mov	eax,[%$newdir]			; Return new directory
		clc
.Exit:		epilogue
		ret	8
endp		;---------------------------------------------------------------


		; RFS_ConcatBlock - deleting, concatenate two blocks.
		; Input: [ESP+4] - pointer to new directory,
		;	 EDX=file system address,
		;	 EBX=left block number,
		;	 EAX=right block number.
		; Output:
proc RFS_ConcatBlock
		arg	newdir

		prologue
		push	eax				; Read the left block
		mBseek
		mov	edi,esi				; EDI = left
		pop	ebx
		push	ebx				; Read the right block
		mBseek
		push	edi
		push	esi
		movzx	ecx,byte [edi+tDirNode.Items]	; Point after data of left
		shl	ecx,RFS_DIRENTRYSHIFT
		add	edi,ecx
		add	edi,RFS_FIRSTDIRENTRY
		movzx	ecx,byte [esi+tDirNode.Items]	; Get amount to move in DWORDS
		shl	ecx,RFS_DIRENTRYSHIFT-2
		add	esi,RFS_FIRSTDIRENTRY		; Get start position
		cld
		rep	movsd				; Do move
		pop	esi
		mov	eax,[esi+tDirNode.PageLess]	; CenterEntry.More = Right.PageLess
		mov	edi,[%$newdir]
		mov	[edi+tDirEntry.More],eax
		mov	edi,esi				; Wipe out right block
		mov	ecx,RFS_BLOCKSIZE/4
		xor	eax,eax
		dec	eax
		rep	stosd
		pop	edi                             ; Get left buffer
		mov	byte [edi+tDirNode.Items],RFS_MAXDIRITEMS-1	; Almost full
		mov	esi,edi				; ESI = EDI
		mov	ebx,[%$newdir]			; Data to insert is in EBX
		call	RFS_FindEntry			; Find entry
		call	RFS_InsertEntry			; Insert entry
		pop	eax				; Deallocate right block
		call	RFS_DeallocBlock

.Exit:		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_RollRightBlock - delete underflow: roll data right.
		; Input: [ESP+4] - rolling entry,
		;	 EDI=pointer to rolling buffer,
		;	 EAX=right block,
		;	 EBX=left block,
		;	 EDX=file system address.
		; Output:
proc RFS_RollRightBlock
		arg	dir		; Rolling entry
		locals	dirbuf		; Buffer rolling entry is in
		locals	dest		; Right buffer

		prologue
		mov	[%$dirbuf],edi
		mov	[%$dest],eax
		mBseek					; Seek at left
		mov	edi,esi
		mov	ebx,eax
		mBseek					; Seek at right
		xchg	esi,edi				; Left in ESI, Right in EDI
		mov	ebx,[%$dir]			; Rolling.More = Right.PageLess
		mov	eax,[edi+tDirNode.PageLess]
		mov	[ebx+tDirEntry.More],eax

		push	edi
		push	esi				; Insert rolling in Right
		mov	esi,edi
		add	esi,RFS_FIRSTDIRENTRY
		call	RFS_InsertEntry
		mov	edi,[%$dirbuf]			; Delete rolling
		mov	esi,ebx
		call	RFS_DeleteEntry
		pop	esi
		mov	edi,esi				; Point to last entry in left
		movzx	ecx,byte [esi+tDirNode.Items]
		dec	ecx
		shl	ecx,RFS_DIRENTRYSHIFT
		add	edi,ecx
		add	edi,RFS_FIRSTDIRENTRY
		mov	eax,[edi+tDirEntry.More]	; MoveUp.More->Right.PageLess
		xchg	[esp],edi
		mov	[edi+tDirNode.PageLess],eax
		mov	edi,[esp]
		mov	eax,[%$dest]			; Right->MoveUp.More
		mov	[edi+tDirEntry.More],eax
		mov	ebx,edi
		push	esi                             ; Insert MoveUp where ROLLING was
		mov	esi,[%$dir]
		mov	edi,[%$dirbuf]
		call	RFS_InsertEntry
		pop	edi				; Now delete it from left
		pop	esi
		call	RFS_DeleteEntry

.Exit:		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_RollLeftBlock - delete underflow: roll left.
		; Input: [ESP+4] - rolling entry,
		;	 EDI=pointer to rolling buffer,
		;	 EAX=right block,
		;	 EBX=left block,
		;	 EDX=file system address.
		; Output:
proc RFS_RollLeftBlock
		arg	dir		; Rolling entry
		locals	dirbuf		; Buffer rolling entry is in
		locals	dest		; Right buffer

		prologue
		mov	[%$dirbuf],edi			; Save Rolling buffer
		mov	[%$dest],eax			; And right block
		mBseek					; Read left
		mov	edi,esi
		mov	ebx,eax
		mBseek					; Read right
		mov	ebx,[%$dir]			; Right.PageLess->Rolling.More
		mov	eax,[esi+tDirNode.PageLess]
		mov	[ebx+tDirEntry.More],eax
		push	esi
		mov	esi,edi				; Move to end of left
		movzx	ecx,byte [esi+tDirNode.Items]
		shl	ecx,RFS_DIRENTRYSHIFT
		add	esi,ecx
		add	esi,RFS_FIRSTDIRENTRY
		call	RFS_InsertEntry		; Move rolling to left
		mov	edi,[%$dirbuf]
		mov	esi,ebx
		call	RFS_DeleteEntry		; Delete rolling from its buffer
		pop	esi
		mov	edi,esi
		add	edi,RFS_FIRSTDIRENTRY
		push	edi				; FirstRight.More->Right.PageLess
		mov	eax,[edi+tDirEntry.More]
		mov	[esi+tDirNode.PageLess],eax
		mov	eax,[%$dest]			; Right-> FirstRight.More
		mov	[edi+tDirEntry.More],eax
		mov	ebx,edi
		push	esi
		mov	esi,[%$dir]			; Insert Firstright where rolling was
		mov	edi,[%$dirbuf]
		call	RFS_InsertEntry
		pop	edi
		pop	esi
		call	RFS_DeleteEntry		; Delete firstright from orig pos

.Exit:		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_MoveBottomEntry - delete from middle: roll bottom up.
		; Input: [ESP+4] -
		;	 EBX=block number,
		;	 ESI=block address,
		;	 EDI=
		;	 EDX=file system address.
		; Output:
proc RFS_MoveBottomEntry
		arg	dest

		prologue
		push	ebx				; Save block and offset
		sub	esi,edi				; to move into
		push	esi
		add	esi,edi

.GetLp:		mov	ebx,[esi-4]			; Grab what is less
		mBseek
		mov	edi,esi
		movzx	eax,byte [esi+tDirNode.Items]	; Point at end
	      	shl	eax,RFS_DIRENTRYSHIFT
		add	eax,RFS_FIRSTDIRENTRY
		add	esi,eax
		bt	dword [edi+tDirNode.Flags],RFS_DFL_LEAF	; See if bottom
		jnc	.GetLp				; Loop if not
		sub	esi,tDirEntry_size		; Point at last entry
		mov	ecx,esi
		pop	edi				; Restore block and offset
		pop	ebx				; to move into
		mBseek
		push	esi
		push	edi
		add	edi,esi				; Move the entry there,
		mov	esi,ecx				; Keeping More intact
		push	esi
		mov	ecx,(tDirEntry_size/4)-1
		rep	movsd
		pop	esi
		mov	edi,[%$dest]			; Move the entry into caller's
		mov	ecx,tDirEntry_size/4		; Buffer for recursive delete
		rep	movsd
		pop	edi
		pop	esi
		add	edi,esi				; Restore esi and edi
		xchg	esi,edi
		epilogue
		ret	4
endp		;---------------------------------------------------------------


		; RFS_InsertFileName - insert a new entry into a directory.
		; Input: [ESP+4]=pointer to directory entry,
		;	 EBX=head directory node,
		;	 EDX=file system address
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: pascal-style call.
proc RFS_InsertFileName
		arg	newdir			; What to insert
		locals	block			; Block we are analyzing
		locals	headnode		; Owning directory inode
		locauto name, tDirEntry_size	; Current name for recursion

		prologue
		push	ebx
		mov	[%$headnode],ebx

		mov	esi,[%$newdir]		; Copy name to local area
		lea	edi,[%$name]
		mov	[%$newdir],edi		; Pointing param at local
		mov	ecx,tDirEntry_size/4
		cld
		rep	movsd

		mov	eax,ebx			; EAX=head dir node
		jmp	.2

		; Come here for recursion
.Entry2:	enter	%$lc,0
		mov	[%$headnode],ebx	; We have new stack here

.2:		mov	ebx,eax			; Get this block
		mov	[%$block],eax
		mBseek

		mov	edi,esi			; Find the entry
		mov	ebx,[%$newdir]
		call	RFS_FindEntry
		jc	.Insert			; Empty dir node, just insert
		jz	.FileExist		; Exists, go proclaim error

		bt	dword [edi+tDirNode.Flags],RFS_DFL_LEAF ; See if bottom
		jc	.Insert			; Yes, just insert
		mov	eax,[esi-4]		; Else recurse on less
		push	dword [%$newdir]
		call	.Entry2
		jc	.Exit

		mov	edi,[%$newdir]		; See if to recurse
		test	byte [edi],-1
		jz	.Exit			; No, get out
		mov	ebx,[%$block]		; Else reread block
		mBseek
		mov	edi,esi			; Find the entry
		mov	ebx,[%$newdir]
		call	RFS_FindEntry

.Insert:	call	RFS_InsertEntry		; Insert here
		jc	.Split			; Split if too full
		mov	esi,edi
		mov	edi,[%$newdir]
		mov	byte [edi],0
		jmp	.Exit

.Split:		mov	ebx,[%$block]		; Splitting, call splitter
		push	dword [%$headnode]
		push	dword [%$newdir]
		call	RFS_SplitBlock

.Exit:		pop	ebx
		epilogue
		ret	4

.FileExist:	mov	ax,EEXIST
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_DeleteFileName - delete file name.
		; Input: [ESP+8]=0,
		;	 [ESP+4]=pointer to name to delete,
		;	 EBX=head directory node,
		;	 EDX=file system address.
		; Output:
proc RFS_DeleteFileName
		arg	shift			; recursion flag (0=top level)
		arg	dir			; name to delete
		locals	toshift			; Set true if recursion necessary
		locals	headnode
		locauto	name, tDirEntry_size	; Local buffer for recursion

		prologue

		mov	[%$headnode],ebx	; Save head dir node

		mov	esi,[%$dir]		; Move file name
		lea	edi,[%$name]		; to local buffer
		mov	[%$dir],edi
		mov	ecx,tDirEntry_size/4
		cld
		rep	movsd

		mov	eax,ebx			; EAX=head dir node
		jmp	.2

		; Recursion comes here
.Entry2:	enter	%$lc,0
		mov	[%$headnode],eax	; Save owning dir index

.2:		mov	dword [%$toshift],0	; Assume no upward shift
		mBseek

		mov	edi,esi			; Find entry in block
		push	ebx
		mov	ebx,[%$dir]
		call	RFS_FindEntry
		pop	ebx
		jnz	.NotFound		; No match, possibly recurse

		bt	dword [edi+tDirNode.Flags],RFS_DFL_LEAF	; If this is not a leaf
		jnc	.MoveToMiddle			; Move to middle
		call	RFS_DeleteEntry			; Delete leaf entry
		jz	near .ClearDir			; Killed head, exit

		cmp	byte [edi+tDirNode.Items],RFS_DIRORDER ; See if underflow
		jnc	.NoUnderflow			; No, get out
		mov	edi,[%$shift]			; See if top level
		or	edi,edi
		jz	.NoUnderflow			; Allowed to underflow root
		inc	byte [edi]			; Else there will be a higher-level
.NoUnderflow:	jmp	.Exit				;  concatenation or roll

.MoveToMiddle:	mov	eax,[%$dir]			; Move bottom entry to middle
		push	eax				;  leaves name of bottom entry in buffer
		call	RFS_MoveBottomEntry
		jc	near .Exit

.NotFound:	bt	dword [edi+tDirNode.Flags],RFS_DFL_LEAF ; If a leaf, file doesn't exist
		jc	near .NotExist
		mpush	esi,edi,ebx			; Else recurse on less
		mov	eax,[%$headnode]
		mov	ebx,[esi-4]
		lea	edi,[%$toshift]
		push	edi
		push	dword [%$dir]
		call	.Entry2
		mpop	ebx,edi,esi
		jc	near .Exit
		test	dword [%$toshift],-1		; See if there was an underflow
		jz	near .Exit			; Quit if not
		sub	esi,edi				; Else read current block
		mov	edi,esi
		mBseek
		xchg	esi,edi				; See if pointing past last entry
		mov	eax,esi
		add	esi,edi
		sub	eax,RFS_FIRSTDIRENTRY
		shr	eax,RFS_DIRENTRYSHIFT
		cmp	al,[edi+tDirNode.Items]
		jc	.NoAdjust
		sub	esi,tDirEntry_size		; Yes, point to last entry

.NoAdjust:	push	esi
                mov	ebx,[esi-4]			; Load LESS block
		mBseek
		xor	ecx,ecx
		mov	cl,[esi+tDirNode.Items]		; Get items in it
		pop	esi

		push	esi
		mov	ebx,[esi+tDirEntry.More]	; Load MORE block
		mBseek
		movzx	eax,byte [esi+tDirNode.Items]	; Get items in it
		add	cl,[esi+tDirNode.Items]		; Get total items
		pop	esi

		cmp	cl,RFS_MAXDIRITEMS		; If can't be concatenated
		jnc	near .Roll			;  we roll
		mov	ebx,[esi-4]			; Get params for concat

		mov	eax,[esi+tDirEntry.More]
		push	edi				; Central dir entry 
		push	esi				;  goes in buffer
		mov	edi,[%$dir]
		cld
		mov	ecx,tDirEntry_size/4
		rep	movsd
		mov	esi,[esp]
		mov	edi,[%$dir]
		push	edi				; Parameter for RFS_ConcatBlock
		call	RFS_ConcatBlock			; Concatenate
		pop	esi
		pop	edi
		jc	near .Exit

		mov	eax,[%$shift]			; Now if this isn't top level
		or	eax,eax
		jz	.ConcTop
		inc	dword [eax]			; We have to delete the
		jmp	.Exit				;  central entry recursively

.ConcTop:	cmp	byte [edi+tDirNode.Items],1	; Else see if we will empty it
		je	.NewHeadDir			; Yes, new head

.DelHeadDirEnt:	call	RFS_DeleteEntry			; Else just delete
		mov	esi,edi				; owning dir entry
		jmp	.Exit				; Get out

.NewHeadDir:	bts	dword [edi+tDirNode.Flags],RFS_DFL_LEAF ; See if it is a leaf
		jc	.DelHeadDirEnt			; Yes, just delete the last file
		mov	esi,edi	
		mov	ebx,[edi+tDirNode.PageLess]	; Get the pageless entry

		xor	eax,eax				; Wipe the block out
		dec	eax
		mov	ecx,RFS_BLOCKSIZE/4
		rep	stosb

		mov	eax,[%$headnode]
		push	eax
		call	RFS_AdjustDirNode
		pop	eax
		call	RFS_DeallocBlock
		jmp	.Exit

.Roll:		mov	ebx,[esi-4]			; Roll params
		mov	eax,[esi+tDirEntry.More]
		cmp	al,RFS_DIRORDER			; See which way to roll
		jb	.DoRight
		push	esi
		call	RFS_RollLeftBlock		; Left roll
		jmp	.Exit

.DoRight:	push	esi				; Right roll
		call	RFS_RollRightBlock

.ClearDir:						; XXX

.Exit:		epilogue
		ret	8

.NotExist:		mov	ax,ENOENT
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_AdjustDirNode - adjust directory node.
		; 
		; Input: EAX=head directory node,
		;	 EBX=new inode,
		;	 EDX=file system address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: The "Entry" field in tDirEntry points to a file or
		;	directory node. If that node was changed, we need
		;	to fix the entry. We can find that entry using the
		;	`Parent' field of our head directory node.
proc RFS_AdjustDirNode
		push	esi
		cmp	eax,[edx+tMasterBlock.RootDir]	; Head dir is root?
		jne	.NotRoot			; No
		mov	[edx+tMasterBlock.RootDir],ecx	; Save new root node
		jmp	.OK

.NotRoot:	push	ebx
		mov	ebx,eax
		mBseek
		mov	ebx,[esi+tDirNode.Parent]	; Search in parent dir
		lea	esi,[esi+tDirNode.Name]		; ESI=directory name
		call	RFS_SearchForFileName		; Search it
		pop	ebx
		jc	.Err1				; Not found - bug
		mov	[eax+tDirEntry.Entry],ebx	; Store new node

.OK:
.Exit:		mpop	edi,esi,ecx,ebx
		ret

.Err1:		mov	ax,ENOENT			; Internal error
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_SearchForFileName - search for file name.
		; Input: EBX=directory node block,
		;	 ESI=pointer to name,
		;	 EDX=file system address.
		; Output: CF=0 - OK:
		;		    EAX=directory entry,
		;		    EDI=pointer to directory node containing
		;			this entry
		;	  CF=1 - error, AX=error code.
proc RFS_SearchForFileName
		locals	name				; Name to search for

		prologue
		mov	[%$name],esi

.Loop:		mBseek
		mov	edi,esi				; Find entry
		mov	ebx,[%$name]
		call	RFS_FindEntry
		jc	.NoEntry			; Empty root, no entry
		jz	.GotEntry			; Else got it if match
		bt	dword [edi+tDirNode.Flags],RFS_DFL_LEAF ; Check for leaf
		jc	.NoEntry			; No entry if it is
		mov	ebx,[esi-4]			; Else recurse on the less
		jmp	.Loop

.NoEntry:	mov	ax,ENOENT
		stc
		jmp	.Exit

.GotEntry:	mov	eax,[esi+tDirEntry.Entry]	; Pull file block entry
		clc

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; RFS_GetNumOfFiles - get total number of files in directory.
		; Input: EDX=file system address,
		;	 EBX=directory node block number.
		; Output: CF=0 - OK, EAX=number of files;
		;	  CF=1 - error, AX=error code.
		; Note: recursive procedure.
proc RFS_GetNumOfFiles
		locals	count

		prologue
		mpush	ebx,ecx,esi,edi

		mBseek
		xor	eax,eax
		mov	al,[esi+tDirNode.Items]
		mov	[%$count],eax
		bt	dword [esi+tDirNode.Flags],RFS_DFL_LEAF
		jc	.OK
		mov	edi,esi
		add	esi,RFS_FIRSTDIRENTRY
		mov	cl,al
		or	cl,cl
		jz	.CheckLess

.Loop:		mov	ebx,[esi+tDirEntry.More]
		or	ebx,ebx
		jz	.NextDirEnt
		call	RFS_GetNumOfFiles
		add	[%$count],eax

.NextDirEnt:	add	esi,tDirEntry_size
		dec	cl
		jnz	.Loop

.CheckLess:	mov	ebx,[edi+tDirNode.PageLess]
		or	ebx,ebx
		je	.OK
		call	RFS_GetNumOfFiles
		add	[%$count],eax
.OK:		mov	eax,[%$count]
		clc
.Exit:		mpop	edi,esi,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------
