;-------------------------------------------------------------------------------
; kernsyscall.nasm - kernel system calls, accessible from C.
;-------------------------------------------------------------------------------

module libc.kernsyscall

%include "syscall.ah"

; Macro for declaring actual system call C routine
%macro mSyscall 1
    exportproc %1
%1:
    mDoSyscall S_%1
    ret
%endmacro

;******* Exports *******

; Interrupt handling
mSyscall InterruptAttach
mSyscall InterruptDetach
mSyscall InterruptDetachFunc
mSyscall InterruptWait

; Message passing
mSyscall MsgSend
mSyscall MsgSendnc
mSyscall MsgError
mSyscall MsgReceive
mSyscall MsgReply
mSyscall MsgRead
mSyscall MsgWrite
mSyscall MsgInfo
mSyscall MsgSendPulse
mSyscall MsgDeliverEvent
mSyscall MsgKeyData
mSyscall MsgReadiov
mSyscall MsgReceivePulse
mSyscall MsgReceivePulsev
mSyscall MsgVerifyEvent

; Signal handling
mSyscall SignalKill
mSyscall SignalReturn
mSyscall SignalFault
mSyscall SignalAction
mSyscall SignalProcmask
mSyscall SignalSuspend
mSyscall SignalWaitinfo

; Channel operations
mSyscall ChannelCreate
mSyscall ChannelDestroy
mSyscall ConnectAttach
mSyscall ConnectDetach
mSyscall ConnectServerInfo
mSyscall ConnectClientInfo
mSyscall ConnectFlags

; Thread management
mSyscall ThreadCreate
mSyscall ThreadDestroy
mSyscall ThreadDetach
mSyscall ThreadJoin
mSyscall ThreadCancel
mSyscall ThreadCtl

; Clock primitives
mSyscall ClockTime
mSyscall ClockAdjust
mSyscall ClockPeriod
mSyscall ClockId

; Timer handling
mSyscall TimerCreate
mSyscall TimerDestroy
mSyscall TimerSettime
mSyscall TimerInfo
mSyscall TimerAlarm
mSyscall TimerTimeout

; Synchronization
mSyscall SyncTypeCreate
mSyscall SyncDestroy
mSyscall SyncMutexLock
mSyscall SyncMutexUnlock
mSyscall SyncCondvarWait
mSyscall SyncCondvarSignal
mSyscall SyncSemPost
mSyscall SyncSemWait
mSyscall SyncCtl
mSyscall SyncMutexRevive

; Scheduling
mSyscall SchedGet
mSyscall SchedSet
mSyscall SchedYield
mSyscall SchedInfo

publicproc libc_init_syscall

		; Initialization
proc libc_init_syscall
		ret
endp		;---------------------------------------------------------------
