;-------------------------------------------------------------------------------
; exception.nasm - CPU exception handling.
;-------------------------------------------------------------------------------

module kernel.exception

%define PFDEBUG

%include "sys.ah"
%include "macros/trap.ah"
%include "kcons.ah"
%include "thread.ah"
%include "tm/process.ah"

externproc PrintChar, PrintString, PrintByteHex, PrintDwordHex, PrintDwordDec
exportproc K_SetupExceptions, K_GetExceptionVec, K_SetExceptionVec

externproc K_GetGateOffset, K_GetGateSelector
externproc K_SetGateOffset, K_SetGateSelector
externproc PG_Alloc, PG_GetPTEaddr
externdata IDTlimAddr


section .data

ExceptionTable:
%assign i 0
%rep 18							; Exception handlers
		mDefineOffset Exception,i,Handler
%assign i i+1
%endrep

		TIMES 14 DD ExceptionReserved		; Reserved by Intel

TxtUnhExcept	DB	10,"Panic: unhandled exception ",0
TxtReservedExc	DB	10,"Panic: reserved exception",0

TxtPageFault	DB	10, "Page fault: CR2=",0
TxtReason	DB	", reason=",0
TxtPID		DB	", PID=",0
TxtPgAllocated	DB	"Alloc OK @ ",0
Txt~HandleViol	DB	"No abort() yet",0 
Txt~AllocPage	DB	"Cannot allocate new page",0
Txt~PageDir	DB	"Page directory absent",0
TxtHalt		DB	" - kernel halted",10,0


section .text

; Exception handlers
mExceptionTramp CPU_EXC_DIV0,	ExceptionCommon
mExceptionTramp CPU_EXC_SSTEP,	ExceptionCommon
mExceptionTramp CPU_EXC_NMI,	ExceptionCommon
mExceptionTramp CPU_EXC_BRPT,	ExceptionCommon
mExceptionTramp CPU_EXC_INTO,	ExceptionCommon
mExceptionTramp CPU_EXC_BOUND,	ExceptionCommon
mExceptionTramp CPU_EXC_INVOP,	ExceptionCommon
mExceptionTramp CPU_EXC_287,	ExceptionCommon
mExcErrTramp CPU_EXC_DBLFLT,	ExceptionCommon
mExceptionTramp 9,		ExceptionReserved
mExcErrTramp CPU_EXC_BADTSS,	ExceptionCommon
mExcErrTramp CPU_EXC_SEGMIS,	ExceptionCommon
mExcErrTramp CPU_EXC_STKFLT,	ExceptionCommon
mExcErrTramp CPU_EXC_GPF,	ExceptionCommon
mExceptionTramp 15,		ExceptionReserved
mExceptionTramp CPU_EXC_FPERR,	ExceptionCommon
mExcErrTramp CPU_EXC_ALIGN,	ExceptionCommon


		; K_SetupExceptions - initialize first 32 descriptors of IDT.
		; Input: EBX=address of IDT.
		; Output: EBX=address of INT 20h descriptor,
		;	  ECX=32.
		; Note: modifies ESI.
proc K_SetupExceptions
		mov	esi,ExceptionTable
		xor	ecx,ecx
		cld
.Loop:		lodsd
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	word [ebx+tGateDesc.Selector],KERNELCODE
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		cmp	cl,3
		je	.BreakPoint
		cmp	cl,14
		je	.PageFault
		mov	byte [ebx+tGateDesc.Type],AR_TrapGate+AR_DPL0+ARpresent
.Next:		add	ebx,byte tGateDesc_size
		inc	cl
		cmp	cl,32
		jne	.Loop
		ret

		; Page fault is interrupt, not trap (to grab CR2 safely)
.PageFault:	mov	byte [ebx+tGateDesc.Type],AR_IntGate+AR_DPL0+ARpresent
		jmp	.Next

		; Make the breakpoint possible in user mode
.BreakPoint:	mov	byte [ebx+tGateDesc.Type],AR_TrapGate+AR_DPL3+ARpresent
		jmp	.Next
endp		;---------------------------------------------------------------


		; K_GetExceptionVec - get exception handler selector
		;		      and offset.
		; Input: AL=vector number.
		; Output: DX=handler selector,
		;	  EBX=handler offset.
proc K_GetExceptionVec
		push	eax
		movzx	ebx,al
		shl	ebx,3				; Count gate address
		add	ebx,[IDTlimAddr+2]
		call	K_GetGateOffset
		call	K_GetGateSelector
		mov	ebx,eax
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_SetExceptionVec - set exception vector.
		; Input: DX=handler selector,
		;	 EBX=handler offset,
		;	 AL=vector number.
proc K_SetExceptionVec
		mpush	eax,ebx
		movzx	eax,al
		shl	eax,3				; Count gate address
		add	eax,[IDTlimAddr+2]
                xchg	eax,ebx
		call	K_SetGateOffset
		call	K_SetGateSelector
		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


		; Common code for all exceptions.
		; Currently just panics.
proc ExceptionCommon
		mov	ax,ss
		mov	ds,ax
		mov	es,ax
		kPrintStr TxtUnhExcept
		mov	eax,[esp+4]
		kPrintDec
		hlt
		jmp	$

		add	esp,byte 8
		iret
endp		;---------------------------------------------------------------


		; Even more weird thing - reserved exception..
proc ExceptionReserved
		mov	ax,ss
		mov	ds,ax
		mov	es,ax
		kPrintStr TxtReservedExc
		hlt
		jmp	$
endp		;---------------------------------------------------------------


		; Page fault trampoline.
proc Exception14Handler
		mTrapEntryWithErr
		call	K_HandlePageFault
		mTrapLeave
endp		;---------------------------------------------------------------


		; K_HandlePageFault - handle page faults.
		; Frame with error code is on the stack
proc K_HandlePageFault
		arg	frame
		prologue

		; Get fault address, then let interrupts back in.  This
		; minimizes latency on kernel preemption, while still keeping
		; a preempting task from hosing our CR2 value.
		mov	ebx,cr2
		sti
		mov	ch,[%$frame+tStackFrame.Err]
		and	ch,PG_ATTRIBUTES
%ifdef PFDEBUG
		kPrintStr TxtPageFault
		kPrint32h ebx
		kPrintStr TxtReason
		kPrint8h ch
		kPrintStr TxtPID
		mCurrThread
		mov	eax,[eax+tTCB.PCB]
		kPrintDec [eax+tProcDesc.PID]
		kPrintChar '.'
		kPrintChar ' '
%endif
		test	ch,PG_PRESENT			; Protection violation?
		jnz	.Violation

		; Page is absent - try to get one
		mov	edx,cr3
		call	PG_GetPTEaddr
		jc	.PageDirAbsent
		mov	dl,1
		call	PG_Alloc
		jc	.OutOfMem
		or	al,PG_WRITABLE
		test	ch,4				; User mode?
		jz	.1
		or	al,PG_USERMODE
.1:		mov	[edi],eax

%ifdef PFDEBUG
		kPrintStr TxtPgAllocated
		kPrint32h
		kPrintChar 10
%endif
		jmp	.Exit

.Violation:	kPrintStr Txt~HandleViol
		jmp	.Halt

.PageDirAbsent:	kPrintStr Txt~PageDir
		jmp	.Halt

.OutOfMem:	kPrintStr Txt~AllocPage
.Halt:		kPrintStr TxtHalt
		cli
		jmp	$

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
