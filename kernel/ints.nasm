;-------------------------------------------------------------------------------
; ints.nasm - interrupt handler routines.
;-------------------------------------------------------------------------------

%include "cpu/stkframe.ah"

publicproc K_InitIDT

library kernel.syscall
extern K_SysInt, K_DebugServEntry

library kernel.mt
extern K_SwitchTask

library kernel.paging
extern PG_FaultHandler, PG_AllocContBlock

library kernel.x86.basedev
extern CMOS_HandleInt, FPU_HandleException

; *** Macros for generating entry points for CPU traps and interrupts.
; *** We push supplied code value for ones without it.
%macro mTrapEntry 1
	pushimm %1
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

; *** Macro for temporary exception stubs
%macro mExceptionHandler 2
Exception%1Handler:
	mov	byte [?ExceptionNum],%1
	call	%2
%endmacro

; *** Macros for interrupt service routines (ISRs).
; *** Parameters: %1=IRQ number, %2=procedure name.

; For first interrupt controller
%macro mISR 2
K_ISR%1:
	mTrapEntry %1
	mPICACK 0
	call	%2
	mTrapLeave
%endmacro

; For second interrupt controller
%macro mISR2 2
K_ISR%1:
	mTrapEntry %1
	mPICACK 1
	call	%2
	mTrapLeave
%endmacro

; *** Macro for service traps (used by some syscalls)
; *** Parameters: %1=trap number, %2=procedure name.
%macro mServTrapHandler 2
ServTrap%1Handler:
	mTrapEntry %1
	call	%2
	mTrapLeave
%endmacro

; --- Data ---

section .data

IRQhandlers	DD	0			; IRQ0: timer
		DD	0			; IRQ1: keyboard
		DD	0			; IRQ2: cascade (unused)
		DD	0			; IRQ3
		DD	0			; IRQ4
		DD	0			; IRQ5
		DD	0			; IRQ6
		DD	0			; IRQ7
		DD	CMOS_HandleInt		; IRQ8: CMOS RTC
		DD	0			; IRQ
		DD	0			; IRQ10
		DD	0			; IRQ11
		DD	0			; IRQ12
		DD	FPU_HandleException	; IRQ13: 387 FPU
		DD	0			; IRQ14
		DD	0			; IRQ15

ServTrapFunct	DD	0			; INT 30h
		DD	0			; INT 31h
		DD	0			; INT 32h
		DD	0			; INT 33h
		DD	0			; INT 34h
		DD	0			; INT 35h
		DD	0			; INT 36h
		DD	0			; INT 37h
		DD	K_SysInt		; INT 38h
		DD	0			; INT 39h
		DD	0			; INT 3Ah
		DD	0			; INT 3Bh
		DD	0			; INT 3Ch
		DD	0			; INT 3Dh
		DD	0			; INT 3Eh
		DD	K_DebugServEntry	; INT 3Fh

MsgUnhExcept	DB	"Panic, unhandled exception ",0
MsgReservedExc	DB	"Panic, reserved exception",0


; --- Variables ---

section .bss

?ExceptionNum	RESB	1			; Last exception number


; --- Code ---

section .text

		; K_Interrupt - routine to serve all hardware interrupts.
		; Note: stack frame (with interrupt number as the error code)
		;	must be on the stack (together with caller's return
		;	address of course).
proc K_Interrupt
		mov	eax,[esp+4+tStackFrame.Err]	; EAX=IRQ number
		mov	eax,[IRQhandlers+eax*4]		; EAX=handler address
		or	eax,eax
		jz	short .Done
		jmp	eax
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


		; Even more weird thing - reserved exception..
proc K_ReservedException
		mServPrintStr MsgReservedExc
		hlt
		jmp	$
endp		;---------------------------------------------------------------


		; Page fault entry
proc K_PageFaultEntry
		mTrapEntryWithErr
		call	PG_FaultHandler
		mTrapLeave
endp		;---------------------------------------------------------------


		; Service trap handler. It gets a trap number on the stack
		; (like hardware interrupt handler gets its IRQ).
proc K_ServTrap
		mov	eax,[esp+4+tStackFrame.Err]	; EAX=trap number
		sub	eax,48
		mov	eax,[ServTrapFunct+eax*4]	; EAX=function number
		or	eax,eax
		jz	short .Done
		jmp	eax
.Done:		ret
endp		;---------------------------------------------------------------


		; Build IDT and initialize IDTR
		; Input: none.
		; Output: none.
proc K_InitIDT
		mov	ecx,IDT_size
		xor	edx,edx
		call	PG_AllocContBlock
		mov	[IDTaddrLim+2],ebx
		mov	esi,TrapHandlersArr
		mov	ecx,IDT_size/tGateDesc_size
		cld

.Loop:		mov	eax,[esi]
		cmp	esi,TrapHandlersArrEnd
		jb	.Present
		mov	[ebx],edx
		mov	[ebx+4],edx				; Mark as absent
		jmp	.Next
		
.Present:	mov	[ebx+tGateDesc.OffsetLo],ax
		mov	word [ebx+tGateDesc.Selector],KERNELCODE
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax

		cmp	esi,K_ISR0			; Exception?
		jb	.Exception
		cmp	esi,ServTrap48Handler		; Service trap?
		jae	.UserTrap
		mov	byte [ebx+tGateDesc.Type],AR_IntGate+AR_DPL0+ARpresent
		jmp	.Next

.Exception:	mov	byte [ebx+tGateDesc.Type],AR_TrapGate+AR_DPL0+ARpresent
		jmp	.Next

.UserTrap:	mov	byte [ebx+tGateDesc.Type],AR_TrapGate+AR_DPL3+ARpresent

.Next:		add	esi,byte 4
		add	ebx,byte tGateDesc_size
		loop	.Loop

		lidt	[IDTaddrLim]
		ret
endp		;---------------------------------------------------------------

; Exception handlers
mExceptionHandler 0,K_UnhandledException
mExceptionHandler 1,K_UnhandledException
mExceptionHandler 2,K_UnhandledException
mExceptionHandler 3,K_UnhandledException
mExceptionHandler 4,K_UnhandledException
mExceptionHandler 5,K_UnhandledException
mExceptionHandler 6,K_UnhandledException
mExceptionHandler 7,K_UnhandledException
mExceptionHandler 8,K_UnhandledException
mExceptionHandler 9,K_UnhandledException
mExceptionHandler 10,K_UnhandledException
mExceptionHandler 11,K_UnhandledException
mExceptionHandler 12,K_UnhandledException
mExceptionHandler 13,K_UnhandledException
mExceptionHandler 14,K_PageFaultEntry
mExceptionHandler 15,K_UnhandledException
mExceptionHandler 16,K_UnhandledException
mExceptionHandler 17,K_UnhandledException

; Hardware Interrupt Service Soutines (ISRs)

mISR 0,K_SwitchTask
mISR 1,K_Interrupt
mISR 2,K_Interrupt
mISR 3,K_Interrupt
mISR 4,K_Interrupt
mISR 5,K_Interrupt
mISR 6,K_Interrupt
mISR 7,K_Interrupt
mISR2 8,K_Interrupt
mISR2 9,K_Interrupt
mISR2 10,K_Interrupt
mISR2 11,K_Interrupt
mISR2 12,K_Interrupt
mISR2 13,K_Interrupt
mISR2 14,K_Interrupt
mISR2 15,K_Interrupt

; Service trap handlers (used by some syscalls)
mServTrapHandler 48,K_ServTrap
mServTrapHandler 49,K_ServTrap
mServTrapHandler 50,K_ServTrap
mServTrapHandler 51,K_ServTrap
mServTrapHandler 52,K_ServTrap
mServTrapHandler 53,K_ServTrap
mServTrapHandler 54,K_ServTrap
mServTrapHandler 55,K_ServTrap
mServTrapHandler 56,K_ServTrap
mServTrapHandler 57,K_ServTrap
mServTrapHandler 58,K_ServTrap
mServTrapHandler 59,K_ServTrap
mServTrapHandler 60,K_ServTrap
mServTrapHandler 61,K_ServTrap
mServTrapHandler 62,K_ServTrap
mServTrapHandler 63,K_ServTrap
