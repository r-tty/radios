;-------------------------------------------------------------------------------
; posix/1_signal.nasm - POSIX signal routines.
;-------------------------------------------------------------------------------

module libc.signal

%include "errors.ah"
%include "locstor.ah"
%include "siginfo.ah"

exportproc _signal, _sigaction, _sigprocmask, _sigpending, _sigsuspend

externproc _SignalAction, _SignalProcmask, _SignalSuspend, _SignalReturn

section .text

		; int SignalStub(struct sighandler_info *ptr);
proc SignalStub
		; Get a context pointer and save the registers
		mov	eax,[esp+tSigHandlerInfo.Context]
		mov	[eax+tUcontext.rEDI],edi
		mov	[eax+tUcontext.rESI],esi
		mov	[eax+tUcontext.rEBP],ebp
		mov	[eax+tUcontext.rEBX],ebx
		mov	[eax+tUcontext.rEDX],edx
		mov	[eax+tUcontext.rECX],ecx
		mov	esi,esp
		mov	edi,eax

		; Call the user signal handler. Its prototype looks like this:
		; void handler(signo, siginfo_t *, ucontext_t *);
		mpush	eax,esi,dword [esi+tSigInfo.SigNo]
		call	dword [esi+tSigHandlerInfo.Handler]
	
		push	esi
		mov	eax,edi
		mov	edi,[eax+tUcontext.rEDI]
		mov	esi,[eax+tUcontext.rESI]
		mov	ebp,[eax+tUcontext.rEBP]
		mov	ebx,[eax+tUcontext.rEBX]
		mov	edx,[eax+tUcontext.rEDX]
		mov	ecx,[eax+tUcontext.rECX]

		; This call won't return
		call	_SignalReturn
endp		;---------------------------------------------------------------


		; void (*signal(int signo, void (*func)(int)))(int);
proc _signal
		arg	signo, func
		locauto	act, tSigAction_size
		prologue
		savereg	ebx

		lea	ebx,[%$act]
		Mov32	ebx+tSigAction.Handler,%$func
		xor	eax,eax
		mov	[ebx+tSigAction.Flags],eax
		mov	[ebx+tSigAction.Mask],eax
		mov	[ebx+tSigAction.Mask+4],eax

		Ccall	_sigaction, dword [%$signo], ebx, ebx
		test	eax,eax
		jnz	.Sigerr
		mov	eax,[ebx+tSigAction.Handler]

.Exit		epilogue
		ret

.Sigerr:	mov	eax,SIG_ERR
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int sigaction(int signo, const struct sigaction *act,
		;		struct sigaction *oact);
proc _sigaction
		arg	signo, act, oact
		prologue
		Ccall	_SignalAction, byte 0, SignalStub, dword [%$signo], \
			dword [%$act], dword [%$oact]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sigprocmask(int how, const sigset_t *set, sigset_t *oset);
proc _sigprocmask
		arg	how, set, oset
		prologue
		cmp	dword [%$how],SIG_SETMASK
		jbe	.Proceed
		mSetErrno EINVAL, eax
		xor	eax,eax
		dec	eax
		jmp	.Exit
.Proceed:	Ccall	_SignalProcmask, byte 0, byte 0, dword [%$how], \
			dword [%$set], dword [%$oset]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sigpending(sigset_t *set);
proc _sigpending
		arg	sigset
		prologue
		Ccall	_SignalProcmask, 0, 0, SIG_PENDING, 0, dword [%$sigset]
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int sigsuspend(const sigset_t *set);
proc _sigsuspend
		jmp	_SignalSuspend
endp		;---------------------------------------------------------------

