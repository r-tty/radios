;*******************************************************************************
; syscall.nasm - RadiOS microkernel system calls.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module kernel.syscall

%include "sys.ah"
%include "errors.ah"
%include "syscall.ah"
%include "bootdefs.ah"
%include "cpu/stkframe.ah"

; --- Definitions ---

; Entry in the system call table.
; Parameters:	%1 = function address,
;		%2 = number of parameters.
%macro mSyscallTabEntry 1-2
%ifid %1
externproc sys_%1
	DD	sys_%1
%else
	DD	%1
%endif

%if %0 == 2
	DB	%2
%else
	DB	0
%endif
%endmacro

%define	NRSYSCALLS	64h			; Number of syscalls

; --- Public ---

publicproc K_Sysenter, K_SysInt, K_ServEntry
exportproc K_InstallSyscallHandler, K_CurrentSyscallHandler

; --- Extern ---

extern K_CopyIn, K_CopyOut

; --- Data ---

section .data

SyscallTable:
mSyscallTabEntry 0				; 00 __kernop
mSyscallTabEntry 0				; 01 __traceevent
mSyscallTabEntry 0				; 02 __Ring0
mSyscallTabEntry 0				; 03 (reserved)
mSyscallTabEntry 0				; 04 (reserved)
mSyscallTabEntry 0				; 05 (reserved)
mSyscallTabEntry 0				; 06 (reserved)
mSyscallTabEntry 0				; 07 __SysCpupageGet
mSyscallTabEntry 0				; 08 __SysCpupageSet
mSyscallTabEntry 0				; 09 (reserved)
mSyscallTabEntry 0				; 0A (reserved)
mSyscallTabEntry MsgSendv, 5			; 0B
mSyscallTabEntry MsgSendvnc, 5			; 0C
mSyscallTabEntry MsgError, 2			; 0D
mSyscallTabEntry MsgReceivev, 4			; 0E
mSyscallTabEntry MsgReplyv, 4			; 0F
mSyscallTabEntry MsgReadv, 4			; 10
mSyscallTabEntry MsgWritev, 4			; 11
mSyscallTabEntry 0				; 12 (reserved)
mSyscallTabEntry MsgInfo, 2			; 13
mSyscallTabEntry MsgSendPulse, 4		; 14
mSyscallTabEntry MsgDeliverEvent, 2		; 15
mSyscallTabEntry MsgKeyData, 6			; 16
mSyscallTabEntry MsgReadIOV, 5			; 17
mSyscallTabEntry MsgReceivePulsev, 4		; 18
mSyscallTabEntry MsgVerifyEvent, 2		; 19
mSyscallTabEntry 0				; 1A SignalKill
mSyscallTabEntry 0				; 1B SignalReturn
mSyscallTabEntry 0				; 1C SignalFault
mSyscallTabEntry 0				; 1D SignalAction
mSyscallTabEntry 0				; 1E SignalProcmask
mSyscallTabEntry 0				; 1F SignalSuspend
mSyscallTabEntry 0				; 20 SignalWaitinfo
mSyscallTabEntry 0				; 21 (reserved)
mSyscallTabEntry 0				; 22 (reserved)
mSyscallTabEntry ChannelCreate, 1		; 23
mSyscallTabEntry ChannelDestroy, 1		; 24
mSyscallTabEntry 0				; 25 (reserved)
mSyscallTabEntry 0				; 26 (reserved)
mSyscallTabEntry 0				; 27 ConnectAttach
mSyscallTabEntry ConnectDetach, 1		; 28
mSyscallTabEntry 0				; 29 ConnectServerInfo
mSyscallTabEntry ConnectClientInfo, 3		; 2A
mSyscallTabEntry 0				; 2B ConnectFlags
mSyscallTabEntry 0				; 2C (reserved)
mSyscallTabEntry 0				; 2D (reserved)
mSyscallTabEntry 0				; 2E ThreadCreate
mSyscallTabEntry 0				; 2F ThreadDestroy
mSyscallTabEntry 0				; 30 (reserved)
mSyscallTabEntry ThreadDetach, 1		; 31
mSyscallTabEntry ThreadJoin, 2			; 32
mSyscallTabEntry ThreadCancel, 2		; 33
mSyscallTabEntry ThreadCtl, 2			; 34
mSyscallTabEntry 0				; 35 (reserved)
mSyscallTabEntry 0				; 36 (reserved)
mSyscallTabEntry InterruptAttach, 5		; 37
mSyscallTabEntry InterruptDetachFunc, 		; 38
mSyscallTabEntry InterruptDetach, 1		; 39
mSyscallTabEntry InterruptWait, 2		; 3A
mSyscallTabEntry 0				; 3B __interruptmask
mSyscallTabEntry 0				; 3C __interruptunmask
mSyscallTabEntry 0				; 3D (reserved)
mSyscallTabEntry 0				; 3E (reserved)
mSyscallTabEntry 0				; 3F (reserved)
mSyscallTabEntry 0				; 40 (reserved)
mSyscallTabEntry ClockTime, 3			; 41
mSyscallTabEntry ClockAdjust, 3			; 42
mSyscallTabEntry ClockPeriod, 3			; 43
mSyscallTabEntry ClockId, 2  			; 44
mSyscallTabEntry 0				; 45 (reserved)
mSyscallTabEntry 0				; 46 TimerCreate
mSyscallTabEntry 0				; 47 TimerDestroy
mSyscallTabEntry 0				; 48 TimerSettime
mSyscallTabEntry 0				; 49 TimerInfo
mSyscallTabEntry 0				; 4A TimerAlarm
mSyscallTabEntry 0				; 4B TimerTimeout
mSyscallTabEntry 0				; 4C (reserved)
mSyscallTabEntry 0				; 4D (reserved)
mSyscallTabEntry SyncTypeCreate, 3		; 4E
mSyscallTabEntry SyncDestroy, 1			; 4F
mSyscallTabEntry SyncMutexLock, 1		; 50
mSyscallTabEntry SyncMutexUnlock, 1		; 51
mSyscallTabEntry SyncCondvarWait, 2		; 52
mSyscallTabEntry SyncCondvarSignal, 2		; 53
mSyscallTabEntry SyncSemPost, 1			; 54
mSyscallTabEntry SyncSemWait, 2			; 55
mSyscallTabEntry SyncCtl, 3			; 56
mSyscallTabEntry SyncMutexRevive, 1		; 57
mSyscallTabEntry 0				; 58 SchedGet
mSyscallTabEntry 0				; 59 SchedSet
mSyscallTabEntry SchedYield			; 5A
mSyscallTabEntry 0				; 5B SchedInfo
mSyscallTabEntry 0				; 5C (reserved)
mSyscallTabEntry 0				; 5D NetCred
mSyscallTabEntry 0				; 5E NetVtid
mSyscallTabEntry 0				; 5F NetUnblock
mSyscallTabEntry 0				; 60 NetInfoscoid
mSyscallTabEntry 0				; 61 NetSignalKill
mSyscallTabEntry 0				; 62 (reserved)
mSyscallTabEntry 0				; 63 __kerbad

		
section .text

		; K_Sysenter - kernel entry point for SYSENTER instruction.
		; Input: EAX=syscall number,
		;	 ECX=user ESP,
		;	 EDX=user EIP.
		; Output: EAX=system call return code.
proc K_Sysenter
		mpush	ds,es,ebx,ecx,edx
		cmp	eax,NRSYSCALLS
		jae	.Err
		mov	ax,ss
		mov	ds,ax
		mov	es,ax
		mov	eax,[SyscallTable+eax*5]
		or	eax,eax
		jz	.Err
		call	eax
.Done:		mpop	edx,ecx,ebx,es,ds
		sysexit
.Err:		mov	eax,ENOSYS
		jmp	.Done
endp		;---------------------------------------------------------------


		; K_SysInt - system interrupt handler.
		; User parameters are in the stack frame.
		; Note: the address of user stack frame is passed in EDX
		;	to each system call.
proc K_SysInt
		arg	frame
		prologue

		; Check syscall number
		lea	edx,[%$frame]
		xor	eax,eax
		mov	al,[edx+tStackFrame.EAX]
		cmp	al,NRSYSCALLS
		jae	.Err
		mov	ebx,[SyscallTable+eax*5]		; routine addr
		or	ebx,ebx
		jz	.Err

		; Copy parameters to the kernel stack		
		movzx	ecx,byte [SyscallTable+eax*5+4]		; # of params
		or	ecx,ecx
		jz	.DoSyscall
		lea	ecx,[ecx*4]
		sub	esp,ecx
		mov	esi,[edx+tStackFrame.ESP]
		mov	edi,esp
		call	K_CopyIn
		jc	.Err

.DoSyscall:	call	ebx					; Do syscall

.Done:		mov	[%$frame+tStackFrame.EAX],eax
		epilogue
		ret

.Err:		mov	eax,-ENOSYS
		jmp	.Done
endp		;---------------------------------------------------------------


		; K_ServEntry - service trap handler (for debugging).
		; Register frame is on the stack.
proc K_ServEntry
		push	ebp
		lea	ebp,[esp+8]
		mov	eax,[ebp+tStackFrame.EAX]
		test	word [ebp+tStackFrame.ECS],SELECTOR_RPL3
		jnz	.User

		; Called from kernel code - use current stack
		mov	ebp,[esp+tStackFrame_size]
		jmp	.DoCall
		
		; Called from user code
.User		add	esi,USERAREASTART
		add	edi,USERAREASTART
		mov	ebp,[ebp+tStackFrame.ESP]
		mov	ebp,[ebp+USERAREASTART]

.DoCall:	xchg	ebp,[esp]
		call	dword [BOOTPARM(ServiceEntry)]
		add	esp,byte 4
		mov	[esp+4+tStackFrame.EAX],eax
		ret
endp		;---------------------------------------------------------------


		; Get an address of current system call handler.
		; Input: AX=syscall number.
		; Output: CF=0 - OK:
		;		  EBX=handler address,
		;		  CL=number of parameters;
		;	  CF-1 - error.
proc K_CurrentSyscallHandler
		cmp	ax,NRSYSCALLS
		cmc
		jbe	.Exit
		and	eax,0FFFFh
		mov	ebx,[SyscallTable+eax*5]
		mov	cl,[SyscallTable+eax*5+4]
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Install a new system call handler.
		; Input: AX=syscall number,
		;	 EBX=function address,
		;	 CL=number of parameters.
		; Output: CF=0 - OK;
		;	  CF-1 - error.
proc K_InstallSyscallHandler
		cmp	ax,NRSYSCALLS
		cmc
		jbe	.Exit
		and	eax,0FFFFh
		mov	[SyscallTable+eax*5],ebx
		mov	[SyscallTable+eax*5+4],cl
		clc
.Exit:		ret
endp		;---------------------------------------------------------------
