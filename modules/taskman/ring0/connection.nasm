;-------------------------------------------------------------------------------
; connection.nasm - connection system calls.
;-------------------------------------------------------------------------------

module tm.kern.connection

%include "errors.ah"
%include "thread.ah"
%include "msg.ah"
%include "tm/kern.ah"
%include "tm/process.ah"

publicdata ConnectSyscallTable, ?ConnPool

library $rmk
importproc K_PoolAllocChunk
importproc K_AllocateID
importproc IPC_ChanDescAddr
importproc K_SemP, K_SemV
importproc BZero

section .data

ConnectSyscallTable:
mSyscallTabEnt ConnectAttach, 5
mSyscallTabEnt ConnectServerInfo, 3
mSyscallTabEnt ConnectFlags, 4
mSyscallTabEnt 0

section .bss

?ConnPool	RESB	tMasterPool_size

section .text

		; int ConnectAttach(uint nd, pid_t pid, int chid,
		;			uint index, int flags);
proc sys_ConnectAttach
		arg	nd, pid, chid, index, flags
		prologue

		; Get the address of channel descriptor
		mov	eax,[%$chid]
		call	IPC_ChanDescAddr
		jc	near .Exit
		mov	edx,esi

		; Get current thread and process
		mCurrThread
		mov	edi,[eax+tTCB.PCB]

		; Allocate a new connection descriptor
		mov	ebx,?ConnPool
		call	K_PoolAllocChunk
		jc	.Again
		mov	ebx,esi
		mov	ecx,tConnDesc_size
		call	BZero

		; Update channel information and put connection to the list
		inc	dword [edx+tChanDesc.NumConn]
		mov	[esi+tConnDesc.ChanDesc],edx
		mLockCB edi, tProcDesc
		mEnqueue dword [edi+tProcDesc.ConnList], Next, Prev, esi, tConnDesc, ebx
		mUnlockCB edi, tProcDesc

		; Update connection ID
		lea	ebx,[edi+tProcDesc.MaxConn]
		call	K_AllocateID
		jc	.Again
		mov	ecx,[%$index]
		or	ecx,ecx
		jz	.IndexOK
		cmp	ecx,SIDE_CHANNEL
		jne	.BadIndex
.IndexOK:	add	eax,ecx
		mov	[esi+tConnDesc.ID],eax

.Exit		epilogue
		ret

.BadIndex:	mov	eax,-EBADF
		jmp	.Exit

.Again:		mov	eax,-EAGAIN
		jmp	.Exit
endp		;---------------------------------------------------------------

		; int ConnectServerInfo(pid_t pid, int coid,
		;			struct _server_info *info);
proc sys_ConnectServerInfo
		arg	pid, coid, info
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ConnectFlags(pid_t pid, int coid, uint mask, uint bits);
proc sys_ConnectFlags
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
