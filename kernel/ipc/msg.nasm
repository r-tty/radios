;*******************************************************************************
;  msg.nasm - RadiOS IPC "message" primitives.
;  Copyright (c) 2000 RET & COM Research.
;  This file is based on the TINOS Operating System (c) 1998 Bart Sekura.
;*******************************************************************************

module kernel.ipc.msg

%include "sys.ah"
%include "errors.ah"
%include "sema.ah"
%include "pool.ah"
%include "msg.ah"


; --- Imports ---

library kernel.pool
extern K_PoolInit:near, K_PoolAllocChunk:near

library kernel.misc
extern BZero:near


; --- Data ---

section .data

MsgCantAllocMsg	DB	":IPC:IPC_PortAlloc: warning: cannot allocate message",0


; --- Variables ---

section .bss

?PortPool	RESB	tMasterPool_size
?MsgPool	RESB	tMasterPool_size


; --- Code ---

section .text

		; IPC_MsgInit - initialize messaging structures.
		; Input: none.
		; Output: none.
proc IPC_MsgInit
		mov	ebx,?PortPool
		mov	ecx,tIPCport_size
		xor	edx,edx
		call	K_PoolInit
		jc	short .Done
		mov	ebx,?MsgPool
		mov	ecx,tMessage_size
		call	K_PoolInit		
.Done:		ret
endp		;---------------------------------------------------------------


		; IPC_MsgAlloc - allocate a memory slot for message.
		; Input: none.
		; Output: CF=0 - OK, ESI=message structure address;
		;	  CF=1 - error, AX=error code.
proc IPC_MsgAlloc
		mpush	ebx,ecx
		mov	ebx,?MsgPool
		call	K_PoolAllocChunk
		jc	short .Exit
		
		mov	ebx,esi
		mov	ecx,tMessage_size
		call	BZero

		lea	ebx,[esi+tMessage.Lock]
		xor	eax,eax
		mSemInit ebx
		mSemSetVal ebx
		clc

.Exit:		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IPC_PortAlloc - initialize messaging port.
		; Input: none.
		; Output: EDI=address of port structure.
proc IPC_PortAlloc
		mpush	ebx,esi
		mov	ebx,?PortPool
		call	K_PoolAllocChunk
		jc	short .Exit

		; Initialize queue pointers
		xor	eax,eax
		mov	[esi+tIPCport.Head],eax
		mov	[esi+tIPCport.Tail],eax

		; Port semaphore
		lea	ebx,[esi+tIPCport.Lock]
		mSemInit ebx

		; "Receive" semaphore
		lea	ebx,[esi+tIPCport.Lock]
		mSemInit ebx
		mSemSetVal ebx				; Semaphore count=0

		; Initialize free list
		mov	edi,esi
		mov	ecx,8
		mov	dword [edi+tIPCport.FreeList],0
.Loop:		call	IPC_MsgAlloc
		jc	short .Warning
		call	IPC_PutFree
		loop	.Loop
		jmp	short .Exit
.Warning:
	%ifdef KPOPUPS
		push	esi
		mov	esi,MsgCantAllocMsg
		call	K_PopUp
		pop	esi
	%endif
.Exit:		mpop	esi,ebx
		ret		
endp		;---------------------------------------------------------------


		; IPC_PutFree - put a message in the free list.
		; Input: ESI=message structure address,
		;	 EDI=port structure address.
		; Output: none.
proc IPC_PutFree
		pushfd
		cli
		mov	eax,[edi+tIPCport.FreeList]
		mov	[esi+tMessage.NextFree],eax
		mov	[edi+tIPCport.FreeList],esi
		popfd
		ret
endp		;---------------------------------------------------------------


		; IPC_GetFree - get a message from the free list.
		; Input: EDI=port structure address.
		; Output: ESI=message structure address.
proc IPC_GetFree
		pushfd
		cli
		mov	esi,[edi+tIPCport.FreeList]
		or	esi,esi
		jz	short .Exit
		mov	eax,[esi+tMessage.NextFree]
		mov	[edi+tIPCport.FreeList],eax
		mov	dword [esi+tMessage.NextFree],0
.Exit:		popfd
		ret
endp		;---------------------------------------------------------------


		; IPC_MsgEnqueue - enqueue a message in a port queue.
		; Input: ESI=message structure address,
		;	 EDI=port structure address.
		; Output: none.
proc IPC_MsgEnqueue
		mov	eax,[edi+tIPCport.Tail]
		or	eax,eax
		jz	short .NoTail
		mov	[eax+tMessage.Next],esi

.NoTail:	mov	dword [esi+tMessage.Next],0
		mov	[edi+tIPCport.Tail],esi
		cmp	dword [edi+tIPCport.Head],0
		jnz	short .Exit
		mov	[edi+tIPCport.Head],esi

.Exit:		ret
endp		;---------------------------------------------------------------


		; IPC_MsgDequeue - remove a message from port queue.
		; Input: ESI=message structure address,
		;	 EDI=port structure address.
		; Output: none.
proc IPC_MsgDequeue
		cmp	[edi+tIPCport.Head],esi
		jne	short .1
		mov	eax,[esi+tMessage.Next]
		mov	[edi+tIPCport.Head],eax
		ret

.1:		push	ebx
		mov	ebx,[edi+tIPCport.Head]

.Loop:		or	ebx,ebx
		jz	short .Exit
		cmp	esi,[ebx+tMessage.Next]
		je	short .2
		mov	ebx,[ebx+tMessage.Next]
		jmp	.Loop

.2:		mov	eax,[esi+tMessage.Next]
		mov	[ebx+tMessage.Next],eax
		cmp	[edi+tIPCport.Tail],esi
		jne	short .Exit
		mov	[edi+tIPCport.Tail],ebx

.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


