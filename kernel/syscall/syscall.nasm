;*******************************************************************************
; syscall.nasm - RadiOS microkernel system calls.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

%include "sys.ah"
%include "errors.ah"
%include "syscall.ah"
%include "cpu/stkframe.ah"

%include "drvhlp.nasm"
%include "userapi.nasm"

module kernel.syscall

publicproc K_Sysenter, K_SysInt, K_DebugServEntry

%define	NRSYSCALLS	64h			; Number of syscalls


section .data

SyscallTable	DD	0			; 00 __kernop
		DD	0			; 01 __traceevent
		DD	0			; 02 __Ring0
		DD	0			; 03 (reserved)
		DD	0			; 04 (reserved)
		DD	0			; 05 (reserved)
		DD	0			; 06 (reserved)
		DD	0			; 07 __SysCpupageGet
		DD	0			; 08 __SysCpupageSet
		DD	0			; 09 (reserved)
		DD	0			; 0A (reserved)
		DD	sys_MsgSend		; 0B
		DD	sys_MsgSendnc		; 0C
		DD	sys_MsgError		; 0D
		DD	sys_MsgReceive		; 0E
		DD	sys_MsgReply		; 0F
		DD	sys_MsgRead		; 10
		DD	sys_MsgWrite		; 11
		DD	0			; 12 (reserved)
		DD	sys_MsgInfo		; 13
		DD	sys_MsgSendPulse	; 14
		DD	sys_MsgDeliverEvent	; 15
		DD	sys_MsgKeyData		; 16
		DD	sys_MsgReadiov		; 17
		DD	sys_MsgReceivePulse	; 18
		DD	sys_MsgVerifyEvent	; 19
		DD	sys_SignalKill		; 1A
		DD	sys_SignalReturn	; 1B
		DD	sys_SignalFault		; 1C
		DD	sys_SignalAction	; 1D
		DD	sys_SignalProcmask	; 1E
		DD	sys_SignalSuspend	; 1F
		DD	sys_SignalWaitinfo	; 20
		DD	0			; 21 (reserved)
		DD	0			; 22 (reserved)
		DD	sys_ChannelCreate	; 23
		DD	sys_ChannelDestroy	; 24
		DD	0			; 25 (reserved)
		DD	0			; 26 (reserved)
		DD	sys_ConnectAttach	; 27
		DD	sys_ConnectDetach	; 28
		DD	sys_ConnectServerInfo	; 29
		DD	sys_ConnectClientInfo	; 2A
		DD	sys_ConnectFlags	; 2B
		DD	0			; 2C (reserved)
		DD	0			; 2D (reserved)
		DD	sys_ThreadCreate	; 2E
		DD	sys_ThreadDestroy	; 2F
		DD	0			; 30 (reserved)
		DD	sys_ThreadDetach	; 31
		DD	sys_ThreadJoin		; 32
		DD	sys_ThreadCancel	; 33
		DD	sys_ThreadCtl		; 34
		DD	0			; 35 (reserved)
		DD	0			; 36 (reserved)
		DD	sys_InterruptAttach	; 37
		DD	sys_InterruptDetachFunc	; 38
		DD	sys_InterruptDetach	; 39
		DD	sys_InterruptWait	; 3A
		DD	0			; 3B __interruptmask
		DD	0			; 3C __interruptunmask
		DD	0			; 3D (reserved)
		DD	0			; 3E (reserved)
		DD	0			; 3F (reserved)
		DD	0			; 40 (reserved)
		DD	sys_ClockTime		; 41
		DD	sys_ClockAdjust		; 42
		DD	sys_ClockPeriod		; 43
		DD	sys_ClockId		; 44
		DD	0			; 45 (reserved)
		DD	sys_TimerCreate		; 46
		DD	sys_TimerDestroy	; 47
		DD	sys_TimerSettime	; 48
		DD	sys_TimerInfo		; 49
		DD	sys_TimerAlarm		; 4A
		DD	sys_TimerTimeout	; 4B
		DD	0			; 4C (reserved)
		DD	0			; 4D (reserved)
		DD	sys_SyncTypeCreate	; 4E
		DD	sys_SyncDestroy		; 4F
		DD	sys_SyncMutexLock	; 50
		DD	sys_SyncMutexUnlock	; 51
		DD	sys_SyncCondvarWait	; 52
		DD	sys_SyncCondvarSignal	; 53
		DD	sys_SyncSemPost		; 54
		DD	sys_SyncSemWait		; 55
		DD	sys_SyncCtl		; 56
		DD	sys_SyncMutexRevive	; 57
		DD	sys_SchedGet		; 58
		DD	sys_SchedSet		; 59
		DD	sys_SchedYield		; 5A
		DD	sys_SchedInfo		; 5B
		DD	0			; 5C (reserved)
		DD	0			; 5D NetCred
		DD	0			; 5E NetVtid
		DD	0			; 5F NetUnblock
		DD	0			; 60 NetInfoscoid
		DD	0			; 61 NetSignalKill
		DD	0			; 62 (reserved)
		DD	0			; 63 __kerbad

		
section .text

		; K_Sysenter - kernel entry point for SYSENTER instruction.
		; Input: EAX=syscall number,
		;	 ECX=user ESP,
		;	 EDX=user EIP.
		; Output: EAX=system call return code.
		; Note: optional parameters may be passed to system call in
		;	ESI and EDI registers.
proc K_Sysenter
		mpush	ecx,edx
		cmp	eax,NRSYSCALLS
		jae	.Err
		mov	eax,[SyscallTable+eax*4]
		or	eax,eax
		jz	.Err
		call	eax
.Done:		mpop	edx,ecx
		sysexit
.Err:		mov	eax,ERR_BadSyscall
		jmp	.Done
endp		;---------------------------------------------------------------


		; K_SysInt - system interrupt handler.
		; User parameters are in the stack frame.
proc K_SysInt
		arg	frame
		prologue

		epilogue
		ret
endp		;---------------------------------------------------------------


		; K_DebugServEntry - service entry for debugging.
		; User parameters are in the stack frame.
proc K_DebugServEntry
		arg	frame
		prologue
		
		lea	eax,[%$frame]
		mov	eax,[eax+tStackFrame.EAX]

		epilogue
		ret
endp		;---------------------------------------------------------------
