;-------------------------------------------------------------------------------
; region.nasm - routines for manipulating memory regions.
;-------------------------------------------------------------------------------

publicproc MM_AllocRegion, MM_FreeRegion

%macro mLockRegion 0
	or	word [ebx+tMCB.Flags],MCBFL_LOCKED
%endmacro

%macro mUnlockRegion 0
	and	word [ebx+tMCB.Flags],~MCBFL_LOCKED
%endmacro


; --- Procedures ---

section .text

		; MM_AllocRegion - allocate a region.
		; Input: ESI=PCB address,
		;	 ECX=region size,
		;	 DL=area location (user/shlib/driver),
		;	 DH=region type.
		; Output: CF=0 - OK:
		;		    EBX=region address,
		;		    EAX=MCB address.
		;	  CF=1 - error, AX=error code.
proc MM_AllocRegion
		push	edx
		mov	ah,PG_USERMODE
		cmp	dh,REGTYPE_CODE
		je	short .DoAlloc
		cmp	dh,REGTYPE_DATA
		je	short .DoAlloc
		or	ah,PG_WRITABLE
.DoAlloc:	push	edx
		mov	dh,ah
		call	MM_AllocBlock
		pop	edx
		jc	short .Exit
		mov	[eax+tMCB.Type],dh

.Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; MM_FreeRegion - free a region.
		; Input: ESI=PCB address,
		;	 EDI=MCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreeRegion
		ret
endp		;---------------------------------------------------------------


		; MM_AttachRegion - attach region to process address space.
		; Input: EBX=region address,
		;	 EDX=process descriptor which the region will be
		;	     attached to,
		;	 ESI=address in target process to attach.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_AttachRegion
		ret
endp		;---------------------------------------------------------------


		; MM_DetachRegion - detach region from process address space.
proc MM_DetachRegion
		ret
endp		;---------------------------------------------------------------


		; MM_CopyRegion - copy region.
proc MM_CopyRegion
		ret
endp		;---------------------------------------------------------------


		; MM_LoadRegion - load data from file in region.
		; Input: EAX=PID,
		;	 EBX=file index,
		;	 ECX=length of data,
		;	 EDX=offset in file to data,
		;	 ESI=address of region.
		; Output: CF=0 - OK;
		;	  CF1= - error, AX=error code.
proc MM_LoadRegion
		ret
endp		;---------------------------------------------------------------
