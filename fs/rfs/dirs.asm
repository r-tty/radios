;*******************************************************************************
;  dirs.asm - RFS directory manipulations;
;	      the B-TREE directory structure handling;
;	      handles inserts, deletes, balancing.
;*******************************************************************************


; --- Procedures ---
segment KCODE

		; RFS_CompareName - compare two names.
		; Input: EDX=first name,
		;	 EBX=second name.
		; Output: ZF=1 - equal;
		;	  ZF=0 - not equal.
proc RFS_CompareName near
		push	ecx esi edi
		mov	ecx,FILENAMELEN		; Name length
		mov	esi,ebx			; File to compare in edx
		mov	edi,eax			; Buffered file name in eax
		cld
		repe	cmpsb
		pop	edi esi ecx
		ret
endp		;---------------------------------------------------------------


		; RFS_FindEntry - find the position an entry would be inserted
		;		   into in this block (binary search).
		; Input: EBX=pointer to directory entry,
		;	 ESI=pointer to directory page.
		; Output: CF=0 - OK;
		;	  CF=1 - error (position not found).
proc RFS_FindEntry near
		push	edi
		movzx	ecx,[esi+tDirPage.Items]	; Get total items
		add	esi,FIRSTDIRENTRY		; Point at first entry
		or	ecx,ecx				; Quit if no items
		jz	short @@Err
		mov	edi,esi				; EDI point beyond last entry
		shl	ecx,DIRENTRYSHIFT
		add	edi,ecx

@@Loop:		mov	eax,edi				; Find out if converged
		sub	eax,esi
		cmp	eax,DIRENTRYSIZE		; Quit if no midpoint
		je	short @@GotEntry
		bt	eax,DIRENTRYSHIFT
		mov	eax,0
		jnc	short @@IsEven			; Else make sure we are
		mov	al,DIRENTRYSIZE			; Going to be on an even

@@IsEven:	add	eax,esi				; boundary when divide by 2
		add	eax,edi				; Find midpoint
		shr	eax,1
		call	RFS_CompareName			; Compare
		jz	short @@IsEqual			; If equal, get out
		jl	short @@MoveDown		; Else decide which way to go
		mov	esi,eax				; Move bottom up
		jmp	@@Loop				; Next test

@@MoveDown:	mov	edi,eax				; Move bottom down
		jmp	@@Loop				; Next test

@@IsEqual:	mov	esi,eax				; Found it, get out
		clc
		jmp	short @@Exit

@@GotEntry:	mov	eax,esi				; Not in block,
		call	RFS_CompareName		; See which is bigger
		clc
		jle	short @@Exit			; Leave ESI pointing above
		mov	esi,edi
		jmp	short @@Exit
@@Err:		stc
@@Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; RFS_InsertEntry - insert an entry in this block.
		; Input: ESI=address of position an entry would be inserted,
		;	 EDI=address of directory page,
		;	 EBX=address of data.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc RFS_InsertEntry near
		cmp	[edi+tDirPage.Items],MAXDIRITEMS	; See if full
		je	short @@Err				; Get out if so
		push	ecx edi esi
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
		pop	esi edi ecx			; Restore regs
		inc	[edi+tDirPage.Items]		; Inc count
		clc					; Get out
		ret
@@Err:		stc					; Error
		ret
endp		;---------------------------------------------------------------


		; RFS_DeleteEntry - delete an entry in block.
		; Input: EDI=directory page address,
		;	 ESI=entry address
		; Output: ZF=0 - number of entries!=0;
		;	  ZF=1 - number of entries==0.
proc RFS_DeleteEntry near
		dec	[edi+tDirPage.Items]		; Decrement items
		pushfd
		push	ecx esi edi
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
		pop	edi esi ecx
		popfd					; Get status of decrement
		clc
		ret
endp		;---------------------------------------------------------------


		; RFS_SplitBlock - split a block into two blocks
		;		   if an insert overflows.
		; Input: EBX=block number,
		;	 DL=file system linkpoint number,
		;	 ESI=buffer offset,
		;	 EDI=directory page address,
		;	 [ESP+4] - pointer to new directory.
		; Output:
proc RFS_SplitBlock near
@@newdir	EQU	ebp+8				; Directory to add
@@oldblock	EQU	ebp-4				; Original block
@@bufferofs	EQU	ebp-8				; Offset to insertion pt
@@buffer	EQU	ebp-12				; Original buffer
@@newblock	EQU	ebp-16				; New block
@@newbuffer	EQU	ebp-20				; New buffer
@@movelen	EQU	ebp-24				; Amount to move
@@insertblock	EQU	ebp-28				; Place to insert overflow entry
@@oldcount	EQU	ebp-32				; Items in orig block
@@newcount	EQU	ebp-36				; Items in new block
@@deviceid	EQU	ebp-40				; Device ID
@@fslp		EQU	ebp-44				; FSLP
@@insertdata	EQU	ebp-44-DIRENTRYSIZE		; Data to insert

		push	ebp
		mov	ebp,esp
		sub	esp,44+DIRENTRYSIZE		; Space for params
		sub	esi,edi				; Get buffer offset
		mov	[@@bufferofs],esi		; Save offset
		mov	[@@oldblock],ebx		; Save orig block
		and	edx,0FFh
		mov	[@@fslp],edx			; Save FLSP
		call	RFS_AllocDirBlock		; Allocate a new block
		jc	short @@Err			; Error if cant
		call	BUF_MarkDirty			; Make it dirty
		mov	[@@newblock],eax		; Save block number
		mov	[@@newbuffer],esi		; And new buffer address

		mov	ebx,[@@oldblock]		; Read the original block
		call	CFS_LPtoDevID			; Get device ID
		mov	[@@deviceid],edx
		call	BUF_ReadBlock
		jc	short @@Err
		call	BUF_MarkDirty			; Make it dirty

		mov	[@@buffer],esi			; Save buffer
		mov	edi,[@@newbuffer]
		mov	ecx,FIRSTDIRENTRY/4             ; Copy the block header
		cld
		rep	movsd

		; See if inserting right at middle
		cmp	[dword @@bufferofs],FIRSTDIRENTRY+(BLOCKSIZE-FIRSTDIRENTRY)/2
		je	@@PromoteNewDir			; Yes, promote it

		pushfd
		mov	esi,[@@newdir]			; Move the new directory
		lea	edi,[@@insertdata]		; To local area
		mov	ecx,DIRENTRYSIZE/4	
		rep	movsd
		popfd
		jc	short @@InsertInOld		; Branch if it goes in orig dir

@InsertInNew:	mov	[dword @@movelen],DIRENTRYSIZE*(DIRORDER-1)/4	; amount to move
		mov	[dword @@newcount],DIRORDER-1	; Items in new after copy
		mov	[dword @@oldcount],DIRORDER	; Items in old after copy
		mov	eax,[@@newblock]		; Get block to insert in
		mov	esi,[@@buffer]			; Source buffer
		add	esi,FIRSTDIRENTRY+DIRENTRYSIZE*DIRORDER ; Point at what to move up
		jmp	short @@InsertCommon

@@Err:		jmp	@@Exit

@@InsertInOld:	mov	[dword @@movelen],DIRENTRYSIZE*DIRORDER/4	; Amount to move
		mov	[dword @@newcount],DIRORDER	; Items in new after copy
		mov	[dword @@oldcount],DIRORDER-1	; Items in old after copy
		mov	eax,[@@oldblock]		; Block to insert in
		mov	esi,[@@buffer]			; Source buffer
		add	esi,FIRSTDIRENTRY+DIRENTRYSIZE*(DIRORDER-1) ; Point at what to move up

@@InsertCommon:	mov	[@@insertblock],eax		; Save insert block
		mov	edi,[@@newdir]			; Copy move up name to callers param
		mov	ecx,DIRENTRYSIZE/4		
		cld					
		push	edi
		rep	movsd
		push	esi				; Starting position to move from
		sub	esi,[@@buffer]			; Save buffer offset
		mov	[@@bufferofs],esi
		pop	esi
		mov	eax,[esi+LESS]	 		; NEWPAGE.PAGELESS is the
		mov	edi,[@@newbuffer]		; MOVEDUP.More
		mov	[edi+tDirPage.PageLess],eax
		pop	edi
		mov	eax,[@@newblock]		; Movedup.More is the new block
		mov	[edi+tDirEntry.More],eax	;  just created
		jmp	short @@Copy

@@PromoteNewDir:mov	edi,[@@newdir]			; EDI = new directory
		mov	esi,[@@newbuffer]		; ESI = new buffer
		mov	eax,[edi+tDirEntry.More]	; NEWPAAGE.PAGELESS is
		mov	[esi + tDirPage.PageLess],eax	;   NEWENTRY.More
		mov	eax,[@@newblock]		; NEWENTRY.More is our newblock
		mov	[edi+tDirEntry.More],eax
		mov	[dword @@movelen],DIRENTRYSIZE*DIRORDER/4 ;Amount to move
		mov	[dword @@newcount],DIRORDER	; New counts after move
		mov	[dword @@oldcount],DIRORDER
		mov	[dword @@insertblock],0	; Nothing to insert
		mov	[dword @@bufferofs],FIRSTDIRENTRY +DIRENTRYSIZE*DIRORDER ; Position to move from

@@Copy:		mov	esi,[@@buffer]			; Original buffer
		mov	eax,[@@oldcount]		; Count to put in it
		mov	[byte esi+tDirPage.Items],al	;
		add	esi,[@@bufferofs]		; Position to move from
		mov	edi,[@@newbuffer]		; New buffer
		mov	eax,[@@newcount]		; Count to put in it
		mov	[edi+tDirPage.Items],al
		add	edi,FIRSTDIRENTRY		; Position to move to
		mov	ecx,[@@movelen]			; Amount to move
		cld					; Do move
		rep	movsd
		mov	edi,[@@buffer]			; Position to wipe at
		add	edi,[@@bufferofs]
		mov	ecx,[@@movelen]			; Amount to wipe
		test	[dword @@insertblock],-1	; See if promoting New entry
		jz	short @@NoDirAdj		; Yes, don't wipe promoted
		sub	edi,DIRENTRYSIZE		; Else wipe promoted entry
		add	ecx,DIRENTRYSIZE/4

@@NoDirAdj:	xor	eax,eax				; Value to wipe with = -1
		dec	eax				;
		rep	stosd				; Do wipe
		test	[dword @@insertblock],-1	; See if promoting New entry
		jz	short @@CheckRoot		; Yep, see if root
		mov	eax,[@@insertblock]		; Else find out where to insert it
		cmp	eax,[@@oldblock]		; Old block?
		mov	esi,[@@buffer]			; Assume so
		jz	short @@InsOld			; Yes!
		mov	esi,[@@newbuffer]		; Else new block

@@InsOld:	mov	edi,esi				; EDI = buffer
		lea	ebx,[@@insertdata]		; Data to insert
		call	RFS_FindEntry			; Find insert position
		call	RFS_InsertEntry			; Do insert

@@CheckRoot:	mov	eax,[@@oldblock]		; Now see if
		mov	edi,[RootsTblAddr]		; original block was root
		mov	edx,[@@fslp]
		cmp	eax,[edi+edx*4]
		jnz	short @@OK			; No, exit
		mov	dl,[@@fslp]
		call	RFS_AllocDirBlock		; Yes, allocate a new root
		jc	@@Err
		mov	[esi+tDirPage.Items],1		; With one item
		mov	eax,[@@oldblock]		; PAGELESS is old root
		mov	[esi+tDirPage.PageLess],eax
		mov	edi,esi				; Copy new entry to root dir
		mov	esi,[@@newdir]
		add	edi,FIRSTDIRENTRY
		mov	ecx,DIRENTRYSIZE
		cld
		rep	movsb

		push	ebx				; Read master block
		xor	ebx,ebx
		mov	edx,[@@deviceid]
		call	BUF_ReadBlock
		pop	ebx
		jc	@@Err
		call	BUF_MarkDirty			; Dirty it
		mov	[esi+tMasterBlock.RootDir],ebx	; New root
		mov	edi,[RootsTblAddr]		; if original block was root
		mov	edx,[@@fslp]
		mov	[edi+edx*4],ebx

@@OK:		clc
@@Exit:		mov	eax,[@@newdir]			; Return new directory
		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_ConcatBlock - deleting, concatenate two blocks.
		; Input: [ESP+4] - pointer to new directory,
		;	 DL=file system linkpoint number,
		;	 EBX=left block number,
		;	 EAX=right block number.
		; Output:
proc RFS_ConcatBlock near
@@newdir	EQU	ebp+8

		push	ebp
		mov	ebp,esp
		push	edx				; Keep FSLP

		call	CFS_LPtoDevID			; Get device ID
		push	eax				; Read the left block
		call	BUF_ReadBlock
		jc	short @@Err
		call	BUF_MarkDirty			; Make it dirty
		mov	edi,esi				; EDI = left
		pop	ebx
		push	ebx				; Read the right block
		call	BUF_ReadBlock
		jc	short @@Err
		call	BUF_MarkDirty			; Make it dirty
		push	edi
		push	esi
		movzx	ecx,[edi+tDirPage.Items]	; Point after data of left
		shl	ecx,DIRENTRYSHIFT
		add	edi,ecx
		add	edi,FIRSTDIRENTRY
		movzx	ecx,[esi+tDirPage.Items]	; Get amount to move in DWORDS
		shl	ecx,DIRENTRYSHIFT-2
		add	esi,FIRSTDIRENTRY		; Get start position
		cld
		rep	movsd				; Do move
		pop	esi
		mov	eax,[esi+tDirPage.PageLess]	; CENTERENTRY.More = RIGHT.PAGELESS
		mov	edi,[@@newdir]
		mov	[edi+tDirEntry.More],eax
		mov	edi,esi				; Wipe out right block
		mov	ecx,BLOCKSIZE/4
		xor	eax,eax
		dec	eax
		rep	stosd
		pop	edi                             ; Get left buffer
		mov	[edi+tDirPage.Items],MAXDIRITEMS-1	; Almost full
		mov	esi,edi				; ESI = EDI
		mov	ebx,[@@newdir]			; Data to insert is in EBX
		call	RFS_FindEntry			; Find entry
		call	RFS_InsertEntry		; Insert entry
		pop	eax edx				; Deallocate right block
		call	RFS_DeallocBlock
		jmp	short @@Exit

@@Err:		pop	edx edx				; AX=error code here
@@Exit:		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_RollRightBlock - delete underflow : roll data right.
		; Input: [ESP+4] - rolling entry,
		;	 EDI=pointer to rolling buffer,
		;	 EAX=right block,
		;	 EBX=left block,
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_RollRightBlock near
@@dir		EQU	ebp+8					; Rolling entry
@@dirbuf	EQU	ebp-4					; Buffer rolling entry is in
@@dest		EQU	ebp-8					; Right buffer

		push	ebp
		mov	ebp,esp
		sub	esp,8
		mov	[@@dirbuf],edi
		mov	[@@dest],eax
		push	edx
		call	CFS_LPtoDevID
		jc	short @@Exit
		push	eax				; Read left
		call	BUF_ReadBlock
		pop	ebx
		jc	short @@Exit

		call	BUF_MarkDirty			; Dirty it
		mov	edi,esi
		call	BUF_ReadBlock			; Read right
		jc	short @@Exit

		call	BUF_MarkDirty			; Dirty it
		xchg	esi,edi				; LEFT in ESI, RIGHT in EDI
		mov	ebx,[@@dir]			; Rolling.More = RIGHT.PAGELESS
		mov	eax,[edi+tDirPage.PageLess]
		mov	[ebx+tDirEntry.More],eax

		push	edi
		push	esi				; Insert ROLLING in RIGHT
		mov	esi,edi
		add	esi,FIRSTDIRENTRY
		call	RFS_InsertEntry
		mov	edi,[@@dirbuf]			; Delete ROLLING
		mov	esi,ebx
		call	RFS_DeleteEntry
		pop	esi				;
		mov	edi,esi				; Point to last entry in left
		movzx	ecx,[esi+tDirPage.Items]
		dec	ecx
		shl	ecx,DIRENTRYSHIFT
		add	edi,ecx
		add	edi,FIRSTDIRENTRY
		mov	eax,[edi+tDirEntry.More]	; MOVUP.More->RIGHT.PAGELESS
		xchg	[esp],edi
		mov	[edi+tDirPage.PageLess],eax
		mov	edi,[esp]
		mov	eax,[@@dest]			; RIGHT->MOVEUP.More
		mov	[edi+tDirEntry.More],eax
		mov	ebx,edi
		push	esi                             ; Insert Moveup where ROLLING was
		mov	esi,[@@dir]
		mov	edi,[@@dirbuf]
		xchg	esi,edi
		call	BUF_MarkDirty			; Dirty buffer
		xchg	esi,edi
		call	RFS_InsertEntry
		pop	edi				; Now delete it from left
		pop	esi
		call	RFS_DeleteEntry

@@Exit:		pop	edx
		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_RollLeftBlock - delete underflow: roll left.
		; Input: [ESP+4] - rolling entry,
		;	 EDI=pointer to rolling buffer,
		;	 EAX=right block,
		;	 EBX=left block,
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_RollLeftBlock near
@@dir		EQU	ebp+8				; Rolling entry
@@dirbuf	EQU	ebp-4				; Buffer rolling entry is in
@@dest		EQU	ebp-8				; Right buffer

		push	ebp
		mov	ebp,esp
		sub	esp,8
		mov	[@@dirbuf],edi			; Save Rolling buffer
		mov	[@@dest],eax			; And right block
		push	edx
		call	CFS_LPtoDevID
		jc	short @@Exit
		push	eax				; Read left
		call	BUF_ReadBlock
		pop	ebx
		jc	short @@Exit
		call	BUF_MarkDirty			; Dirty it
		mov	edi,esi				;
		call	BUF_ReadBlock			; Read right
		jc	short @@Exit
		call	BUF_MarkDirty			; Dirty it
		mov	ebx,[@@dir]			; RIGHT.PageLess->ROLLING.More
		mov	eax,[esi + tDirPage.PageLess]
		mov	[ebx+tDirEntry.More],eax
		push	esi
		mov	esi,edi				; Move to end of left
		movzx	ecx,[esi + tDirPage.Items]
		shl	ecx,DIRENTRYSHIFT
		add	esi,ecx
		add	esi,FIRSTDIRENTRY
		call	RFS_InsertEntry		; Move rolling to left
		mov	edi,[@@dirbuf]
		mov	esi,ebx
		call	RFS_DeleteEntry		; Delete rolling from its buffer
		pop	esi
		mov	edi,esi
		add	edi,FIRSTDIRENTRY
		push	edi				; FIRSTRIGHT.More->RIGHT.PageLess
		mov	eax,[edi+tDirEntry.More]
		mov	[esi+tDirPage.PageLess],eax
		mov	eax,[@@dest]			; RIGHT-> FIRSTRIGHT.More
		mov	[edi + tDirEntry.More],eax
		mov	ebx,edi
		push	esi
		mov	esi,[@@dir]			; Insert Firstright where rolling was
		mov	edi,[@@dirbuf]
		xchg	esi,edi
		call	BUF_MarkDirty			; Dirty rolling buffer
		xchg	esi,edi
		call	RFS_InsertEntry
		pop	edi
		pop	esi
		call	RFS_DeleteEntry		; Delete firstright from orig pos

@@Exit:		pop	edx
		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_MoveBottomEntry - delete from middle: roll bottom up
		; Input: [ESP+4] -
		;	 EBX=
		;	 ESI=
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_MoveBottomEntry near
@@dest		EQU	ebp+8

		push	ebp
		mov	ebp,esp

		push	edx				; Keep FSLP
		call	CFS_LPtoDevID			; Get device ID
		jc	short @@Exit
		push	ebx				; Save block and offset
		sub	esi,edi				; to move into
		push	esi
		add	esi,edi

@@GetLp:	mov	ebx,[esi+LESS]			; Grab what is less
		call	BUF_ReadBlock			; Read the block
		jc	short @@Error
		mov	edi,esi
		movzx	eax,[esi+tDirPage.Items]	; Point at end
	      	shl	eax,DIRENTRYSHIFT
		add	eax,FIRSTDIRENTRY
		add	esi,eax
		bt	[dword edi+tDirPage.Flags],DFL_LEAF	; See if bottom
		jnc	short @@GetLp			; Loop if not
		sub	esi,DIRENTRYSIZE		; Point at last entry
		mov	ecx,esi
		pop	edi				; Restore block and offset
		pop	ebx				; to move into
		call	BUF_ReadBlock
		jc	short @@Exit
		push	esi
		push	edi
		add	edi,esi				; Move the entry there,
		mov	esi,ecx				; Keeping MORE intact
		push	esi
		mov	ecx,(DIRENTRYSIZE/4) -1
		rep	movsd
		pop	esi
		mov	edi,[@@dest]			; Move the entry into caller's
		mov	ecx,DIRENTRYSIZE/4		; Buffer for recursive delete
		rep	movsd
		pop	edi
		pop	esi
		add	edi,esi				; Restore esi and edi
		xchg	esi,edi
		jmp	short @@Exit

@@Error:	pop	edi ebx
@@Exit:		pop	edx
		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_InsertFileName - insert a file name.
		; Input: [ESP+4]=pointer to directory entry,
		;	 EBX=directory index,
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: pascal-style call.
proc RFS_InsertFileName near
@@newdir	EQU	ebp+8				; What to insert
@@block		EQU	ebp-4				; Block we are analyzing
@@deviceid	EQU	ebp-8				; Device ID
@@fslp		EQU	ebp-12				; FSLP
@@name		EQU	ebp-12-DIRENTRYSIZE		; Current name for recursion

		push	ebp
		mov	ebp,esp
		sub	esp,12+DIRENTRYSIZE		; Save space for vars

		push	ebx edx
		and	edx,0FFh
		mov	[@@fslp],edx			; Keep FSLP

		mov	esi,[@@newdir]			; Copy name to local area
		lea	edi,[@@name]
		mov	[@@newdir],edi			; Pointing param at local
		mov	ecx,DIRENTRYSIZE/4
		cld
		rep	movsd
		call	RFS_LoadRootDir		; Start with the root
		jc	@@Error
		mov	eax,ebx				; In EAX
		call	CFS_LPtoDevID			; Get device ID
		jc	@@Error
		mov	[@@deviceid],edx		; Keep device ID
		jmp	short @@2

@@Entry2:	enter	12,0				; Come here for recursion
		mov	[@@fslp],edx			; Keep FSLP in local stack
		call	CFS_LPtoDevID			; Keep device ID
		jc	short @@Exit			; in local stack
		mov	[@@deviceid],edx

@@2:		mov	ebx,eax				; Get this block
		mov	[@@block],eax			; Save it
		call	BUF_ReadBlock			; Read it
		jc	short @@Error

		mov	edi,esi				; Find the entry
		mov	ebx,[@@newdir]
		call	RFS_FindEntry
		jc	short @@Insert			; Empty root, just insert
		jz	short @@FileExist		; Exists, go proclaim error

		bt	[dword edi+tDirPage.Flags],DFL_LEAF ; See if bottom
		jc	short @@Insert			; Yes, just insert
		mov	eax,[esi+LESS]			; Else recurse on less
		mov	edx,[@@fslp]
		push	[dword @@newdir]
		call	@@Entry2
		jc	short @@Error

		mov	edi,[@@newdir]			; See if to recurse
		test	[byte edi],-1
		jz	short @@Exit			; No, get out
		mov	ebx,[@@block]			; Else reread block
		mov	edx,[@@deviceid]
		call	BUF_ReadBlock
		jc	short @@Error
		mov	edi,esi				; Find the entry
		mov	ebx,[@@newdir]
		call	RFS_FindEntry

@@Insert:	call	RFS_InsertEntry		; Insert here
		jc	short @@Split			; Split if too full
		mov	esi,edi
		call	BUF_MarkDirty			; Else just dirty buffer
		mov	edi,[@@newdir]			; And mark done
		mov	[byte edi],0
		jmp	short @@Exit

@@Split:	mov	ebx,[@@block]			; Splitting, call splitter
		mov	edx,[@@fslp]
		push	[dword @@newdir]
		call	RFS_SplitBlock
		jc	short @@Error
		jmp	short @@Exit

@@FileExist:	mov	ax,ERR_FS_FileExists
@@Error:	stc
@@Exit:		pop	edx ebx
		mov	esp,ebp
		pop	ebp
		ret	4
endp		;---------------------------------------------------------------


		; RFS_DeleteFileName - delete file name.
		; Input: [ESP+8]=0,
		;	 [ESP+4]=pointer to name to delete,
		;	 DL=file system linkpoint number.
		; Output:
proc RFS_DeleteFileName near
@@shift		EQU	ebp+12			; Location of flag for recursion: 0 for top level
@@dir		EQU	ebp+8			; Name to delete
@@toshift	EQU	ebp-4			; Set true if recursion necessary
@@deviceid	EQU	ebp-8			; Device ID
@@fslp		EQU	ebp-12			; FSLP
@@name		EQU	ebp-12-DIRENTRYSIZE	; Local buffer for recursion

		push	ebp
		mov	ebp,esp
		sub	esp,12+DIRENTRYSIZE

		push	edx
		and	edx,0FFh
		mov	[@@fslp],edx			; Keep FSLP

		mov	esi,[@@dir]			; Move file name
		lea	edi,[@@name]			; to local buffer
		mov	[@@dir],edi
		mov	ecx,DIRENTRYSIZE/4
		cld
		rep	movsd

		call	RFS_LoadRootDir		; Start with root dir
		jc	@@Exit
		mov	eax,ebx				; in EAX
		call	CFS_LPtoDevID			; Get device ID
		jc	@@Exit
		mov	[@@deviceid],edx		; Keep device ID
		jmp	short @@2

@@Entry2:	enter	12,0				; Recursion comes here
		mov	[@@fslp],edx			; Keep FSLP in local stack
		call	CFS_LPtoDevID			; Keep device ID
		jc	@@Exit				; in local stack
		mov	[@@deviceid],edx

@@2:		mov	[dword @@toshift],0		; Assume no upward shift
		call	BUF_ReadBlock			; Read current block
		jc	@@Exit

		mov	edi,esi				; Find entry in block
		push	ebx
		mov	ebx,[@@dir]
		call	RFS_FindEntry
		pop	ebx
		jnz	short @@NotFound		; No match, possibly recurse

		push	esi				; Else dirty the buffer
		mov	esi,edi
		call	BUF_MarkDirty
		pop	esi

		bt	[dword edi+tDirPage.Flags],DFL_LEAF	; If this is not a leaf
		jnc	short @@MoveToMiddle			; Move to middle
		call	RFS_DeleteEntry			; Delete leaf entry
		jz	@@ClearDir				; Killed root, exit

		cmp	[byte edi+tDirPage.Items],DIRORDER	; See if underflow
		jnc	short @@NoUnderflow			; No, get out
		mov	edi,[@@shift]				; See if top level
		or	edi,edi
		jz	short @@NoUnderflow			; Allowed to underflow root
		inc	[byte edi]			; Else there will be a higher-level
@@NoUnderflow:	jmp	@@Exit				;  concatenation or roll

@@MoveToMiddle:	mov	dl,[@@fslp]
		mov	eax,[@@dir]			; Move bottom entry to middle
		push	eax				;  leaves name of bottom entry in buffer
		call	RFS_MoveBottomEntry
		jc	@@Exit

@@NotFound:	bt	[dword edi+tDirPage.Flags],DFL_LEAF ; If a leaf, file doesn't exist
		jc	@@None
		push	esi edi ebx			; Else recurse on less
		mov	ebx,[esi+LESS]
		mov	edx,[@@fslp]
		lea	edi,[@@toshift]
		push	edi
		push	[dword @@dir]
		call	@@Entry2
		pop	ebx edi esi
		jc	@@Exit
		test	[dword @@toshift],-1		; See if there was an underflow
		jz	@@Exit				; Quit if not
		sub	esi,edi				; Else read current block
		mov	edi,esi
		mov	edx,[@@deviceid]
		call	BUF_ReadBlock
		jc	@@Exit
		xchg	esi,edi				; See if pointing past last entry
		mov	eax,esi
		add	esi,edi
		sub	eax,FIRSTDIRENTRY
		shr	eax,DIRENTRYSHIFT
		cmp	al,[edi+tDirPage.Items]
		jc	short @@NoAdjust
		sub	esi,DIRENTRYSIZE		; Yes, point to last entry

@@NoAdjust:	mov	edx,[@@deviceid]

		push	esi
                mov	ebx,[esi+LESS]			; Load LESS block
		call	BUF_ReadBlock
		movzx	ecx,[esi+tDirPage.Items]	; Get items in it
		pop	esi
		jc	@@Error2

		push	esi ecx
		mov	ebx,[esi+tDirEntry.More]	; Load MORE block
		call	BUF_ReadBlock
		pop	ecx
		pushfd
		movzx	eax,[esi+tDirPage.Items]	; Get items in it
		add	cl,[esi+tDirPage.Items]		; Get total items
		popfd
		pop	esi
		jc	@@Error2

		cmp	cl,MAXDIRITEMS			; If can't be concatted we roll
		jnc	@@Roll
		mov	ebx,[esi+LESS]			; Get params for concat

		mov	eax,[esi+tDirEntry.More]
		push	edi esi				; Central dir entry goes in buffer
		mov	edi,[@@dir]
		cld
		mov	ecx,DIRENTRYSIZE/4
		rep	movsd
		pop	esi
		push	esi
		mov	dl,[@@fslp]
		mov	edi,[@@dir]
		push	edi				; Parameter for RFS_ConcatBlock
		call	RFS_ConcatBlock		; Do concat
		pop	esi edi
		jc	@@Exit

		mov	eax,[@@shift]			; Now if this isn't top level
		or	eax,eax
		jz	short @@ConcTop
		inc	[dword eax]			; We have to delete the central entry
		jmp	short @@Exit			;   recursively

@@ConcTop:	cmp	[byte edi+tDirPage.Items],1	; Else see if we will empty it
		jz	short @@NewRoot			; Yes, new root

@@DelRootEnt:	call	RFS_DeleteEntry		; Else just delete root entry
		mov	esi,edi
		call	BUF_MarkDirty			; Mark dirty
		jmp	short @@Exit			; Get out

@@NewRoot:	bts	[dword edi+tDirPage.Flags],DFL_LEAF	; See if it is a leaf
		jc	short @@DelRootEnt		; Yes, just delete the last file
		mov	esi,edi				; Else dirty buffer
		call	BUF_MarkDirty			;
		mov	eax,[edi+tDirPage.PageLess]	; Get the pageless entry

		push	eax				; Wipe the block out
		xor	eax,eax
		dec	eax
		mov	ecx,BLOCKSIZE/4
		rep	stosb
		mov	edx,[@@deviceid]
		xor	ebx,ebx				; Read master block
		call	BUF_ReadBlock
		jnc	short @@CorrectRoot
		add	esp,4				; Keep error code
		jmp	short @@Exit

@@CorrectRoot:	pop	eax
		call	BUF_MarkDirty			; Dirty it
		mov	edi,[RootsTblAddr]
		mov	edx,[@@fslp]
		mov	[edi+edx*4],eax			; Mark a new root
		xchg	[esi+tMasterBlock.RootDir],eax
		call	RFS_DeallocBlock
		jmp	short @@Exit

@@Roll:		cmp	al,DIRORDER			; See which way to roll
		mov	ebx,[esi+LESS]			; Roll params
		mov	eax,[esi+tDirEntry.More]
		mov	dl,[@@fslp]
		jc	short @@DoRight
		push	esi
		call	RFS_RollLeftBlock		; Left roll
		jmp	short @@Exit

@@DoRight:	push	esi				; Right roll
		call	RFS_RollRightBlock

@@ClearDir:
@@Exit:		pop	edx
		mov	esp,ebp
		pop	ebp
		ret	8

@@None:		mov	ax,ERR_FS_FileNotFound
		stc
		jmp	short @@Exit

@@Error2:	pop	esi
		jmp	short @@Exit
endp		;---------------------------------------------------------------


		; RFS_SearchForFileName - search for file name.
		; Input: EBX=disk index of directory,
		;	 ESI=pointer to name,
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK, EAX=directory entry;
		;	  CF=1 - error, AX=error code.
proc RFS_SearchForFileName near
@@name		EQU	ebp-4				; Name to search for
@@deviceid	EQU	ebp-8

		push	ebp
		mov	ebp,esp
		sub	esp,8
		push	edx

		mov	[@@name],esi			; Save name

@@Begin:	call	RFS_LoadRootDir		; Start at root
		jc	short @@Exit
		call	CFS_LPtoDevID
		jc	short @@Exit
		mov	[@@deviceid],edx

@@Loop:		mov	edx,[@@deviceid]
		call	BUF_ReadBlock			; Read block
		jc	short @@Exit
		mov	edi,esi				; Find entry
		mov	ebx,[@@name]
		call	RFS_FindEntry
		jc	short @@NoEntry			; Empty root, no entry
		jz	short @@GotEntry		; Else got it if match
		bt	[dword edi+tDirPage.Flags],DFL_LEAF ; Check for leaf
		jc	short @@NoEntry			; No entry if it is
		mov	ebx,[esi+LESS]			; Else recurse on the less
		jmp	@@Loop

@@NoEntry:	mov	ax,ERR_FS_FileNotFound
		stc
		jmp	short @@Exit
@@GotEntry:	mov	eax,[esi+tDirEntry.Entry]	; Pull file block entry
		clc

@@Exit:		pop	edx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; RFS_GetNumOfFiles - get total number of files in directory.
		; Input: EDX=device ID,
		;	 EBX=directory index.
		; Output: CF=0 - OK, EAX=number of files;
		;	  CF=1 - error, AX=error code.
		; Note: recursive procedure.
proc RFS_GetNumOfFiles near
@@count		EQU	ebp-4

		push	ebp
		mov	ebp,esp
		sub	esp,4
		push	ebx ecx edx esi edi

		call	BUF_ReadBlock
		jc	short @@Exit

		xor	eax,eax
		mov	al,[esi+tDirPage.Items]
		mov	[@@count],eax
		bt	[dword esi+tDirPage.Flags],DFL_LEAF
		jc	short @@OK
		mov	edi,esi
		add	esi,FIRSTDIRENTRY
		mov	cl,al
		or	cl,cl
		jz	short @@CheckLess

@@Loop:		mov	ebx,[esi+tDirEntry.More]
		or	ebx,ebx
		jz	@@NextDirEnt
		call	RFS_GetNumOfFiles
		add	[@@count],eax

@@NextDirEnt:	add	esi,DIRENTRYSIZE
		dec	cl
		jnz	@@Loop

@@CheckLess:	mov	ebx,[edi+tDirPage.PageLess]
		or	ebx,ebx
		je	short @@OK
		call	RFS_GetNumOfFiles
		add	[@@count],eax
@@OK:		mov	eax,[@@count]
		clc
@@Exit:		pop	edi esi edx ecx ebx
		leave
		ret
endp		;---------------------------------------------------------------

ends

