;-------------------------------------------------------------------------------
;  ints.nasm - interrupt handlers.
;-------------------------------------------------------------------------------

%include "x86/stkframe.ah"

library kernel.mt
extern K_SwitchTask

library kernel.paging
extern PG_FaultHandler

library kernel.x86.basedev
extern CMOS_HandleInt, FPU_HandleException

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
	mov	byte [?ExceptionNum],%1
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

IRQdrivers	DD	0			; IRQ0: timer
		DD	0			; IRQ1: keyboard
		DD	0			; IRQ2: cascade (unused)
		DD	0			; IRQ3
		DD	0			; IRQ4
		DD	0			; IRQ5
		DD	0			; IRQ6
		DD	0			; IRQ7
		DD	0			; IRQ8: CMOS RTC
		DD	0			; IRQ
		DD	0			; IRQ10
		DD	0			; IRQ11
		DD	0			; IRQ12
		DD	0			; IRQ13: 387 FPU
		DD	0			; IRQ14
		DD	0			; IRQ15

MsgUnhExcept	DB	"Panic, unhandled exception ",0

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
;		push	byte DRVF_HandleEv
;		call	DRV_CallDriver
.Done:		ret
endp		;---------------------------------------------------------------


		; When some exception is occured and it's not handled
		; by anyone, we only can panic..
proc K_UnhandledException
		mServPrintStr MsgUnhExcept
		movzx	eax,byte [?ExceptionNum]
		mServPrintDec
		hlt
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
mTrapHandler 0,K_UnhandledException
mTrapHandler 1,K_UnhandledException
mTrapHandler 2,K_UnhandledException
mTrapHandler 3,K_UnhandledException
mTrapHandler 4,K_UnhandledException
mTrapHandler 5,K_UnhandledException
mTrapHandler 6,K_UnhandledException
mTrapHandler 7,K_UnhandledException
mTrapHandler 8,K_UnhandledException
mTrapHandler 9,K_UnhandledException
mTrapHandler 10,K_UnhandledException
mTrapHandler 11,K_UnhandledException
mTrapHandler 12,K_UnhandledException
mTrapHandler 13,K_UnhandledException
mTrapHandler 14,K_PageFaultEntry
mTrapHandler 15,K_UnhandledException
mTrapHandler 16,K_UnhandledException
mTrapHandler 17,K_UnhandledException

; Interrupt service routines (ISRs)

mISR K_SwitchTask, 0
mISR K_Interrupt, 1
mISR K_Interrupt, 2
mISR K_Interrupt, 3
mISR K_Interrupt, 4
mISR K_Interrupt, 5
mISR K_Interrupt, 6
mISR K_Interrupt, 7
mISR2 CMOS_HandleInt, 8
mISR2 K_Interrupt, 9
mISR2 K_Interrupt, 10
mISR2 K_Interrupt, 11
mISR2 K_Interrupt, 12
mISR2 FPU_HandleException, 13
mISR2 K_Interrupt, 14
mISR2 K_Interrupt, 15
