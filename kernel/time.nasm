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
exportdata ?RTticks

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
