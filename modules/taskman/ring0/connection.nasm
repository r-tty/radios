;-------------------------------------------------------------------------------
; connection.nasm - connection system calls.
;-------------------------------------------------------------------------------

module tm.kern.connection

%include "errors.ah"
%include "thread.ah"
%include "msg.ah"
%include "tm/kern.ah"
%include "tm/process.ah"

publicproc FindConnByNum
publicdata ConnectSyscallTable

externproc R0_Pid2PCBaddr

library $rmk
importproc K_PoolAllocChunk, K_PoolChunkAddr
importproc K_HashAdd
importproc K_AllocateID
importproc K_ChanDescAddr, K_ConnDescAddr, K_CreateSConnDesc
importproc K_SemP, K_SemV
importproc BZero
importdata ?ConnPool, ?ConnHash

section .data

ConnectSyscallTable:
mSyscallTabEnt ConnectAttach, 5
mSyscallTabEnt ConnectServerInfo, 3
mSyscallTabEnt ConnectFlags, 4
mSyscallTabEnt 0


section .text

		; Find a connection descriptor by its ordinal number.
		; Input: EAX=descriptor number.
		; Output: CF=0 - OK, EDI=descriptor address;
		;	  CF=1 - error, EAX=errno.
proc FindConnByNum
		mpush	ebx,esi
		mov	ebx,?ConnPool
		call	K_PoolChunkAddr
		jc	.NotFound
		mov	edi,esi
.Exit:		mpop	esi,ebx
		ret

.NotFound:	mov	eax,-EBADF
		jmp	.Exit
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------

		; int ConnectAttach(uint nd, pid_t pid, int chid,
		;			uint index, int flags);
proc sys_ConnectAttach
		arg	nd, pid, chid, index, flags
		locals	sconnlist
		prologue

		; Attaching to a remote channel is a different story...
		mov	eax,[%$nd]
		or	eax,eax
		jnz	near .Exit

		; Get the address of channel descriptor
		mov	eax,[%$pid]
		call	R0_Pid2PCBaddr
		jc	near .Exit
		Mov32	%$sconnlist,esi+tProcDesc.ConnList
		mov	eax,[%$chid]
		call	K_ChanDescAddr
		jc	near .Exit
		mov	edx,esi

		; Get current thread and process
		mCurrThread
		mov	edi,[eax+tTCB.PCB]

		; Allocate a new connection descriptor
		mov	ebx,?ConnPool
		call	K_PoolAllocChunk
		jc	near .Again
		mov	ebx,esi
		mov	ecx,tConnDesc_size
		call	BZero

		; Check the index
		mov	ecx,[%$index]
		or	ecx,ecx
		jz	.AllocID
		cmp	ecx,SIDE_CHANNEL
		jne	near .BadIndex

		; Allocate connection ID
.AllocID:	lea	ebx,[edi+tProcDesc.MaxConn]
		call	K_AllocateID
		jc	near .Again
		add	eax,ecx
		mov	[esi+tConnDesc.ID],eax

		; Examine the server's connection list. If there are no
		; connections from our process to this channel - create a
		; new scoid, otherwise use the existing one.
		mov	ebx,[%$sconnlist]
.ScoIdLoop:	or	ebx,ebx
		jz	.NewScoDesc
		cmp	[ebx+tConnDesc.ClientPCB],edi
		jne	.Next
		cmp	[ebx+tConnDesc.ChanDesc],edx
		mov	eax,[ebx+tConnDesc.ID]
		je	.ScoDescFound
.Next:		mov	eax,ebx
		mov	ebx,[ebx+tConnDesc.Next]
		cmp	ebx,eax
		jne	.ScoIdLoop

		; Allocate a new server connection descriptor
.NewScoDesc:	call	K_CreateSConnDesc
		jc	.Exit

		; Update channel information and put the connection to the list
.ScoDescFound:	mov	[esi+tConnDesc.ScoID],eax
		mov	[esi+tConnDesc.ChanDesc],edx
		inc	dword [edx+tChanDesc.NumConn]
		mLockCB edi, tProcDesc
		mEnqueue dword [edi+tProcDesc.ConnList], Next, Prev, esi, tConnDesc, ebx
		mUnlockCB edi, tProcDesc

		; Use connection ID as identifier and PCB address as hash key
		mov	ebx,edi
		mov	edi,esi
		mov	esi,[?ConnHash]
		call	K_HashAdd
		jc	.Again
		mov	eax,[edi+tConnDesc.ID]

.Exit:		epilogue
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

		; Zero PID is also okay - it means local process
		mCurrThread ebx
		mov	esi,[ebx+tTCB.PCB]
		mov	eax,[%$pid]
		or	eax,eax
		jz	.CheckCoid
		mov	edi,esi
		call	R0_Pid2PCBaddr
		jc	.Exit

.CheckCoid:	mov	eax,[%$coid]
		call	K_ConnDescAddr
		jc	.Exit

		mov	edx,[%$info]
		add	edx,USERAREACHECK
		jc	.Fault
		cmp	edx,-tMsgInfo_size
		jg	.Fault

.Exit:		epilogue
		ret

.Fault:		mov	eax,-EFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ConnectFlags(pid_t pid, int coid, uint mask, uint bits);
proc sys_ConnectFlags
		arg	pid, coid, mask, bits
		prologue

		; If pid is nonzero, check if that process is owned by a user
		mCurrThread ebx
		mov	esi,[ebx+tTCB.PCB]
		mov	eax,[%$pid]
		or	eax,eax
		jz	.CheckCoid
		mov	edi,esi
		call	R0_Pid2PCBaddr
		jc	.Exit
		Cmp32	esi+tProcDesc.Cred+tCredInfo.EUID, \
			edi+tProcDesc.Cred+tCredInfo.RUID
		jne	.BadPerm

.CheckCoid:	mov	eax,[%$coid]
		call	K_ConnDescAddr
		jc	.Exit
		mov	edx,[edi+tConnDesc.Flags]
		mov	eax,[%$mask]
		and	eax,COF_CLOEXEC			; Supported flags
		mov	ecx,[%$bits]
		and	ecx,eax
		or	[edi+tConnDesc.Flags],ecx
		not	eax
		or	eax,[%$bits]
		and	[edi+tConnDesc.Flags],eax
		mov	eax,edx

.Exit:		epilogue
		ret

.BadPerm:	mov	eax,-EPERM
		jmp	.Exit
endp		;---------------------------------------------------------------
