;-------------------------------------------------------------------------------
; clock.nasm - clock system calls.
;-------------------------------------------------------------------------------

module tm.kern.clock

%include "sys.ah"
%include "errors.ah"
%include "perm.ah"
%include "thread.ah"
%include "time.ah"
%include "tm/kern.ah"

publicdata ClockSyscallTable

importdata ?RTticks

; --- System call table ---

section .data

ClockSyscallTable:
mSyscallTabEnt ClockTime, 3
mSyscallTabEnt ClockAdjust, 3
mSyscallTabEnt ClockPeriod, 3
mSyscallTabEnt ClockId, 2
mSyscallTabEnt 0


; --- Code ---

section .text

		; int ClockTime(clockid_t id, const uint64_t *new, uint64_t *old);
proc sys_ClockTime
		arg	id, newt, oldt
		prologue

		; Currently we support only real time clock
		mov	eax,[%$id]
		cmp	eax,CLOCK_REALTIME
		jne	.Inval

		; Is the old time requested?
		mov	edi,[%$oldt]
		or	edi,edi
		jz	.CheckPerm

		; Check if the buffer is OK
		add	edi,USERAREACHECK
		jc	.Fault
		mov	eax,edi
		add	eax,byte 7
		jc	.Fault

		; Store the old time
		mov	eax,[?RTticks]
		mov	[edi],eax
		mov	eax,[?RTticks+4]
		mov	[edi+4],eax

		; Check if user wants to set new time
		mov	esi,[%$newt]
		or	esi,esi
		jz	.Success
		add	esi,USERAREACHECK
		jc	.Fault
		mov	eax,esi
		add	eax,byte 7
		jc	.Fault

		; Does he have enough privileges?
.CheckPerm:	mCurrThread ebx
		mIsRoot [ebx+tTCB.PCB]
		jc	.Perm

		; Set time
		mov	eax,[esi]
		mov	[?RTticks],eax
		mov	eax,[esi+4]
		mov	[?RTticks+4],eax

		; All OK
.Success:	xor	eax,eax

.Exit:		epilogue
		ret

.Inval:		mov	eax,-EINVAL
		jmp	.Exit
.Perm:		mov	eax,-EPERM
		jmp	.Exit
.Fault:		mov	eax,-EPERM
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int ClockAdjust(clockid_t id, const struct clockadjust *new,
		;		  struct clockadjust *old);
proc sys_ClockAdjust
		arg	id, new, old
		prologue

		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ClockAdjust(clockid_t id, const struct clockperiod *new,
		;		  struct clockperiod *old, int reserved);
proc sys_ClockPeriod
		arg	id, new, old, reserved
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int ClockId(pid_t pid, int tid);
proc sys_ClockId
		arg	pid, tid
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
