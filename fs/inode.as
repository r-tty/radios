;*******************************************************************************
;  inode.as - inode routines.
;  Copyright (c) 1999-2001 RET & COM Research.
;  This file is based on the Linux Kernel (c) 1991-2001 Linus Torvalds.
;*******************************************************************************

module cfs.inode

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "sema.ah"
%include "pool.ah"
%include "wait.ah"
%include "x86/setjmp.ah"
%include "thread.ah"

%include "fs/cfs.ah"
%include "fs/inode.ah"

; --- Exports ---

global IND_Init


; --- Imports ---

library kernel.driver
extern DRV_CallDriver:near

library kernel.paging
extern AllocPhysMem:near

library kernel.pool
extern K_PoolInit:near, K_PoolAllocChunk:near

library kernel.mt
extern MT_WakeupTQ:near, MT_SleepTQ:near, MT_Schedule:near
extern ?CurrThread

library kernel.misc
extern BZero:near


; --- Definitions ---

%define	HASH_NUMBER	131

%define	HASHENTRYSHIFT	3

struc tInodeHashEntry
.InodePtr	RESD	1
.Updating	RESD	1
endstruc

; Hash macro: returns (device XOR block) MOD ?NumHash
;	      EDX=device, EBX=block
;	      EAX=result
%macro mHashFunction 0
	push	edx
	xor	edx,ebx
	mov	eax,edx
	xor	edx,edx
	div	dword [?NumHash]
	mov	eax,edx
	pop	edx
%endmacro

%macro mWaitOnInode 0
	test	word [esi+tInode.Flags],IFL_LOCKED
	jz	%%nowait
	call	IND_Wait
%%nowait:
%endmacro

%macro mLockInode 0
	mWaitOnInode
	or	word [esi+tInode.Flags],IFL_LOCKED
%endmacro

%macro mUnlockInode 0
	and	word [esi+tInode.Flags],~IFL_LOCKED
	mov	ebx,[esi+tInode.WaitQ]
	call	MT_WakeupTQ
%endmacro


; --- Variables ---

section .bss

?InodePool	RESB	tMasterPool_size
?InodeTblAddr	RESD	1
?HashTblAddr	RESD	1
?FirstInodePtr	RESD	1
?NumInodes	RESD	1
?NumFreeInodes	RESD	1
?NumHash	RESD	1
?InodeWaitQ	RESD	1


; --- Procedures ---

section .text

		; IND_Init - initialize inodes.
		; Input: none.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IND_Init
		; Initialize inodes master pool
		mov	ebx,?InodePool
		mov	ecx,tInode_size
		mov	edx,POOLFL_HIMEM+POOLFL_BUCKETALLOC
		call	K_PoolInit
		jc	short .Exit

		mov	ecx,HASH_NUMBER
		mov	[?NumHash],ecx
		mov	eax,tInodeHashEntry_size
		mul	ecx
		mov	ecx,eax
		mov	dl,1
		call	AllocPhysMem
		jc	short .Exit
		mov	[?HashTblAddr],ebx
		call	BZero
		xor	eax,eax
.Exit:		ret
endp		;---------------------------------------------------------------


		; CFS_GetInode - get an inode.
		; Input: EBX=block number,
		;	 EDX=device ID,
		;	 CL=mount point cross flag (0/1).
		; Output: CF=0 - OK, ESI=pointer to inode;
		;	  CF=1 - error, AX=error code.
proc CFS_GetInode
%define .updatewait	ebp-4
%define .xmntp		ebp-8

		prologue 4
		mpush	ebx,ecx,edx,edi
		
		mov	dword [.updatewait],0
		mov	[.xmntp],cl
		
		call	IND_Hash
		mov	edi,eax				; EDI=entry in hash table
		xor	ecx,ecx

.Repeat:	mov	esi,[edi+tInodeHashEntry.InodePtr]
.HashSrch:	or	esi,esi
		jz	short .ChkEmpty
		cmp	edx,[esi+tInode.Dev]
		jne	short .NextInd
		cmp	ebx,[esi+tInode.Block]
		je	short .Found
.NextInd:	mov	esi,[esi+tInode.HashNext]
		jmp	.HashSrch

.ChkEmpty:	or	ecx,ecx
		jnz	short .FillInode
		inc	dword [edi+tInodeHashEntry.Updating]
		push	esi
		call	IND_GetEmpty
		mov	ecx,esi
		pop	esi
		jc	.Exit
		dec	dword [edi+tInodeHashEntry.Updating]
		cmp	dword [edi+tInodeHashEntry.Updating],0
		jne	short .NoWakeup
		push	ebx
		lea	ebx,[.updatewait]
		call	MT_WakeupTQ
		pop	ebx
.NoWakeup:	or	ecx,ecx
		jnz	.Repeat
		xor	esi,esi
		stc
		jmp	.Exit

.FillInode:	mov	esi,ecx
		mov	[esi+tInode.Dev],edx
		mov	[esi+tInode.Block],ebx
		call	IND_PutLastFree
		call	IND_InsertHash
		call	CFS_ReadInode
		jmp	short .Return

.Found:		cmp	word [esi+tInode.Count],0
		jne	short .IncCount
		dec	dword [?NumFreeInodes]
.IncCount:	inc	word [esi+tInode.Count]
		mWaitOnInode
		
		; Check whether inode changed during wait
		cmp	[esi+tInode.Dev],edx
		jne	short .InodeChanged
		cmp	[esi+tInode.Block],ebx
		jne	short .InodeChanged
		
		; Check whether the mount point is crossed
		cmp	byte [.xmntp],0
		je	short .UngetEmpty
		cmp	dword [esi+tInode.Mount],0
		je	short .UngetEmpty
		mov	eax,[esi+tInode.Mount]
		inc	word [eax+tInode.Count]
		push	eax
		call	CFS_UngetInode
		pop	eax
		mov	esi,eax
		mWaitOnInode
		
.UngetEmpty:	or	ecx,ecx
		jz	short .Return
		push	esi
		mov	esi,ecx
		call	CFS_UngetInode
		pop	esi

.Return:	lea	ebx,[.updatewait]
.Sleep:		cmp	dword [edi+tInodeHashEntry.Updating],0
		je	short .Exit
		call	MT_SleepTQ
		jmp	.Sleep
		
.Exit:		mpop	edi,edx,ecx,ebx
		epilogue
		ret
		
.InodeChanged:
	%ifdef KPOPUP
	%endif
		call	CFS_UngetInode
		jmp	.Repeat
endp		;---------------------------------------------------------------


		; CFS_UngetInode - unget an inode.
		; Input: ESI=pointer to inode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_UngetInode
		ret
endp		;---------------------------------------------------------------


		; CFS_ReadInode - read an inode.
		; Input: ESI=pointer to inode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ReadInode
		mLockInode
		mCallDriverCtrl dword [esi+tInode.Dev],MOP_ReadInode
		mUnlockInode
		ret
endp		;---------------------------------------------------------------


		; CFS_WriteInode - write inode.
		; Input: ESI=pointer to inode.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_WriteInode
		test	word [esi+tInode.Flags],IFL_DIRTY
		jz	short .Exit
		mWaitOnInode
		test	word [esi+tInode.Flags],IFL_DIRTY
		jz	short .Exit
                or	word [esi+tInode.Flags],IFL_LOCKED
		mCallDriverCtrl dword [esi+tInode.Dev],MOP_ReadInode
		mUnlockInode
.Exit:		ret
endp		;---------------------------------------------------------------


		; CFS_ClearInode - clear an inode.
		; Input: ESI=pointer to inode.
		; Output: none.
proc CFS_ClearInode
		mpush	ebx,ecx
		mWaitOnInode
		call	IND_RemoveHash
		call	IND_RemoveFree
		push	dword [esi+tInode.WaitQ]
		cmp	word [esi+tInode.Count],0
		jz	short .1
		inc	dword [?NumFreeInodes]
.1:		mov	ebx,esi
		mov	ecx,tInode_size
		call	BZero
		pop	dword [esi+tInode.WaitQ]
		call	IND_InsertFree
		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; IND_Hash - get address of hash entry.
		; Input: EDX=device ID,
		;	 EBX=block number.
		; Output: EAX=address.
proc IND_Hash
		mHashFunction
		shl	eax,HASHENTRYSHIFT
		add	eax,[?HashTblAddr]
		ret
endp		;---------------------------------------------------------------


		; IND_InsertFree - insert inode in list of free inodes.
		; Input: ESI=pointer to inode.
		; Output: none.
		; Note: destroys EAX.
proc IND_InsertFree
		mov	eax,[?FirstInodePtr]
		mov	[esi+tInode.Next],eax
		mov	eax,[eax+tInode.Prev]
		mov	[esi+tInode.Prev],eax
		mov	eax,[esi+tInode.Next]
		mov	[eax+tInode.Prev],esi
		mov	eax,[esi+tInode.Prev]
		mov	[eax+tInode.Next],esi
		mov	[?FirstInodePtr],esi
		ret
endp		;---------------------------------------------------------------


		; IND_RemoveFree - remove inode from list of free Inodes.
		; Input: ESI=pointer to inode.
		; Output: none.
		; Note: destroys EAX.
proc IND_RemoveFree
		push	ebx
		cmp	esi,[?FirstInodePtr]
		jne	short .1
		mov	eax,[?FirstInodePtr]
		mov	eax,[eax+tInode.Next]
		mov	[?FirstInodePtr],eax
.1:		mov	eax,[esi+tInode.Next]
		mov	ebx,[esi+tInode.Prev]
		or	eax,eax
		jz	short .2
		mov	[eax+tInode.Prev],ebx
.2:		or	ebx,ebx
		jz	short .3
		mov	[ebx+tInode.Next],eax
.3:		xor	eax,eax
		mov	[esi+tInode.Next],eax
		mov	[esi+tInode.Prev],eax
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; IND_InsertHash - insert inode in hash chain.
		; Input: ESI=pointer to inode.
		; Output: none.
		; Note: destroys EAX.
proc IND_InsertHash
		mpush	ebx,ecx,edx
		mov	edx,[esi+tInode.Dev]
		mov	ebx,[esi+tInode.Block]
		call	IND_Hash
		mov	ebx,[eax+tInodeHashEntry.InodePtr]
		mov	[esi+tInode.HashNext],ebx
		mov	dword [esi+tInode.HashPrev],0
		or	ebx,ebx
		jz	short .1
		mov	[ebx+tInode.HashPrev],esi
.1:		mov	[eax+tInodeHashEntry.InodePtr],esi
		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IND_RemoveHash - remove inode from hash chain.
		; Input: ESI=pointer to inode.
		; Output: none.
proc IND_RemoveHash
		mpush	ebx,ecx,edx
		mov	edx,[esi+tInode.Dev]
		mov	ebx,[esi+tInode.Block]
		call	IND_Hash
		mov	ebx,[esi+tInode.HashNext]
		mov	edx,[esi+tInode.HashPrev]
		cmp	[eax+tInodeHashEntry.InodePtr],esi
		jne	short .1
		mov	[eax+tInodeHashEntry.InodePtr],ebx
.1:		or	ebx,ebx
		jz	short .2
		mov	[ebx+tInode.HashPrev],edx
.2:		or	edx,edx
		jz	short .3
		mov	[edx+tInode.HashNext],ebx
.3:		xor	eax,eax
		mov	[esi+tInode.HashNext],eax
		mov	[esi+tInode.HashPrev],eax
		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IND_PutLastFree - put inode last in free list.
		; Input: ESI=pointer to inode.
		; Output: none.
		; Note: destroys EAX.
proc IND_PutLastFree
		call	IND_RemoveFree
		mov	eax,[?FirstInodePtr]
		push	eax
		mov	eax,[eax+tInode.Prev]
		mov	[esi+tInode.Prev],eax
		mov	[eax+tInode.Next],esi
		pop	eax
		mov	[esi+tInode.Next],eax
		mov	[eax+tInode.Prev],esi
		ret
endp		;---------------------------------------------------------------


		; IND_Grow - grow inodes list.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IND_Grow
		mpush	ebx,ecx
		
		; Allocate a "bucket" of inodes (as many as fit in one page)
		mov	ebx,?InodePool
		call	K_PoolAllocChunk
		jc	short .Exit

		; Update counters
		add	[?NumInodes],ecx
		add	[?NumFreeInodes],ecx

		; If it's not first inode bucket - just add them into the
		; free inodes list.
		cmp	dword [?FirstInodePtr],0
		jne	short .InitList

		; If first one - initialize all pointers
		mov	[?FirstInodePtr],esi
		mov	[esi+tInode.Next],esi
		mov	[esi+tInode.Prev],esi
		add	esi,tInode_size
		dec	ecx
		jecxz	.OK

.InitList:	call	IND_InsertFree
		add	esi,tInode_size
		loop	.InitList

.OK:		xor	eax,eax
.Exit:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IND_GetEmpty - get empty inode.
		; Input: none.
		; Output: CF=0 - OK, ESI=pointer to inode;
		;	  CF=1 - error, AX=error code.
proc IND_GetEmpty
		mpush	ecx,edi
		mov	eax,[?NumInodes]
		mov	ecx,eax
		cmp	eax,NR_INODE
		jae	short .Search
		shr	eax,2
		cmp	[?NumFreeInodes],eax
		jae	short .Loop
		call	IND_Grow
		jc	short .Search

.Search:	mov	esi,[?FirstInodePtr]
		xor	edi,edi

.Loop:		cmp	word [esi+tInode.Count],0
		jnz	short .2
		or	edi,edi
		jnz	short .1
		mov	edi,esi
.1:		test	word [esi+tInode.Flags],IFL_DIRTY
		jnz	short .2
		cmp	word [esi+tInode.Flags],IFL_LOCKED
		jnz	short .2
		mov	edi,esi
		jmp	short .CheckBest
.2:		mov	esi,[esi+tInode.Next]
		loop	.Loop

.CheckBest:	or	edi,edi
		jz	short .ChkGrow
		test	word [edi+tInode.Flags],IFL_DIRTY
		jnz	short .ChkGrow
		test	word [edi+tInode.Flags],IFL_LOCKED
		jz	short .TakeBest
.ChkGrow:	cmp	dword [?NumInodes],NR_INODE
		jae	short .TakeBest
		call	IND_Grow
		jmp	.Search

.TakeBest:	mov	esi,edi
		or	esi,esi
		jnz	short .GoodInode
	%ifdef KPOPUP
	%endif
		mov	ebx,?InodeWaitQ
		call	MT_SleepTQ
		jmp	.Search

.GoodInode:	test	word [edi+tInode.Flags],IFL_LOCKED
		jz	short .ChkDirt
		mWaitOnInode
		jmp	.Search

.ChkDirt:	test	word [edi+tInode.Flags],IFL_DIRTY
		jz	short .ChkCount
		call	CFS_WriteInode

.ChkCount:	cmp	word [esi+tInode.Count],0
		jne	.Search

		call	CFS_ClearInode
		mov	word [esi+tInode.Count],1
		mov	dword [esi+tInode.NLinks],1

.Exit:		mpop	edi,ecx
		ret
endp		;---------------------------------------------------------------


		; IND_Invalidate - invalidate all inodes of a device.
		; Input: EDX=device ID.
		; Output: none.
proc IND_Invalidate
		mpush	ecx,esi,edi
		mov	edi,[?FirstInodePtr]
		mov	ecx,[?NumInodes]
		inc	ecx
		
.Loop:		dec	ecx
		jz	short .Exit
		mov	esi,edi
		mov	edi,[esi+tInode.Next]
		cmp	[esi+tInode.Dev],edx
		jne	.Loop
		cmp	word [esi+tInode.Count],0
		jne	short .Busy
		test	word [esi+tInode.Flags],IFL_DIRTY
		jnz	short .Busy
		test	word [esi+tInode.Flags],IFL_LOCKED
		jnz	short .Busy
		call	CFS_ClearInode
		jmp	.Loop

.Busy:
	%ifdef KPOPUP
		push	esi
		mov	esi,MsgInodeBusy
		call	K_PopUp
		pop	esi
	%endif
		jmp	.Loop
		
.Exit:		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; IND_Wait - wait until an inode will be unlocked.
		; Input: ESI=pointer to inode.
		; Output: none.
proc IND_Wait
%define .waitqentry	ebp-tWaitQueue_size

		prologue tWaitQueue_size
		mpush	ebx,edx
		mov	ebx,[?CurrThread]
		lea	edx,[.waitqentry]
		mov	dword [edx+tWaitQueue.WaitingTCB],ebx
		mov	dword [edx+tWaitQueue.Next],0
		

		mAddToWaitQ dword [esi+tInode.WaitQ],edx
.Loop:		mov	dword [ebx+tTCB.State],THRST_UNINTERRUPTIBLE
		test	word [esi+tInode.Flags],IFL_LOCKED
		jz	short .Restore
		call	MT_Schedule
		jmp	.Loop
		
.Restore:	mRemoveFromWaitQ dword [esi+tInode.WaitQ],edx
		mov	dword [ebx+tTCB.State],THRST_READY
		mpop	edx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------

