;-------------------------------------------------------------------------------
; sigevent.nasm - signal and event system calls.
;-------------------------------------------------------------------------------

module tm.kern.sigevent

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "siginfo.ah"
%include "tm/kern.ah"

publicdata SignalSyscallTable

externproc FindConnByNum, R0_Pid2PCBaddr
importproc K_DecodeRcvid, K_SendPulse

; --- System call table ---

section .data

SignalSyscallTable:

mSyscallTabEnt MsgDeliverEvent, 2
mSyscallTabEnt MsgVerifyEvent, 2
mSyscallTabEnt SignalKill, 6
mSyscallTabEnt SignalReturn, 1
mSyscallTabEnt SignalFault, 3
mSyscallTabEnt SignalAction, 5
mSyscallTabEnt SignalProcmask, 5
mSyscallTabEnt SignalSuspend, 1
mSyscallTabEnt SignalWaitinfo, 2
mSyscallTabEnt 0

; --- Procedures ---

section .text

		; int MsgDeliverEvent(int rcvid, const struct sigevent* event);
proc sys_MsgDeliverEvent
		arg	rcvid, event
		prologue

		; Get the TCB address of sender
		mov	eax,[%$rcvid]
		call	K_DecodeRcvid
		jc	.Exit

		; Check if sigevent address is okay
		mov	edx,[%$event]
		add	edx,USERAREASTART
		jc	.Fault
		mov	eax,[edx+tSigEvent.SigEvNotify]

		; Examine notification type
		cmp	eax,SIGEV_THREAD
		ja	.Invalid
		cmp	al,SIGEV_NONE
		je	.Exit
		cmp	al,SIGEV_SIGNAL
		je	.Signal
		cmp	al,SIGEV_SIGNAL_CODE
		je	.SignalCode
		cmp	al,SIGEV_SIGNAL_THREAD
		je	.SignalThread
		cmp	al,SIGEV_PULSE
		je	.Pulse
		cmp	al,SIGEV_UNBLOCK
		je	.Unblock
		cmp	al,SIGEV_INTR
		je	.Interrupt

		; Create a new thread
		jmp	.Exit

		; Send a signal
.Signal:
		jmp	.Exit

		; Send a signal with data
.SignalCode:
		jmp	.Exit

		; Send a signal to a specific thread
.SignalThread:
		jmp	.Exit

		; Send a pulse. Check if a connection is still attached first.
.Pulse:		mov	eax,[%$rcvid]
		shr	eax,16
		call	FindConnByNum
		jc	.Exit
		mov	cl,[edx+tSigEvent.SigEvCode]
		mov	eax,[edx+tSigEvent.SigEvVal]
		call	K_SendPulse
		jmp	.Exit

		; Simply unblock a thread
.Unblock:
		jmp	.Exit

		; Raise an interrupt
.Interrupt:

.Exit:		epilogue
		ret

.Fault:		mov	eax,-EFAULT
		jmp	.Exit
.Invalid:	mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int MsgVerifyEvent(int rcvid, const struct sigevent *event);
proc sys_MsgVerifyEvent
		arg	rcvid, event
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SignalKill(uint nd, pid_t pid, int tid, int signo,
		;		 int code, int value);
proc sys_SignalKill
		arg	nd, pid, tid, signo, code, value
		prologue

		mCurrThread ebx
		mov	esi,[ebx+tTCB.PCB]

		; If pid == 0, send a signal to the current pgrp.
		; If it is negative, send to pgrp of -pid.
		mov	eax,[%$pid]
		or	eax,eax
		jz	.Pgrp
		jns	.Single
		neg	eax
		call	R0_Pid2PCBaddr
		jc	.Exit
.Pgrp:

		; If tid != 0, send a signal only to that thread
.Single:	mov	eax,[%$tid]
		or	eax,eax

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SignalReturn(struct sighandler_info *info);
proc sys_SignalReturn
		arg	info
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void SignalFault(uint sigcode, void *regs, void *refaddr);
proc sys_SignalFault
		arg	sigcode, regs, refaddr
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SignalAction(pid_t pid, void (*sigstub()), int signo,
		;		   const struct sigaction *act,
		;		   struct sigaction *oact);
proc sys_SignalAction
		arg	pid, sigstub, signo, act, oact
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SignalProcmask(pid_t pid, int tid, int how,
		;		     const sigset_t *set, sigset_t *oldset);
proc sys_SignalProcmask
		arg	pid, tid, how, set, oldset
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SignalSuspend(const sigset_t *set);
proc sys_SignalSuspend
		arg	set
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int SignalWaitInfo(const sigset_t *set, siginfo_t *info);
proc sys_SignalWaitinfo
		arg	set, info
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------
