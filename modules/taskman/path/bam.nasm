;-------------------------------------------------------------------------------
; bam.nasm - routines for handling Block Allocation Maps (BAMs).
; Based on David Lindauer's OS-32 kernel.
;-------------------------------------------------------------------------------

module tm.pathman.bam

%include "errors.ah"
%include "tm/rfs.ah"
%include "rm/stat.ah"

publicproc RFS_MakeBAMs
publicproc RFS_AllocBlock, RFS_AllocDirBlock, RFS_DeallocBlock


; --- Procedures ---

section .text

		; RFS_MakeBAMs - make the initial BAM table.
		; Input: EDX=file system address,
		;	 ECX=number of block in the RAM-disk.
		; Output: CF=0 - OK, EAX=number of BAMs;
		;	  CF=1 - error, AX=error code.
proc RFS_MakeBAMs
		mpush	ebx,ecx,esi,edi
		mov	eax,ecx
		mov	ecx,RFS_BITSPERBAM	; Get number of BAMs required
		add	eax,ecx
		dec	eax
		push	edx
		xor	edx,edx
		div	ecx
		pop	edx
		mov	ecx,eax			; Total count

		mov	ebx,RFS_BAMOFS		; First BAM
		push	ecx			; Save count and BAM
		push	ebx

.WriteBAMs:	push	ecx			; Save count
		mBseek				; Get a block address
		mov	ecx,RFS_BLOCKSIZE / 4	; Getting ready to fill buffer
		mov	edi,esi
		xor	eax,eax			; Fill it with -1
		dec	eax
		cld
		rep	stosd
		pop	ecx			; Restore count
		inc	ebx			; Next block
		loop	.WriteBAMs

		pop	ebx			; Restore BAM
		mov	ecx,[esp]		; Get count
		mBseek
		btr	dword [esi],0		; Mark master block allocated

.CleanBAMs:	btr	dword [esi],ebx		; Mark one of the BAM blocks allocated
		inc	ebx			; Next bit
		loop	.CleanBAMs
		pop	eax			; Restore count

		clc
		mpop	edi,esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_AllocBlock - allocate a block.
		; Input: EDX=file system address.
		; Output: CF=0 - OK, EAX=allocated block number;
		;	  CF=1 - error, AX=error code.
proc RFS_AllocBlock
		mpush	ebx,ecx,edx,esi,edi
		mov	ecx,[edx+tMasterBlock.NumBAMs]
		xor	ebx,ebx

.Loop:		mov	eax,ebx			; Bit number in eax
		call	RFS_GetBAM		; Read a BAM
		jc	.Exit			; Exit if error
		call	RFS_ScanForBlock	; Scan for block
		jnc	.GotBlock		; If got a block mark the BAM dirty
		add	ebx,RFS_BITSPERBAM	; Next BAM
		dec	ecx
		jnz	.Loop

.GotBlock:	cmp	eax,[edx+tMasterBlock.TotalBlocks]	; Limit check
		jae	.Err
		clc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret

.Err:		mov	ax,ENOSPC
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RFS_AllocDirBlock - allocate a directory block.
		; Input: EDX=file system address,
		;	 ESI=pointer to directory name.
		; Output: CF=0 - OK:
		;		    EAX=allocated block number,
		;		    ESI=address of allocated block buffer;
		;	  CF=1 - error, AX=error code.
proc RFS_AllocDirBlock
		call	RFS_AllocBlock		; Allocate a block
		jc	.Exit

		mpush	eax,edx,edi
		mov	ebx,eax
		push	esi
		mBseek
		mov	edi,esi			; Fill it in with -1
		mov	ecx,RFS_BLOCKSIZE / 4
		xor	eax,eax
		dec	eax
		cld
		push	edi
		rep	stosd
		mpop	edi,esi

		xor	eax,eax
		mov	[edi+tDirNode.Flags],al		; Mark it as a leaf
		mov	[edi+tDirNode.Items],al		; No items in dir
		mov	word [edi+tDirNode.Type],ST_MODE_IFDIR
		mov	[edi+tDirNode.PageLess],eax	; No less page
		push	edi				; Save block address
		lea	edi,[edi+tDirNode.Name]		; Copy directory name
		mov	ecx,RFS_FILENAMELEN
		cld
		rep	movsb
		pop	esi				; Restore block address

		clc
		mpop	edi,edx,eax
.Exit:		ret
endp		;---------------------------------------------------------------


		; RFS_DeallocBlock - deallocate a block by setting
		;		      its BAM bit.
		; Input: EAX=block number,
		;	 EDX=file system address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RFS_DeallocBlock
		push	esi
		call	RFS_GetBAM		; Read the BAM table
		jc	.Exit
		bts	[esi],eax		; Set the bit
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
		mov	ecx,RFS_BLOCKSIZE / 4	; Number of dwords to scan

.BitSect:	bsf	eax,[esi]		; Scan a dword
		jnz	.GotBit			; Got a bit, go calc block number
		add	esi,4			; Next dword
		dec	ecx
		jnz	.BitSect		; Continue
		mov	ax,ENOSPC		; Error: disk full
		stc
		jmp	.Exit

.GotBit:	btr	[esi],eax		; Clear the block bit
		sub	esi,ebx			; Get total bytes scanned
		shl	esi,3			; Eight bits per byte
		add	eax,esi			; Add in the offset of the last word
		clc
.Exit:		mov	esi,ebx			; Restore block buffer
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; RFS_GetBAM - for given block get a corresponding BAM address
		;	       and relative bit number inside number.
		; Input: EAX=block number,
		;	 EDX=file system address.
		; Output: CF=0 - OK:
		;		  EAX=relative (to BAM read) bit number,
		;		  ESI=address of BAM read;
		;	  CF=1 - error, AX=error code.
proc RFS_GetBAM
		mpush	ebx,ecx
		mov	ebx,edx
		mov	ecx,RFS_BITSPERBAM	; Divide by blocks per BAM
		xor	edx,edx
		div	ecx

		add	eax,RFS_BAMOFS		; Offset to first BAM
		xchg	edx,eax			; EDX=block, EAX=relative bit
		xchg	ebx,edx			; EBX=block, EDX=FS address
		mBseek
		clc
		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------
