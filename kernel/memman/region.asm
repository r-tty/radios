;-------------------------------------------------------------------------------
;  region.asm - process memory region manipulation routines.
;-------------------------------------------------------------------------------

macro mLockRegion
	or	[ebx+tMCB.Flags],MCBFL_LOCKED
endm

macro mUnlockRegion
	and	[ebx+tMCB.Flags],not MCBFL_LOCKED
endm


; --- Procedures ---
segment KCODE

		; MM_AllocRegion - allocate a region.
		; Input: EAX=PID,
		;	 ECX=region size,
		;	 DL=region type.
		; Output: CF=0 - OK:
		;		    EBX=region address,
		;		    EAX=MCB address.
		;	  CF=1 - error, AX=error code.
proc MM_AllocRegion near
		push	edx
		mov	dh,PG_USERMODE
		cmp	dl,REGTYPE_CODE
		je	short @@DoAlloc
		cmp	dl,REGTYPE_DATA
		je	short @@DoAlloc
		or	dh,PG_WRITEABLE
@@DoAlloc:	push	edx
		mov	dl,1
		call	MM_AllocBlock
		pop	edx
		jc	short @@Exit
		mov	[eax+tMCB.Type],dl

@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------

		; MM_FreeRegion - free a region.
		; Input: EAX=PID,
		;	 EDI=MCB address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_FreeRegion near
		ret
endp		;---------------------------------------------------------------


		; MM_AttachRegion - attach region to process address space.
		; Input: EBX=region address,
		;	 EDX=process descriptor which the region will be
		;	     attached to,
		;	 ESI=address in target process to attach.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_AttachRegion near
		ret
endp		;---------------------------------------------------------------


		; MM_DetachRegion - detach region from process address space.
proc MM_DetachRegion near
		ret
endp		;---------------------------------------------------------------


		; MM_CopyRegion - copy region.
proc MM_CopyRegion near
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
proc MM_LoadRegion near
		ret
endp		;---------------------------------------------------------------

ends
