;-------------------------------------------------------------------------------
;  ints.as - interrupt handlers.
;-------------------------------------------------------------------------------

%include "x86/stkframe.ah"

extern PG_FaultHandler:near

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
%macro mTrapHandler 2
Trap%1Handler:
%if %2 != 0
	mov	byte [ExceptionNum],%1
	call	%2
%endif
%endmacro

; Macros for interrupt service routines (ISRs).
; Parameters: %1=procedure name, %2=IRQ number.

; For first interrupt controller
%macro mISR 2
K_ISR%2:
	mTrapEntry %2
	mPICACK 0
	call	%1
	mTrapLeave
%endmacro

; For second interrupt controller
%macro mISR2 2
K_ISR%2:
	mTrapEntry %2
	mPICACK 1
	call	%1
	mTrapLeave
%endmacro

; --- Data ---

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

		; K_Interrupt - routine to serve all hardware interrupts.
		; Note: stack frame (with interrupt number as the error code)
		;	must be on the stack (together with caller's return
		;	address of course).
proc K_Interrupt
		mov	eax,[esp+4+tStackFrame.Err]	; EAX=IRQ number
		mov	ebx,[IRQdrivers+eax*4]		; EAX=driver ID
		or	ebx,ebx
		jz	short .Done
		add	eax,(EV_IRQ << 16)		; Event code (IRQ)
		push	ebx
		push	byte DRVF_HandleEv
		call	DRV_CallDriver
.Done:		ret
endp		;---------------------------------------------------------------


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


		; Page fault entry
proc K_PageFaultEntry
		mTrapEntryWithErr
		call	PG_FaultHandler
		mTrapLeave
endp		;---------------------------------------------------------------


; Exception handlers
mTrapHandler Reserved,0
mTrapHandler 0,K_TmpExcHandler
mTrapHandler 1,K_TmpExcHandler
mTrapHandler 2,K_TmpExcHandler
mTrapHandler 3,K_TmpExcHandler
mTrapHandler 4,K_TmpExcHandler
mTrapHandler 5,K_TmpExcHandler
mTrapHandler 6,K_TmpExcHandler
mTrapHandler 7,K_TmpExcHandler
mTrapHandler 8,K_TmpExcHandler
mTrapHandler 9,K_TmpExcHandler
mTrapHandler 10,K_TmpExcHandler
mTrapHandler 11,K_TmpExcHandler
mTrapHandler 12,K_TmpExcHandler
mTrapHandler 13,K_TmpExcHandler
mTrapHandler 14,K_PageFaultEntry
mTrapHandler 15,K_TmpExcHandler
mTrapHandler 16,K_TmpExcHandler
mTrapHandler 17,K_TmpExcHandler

; Interrupt service routines (ISRs)

mISR K_SwitchTask, 0
mISR K_Interrupt, 1
mISR K_Interrupt, 2
mISR K_Interrupt, 3
mISR K_Interrupt, 4
mISR K_Interrupt, 5
mISR K_Interrupt, 6
mISR K_Interrupt, 7
mISR2 K_Interrupt, 8
mISR2 K_Interrupt, 9
mISR2 K_Interrupt, 10
mISR2 K_Interrupt, 11
mISR2 K_Interrupt, 12
mISR2 K_Interrupt, 13
mISR2 K_Interrupt, 14
mISR2 K_Interrupt, 15
