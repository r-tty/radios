;*******************************************************************************
;  diskbuf.asm - disk buffers management.
;  Written by Yuri Zaporogets from David Lindauer's OS-32.
;  (c) 1995 David Lindauer.
;  (c) 1999 Yuri Zaporogets.
;
;  Version list:
;   28 Apr 1999  -  initial version (1.0)
;   23 Sep 1999  -  NASM version (1.1)
;*******************************************************************************

; --- Exports ---
global BUF_InitMem, BUF_Release
global BUF_ReadBlock, BUF_Write, BUF_MarkDirty, BUF_FlushAll
global BUF_StampAsLatest, GetNumBlocks


; --- Imports ---

library kernel.driver
extern AllocPhysMem:near, DRV_CallDriver:near, DRV_GetFlags:near


; --- Definitions ---

%define	SectorsInBlock	2
%define	SecInBlockShift	1

struc tBuffer
.Flags		RESB	1
.Reserved	RESB	3
.Device		RESD	1
.Stamp		RESW	1
.UU		RESW	1
.Block		RESD	1
.Data		RESB	SectorsInBlock*SECTORSIZE
endstruc

%define	RETRIES		3

%define	BF_DIRTY	7				; Flags
%define	BF_EMPTY	6


; --- Variables ---

section .bss

BufferStart	RESD	1
NumBuffers	RESD	1
Stamp		RESW	1


; --- Procedures ---

section .text

		; BUF_InitMem - initialize buffer memory structures.
		; Input: ECX=amount of memory for buffers (in KB).
		; Output: CF=0 - OK, ECX=number of allocated buffers.
		;	  CF=1 - error.
proc BUF_InitMem
		mpush	ebx,ecx,edx
		shl	ecx,10
		call	AllocPhysMem
		jc	short .Exit
		mov	[BufferStart],ebx

		mov	eax,ecx
		xor	edx,edx
		mov	ecx,tBuffer_size
		div	ecx
                mov	[NumBuffers],eax

		mov	edx,BUF_MarkEmpty
		call	BUF_RunThrough
		mov	ecx,[NumBuffers]
		clc
		jmp	short .Exit

.Err:		stc
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; BUF_MarkEmpty - mark buffer as clean.
		; Input: EDI=buffer address.
		; Output: none.
proc BUF_MarkEmpty
		mov	byte [edi+tBuffer.Flags],0		; Mark it empty
		bts	dword [edi+tBuffer.Flags],BF_EMPTY	; and clean
		ret
endp		;---------------------------------------------------------------


		; BUF_RunThrough - run through all buffers applying a function.
		; Input: EDX=function address
		; Output: CF=0 - OK;
		;	  CF=1 - target function error.
proc BUF_RunThrough
		mov	edi,[BufferStart]		; First buffer
		mov	ecx,[NumBuffers]		; Number of buffers
.Loop:		push	edx				; Save function
		call	edx				; Call function
		pop	edx
		jc	short .Exit			; Exit if function carry
		add	edi,tBuffer_size		; Next buffer
		dec	ecx
		jnz	.Loop				; Do next
		clc					; Finished all buffers
.Exit:		ret
endp		;---------------------------------------------------------------


		; BUF_Flush - flush a buffer.
		; Input: EDI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc BUF_Flush
		bt	dword [edi+tBuffer.Flags],BF_DIRTY	; See if dirty
		jnc	short .Exit				; Quit if clean
		mov	ebx,[edi+tBuffer.Block]		; Get block number
		mov	edx,[edi+tBuffer.Device]	; and device ID
		lea	esi,[edi+tBuffer.Data]		; Get data address
		call	BUF_WriteToMedia		; Write the buffer out
		jc	short .Exit
		btr	dword [edi+tBuffer.Flags],BF_DIRTY	; Clean buffer
		clc						; No error
.Exit:		ret
endp		;---------------------------------------------------------------


		; BUF_FlushAll - flush all buffers.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc BUF_FlushAll
		mpush	ebx,ecx,edx,esi
		mov	edx,offset BUF_Flush		; Flush routine
		call	BUF_RunThrough			; Do RunThrough
		mpop	esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; BUF_Invalidate - invalidate a buffer for a given device.
		; Input: EAX=device ID,
		;	 EDI=buffer address.
		; Output: none.
proc BUF_Invalidate
		cmp	[edi+tBuffer.Device],eax	; See if for this device
		jne	short .OK			; Quit if not
		btr	dword [edi+tBuffer.Flags],BF_DIRTY	; Else clean it
		bts	dword [edi+tBuffer.Flags],BF_EMPTY	; Empty it
.OK:		clc					; No error
		ret
endp		;---------------------------------------------------------------


		; BUF_InvalidateAll - invalidate all buffers for a
		;		      given device.
		; Input: EDX=device ID,
		;	 CF and EAX - result of last media R/W operation.
proc BUF_InvalidateAll
		jnc	short .NoErr			; Get out if not error
		push	eax				; Save error code
		pushfd					; Save err flag
		cmp	ax,ERR_DISK_MediaChgd		; See if media changed
		je	short .Do			; Yes, go invalidate
	       	cmp	ax,ERR_DISK_NoMedia		; See if media missing
		jne	short .Exit			; No, no invalidate

.Do:		mpush	ecx,edx,edi
		mov	eax,edx				; EAX = device
		mov	edx,BUF_Invalidate		; Invalidate function
		call	BUF_RunThrough			; Run through buffers
		mpop	edi,edx,ecx

.Exit:		popfd					; Restore err flag
		pop	eax				; And error code
.NoErr:		ret
endp		;---------------------------------------------------------------


		; BUF_Restamp - set a buffer stamp back to halfway mark.
		;		Buffer stamps start at 0, progress to 65535,
		;		then start back at 32767.
		; Input: EDI=buffer address.
		; Output: none.
proc BUF_Restamp
		btr	word [edi+tBuffer.Stamp],15	; Set us back
		clc					; No errors
		ret
endp		;---------------------------------------------------------------


		; BUF_RestampAll - restamp all buffers.
		; Input: none.
		; Output: none.
proc BUF_RestampAll
		mov	edx,offset BUF_Restamp		; Restamp function
		call	BUF_RunThrough			; Run through all buffers
		ret
endp		;---------------------------------------------------------------


		; BUF_Stamp - stamp a buffer with current time stamp.
		; Input: EDI=buffer address.
		; Output: none.
proc BUF_Stamp
		mov	ax,[Stamp]			; Get stamp
		mov	[edi+tBuffer.Stamp],ax		; Load buffer with stamp
		inc	word [Stamp]			; Next stamp
		jnz	short .Exit			; Get out if no overflow
		mpush	edx,edi
		call	BUF_RestampAll			; Restamp all buffers
		mpop	edi,edx
.Exit:		ret
endp		;---------------------------------------------------------------


		; BUF_IsFree - see if a buffer is free or lowest stamp.
		; Input: EBX=stamp,
		;	 EDI=buffer address.
		; Output: CF=1 - free, ESI=found buffer address;
		;	  CF=0 - not free.
proc BUF_IsFree
		bt	dword [edi+tBuffer.Flags],BF_EMPTY	; See if empty
		jc	short .GotFree			; Automatically free if empty
		movzx	eax,word [edi+tBuffer.Stamp]	; Else get stamp
		cmp	eax,ebx				; See if is lowest stamp yet
		jnc	short .Exit		 	; No, get out
		mov	ebx,eax				; Yes, make it lowest
		cmc
.GotFree:	mov	esi,edi				; ESI=found buffer
.Exit:		ret
endp		;---------------------------------------------------------------


		; BUF_FindFree - find a free buffer.
		; Input: none.
		; Output: CF=0 - OK, EDI=buffer address.
		;	  CF=1 - error.
proc BUF_FindFree
		mov	edx,offset BUF_IsFree		; Free function
		xor	ebx,ebx				; EBX = way high
		dec	ebx
		call	BUF_RunThrough			; Get us a buffer
		mov	edi,esi				; in EDI
%ifdef DEBUG
		mpush	eax,edx				; Debugging, print buffer
		mov	eax,esi
		call	PrintDwordHex
		mPrintChar ' '
		mpop	edx,eax
%endif
		call	BUF_Flush			; Make sure it is flushed
		jc	short .Exit			; Exit if error
		btr	dword [edi+tBuffer.Flags],BF_EMPTY	; Not empty
		call	BUF_Stamp				; Stamped
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; BUF_Match - see if this buffer matches the requested block.
		; Input: EAX=device ID,
		;	 EBX=block number,
		;	 EDI=buffer address.
		; Output: CF=1 - matched;
		;	  CF=0 - not matched.
proc BUF_Match
%ifdef DEBUG
		mpush	eax,edx				; Debugging, print a star
		mPrintChar '*'
		mpop	edx,eax
%endif
		bt	dword [edi+tBuffer.Flags],BF_EMPTY	; See if empty
		jc	short .NoMatch			; Can't match empty buffer
		cmp	eax,[edi+tBuffer.Device]	; See if device matches
		jne	short .NoMatch			; No, exit
		cmp	ebx,[edi+tBuffer.Block]		; See if block matches
		jne	short .NoMatch			; No, exit
%ifdef DEBUG
		mpush	eax,edx      			; Debugging, just put output
		call	PrintByteHex
		mPrintChar ' '
		mpop	edx,eax
%endif
		stc					; Mark we found a match
		ret

.NoMatch:	clc					; No match
		ret
endp		;---------------------------------------------------------------


		; BUF_FindMatch - see if any buffers match the requested block.
		; Input: EBX=block number,
		;	 EDX=device ID.
		; Output: same as BUF_Match.
proc BUF_FindMatch
		mov	eax,edx				; EAX=device ID
		mov	edx,offset BUF_Match		; Match function
		call	BUF_RunThrough			; Run through all buffers
		ret
endp		;---------------------------------------------------------------


		; BUF_MarkDirty - mark a buffer as dirty.
		; Input: ESI=pointer to "Data" field of tBuffer structure.
		; Output: none.
proc BUF_MarkDirty
		push	esi				; Save esi
		sub	esi,tBuffer.Data		; Point to control info
		bts	dword [esi+tBuffer.Flags],BF_DIRTY ; Mark buffer dirty
		clc					; In case multiple marks
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; BUF_Write - get a write buffer.
		; Input: EBX=block number,
		;	 EDX=device ID.
		; Output: CF=0 - OK, ESI=buffer address;
		;	  CF=1 - error, AX=error code.
proc BUF_Write
		push	edi
		mpush	ebx,ecx,edx			; Save regs
		call	BUF_FindMatch			; See if already there
		jnc	short .GetFree			; Not there, get free buffer
		call	BUF_Flush			; Flush it
		jmp	short .GotBuf

.GetFree:	call	BUF_FindFree			; Get a free buffer
.GotBuf:	mpop	edx,ecx,ebx
		jc	short .Exit			; Get out if flush failed
		btr	dword [edi+tBuffer.Flags],BF_DIRTY	; Never dirty
		mov	[edi+tBuffer.Block],ebx		; Save block number
		mov	[edi+tBuffer.Device],edx	; Save device ID
		lea	esi,[edi+tBuffer.Data]		; Get buffer address
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; BUF_ReadBlock - get a block off disk and return buffer.
		; Input: EBX=block number,
		;	 EDX=device ID.
		; Output: CF=0 - OK, ESI=buffer address;
		;	  CF=1 - error, AX=error code.
proc BUF_ReadBlock
		mpush	edi,edx,ecx,ebx
		call	BUF_FindMatch			; See if block in buffer
		jc	short .Found			; Yes, go restamp it
		call	BUF_FindFree			; Else get a free buffer
		mpop	ebx,ecx,edx
		jc	short .Exit
		mov	[edi+tBuffer.Block],ebx		; Save block
		mov	[edi+tBuffer.Device],edx	; and device ID
		lea	esi,[edi+tBuffer.Data]		; Get buffer
		pop	edi
		call	BUF_ReadFromMedia		; Read a block into it
		ret

.Found:		mpop	ebx,ecx,edx			; Restore regs
		call	BUF_Stamp			; Restamp the buffer
		lea	esi,[edi+tBuffer.Data]		; Return buffer address
		clc
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; BUF_StampAsLatest - stamp buffer as latest.
		; Input: EDI=pointer to "Data" field of tBuffer structure.
proc BUF_StampAsLatest
		push	edi
		sub	edi,tBuffer.Data
		call	BUF_Stamp
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; BUF_ReadFromMedia - read block from media.
		; Input: EDX=device ID,
		;	 EBX=block number,
		;	 ESI=address of memory block.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc BUF_ReadFromMedia
		mpush	ebx,ecx,edi
		shl	ebx,SecInBlockShift		; EBX=sector number
		xor	ecx,ecx
		mov	cl,SectorsInBlock
		mov	edi,RETRIES			; Counter of errors

.Loop:		push	edx				; Push device ID
		push	dword DRVF_Read			; and function code
		call	DRV_CallDriver
		jnc	short .Exit			; Error?
		cmp	ax,ERR_DISK_MediaChgd		; Media changed?
		jne	short .Err			; No, another error
		call	BUF_InvalidateAll		; Else invalidate buffers
		dec	edi
		jnz	.Loop
		jmp	short .Exit

.Err:		stc
.Exit:		mpop	edi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; BUF_WriteToMedia - write block to media.
		; Input: EDX=device ID,
		;	 EBX=block number,
		;	 ESI=address of memory block.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc BUF_WriteToMedia
		mpush	ebx,ecx,edi
		shl	ebx,SecInBlockShift		; EBX=sector number
		xor	ecx,ecx
		mov	cl,SectorsInBlock
		mov	edi,RETRIES			; Counter of errors

.Loop:		push	edx				; Push device ID
		push	dword DRVF_Write		; and function code
		call	DRV_CallDriver
		jnc	short .Exit			; Error?
		cmp	ax,ERR_DISK_MediaChgd		; Media changed?
		jne	short .Err			; No, another error
		call	BUF_InvalidateAll		; Else invalidate buffers
		dec	edi
		jnz	.Loop
		jmp	short .Exit

.Err:		stc
.Exit:		mpop	edi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; GetNumBlocks - get total number of blocks on device.
		; Input: EDX=device ID
		; Output: CF=0 - OK, EAX=number of blocks;
		;	  CF=1 - error, AX=error code.
proc GetNumBlocks
		push	ecx
		push	edx
		push	dword 10000h*DRVCTL_GetParams+DRVF_Control
		call	DRV_CallDriver			; Get number of sectors
		jc	short .Exit
		mov	eax,ecx
		shr	eax,SecInBlockShift
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------

