;-------------------------------------------------------------------------------
; unix.nasm - differenyt routines present in *BSD and other Unices.
;-------------------------------------------------------------------------------

module libc.unix

%include "rmk.ah"
%include "errors.ah"
%include "locstor.ah"
%include "resource.ah"
%include "tm/wait.ah"
%include "tm/signal.ah"

exportproc _wait4

externproc _waitid

section .text

		; pid_t wait4(pid_t pid, int *stat_loc, int options,
		;		struct rusage *resource_usage);
proc _wait4
		arg	pid, statloc, opts, resusg
		locauto	info, tSigInfo_size
		prologue
		savereg	ebx,ecx,edx,edi

		xor	edx,edx
		mov	eax,[%$pid]
		test	eax,eax
		jz	.All
		js	.PGID
		mov	dl,P_PID
		jmp	.WaitID

.All:		mov	dl,P_ALL
		jmp	.WaitID

.PGID:		neg	eax
		mov	dl,P_PGID

.WaitID:	lea	ebx,[%$info]
		or	dword [%$opts],WEXITED | WTRAPPED
		Ccall	_waitid, edx, eax, ebx, dword [%$opts]
		inc	eax
		jz	near .Exit
		xor	eax,eax
		cmp	dword [ebx+tSigInfo.SigNo],SIGCHLD
		jne	near .Exit

		mov	edx,[%$statloc]
		or	edx,edx
		jz	.ChkResUsg
		movzx	ecx,byte [ebx+tSigInfo.Status]
		mov	eax,[ebx+tSigInfo.Code]
		cmp	eax,NSIGCLD
		ja	.Inval
		cmp	al,CLD_EXITED
		je	.Exited
		cmp	al,CLD_KILLED
		je	.Killed
		cmp	al,CLD_DUMPED
		je	.Dumped
		cmp	al,CLD_TRAPPED
		je	.Stopped
		cmp	al,CLD_STOPPED
		je	.Stopped
		cmp	al,CLD_CONTINUED
		je	.Continued
.Inval:		mSetErrno EINVAL, eax
		xor	eax,eax
		dec	eax
		jmp	.Exit

.Exited:	shl	ecx,byte 8
		jmp	.SetStatLoc

.Killed:	and	cl,WSIGMASK
		jmp	.SetStatLoc

.Dumped:	and	cl,WSIGMASK
		or	cl,WCOREFLG
		jmp	.SetStatLoc

.Stopped:	and	cl,WSIGMASK
		shl	ecx,byte 8
		or	cl,WSTOPFLG
		jmp	.SetStatLoc

.Continued:	mov	ecx,WCONTFLG
.SetStatLoc:	mov	[edx],ecx

.ChkResUsg:	mov	edi,[%$resusg]
		or	edi,edi
		jz	.OK
		mov	ecx,tResUsage_size
		xor	eax,eax
		rep	stosb
		mov	ecx,CLOCKS_PER_SEC
		xor	edx,edx
		mov	eax,[ebx+tSigInfo.Utime]
		div	ecx
		mov	edi,[%$resusg]
		mov	[edi+tResUsage.Utime+tTimeVal.Seconds],eax
		mov	[edi+tResUsage.Utime+tTimeVal.Microseconds],edx
		xor	edx,edx
		mov	eax,[ebx+tSigInfo.Stime]
		div	ecx
		mov	[edi+tResUsage.Stime+tTimeVal.Seconds],eax
		mov	[edi+tResUsage.Stime+tTimeVal.Microseconds],edx
		
.OK:		mov	eax,[%$info+tSigInfo.PID]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
