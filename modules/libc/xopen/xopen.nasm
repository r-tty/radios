;-------------------------------------------------------------------------------
; xopen.nasm - various routines described by X/Open specification.
;-------------------------------------------------------------------------------

module libc.xopen

%include "rmk.ah"
%include "time.ah"
%include "tm/procmsg.ah"

; Exports and publics

exportproc _usleep, _waitid, _poll
publicdata _environ

; Imports

externproc _clock_nanosleep
externproc _MsgSendv

; Variables

section .bss

_environ	RESD	1

; Code

section .text

		; int usleep(ulong usec);
proc _usleep
		arg	usec
		locauto	ts, tTimeSpec_size
		prologue
		mpush	ecx,edx
		mov	eax,[%$usec]
		mov	ecx,1000000
		xor	edx,edx
		div	ecx
		mov	[%$ts+tTimeSpec.Seconds],eax
		mov	eax,edx
		mov	ecx,1000
		mul	ecx
		mov	[%$ts+tTimeSpec.Nanoseconds],eax
		lea	edx,[%$ts]
		Ccall	_clock_nanosleep, CLOCK_REALTIME, 0, edx, 0
		mpop	edx,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int waitid(idtype_t idtype, id_t id, siginfo_t *infop,
		;		int options);
proc _waitid
		arg	idtype, id, infop, opts
		locauto	msg, tMsg_ProcWait_size
		locauto	iov, 2*tIOV_size
		prologue
		savereg	ebx,edx

		lea	ebx,[%$msg]
		mov	word [ebx+tProcWaitRequest.Type],PROC_WAIT
		Mov16	ebx+tProcWaitRequest.IDtype,%$idtype
		Mov32	ebx+tProcWaitRequest.ID,%$id
		Mov32	ebx+tProcWaitRequest.Options,%$opts
		lea	edx,[%$iov]
		mSetIOV	edx, 0, ebx, tProcWaitRequest_size
		mov	eax,[%$infop]
		mSetIOV	edx, 1, eax, tSigInfo_size
		lea	ebx,[edx+tIOV_size]
		or	eax,eax
		jz	.1
		xor	eax,eax
		inc	eax
.1:		Ccall	_MsgSendv, PROCMGR_COID, edx, byte 1, ebx, eax

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int poll(struct pollfd *ufds, uint nfds, int timeout);
proc _poll
		arg	ufds, nfds, timeout
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
