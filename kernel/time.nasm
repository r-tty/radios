;-------------------------------------------------------------------------------
; time.nasm - routines for dealing with time, date and delays.
;-------------------------------------------------------------------------------

module kernel.time

publicproc K_TTDelay, K_LDelay, K_LDelayMs

library kernel.mt
extern ?TicksCounter

library kernel
extern ?CPUspeed

section .text

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


; ========================== Time/date procedures ==============================

		; K_GetDate - get current date.
		; Input: none.
		; Output: BL=day,
		;	  BH=month,
		;	  CX=year.
proc K_GetDate
		ret
endp		;---------------------------------------------------------------


		; K_GetTime - get current time.
		; Input: none.
		; Output: BH=hour,
		;	  BL=minute,
		;	  CL=second.
proc K_GetTime
		ret
endp		;---------------------------------------------------------------


		; K_SetSysDate - set system date.
		; Input: AH=seconds,
		;	 BL=minutes,
		;	 BH=hours,
		;	 DL=day,
		;	 DH=month,
		;	 CX=year.
		; Output:
proc K_SetSysDate
		ret
endp		;---------------------------------------------------------------

