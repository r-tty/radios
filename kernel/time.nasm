;-------------------------------------------------------------------------------
; time.nasm - routines for dealing with time, date and delays.
;-------------------------------------------------------------------------------

module kernel.time

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "perm.ah"
%include "time.ah"

publicproc K_InitTime, K_TTDelay, K_LDelay, K_LDelayMs
publicproc sys_ClockTime, sys_ClockAdjust, sys_ClockPeriod, sys_ClockId
publicdata ?RTticks

externproc PIC_EnableIRQ, CMOS_EnableInt
externdata ?TicksCounter, ?CPUspeed


section .bss

?RTticks	RESQ	1


section .text

		; K_InitTime - initialize RTC, enable CMOS interrupts
		;		and set the system RT clock.
		; Input: none.
		; Output: none.
proc K_InitTime
		mov	al,2
		call	PIC_EnableIRQ
		mov	al,8
		call	PIC_EnableIRQ
		call	CMOS_EnableInt
		ret
endp		;---------------------------------------------------------------


		; K_TTDelay - kernel delay (using timer ticks counter).
		; Input: ECX=number of quantum of times in delay.
		; Output: none.
proc K_TTDelay
		mpush	eax,ecx
		mov	eax,[?TicksCounter]
		lea	ecx,[eax+ecx]
.Loop:		mov	eax,[?TicksCounter]
		cmp	eax,ecx
		jb	.Loop
		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; K_LDelay - kernel delay (using LOOP).
		; Input: ECX=number of repeats in loop.
		; Output: none.
		; Note: uses ?CPUspeed variable.
proc K_LDelay
		mpush	eax,ecx,edx
		xor	edx,edx
		mov	eax,[?CPUspeed]
		mul	ecx
		mov	ecx,eax
		align 4
.LDel:		nop
		dec	ecx
		js	short .Exit
		jmp	.LDel
.Exit:		mpop	edx,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; K_LDelayMs - loop delay (in milliseconds)
		; Input: ECX=time of delay (ms).
		; Output: none.
proc K_LDelayMs
		mpush	eax,ecx,edx
		mov	eax,159
		xor	edx,edx
		mul	ecx
		mov	ecx,eax
		call	K_LDelay
		mpop	edx,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; K_MicroDelay - loop delay (in microseconds)
		; Input: ECX=number of microseconds.
		; Output: none.
proc K_MicroDelay
		ret
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------

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


proc sys_ClockAdjust
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_ClockPeriod
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


proc sys_ClockId
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
