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

exportproc K_CurrentSoftIntHandler, K_InstallSoftIntHandler
publicproc K_InitInterrupts

publicproc sys_InterruptAttach, sys_InterruptDetach
publicproc sys_InterruptDetachFunc, sys_InterruptWait
publicdata IDTlimAddr

externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkAddr, K_PoolChunkNumber
externproc PG_Alloc, K_SetupExceptions
externproc DebugKDOutput, K_SysInt, K_ServEntry, K_Ring0, K_UnimplSysCall
externproc MT_ThreadSleep, MT_ThreadWakeup
externproc PIC_EnableIRQ, PIC_DisableIRQ
externproc K_SwitchTask, MT_Schedule
externproc BZero
externdata ?RTticks

; Number of hardware interrupt we can support
%define MAXIRQ	64

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
%assign i 32
%rep 16						; Software interrupts
		mDefineOffset SoftInt,i,Handler
%assign i i+1
%endrep

%assign i 0
%rep MAXIRQ					; IRQ handlers
		mDefineOffset K_ISR,i
%assign i i+1
%endrep


IDTlimAddr	DW	IDT_limit		; IDT address and limit
		DD	0

SoftIntFunct	DD	0			; INT 20h
		DD	DebugKDOutput		; INT 21h
		DD	0			; INT 22h
		DD	0			; INT 23h
		DD	0			; INT 24h
		DD	0			; INT 25h
		DD	0			; INT 26h
		DD	0			; INT 27h
		DD	K_SysInt		; INT 28h
		DD	K_Ring0			; INT 29h
		DD	0			; INT 2Ah
		DD	0			; INT 2Bh
		DD	0			; INT 2Ch
		DD	K_UnimplSysCall		; INT 2Dh
		DD	0			; INT 2Eh
		DD	K_ServEntry		; INT 2Fh


section .bss

?HLintDescPool	RESD	tMasterPool_size
?HLintHandlers	RESD	MAXIRQ


section .text

; Hardware Interrupt Service Soutines (ISRs)
; First 8259 PIC
mISR 0,K_SwitchTask
%assign i 1
%rep 7
mISR i,K_HandleIRQ
%assign i i+1
%endrep

; Second 8259 PIC
%assign i 9
%rep 7
mISR2 i,K_HandleIRQ
%assign i i+1
%endrep

; For APIC - not used yet
%rep 48
mAISR i,K_HandleIRQ
%assign i i+1
%endrep

; Software interrupt handlers
mSoftIntHandler 32,K_SoftInt
mSoftIntHandler 33,K_SoftInt
mSoftIntHandler 34,K_SoftInt
mSoftIntHandler 35,K_SoftInt
mSoftIntHandler 36,K_SoftInt
mSoftIntHandler 37,K_SoftInt
mSoftIntHandler 38,K_SoftInt
mSoftIntHandler 39,K_SoftInt
mSoftIntHandler 40,K_SoftInt
mSoftIntHandler 41,K_SoftInt
mSoftIntHandler 42,K_SoftInt
mSoftIntHandler 43,K_SoftInt
mSoftIntHandler 44,K_SoftInt
mSoftIntHandler 45,K_SoftInt
mSoftIntHandler 46,K_SoftInt
mSoftIntHandler 47,K_SoftInt


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
.Loop:		cmp	cl,MAXIRQ+IRQVECTOR(0)
		jae	.Absent
		lodsd
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	word [ebx+tGateDesc.Selector],KERNELCODE
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		cmp	cl,IRQVECTOR(0)
		jb	.SoftInt
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


		; Software interrupt handler. It gets an interrupt number on
		; the stack (like hardware interrupt handler gets its IRQ).
proc K_SoftInt
		mov	eax,[esp+4+tStackFrame.Err]	; EAX=interrupt number
		sub	eax,SOFTINTSTART
		mov	eax,[SoftIntFunct+eax*4]	; EAX=function number
		or	eax,eax
		jz	.Done
		jmp	eax
.Done:		ret
endp		;---------------------------------------------------------------


		; Get an address of current software interrupt handler.
		; Input: AL=interrupt number.
		; Output: CF=0 - OK, EBX=handler address;
		;	  CF-1 - error.
proc K_CurrentSoftIntHandler
		sub	al,SOFTINTSTART
		jc	.Exit
		cmp	al,NUMSOFTINTS
		cmc
		jc	.Exit
		movzx	eax,al
		mov	ebx,[SoftIntFunct+eax*4]
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Install a new software interrupt handler.
		; Input: AL=interrupt number,
		;	 EBX=handler address.
		; Output: CF=0 - OK;
		;	  CF-1 - error.
proc K_InstallSoftIntHandler
		sub	al,SOFTINTSTART
		jc	.Exit
		cmp	al,NUMSOFTINTS
		cmc
		jc	.Exit
		movzx	eax,al
		mov	[SoftIntFunct+eax*4],ebx
		clc
.Exit:		ret
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


		; int InterruptDetachFunc(int id, void (*func)(void);
proc sys_InterruptDetachFunc
		arg	id, func
		prologue
		MISSINGSYSCALL
		epilogue
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
