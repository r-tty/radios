;-------------------------------------------------------------------------------
;  userapi.nasm - user APIs (system calls).
;-------------------------------------------------------------------------------

module $syscall.user

exportproc sys_MsgSend
exportproc sys_MsgSendnc
exportproc sys_MsgError
exportproc sys_MsgReceive
exportproc sys_MsgRead
exportproc sys_MsgWrite
exportproc sys_MsgInfo
exportproc sys_MsgSendPulse
exportproc sys_MsgDeliverEvent
exportproc sys_MsgKeyData
exportproc sys_MsgReadiov
exportproc sys_MsgReceivePulse
exportproc sys_MsgVerifyEvent
exportproc sys_SignalKill
exportproc sys_SignalReturn
exportproc sys_SignalFault
exportproc sys_SignalAction
exportproc sys_SignalProcmask
exportproc sys_SignalSuspend
exportproc sys_SignalWaitinfo
exportproc sys_ChannelCreate
exportproc sys_ChannelDestroy
exportproc sys_ConnectAttach
exportproc sys_ConnectDetach
exportproc sys_ConnectServerInfo
exportproc sys_ConnectClientInfo
exportproc sys_ConnectFlags
exportproc sys_ThreadCreate
exportproc sys_ThreadDestroy
exportproc sys_ThreadDetach
exportproc sys_ThreadJoin
exportproc sys_ThreadCancel
exportproc sys_ThreadCtl
exportproc sys_InterruptAttach
exportproc sys_InterruptDetachFunc
exportproc sys_InterruptDetach
exportproc sys_InterruptWait
exportproc sys_ClockTime
exportproc sys_ClockAdjust
exportproc sys_ClockPeriod
exportproc sys_ClockId
exportproc sys_TimerCreate
exportproc sys_TimerDestroy
exportproc sys_TimerSettime
exportproc sys_TimerInfo
exportproc sys_TimerAlarm
exportproc sys_TimerTimeout
exportproc sys_SyncTypeCreate
exportproc sys_SyncDestroy
exportproc sys_SyncMutexLock
exportproc sys_SyncMutexUnlock
exportproc sys_SyncCondvarWait
exportproc sys_SyncCondvarSignal
exportproc sys_SyncSemPost
exportproc sys_SyncSemWait
exportproc sys_SyncCtl
exportproc sys_SyncMutexRevive
exportproc sys_SchedGet
exportproc sys_SchedSet
exportproc sys_SchedYield
exportproc sys_SchedInfo


section .text

proc sys_MsgSend
		ret
endp		;---------------------------------------------------------------


proc sys_MsgSendnc
		ret
endp		;---------------------------------------------------------------


proc sys_MsgError
		ret
endp		;---------------------------------------------------------------


proc sys_MsgReceive
		ret
endp		;---------------------------------------------------------------


proc sys_MsgRead
		ret
endp		;---------------------------------------------------------------


proc sys_MsgWrite
		ret
endp		;---------------------------------------------------------------


proc sys_MsgInfo
		ret
endp		;---------------------------------------------------------------


proc sys_MsgSendPulse
		ret
endp		;---------------------------------------------------------------


proc sys_MsgDeliverEvent
		ret
endp		;---------------------------------------------------------------


proc sys_MsgKeyData
		ret
endp		;---------------------------------------------------------------


proc sys_MsgReadiov
		ret
endp		;---------------------------------------------------------------


proc sys_MsgReceivePulse
		ret
endp		;---------------------------------------------------------------


proc sys_MsgVerifyEvent
		ret
endp		;---------------------------------------------------------------


proc sys_SignalKill
		ret
endp		;---------------------------------------------------------------


proc sys_SignalReturn
		ret
endp		;---------------------------------------------------------------


proc sys_SignalFault
		ret
endp		;---------------------------------------------------------------


proc sys_SignalAction
		ret
endp		;---------------------------------------------------------------


proc sys_SignalProcmask
		ret
endp		;---------------------------------------------------------------


proc sys_SignalSuspend
		ret
endp		;---------------------------------------------------------------


proc sys_SignalWaitinfo
		ret
endp		;---------------------------------------------------------------


proc sys_ChannelCreate
		ret
endp		;---------------------------------------------------------------


proc sys_ChannelDestroy
		ret
endp		;---------------------------------------------------------------


proc sys_ConnectAttach
		ret
endp		;---------------------------------------------------------------


proc sys_ConnectDetach
		ret
endp		;---------------------------------------------------------------


proc sys_ConnectServerInfo
		ret
endp		;---------------------------------------------------------------


proc sys_ConnectClientInfo
		ret
endp		;---------------------------------------------------------------


proc sys_ConnectFlags
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadCreate
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadDestroy
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadDetach
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadJoin
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadCancel
		ret
endp		;---------------------------------------------------------------


proc sys_ThreadCtl
		ret
endp		;---------------------------------------------------------------


proc sys_InterruptAttach
		ret
endp		;---------------------------------------------------------------


proc sys_InterruptDetachFunc
		ret
endp		;---------------------------------------------------------------


proc sys_InterruptDetach
		ret
endp		;---------------------------------------------------------------


proc sys_InterruptWait
		ret
endp		;---------------------------------------------------------------


proc sys_ClockTime
		ret
endp		;---------------------------------------------------------------


proc sys_ClockAdjust
		ret
endp		;---------------------------------------------------------------


proc sys_ClockPeriod
		ret
endp		;---------------------------------------------------------------


proc sys_ClockId
		ret
endp		;---------------------------------------------------------------


proc sys_TimerCreate
		ret
endp		;---------------------------------------------------------------


proc sys_TimerDestroy
		ret
endp		;---------------------------------------------------------------


proc sys_TimerSettime
		ret
endp		;---------------------------------------------------------------


proc sys_TimerInfo
		ret
endp		;---------------------------------------------------------------


proc sys_TimerAlarm
		ret
endp		;---------------------------------------------------------------


proc sys_TimerTimeout
		ret
endp		;---------------------------------------------------------------


proc sys_SyncTypeCreate
		ret
endp		;---------------------------------------------------------------


proc sys_SyncDestroy
		ret
endp		;---------------------------------------------------------------


proc sys_SyncMutexLock
		ret
endp		;---------------------------------------------------------------


proc sys_SyncMutexUnlock
		ret
endp		;---------------------------------------------------------------


proc sys_SyncCondvarWait
		ret
endp		;---------------------------------------------------------------


proc sys_SyncCondvarSignal
		ret
endp		;---------------------------------------------------------------


proc sys_SyncSemPost
		ret
endp		;---------------------------------------------------------------


proc sys_SyncSemWait
		ret
endp		;---------------------------------------------------------------


proc sys_SyncCtl
		ret
endp		;---------------------------------------------------------------


proc sys_SyncMutexRevive
		ret
endp		;---------------------------------------------------------------


proc sys_SchedGet
		ret
endp		;---------------------------------------------------------------


proc sys_SchedSet
		ret
endp		;---------------------------------------------------------------


proc sys_SchedYield
		ret
endp		;---------------------------------------------------------------


proc sys_SchedInfo
		ret
endp		;---------------------------------------------------------------
