;-------------------------------------------------------------------------------
;  master.as -  basic file system functionality:
;		creating master disk block (boot sector and config sector);
;		creating directory blocks (empty);
;		creating block allocation maps (BAMs);
;
;  Warning: error handling not implemented;
;	    not tested with huge BAMs.
;-------------------------------------------------------------------------------

; --- Imports ---

library kernel.fs
extern CFS_LPtoDevID:extcall
extern BUF_ReadBlock:extcall, BUF_Write:extcall, BUF_MarkDirty:extcall
extern GetNumBlocks:extcall
extern CFS_GetRootIndex:extcall, CFS_SetRootIndex:extcall


; --- Data ---

section .data

RFS_ID		DB	"RFS 01.00",0		; RFS label (ASCIIZ!)
RFS_ID_size	EQU	$-RFS_ID
RFS_DirID	DB	"RFS DirectoryID     "	; RFS directory label
RFS_DirID_size	EQU	$-RFS_DirID



; --- Variables ---

section .bss

BAMs		RESD	1			; Number of BAMs to allocate



; --- Procedures ---

section .text

		; RFS_ClearNumBAMs - clear the NumBAMs and root pointers
		;		      if media changed.
		; Input: CF and AX - result of last disk operation,
		;	 DL=file system linkpoint number.
		; Output: none.
proc RFS_ClearNumBAMs
		jnc	short .Exit		; Exit if no error
		cmp	ax,ERR_DISK_MediaChgd	; If changed, reset BAMs
		je	short .Changed
		cmp	ax,ERR_DISK_NoMedia	; If not present, reset BAMs
		jnz	short .NoChange

.Changed:	mov	edi,[NumBAMsTblAddr]	; Get sat table
		push	edx
		and	edx,0FFh
		mov	dword [edi+edx*4],-1	; Clear it
		pop	edx
.NoChange:	stc				; Restore carry flag
.Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_LoadNumBAMs - load up the number of BAMs.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK, ECX=number of BAMs;
		;	  CF=1 - error, AX=error code.
proc RFS_LoadNumBAMs
		mpush	ebx,edx
		mov	edi,[NumBAMsTblAddr]	; Get table address
		and	edx,0FFh
		mov	ecx,[edi+edx*4]		; Get number of BAMs
		inc	ecx			; See if is -1
		jnz	short .GotBAMs		; Got BAMs number if not
		mov	ecx,edx			; Store FSLP
		xor	ebx,ebx			; Block number=0 (master)
		call	CFS_LPtoDevID		; Get device ID
		jc	short .Exit
		call	BUF_ReadBlock		; Read the master block
		jc	short .Err
                mov	edx,ecx			; Restore FSLP
		mov	ecx,[esi+tMasterBlock.NumBAMs] ; Get BAMs number
		mov	[edi+edx*4],ecx		; from master block
		mov	ebx,[esi+tMasterBlock.RootDir] ; Get root dir begin block
		call	CFS_SetRootIndex
		inc	ecx

.GotBAMs:	dec	ecx
		clc
		jmp	short .Exit

.Err:		mov	ax,ERR_RFS_NoBAMs
		stc
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_LoadRootDir - load up the root directory block.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK, EBX=root directory disk index;
		;	  CF=1 - error, AX=error code.
proc RFS_LoadRootDir
		mpush	edx,edi
		call	RFS_LoadNumBAMs		; Make sure
		jc	short .Err		; we have the right device
		call	CFS_GetRootIndex	; Get root index
.Done:		mpop	edi,edx
		ret

.Err:		mov	ax,ERR_RFS_NoRoot
		stc
		jmp	short .Done
endp		;---------------------------------------------------------------


		; RFS_ReadBAM - read block allocation map.
		; Input: EAX=block number,
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK:
		;		  EAX=relative (to read BAM) bit number,
		;		  ESI=address of read BAM;
		;	  CF=1 - error, AX=error code.
proc RFS_ReadBAM
		mpush	ebx,ecx,edx
		mov	ebx,edx			; Keep FSLP
		mov	ecx,BITSPERBAM		; Divide by blocks per BAM
		xor	edx,edx
		div	ecx

		add	eax,BAMOFS		; Offset to first BAM
		xchg	edx,eax			; EDX=block, EAX=relative bit
		xchg	ebx,edx			; EBX=block, DL=FSLP
		call	CFS_LPtoDevID		; Get device ID
		jc	short .Exit
		push	eax
		call	BUF_ReadBlock		; Read the BAM
		jc	short .Err		; Exit if error
		pop	eax
		jmp	short .Exit
.Err:		pop	edx
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_MakeBAMs - make the initial BAM table.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_MakeBAMs
		push	edx
		call	CFS_LPtoDevID
		jc	short .Exit
		call	GetNumBlocks		; Get blocks per disk
		jc	short .Exit

		push	edx			; Keep device ID
		xor	edx,edx			; Zero high dword for division
		mov	ecx,BITSPERBAM		; Get number of BAMs required
		add	eax,ecx
		dec	eax
		div	ecx
		mov	[BAMs],eax		; Save it
		mov	ecx,eax			; Total count
		pop	edx			; Restore device ID

		mov	ebx,BAMOFS		; First BAM
		mpush	ebx,ecx			; Save BAM and count

.WriteBAMs:	push	ecx			; Save count
		call	BUF_Write		; Get a write buffer
		jc	short .Err		; Get out if flush failed
		call	BUF_MarkDirty		; Dirty the buffer
		mov	ecx,BLOCKSIZE/4		; Getting ready to fill buffer
		mov	edi,esi
		xor	eax,eax			; Fill it with -1
		dec	eax			;
		cld
		rep	stosd			; Fill it
		pop	ecx			; Restore count
		inc	ebx			; Next block
		dec	ecx
		jnz	.WriteBAMs		; Do it

		mpop	ecx,ebx			; Restore BAM and count
		call	BUF_ReadBlock		; Read initial BAM buffer
		btr	dword [esi],0		; Mark master block allocated

.CleanBAMs:	btr	dword [esi],ebx		; Mark one of the BAM blocks allocated
		inc	ebx			; Next bit
		dec	ecx
		jnz	.CleanBAMs		; Loop till done
		clc				; No errors
		jmp	short .Exit

.Err:		add	esp,byte 12
		stc
.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; RFS_MakeBBBs - make badblock bitmaps.
		; Input: AL=test type (0=none, 1=read-only, 2=read-write),
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: discards EBX, ECX, ESI and EDI.
proc RFS_MakeBBBs
int3
		mpush	edx,ebp
		mov	bp,ax			; Save test type
		call	CFS_LPtoDevID
		jc	.Done
		mov	ecx,[BAMs]		; Number of BBBs = [BAMs]
		lea	ebx,[ecx+BAMOFS]	; EBX=fist block of BBB
		xor	edi,edi			; EDI=global block counter

.WriteBBBs:	push	ecx
		call	BUF_Write		; Get a write buffer
		jc	.Err
		call	BUF_MarkDirty		; Mark it as dirty
		mov	ecx,BLOCKSIZE
		push	ebx
		mov	ebx,edi

.TestSectors:	mov	ax,bp			; Restore test type
		call	RFS_Test8Blocks		; Test 8 blocks
		jc	.Err1
		mov	[esi],al		; Keep result in BBB
		inc	esi			; Next 8 blocks to test
		add	ebx,byte 8
		loop	.TestSectors
		mov	edi,ebx			; Save block for next BBB

		mpop	ebx,ecx			; Restore BAM block
		loop	.WriteBBBs		; Next block
		clc
.Done:		mpop	ebp,edx
		ret

.Err1:		pop	ebx
.Err:		pop	ecx
		jmp	short .Done
endp		;---------------------------------------------------------------


		; RFS_MakeMasterBlock - make the master block.
		; Input: DL=file system linkpoint number.
		; Output: none.
proc RFS_MakeMasterBlock
                push	edx
		call	CFS_LPtoDevID
		jc	short .Err1
		xor	ebx,ebx			; Get a write buffer for MB
		call	BUF_Write
		pop	edx
		jc	short .Err		; Exit if flush failed
		call	BUF_MarkDirty		; Mark it dirty
		mov	edi,esi			; Getting ready to empty buffer
		push	edi
		mov	ecx,BLOCKSIZE/4		; Length of buffer
		xor	eax,eax			; Fill it with zeroes
		cld
		rep	stosd
		pop	edi
		push	edi
		mov	esi,RFS_ID			; Copy the FS ident
		lea	edi,[edi+tMasterBlock.ID]	; into the ident field
		mov	ecx,RFS_ID_size
		cld
		rep	movsb
		pop	edi

		; Put in a jump instruction for when we want to boot
		mov	word [edi+tMasterBlock.JmpAround],JMPinst+(BootJMP << 8)
		mov	eax,[BAMs]		; Get number of BAMs
		mov	[edi+tMasterBlock.NumBAMs],eax	; Put it in master block
		mov	dword [edi+tMasterBlock.Ver],0	; Blank the version field
		mov	eax,1			; Initialize the KBperBAM field to 1
		mov	[edi+tMasterBlock.KBperBAM],eax
		ret

.Err1:		pop	edx
.Err:		ret
endp		;---------------------------------------------------------------


		; RFS_AllocBlock - allocate a block.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK, EAX=allocated block number;
		;	  CF=1 - error, AX=error code.
proc RFS_AllocBlock
		mpush	ebx,ecx,edx,esi,edi
		call	RFS_LoadNumBAMs		; Load the number of BAMs
		jc	short .Exit		; Exit if couldn't
		xor	ebx,ebx			; Start at onest of BAMs

.Loop:		mov	eax,ebx			; Bit number in eax
		call	RFS_ReadBAM		; Read a BAM
		jc	short .Exit		; Exit if error
		call	RFS_ScanForBlock	; Scan for block
		jnc	.GotBlock		; If got a block mark the BAM dirty
		add	ebx,BITSPERBAM		; Next BAM
		dec	ecx
		jnz	.Loop

.GotBlock:	push	eax			; Now get total blocks on disk
		call	CFS_LPtoDevID
		call	GetNumBlocks		; EAX=total blocks
		pop	ecx
		jc	short .Exit
		xchg	eax,ecx			; Restore block number
		cmp	eax,ecx			; Limit check
		jae	short .Err		; Failed, mark error
		call	BUF_MarkDirty		; Mark the BAM as dirty
		clc
		jmp	short .Exit

.Err:		mov	ax,ERR_FS_DiskFull
		stc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_AllocDirBlock - allocate a directory block.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK:
		;		    EAX=allocated block number,
		;		    ESI=address of allocated block buffer;
		;	  CF=1 - error, AX=error code.
proc RFS_AllocDirBlock
		call	RFS_AllocBlock		; Allocate a block
		jc	short .Exit
		mpush	eax,edx,edi
		mov	ebx,eax			; Get the block number to EBX
		call	CFS_LPtoDevID		; Get device ID
		jc	short .Err
		call	BUF_Write		; Allocate a write buffer
		jc	short .Err		; Get out on error
		call	BUF_MarkDirty		; Mark the buffer dirty
		mov	edi,esi			; Get ready to fill it with -1
		mov	ecx,BLOCKSIZE / 4	; Length of buffer
		xor	eax,eax			; Fill value = -1
		dec	eax
		cld
		rep	stosd			; Fill the buffer
		xor	eax,eax
		push	esi
		mov	edi,esi
		mov	[esi+tDirPage.Flags],al		; Mark it as a leaf
		mov	[esi+tDirPage.Items],al		; No items in dir
		mov	word [esi+tDirPage.Type],FT_DIR	; Type=directory
		mov	[esi+tDirPage.PageLess],eax	; No less page
		mov	esi,RFS_DirID			; Get directory ident
		lea	edi,[edi+tDirPage.NM]		; Copy into dir block
		mov	ecx,RFS_DirID_size
		cld
		rep	movsb
		clc
		pop	esi
		mpop	edi,edx,eax
		ret

.Err:		mpop	edi,edx
		add	esp,4				; Keep error code
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_DeallocBlock - deallocate a block by setting
		;		      its BAM bit.
		; Input: EAX=block number,
		;	 DL=file system linkpoint number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_DeallocBlock
		push	esi
		call	RFS_ReadBAM		; Read the BAM table
		jc	short .Exit
		bts	[esi],eax		; Set the bit
		call	BUF_MarkDirty		; Mark the BAM buffer dirty
.Exit:		pop	esi
		ret
endp		;---------------------------------------------------------------


		; RFS_ScanForBlock - scan a BAM block for a set bit.
		; Input: ESI=begin of BAM block buffer
		; Output: CF=0 - OK, EAX=found block number;
		;	  CF=1 - error, AX=error code.
proc RFS_ScanForBlock
		push	ebx
		mov	ebx,esi			; Get start of buffer
		mov	ecx,BLOCKSIZE/4		; Number of dwords to scan

.BitSect:	bsf	eax,[esi]		; Scan a dword
		jnz	short .GotBit		; Got a bit, go calc block number
		add	esi,4			; Next dword
		dec	ecx
		jnz	.BitSect		; Continue
		mov	ax,ERR_FS_DiskFull	; Error: disk full
		stc
		jmp	short .Exit

.GotBit:	btr	[esi],eax		; Clear the block bit
		sub	esi,ebx			; Get total bytes scanned
		shl	esi,3			; Eight bits per byte
		add	eax,esi			; Add in the offset of the last word
		clc
.Exit:		mov	esi,ebx			; Restore block buffer
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_CreateRootDir - create root directory.
		; Input: DL=file system linkpoint number.
		; Output: CF=0 - OK, EBX=disk index of root;
		;	  CF=1 - error, AX=error code.
proc RFS_CreateRootDir
int3
		call	RFS_AllocDirBlock	; Allocate a directory block
		jc	short .Exit
		push	eax			; Save block number
		push	edx			; Keep FSLP
		call	CFS_LPtoDevID		; Get device ID
		jc	short .Err2
		xor	ebx,ebx			; Read master block
		call	BUF_ReadBlock
		jc	short .Err2		; Exit if error
		call	BUF_MarkDirty		; Master block is dirty
		pop	edx			; Restore FSLP
		pop	ebx			; Get allocated block

		mov	[esi+tMasterBlock.RootDir],ebx	; Put it
		push	edx				; in the master block
		call	CFS_SetRootIndex		; and LP table
		call	CFS_LPtoDevID			; Get device ID
		call	BUF_ReadBlock			; Read the block data
		jc	short .Err2
		call	BUF_MarkDirty				; Mark it dirty
		bts	dword [esi+tDirPage.Flags],DFL_LEAF
		mov	word [esi+tDirPage.Type],FT_DIR		; Mark as dir
		pop	edx
		clc
.Exit:		ret

.Err2:		pop	edx
.Err:		add	esp,byte 4			; Keep error code
		stc
		ret
endp		;---------------------------------------------------------------


		; RFS_Test8Blocks - test 8 blocks on device.
		; Input: AL=test type (0=none, 1=read/only, 2=read-write).
		;	 EBX=block number,
		;	 EDX=device ID.
		; Output: CF=0 - OK, AL=test results (bitmap);
		;	  CF=1 - error, AX=error code.
proc RFS_Test8Blocks
		ret
endp		;---------------------------------------------------------------
