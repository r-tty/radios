;-------------------------------------------------------------------------------
; kernsyscall.nasm - kernel system calls, accessible from C.
;-------------------------------------------------------------------------------

module libc.kernsyscall

%include "locstor.ah"
%include "syscall.ah"

; Macro for declaring pair of system call C routines
%macro mSyscall 1
	exportproc %1_r
%1_r:	pop	edx
	mDoSyscall S%1
	jmp	edx

	exportproc %1
%1:	pop	edx
	mDoSyscall S%1
	push	edx
	test	eax,eax
	jns	%%ret
	tlsptr(edx)
	mov	[edx+tTLS.ErrVal],eax
	xor	eax,eax
	not	eax
%%ret:	ret
%endmacro

;******* Exports *******

; Interrupt handling
mSyscall _InterruptAttach
mSyscall _InterruptDetach
mSyscall _InterruptDetachFunc
mSyscall _InterruptWait

; Message passing
mSyscall _MsgSend
mSyscall _MsgSendnc
mSyscall _MsgError
mSyscall _MsgReceive
mSyscall _MsgReply
mSyscall _MsgRead
mSyscall _MsgWrite
mSyscall _MsgInfo
mSyscall _MsgSendPulse
mSyscall _MsgDeliverEvent
mSyscall _MsgKeyData
mSyscall _MsgReadiov
mSyscall _MsgReceivePulse
mSyscall _MsgReceivePulsev
mSyscall _MsgVerifyEvent

; Signal handling
mSyscall _SignalKill
mSyscall _SignalReturn
mSyscall _SignalFault
mSyscall _SignalAction
mSyscall _SignalProcmask
mSyscall _SignalSuspend
mSyscall _SignalWaitinfo

; Channel operations
mSyscall _ChannelCreate
mSyscall _ChannelDestroy
mSyscall _ConnectAttach
mSyscall _ConnectDetach
mSyscall _ConnectServerInfo
mSyscall _ConnectClientInfo
mSyscall _ConnectFlags

; Thread management
mSyscall _ThreadCreate
mSyscall _ThreadDestroy
mSyscall _ThreadDetach
mSyscall _ThreadJoin
mSyscall _ThreadCancel
mSyscall _ThreadCtl

; Clock primitives
mSyscall _ClockTime
mSyscall _ClockAdjust
mSyscall _ClockPeriod
mSyscall _ClockId

; Timer handling
mSyscall _TimerCreate
mSyscall _TimerDestroy
mSyscall _TimerSettime
mSyscall _TimerInfo
mSyscall _TimerAlarm
mSyscall _TimerTimeout

; Synchronization
mSyscall _SyncTypeCreate
mSyscall _SyncDestroy
mSyscall _SyncMutexLock
mSyscall _SyncMutexUnlock
mSyscall _SyncCondvarWait
mSyscall _SyncCondvarSignal
mSyscall _SyncSemPost
mSyscall _SyncSemWait
mSyscall _SyncCtl
mSyscall _SyncMutexRevive

; Scheduling
mSyscall _SchedGet
mSyscall _SchedSet
mSyscall _SchedYield
mSyscall _SchedInfo

publicproc libc_init_syscall

		; Initialization
proc libc_init_syscall
		ret
endp		;---------------------------------------------------------------
