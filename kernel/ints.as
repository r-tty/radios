;-------------------------------------------------------------------------------
;  ints.as - interrupt handlers.
;-------------------------------------------------------------------------------

%include "i386/stkframe.ah"

; Macros for generating entry points for CPU traps and interrupts.
; We push supplied code value for ones without it.
%macro mTrapEntry 1
%if %1<128
	push	byte %1
%else
	push	dword %1
%endif
	cld
	mSaveRegs
%endmacro

%macro mTrapEntryWithErr 0
	cld
	mSaveRegs
%endmacro

%macro mTrapLeave 0
	mRestoreRegs
	add	esp,byte 4
	iret
%endmacro

; Macro for temporary trap stubs
%macro mIntHandler 2
Int%1Handler:
%if %2 != 0
	mov	byte [ExceptionNum],%1
	call	%2
%endif
%endmacro


section .data

; Table of drivers for each IRQ

IRQdrivers	DD	0			; 0: timer (handled by kernel)
		DD	DRVID_Keyboard		; 1: keyboard
		DD	0			; 2: cascade (unused)
		DD	DRVID_Serial		; 3: serial port 2
		DD	DRVID_Serial		; 4: serial port 1
		DD	DRVID_Audio		; 5: audio (SB)
		DD	DRVID_FDD		; 6: floppy
		DD	DRVID_Parallel		; 7: parallel port
		DD	0			; 8: CMOS RTC (handled by kernel)
		DD	0			; 9: unused
		DD	0			; 10: unused
		DD	0			; 11: unused
		DD	0			; 12: unused
		DD	0			; 13: 387 FPU (handled by kernel)
		DD	DRVID_HDIDE		; 14: primary IDE interface
		DD	DRVID_HDIDE		; 15: secondary IDE interface


section .text

; Temporary exception handler
proc K_TmpExcHandler
		mov	ebx,0B8000h
		add	bl,[ExcPrintPos]
		mov	al,[ExceptionNum]
		mov	ah,15
		mov	[ebx],ax
		add	byte [ExcPrintPos],2
		jmp	$
endp		;---------------------------------------------------------------


; Exception handler stubs
mIntHandler Reserved,0
mIntHandler 0,K_TmpExcHandler
mIntHandler 1,K_TmpExcHandler
mIntHandler 2,K_TmpExcHandler
mIntHandler 3,K_TmpExcHandler
mIntHandler 4,K_TmpExcHandler
mIntHandler 5,K_TmpExcHandler
mIntHandler 6,K_TmpExcHandler
mIntHandler 7,K_TmpExcHandler
mIntHandler 8,K_TmpExcHandler
mIntHandler 9,K_TmpExcHandler
mIntHandler 10,K_TmpExcHandler
mIntHandler 11,K_TmpExcHandler
mIntHandler 12,K_TmpExcHandler
mIntHandler 13,K_TmpExcHandler
mIntHandler 14,K_TmpExcHandler
mIntHandler 15,K_TmpExcHandler
mIntHandler 16,K_TmpExcHandler
mIntHandler 17,K_TmpExcHandler


; IRQ handlers
		; IRQ0: system timer.
proc IRQ0Handler
		mTrapEntry 0
		mov	eax,[TimerTicksLo]
		inc	eax
		mov	[TimerTicksLo],eax
		or	eax,eax
		jz	.SetTTHi
		jmp	short .1
.SetTTHi:	inc	dword [TimerTicksHi]

.1:		mPICACK 0
		call	K_SwitchTask
		mTrapLeave
endp		;---------------------------------------------------------------


		; IRQ1: keyboard.
proc IRQ1Handler
		sti
		mpush	eax,edx
		mov	eax,(EV_IRQ << 16)+1
		push	dword [IRQdrivers+4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ2Handler
		push	eax
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 3: serial ports #2 & #4
proc IRQ3Handler
		mpush	eax,edx
		mov	eax,(EV_IRQ << 16)+3
		push	dword [IRQdrivers+3*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 4: serial ports #1 & #3
proc IRQ4Handler
		mpush	eax,edx
		mov	eax,(EV_IRQ << 16)+4
		push	dword [IRQdrivers+4*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 5: audio device.
proc IRQ5Handler
		mpush	eax,edx
		mov	eax,(EV_IRQ << 16)+5
		push	dword [IRQdrivers+5*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 6: FDD.
proc IRQ6Handler
		mpush	eax,edx
		mov	eax,(EV_IRQ << 16)+6
		push	dword [IRQdrivers+6*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 7: parallel port #1.
proc IRQ7Handler
		mpush	eax,edx
		mov	eax,(EV_IRQ << 16)+7
		push	dword [IRQdrivers+7*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------



		; IRQ 8: CMOS real-time clock.
proc IRQ8Handler
		push	eax
		call	CMOS_HandleInt
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ9Handler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ10Handler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ11Handler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ12Handler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ13Handler
		push	eax
		call	FPU_HandleEvents
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ14Handler
		push	eax
		mov	eax,(EV_IRQ << 16)+0			; Interface 0
		push	dword [IRQdrivers+14*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc IRQ15Handler
		push	eax
		mov	eax,(EV_IRQ << 16)+1			; Interface 1
		push	dword [IRQdrivers+15*4]
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------
