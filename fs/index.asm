;-------------------------------------------------------------------------------
;  index.asm - disk index routines.
;-------------------------------------------------------------------------------

; --- Definitions ---

HASH_NUMBER	EQU	131

HASHENTRYSHIFT	EQU	3

struc tIndexHashEntry
 IndexPtr	DD	?
 Updating	DD	?
ends

macro mHashFunction
	and	edx,0FFh
	xor	edx,ebx
	mov	eax,edx
	xor	edx,edx
	div	[NumHash]
	mov	eax,edx
endm

macro mWaitOnIndex
	test	[esi+tCFS_Index.Flags],IFL_LOCKED
	jz	short @@__1
	call	IND_Wait
@@__1:
endm

macro mLockIndex
	mWaitOnIndex
	or	[esi+tCFS_Index.Flags],IFL_LOCKED
endm

macro mUnlockIndex
	and	[esi+tCFS_Index.Flags],not IFL_LOCKED
	;mov	ebx,[esi+tCFS_Index.WaitQPtr]
	;call	K_ResumeThread
endm


; --- Variables ---
segment KVARS
HashTblAddr	DD	?
FirstIndexPtr	DD	0
NumFreeIndexes	DD	0
NumHash		DD	?
ends


; --- Procedures ---

segment KCODE

		; IND_Grow - allocate memory for indexes and initialize the
		;	     index list.
		; Input: ECX=number of indexes to allocate.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IND_Grow near
		push	ebx ecx edx esi
		mov	eax,INDEXSIZE
                mul	ecx
		mov	edx,ecx
                mov	ecx,eax
		call	EDRV_AllocData			; Allocate memory
		jc	short @@Exit
		mov	[CFS_IndTblAddr],ebx
		call	KH_FillZero			; Clear indexes table

		mov	ecx,edx
		mov	[CFS_NumIndexes],ecx
		mov	[NumFreeIndexes],ecx

		cmp	[FirstIndexPtr],0
		jne	short @@InitList
		mov	esi,ebx
		add	ebx,INDEXSIZE
		mov	[FirstIndexPtr],ebx
		mov	[esi+tCFS_Index.Next],ebx
		mov	[esi+tCFS_Index.Prev],ebx
		mov	esi,ebx
		dec	ecx
		or	ecx,ecx
                jz	short @@OK

@@InitList:	call	IND_InsertFree
		add	esi,INDEXSIZE
		loop	@@InitList

@@OK:		xor	eax,eax
@@Exit:		pop	esi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; IND_InitHashTable - intialize index hash table.
		; Input: ECX=number of entries in table.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IND_InitHashTable near
		push	ebx ecx edx
		mov	[NumHash],ecx
		mov	eax,size tIndexHashEntry
		mul	ecx
		mov	ecx,eax
		call	KH_Alloc
		jc	short @@Exit
		mov	[HashTblAddr],ebx
		call	KH_FillZero
		xor	eax,eax
@@Exit:		pop	edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_GetIndex - get index.
		; Input: EBX=block number,
		;	 DL=FSLP.
		; Output: CF=0 - OK, ESI=pointer to index;
		;	  CF=1 - error, AX=error code.
proc CFS_GetIndex near
		push	ebx edx
		call	IND_Hash
		mov	edi,eax
		xor	ecx,ecx

@@Repeat:	mov	esi,[edi+tIndexHashEntry.IndexPtr]
@@HashSrch:	or	esi,esi
		jz	short @@ChkEmpty
		cmp	dl,[esi+tCFS_Index.FSLP]
		jne	short @@NextInd
		cmp	ebx,[esi+tCFS_Index.Block]
		je	short @@Found
@@NextInd:	mov	esi,[esi+tCFS_Index.HashNext]
		jmp	@@HashSrch

@@ChkEmpty:	or	ecx,ecx
		jnz	short @@FillIndex
		inc	[edi+tIndexHashEntry.Updating]
		push	esi
		call	IND_GetEmpty
		mov	ecx,esi
		pop	esi
		jc	short @@Exit
		dec	[edi+tIndexHashEntry.Updating]
		cmp	[edi+tIndexHashEntry.Updating],0
		jne	short @@NoWakeup
		;call	K_ResumeThread
@@NoWakeup:	or	ecx,ecx
		jnz	@@Repeat
		xor	esi,esi
		stc
		jmp	short @@Exit

@@FillIndex:	mov	esi,ecx
		mov	[esi+tCFS_Index.FSLP],dl
		mov	[esi+tCFS_Index.Block],ebx
		call	IND_PutLastFree
		call	IND_InsertHash
		call	CFS_ReadIndex
		jmp	short @@Return

@@Found:	cmp	[esi+tCFS_Index.RefNum],0
		jne	short @@IncCount
		dec	[NumFreeIndexes]
@@IncCount:

@@Return:	clc
@@Exit:		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_UngetIndex - unget index.
		; Input: ESI=pointer to index.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_UngetIndex near
		ret
endp		;---------------------------------------------------------------


		; CFS_ReadIndex - read index.
		; Input: ESI=pointer to index.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ReadIndex near
		push	ebx edx
		mLockIndex
		mov	dl,[esi+tCFS_Index.FSLP]
		call	CFS_LPtoFSdrvID
		jnc	short @@DoRead
		push	eax
		mUnlockIndex
		pop	eax
		stc
		jmp	short @@Exit

@@DoRead:	mCallDriverCtrl ebx,MOP_ReadIndex
		mUnlockIndex
@@Exit:		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; CFS_WriteIndex - write index.
		; Input: ESI=pointer to index.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_WriteIndex near
		test	[esi+tCFS_Index.Flags],IFL_DIRTY
		jz	short @@Ret
		mWaitOnIndex
		test	[esi+tCFS_Index.Flags],IFL_DIRTY
		jz	short @@Ret

                or	[esi+tCFS_Index.Flags],IFL_LOCKED
		push	ebx edx
		mov	dl,[esi+tCFS_Index.FSLP]
		call	CFS_LPtoFSdrvID
		jnc	short @@DoRead
		push	eax					; Keep error code
		mUnlockIndex
		pop	eax
		stc
		jmp	short @@Exit

@@DoRead:	mCallDriverCtrl ebx,MOP_ReadIndex
		mUnlockIndex
@@Exit:		pop	edx ebx
@@Ret:		ret
endp		;---------------------------------------------------------------



; --- Implementation routines ---

		; IND_Hash - get address of hash entry.
		; Input: DL=FSLP,
		;	 EBX=block number.
		; Output: EAX=address.
proc IND_Hash near
		mHashFunction
		shl	eax,HASHENTRYSHIFT
		add	eax,[HashTblAddr]
		ret
endp		;---------------------------------------------------------------


		; IND_InsertFree - insert index in list of free indexes.
		; Input: ESI=pointer to index.
		; Output: none.
		; Note: destroys EAX.
proc IND_InsertFree near
		mov	eax,[FirstIndexPtr]
		mov	[esi+tCFS_Index.Next],eax
		mov	eax,[eax+tCFS_Index.Prev]
		mov	[esi+tCFS_Index.Prev],eax
		mov	eax,[esi+tCFS_Index.Next]
		mov	[eax+tCFS_Index.Prev],esi
		mov	eax,[esi+tCFS_Index.Prev]
		mov	[eax+tCFS_Index.Next],esi
		mov	[FirstIndexPtr],esi
		ret
endp		;---------------------------------------------------------------


		; IND_RemoveFree - remove index from list of free indexes.
		; Input: ESI=pointer to index.
		; Output: none.
		; Note: destroys EAX.
proc IND_RemoveFree near
		push	ebx
		cmp	esi,[FirstIndexPtr]
		jne	short @@1
		mov	eax,[FirstIndexPtr]
		mov	eax,[eax+tCFS_Index.Next]
		mov	[FirstIndexPtr],eax
@@1:		mov	eax,[esi+tCFS_Index.Next]
		mov	ebx,[esi+tCFS_Index.Prev]
		or	eax,eax
		jz	short @@2
		mov	[eax+tCFS_Index.Prev],ebx
@@2:		or	ebx,ebx
		jz	short @@3
		mov	[ebx+tCFS_Index.Next],eax
@@3:		xor	eax,eax
		mov	[esi+tCFS_Index.Next],eax
		mov	[esi+tCFS_Index.Prev],eax
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; IND_InsertHash - insert index in hash chain.
		; Input: ESI=pointer to index.
		; Output: none.
		; Note: destroys EAX.
proc IND_InsertHash near
		push	ebx ecx edx
		mov	dl,[esi+tCFS_Index.FSLP]
		mov	ebx,[esi+tCFS_Index.Block]
		call	IND_Hash
		mov	ebx,[eax+tIndexHashEntry.IndexPtr]
		mov	[esi+tCFS_Index.HashNext],ebx
		mov	[esi+tCFS_Index.HashPrev],0
		or	ebx,ebx
		jz	short @@1
		mov	[ebx+tCFS_Index.HashPrev],esi
@@1:		mov	[eax+tIndexHashEntry.IndexPtr],esi
		pop	edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; IND_RemoveHash - remove index from hash chain.
		; Input: ESI=pointer to index.
		; Output: none.
proc IND_RemoveHash near
		push	ebx ecx edx
		mov	dl,[esi+tCFS_Index.FSLP]
		mov	ebx,[esi+tCFS_Index.Block]
		call	IND_Hash
		mov	ebx,[esi+tCFS_Index.HashNext]
		mov	edx,[esi+tCFS_Index.HashPrev]
		cmp	[eax+tIndexHashEntry.IndexPtr],esi
		jne	short @@1
		mov	[eax+tIndexHashEntry.IndexPtr],ebx
@@1:		or	ebx,ebx
		jz	short @@2
		mov	[ebx+tCFS_Index.HashPrev],edx
@@2:		or	edx,edx
		jz	short @@3
		mov	[edx+tCFS_Index.HashNext],ebx
@@3:		xor	eax,eax
		mov	[esi+tCFS_Index.HashNext],eax
		mov	[esi+tCFS_Index.HashPrev],eax
		pop	edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; IND_PutLastFree - put index last in free list.
		; Input: ESI=pointer to index.
		; Output: none.
		; Note: destroys EAX.
proc IND_PutLastFree near
		call	IND_RemoveFree
		mov	eax,[FirstIndexPtr]
		push	eax
		mov	eax,[eax+tCFS_Index.Prev]
		mov	[esi+tCFS_Index.Prev],eax
		mov	[eax+tCFS_Index.Next],esi
		pop	eax
		mov	[esi+tCFS_Index.Next],eax
		mov	[eax+tCFS_Index.Prev],esi
		ret
endp		;---------------------------------------------------------------


		; IND_GetEmpty - get empty index.
		; Input: none.
		; Output: CF=0 - OK, ESI=pointer to index;
		;	  CF=1 - error, AX=error code.
proc IND_GetEmpty near

		ret
endp		;---------------------------------------------------------------


		; IND_Wait - wait until index will be unlocked.
		; Input: ESI=pointer to index.
		; Output: none.
proc IND_Wait near
		ret
endp		;---------------------------------------------------------------


ends
