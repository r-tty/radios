;-------------------------------------------------------------------------------
; intterrupt.nasm - hardware and software interrupt handling.
;-------------------------------------------------------------------------------

module kernel.interrupt

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "pool.ah"
%include "siginfo.ah"
%include "hw/ports.ah"
%include "hw/pic.ah"
%include "macros/trap.ah"

publicproc K_InitInterrupts

publicproc sys_InterruptAttach, sys_InterruptDetach
publicproc sys_InterruptDetachFunc, sys_InterruptWait
publicdata IDTlimAddr

externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkAddr, K_PoolChunkNumber
externproc PG_Alloc, K_SetupExceptions
externproc K_SysInt, K_ServEntry, K_Ring0
externproc MT_ThreadSleep, MT_ThreadWakeup
externproc PIC_EnableIRQ, PIC_DisableIRQ
externproc K_SwitchTask, MT_Schedule
externproc BZero
externdata ?RTticks

; Number of hardware interrupt we can support
%define MAXIRQ	256

; High-level interrupt descriptor
struc tHLintDesc
.IRQnum		RESD	1			; IRQ number
.Handler	RESD	1			; User handler (or 0)
.SigEvent	RESD	1			; Communication area (or 0)
.TCB		RESD	1			; Address of TCB
.Flags		RESD	1			; INTR_* flags
.Next		RESD	1			; List link
.Prev		RESD	1
endstruc

section .data

IntHandlers:
%assign i 0
%rep 16							; IRQ handlers
		mDefineOffset K_ISR,i
%assign i i+1
%endrep

%assign i 48
%rep 16							; Service traps
		mDefineOffset ServTrap,i,Handler
%assign i i+1
%endrep

IDTlimAddr	DW	IDT_limit			; IDT address and limit
		DD	0

ServTrapFunct	DD	0			; INT 30h
		DD	0			; INT 31h
		DD	0			; INT 32h
		DD	0			; INT 33h
		DD	0			; INT 34h
		DD	0			; INT 35h
		DD	0			; INT 36h
		DD	0			; INT 37h
		DD	K_SysInt		; INT 38h
		DD	K_Ring0			; INT 39h
		DD	0			; INT 3Ah
		DD	0			; INT 3Bh
		DD	0			; INT 3Ch
		DD	0			; INT 3Dh
		DD	0			; INT 3Eh
		DD	K_ServEntry		; INT 3Fh


section .bss

?HLintDescPool	RESD	tMasterPool_size
?HLintHandlers	RESD	MAXIRQ


section .text

; Hardware Interrupt Service Soutines (ISRs)
mISR 0,K_SwitchTask
mISR 1,K_HandleIRQ
mISR 2,K_HandleIRQ
mISR 3,K_HandleIRQ
mISR 4,K_HandleIRQ
mISR 5,K_HandleIRQ
mISR 6,K_HandleIRQ
mISR 7,K_HandleIRQ
mISR2 9,K_HandleIRQ
mISR2 10,K_HandleIRQ
mISR2 11,K_HandleIRQ
mISR2 12,K_HandleIRQ
mISR2 13,K_HandleIRQ
mISR2 14,K_HandleIRQ
mISR2 15,K_HandleIRQ

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


		; K_InitInterrupts - build IDT, initialize IDTR and initialize
		;		     high-level interrupt handlers pool.
		; Input: EAX=maximum number of HLint descriptors.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc K_InitInterrupts
		; Get memory for IDT
		xor	edx,edx
		call	PG_Alloc
		jc	.Exit
		mov	[IDTlimAddr+2],eax
		mov	ebx,eax

		; Set up descriptors for all exceptions
		call	K_SetupExceptions
		mov	esi,IntHandlers
		cld

		; Set up descriptors of hardware and software interrupts
.Loop:		cmp	cl,64
		jae	.Absent
		lodsd
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	word [ebx+tGateDesc.Selector],KERNELCODE
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		cmp	cl,48
		jae	.SoftInt
		mov	byte [ebx+tGateDesc.Type],AR_IntGate+AR_DPL0+ARpresent
.Next:		add	ebx,byte tGateDesc_size
		inc	cl
		jnz	.Loop

		; Initialize IDTR
		lidt	[IDTlimAddr]

		; Initialize master pool of HLint descriptors
		mov	ebx,?HLintDescPool
		mov	cl,tHLintDesc_size
		call	K_PoolInit
.Exit:		ret

.SoftInt:	mov	byte [ebx+tGateDesc.Type],AR_TrapGate+AR_DPL3+ARpresent
		jmp	.Next

.Absent:	mov	[ebx],edx
		mov	[ebx+4],edx				; Mark as absent
		jmp	.Next
endp		;---------------------------------------------------------------


		; High-level hardware interrupt handler. If there is a user
		; handler for the interrupt, we will call it using SignalKill()
		; technique. Then, if there is a thread waiting for the
		; interrupt, we will wake it up and remove from the wait queue.
proc K_HandleIRQ
		lea	edx,[esp+4]

		; Go through the list invoking the handler (if there is one).
		; Also wake up threads waiting for this interrupt.
		mov	eax,[edx+tStackFrame.Err]
		mov	esi,[?HLintHandlers+eax*4]

.Loop:		or	esi,esi
		jz	.Exit
		mov	ebx,[esi+tHLintDesc.Handler]
		or	ebx,ebx
		jz	.SetPending
		call	K_RunUserIntHandler
.SetPending:	mov	ebx,[esi+tHLintDesc.TCB]
		inc	byte [ebx+tTCB.IntPending]
		cmp	byte [ebx+tTCB.State],THRSTATE_INTR
		jne	.Next
		call	MT_ThreadWakeup
		call	MT_Schedule
.Next:		mov	eax,esi
		mov	esi,[esi+tHLintDesc.Next]
		cmp	esi,eax
		jne	.Loop
.Exit		ret
endp		;---------------------------------------------------------------


		; Run user interrupt handler.
		; Input: ESI=address of HLint descriptor.
		; Output: none.
proc K_RunUserIntHandler
		ret
endp		;---------------------------------------------------------------


		; Fast RTC interrupt handler
		; Input: none.
		; Output: none.
proc K_ISR8
		push	ds
		push	es
		push	eax
		mov	ax,ss
		mov	ds,ax
		mov	al,0Ch
		out	PORT_CMOS_Addr,al
		PORTDELAY
		PORTDELAY
		in	al,PORT_CMOS_Data
		add	dword [?RTticks],1
		adc	dword [?RTticks+4],0
		mPICACK 1
		pop	eax
		pop	es
		pop	ds
		iret
endp		;---------------------------------------------------------------


		; Service trap handler. It gets a trap number on the stack
		; (like hardware interrupt handler gets its IRQ).
proc K_ServTrap
		mov	eax,[esp+4+tStackFrame.Err]	; EAX=trap number
		sub	eax,48
		mov	eax,[ServTrapFunct+eax*4]	; EAX=function number
		or	eax,eax
		jz	.Done
		jmp	eax
.Done:		ret
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------

		; int InterruptAttach(int intr, const struct sigevent *
		;		(* handler)(void *, int), const void *area,
		;		int size, unsigned flags);
proc sys_InterruptAttach
		arg	intr, handler, area, size, flags
		prologue

		; Get a new HLint descriptor and zero it
		mov	ebx,?HLintDescPool
		call	K_PoolAllocChunk
		jc	near .Again
		mov	ebx,esi
		mov	ecx,tHLintDesc_size
		call	BZero

		; If the handler is NULL, communication area must be valid
		; and its size must be at least tSigEvent_size
		mov	ebx,[%$handler]
		or	ebx,ebx
		jz	.VerifyArea
		mov	eax,ebx
		add	eax,USERAREASTART
		jc	near .Fault

		; Verify if communication area is OK
.VerifyArea:	mov	[esi+tHLintDesc.Handler],ebx
		mov	edx,[%$area]
		or	edx,edx
		jnz	.ChkAreaSize
		or	ebx,ebx
		jz	near .Fault
		jmp	.1
.ChkAreaSize:	mov	eax,edx
		add	eax,USERAREASTART
		jc	near .Fault
		mov	ecx,[%$size]
		cmp	ecx,tSigEvent_size
		jne	near .Fault
		dec	ecx
		add	eax,ecx
		jc	.Fault

		; Fill in HLint descriptor and enqueue it.
		; Flags are ignored for now.
.1:		mov	[esi+tHLintDesc.SigEvent],edx
		mCurrThread ebx
		mov	[esi+tHLintDesc.TCB],ebx
		mov	eax,[%$flags]
		mov	[esi+tHLintDesc.Flags],eax
		mov	eax,[%$intr]
		cmp	eax,MAXIRQ
		jae	.Inval
		mov	[esi+tHLintDesc.IRQnum],eax
		mEnqueue dword [?HLintHandlers+eax*4], Next, Prev, esi, tHLintDesc, ebx

		; If it's a first handler in the chain, unblock the interrupt
		mov	ebx,[?HLintHandlers+eax*4]
		cmp	[esi+tHLintDesc.Next],ebx
		jne	.2
		call	PIC_EnableIRQ

		; Return interrupt ID
.2:		call	K_PoolChunkNumber

.Exit:		epilogue
		ret

.Again:		mov	eax,-EAGAIN
		jmp	.Exit
.Fault:		mov	eax,-EFAULT
		jmp	.Exit
.Inval:		mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


proc sys_InterruptDetachFunc
		ret
endp		;---------------------------------------------------------------


		; int InterruptDetach(int id);
proc sys_InterruptDetach
		arg	id
		prologue

		; Check if interrupt ID is valid
		mov	ebx,?HLintDescPool
		call	K_PoolChunkAddr
		jc	.Inval

		; If it's only one handler in the chain, block this IRQ
		mov	eax,[esi+tHLintDesc.IRQnum]
		mov	ebx,[?HLintHandlers+eax*4]
		cmp	[esi+tHLintDesc.Next],ebx
		jne	.Deq
		call	PIC_DisableIRQ

		; Dequeue the descriptor and free it
.Deq:		mDequeue dword [?HLintHandlers+eax*4], Next, Prev, esi, tHLintDesc, ebx
		call	K_PoolFreeChunk

		; Return success
		xor	eax,eax

.Exit:		epilogue
		ret

.Inval:		mov	eax,-EINVAL
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int InterruptWait(int flags, const uint64 *timeout);
proc sys_InterruptWait
		; Get a current thread
		mCurrThread ebx

		; If there are interrupts pending - exit immediately
		cmp	byte [ebx+tTCB.IntPending],0
		jg	.GotInt

		; Otherwise just suspend ourselves
		mov	al,THRSTATE_INTR
		call	MT_ThreadSleep
		call	MT_Schedule

		; Decrease pending counter and return successfully
.GotInt:	dec	byte [ebx+tTCB.IntPending]
		xor	eax,eax
		ret
endp		;---------------------------------------------------------------
