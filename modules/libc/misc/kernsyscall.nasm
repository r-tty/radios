;-------------------------------------------------------------------------------
; kernsyscall.nasm - kernel system calls, accessible from C.
;-------------------------------------------------------------------------------

module libc.kernsyscall

%include "locstor.ah"
%include "syscall.ah"

; Negate the dword in stack.
; Parameters:	%1 - parameter number (starting from 1).
%macro mNegate 1
%ifnum %1
%if %1 != 0
	neg	dword [esp+4*%1]
%endif
%endif
%endmacro

; Macro for declaring pair of system call C routines
; Parameters:	%1 - function base name,
;		%2 - optional parameter to negate (or 0),
;		%3 - optional parameter to negate (or 0),
;		%4 - optional syscall number (if omited, S%1 is assumed).
%macro mSyscall 1-4
	exportproc %1_r
%1_r:	pop	edx
	mNegate %2
	mNegate %3
%ifid %4
	mDoSyscall %4
%else
	mDoSyscall S%1
%endif
	jmp	edx

	exportproc %1
%1:	pop	edx
	mNegate %2
	mNegate %3
%ifid %4
	mDoSyscall %4
%else
	mDoSyscall S%1
%endif
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
mSyscall _MsgSendv
mSyscall _MsgSend,	3, 5, S_MsgSendv
mSyscall _MsgSendvnc
mSyscall _MsgSendnc,	3, 5, S_MsgSendvnc
mSyscall _MsgSendsv,	3, 0, S_MsgSendv
mSyscall _MsgSendsvnc,	3, 0, S_MsgSendvnc
mSyscall _MsgSendvs,	5, 0, S_MsgSendv
mSyscall _MsgSendvsnc,	5, 0, S_MsgSendvnc
mSyscall _MsgError
mSyscall _MsgReceive,	3, 0, S_MsgReceivev
mSyscall _MsgReceivev
mSyscall _MsgReply,	4, 0, S_MsgReplyv
mSyscall _MsgReplyv
mSyscall _MsgRead,	3, 0, S_MsgReadv
mSyscall _MsgReadv
mSyscall _MsgWrite,	3, 0, S_MsgWritev
mSyscall _MsgWritev
mSyscall _MsgInfo
mSyscall _MsgSendPulse
mSyscall _MsgDeliverEvent
mSyscall _MsgKeyData
mSyscall _MsgReadiov
mSyscall _MsgReceivePulse, 3, 0, S_MsgReceivePulsev
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
