
module kernel.ipc.event

%include "sys.ah"
%include "errors.ah"

%include "process.ah"

global K_HandleEvent

extern ?ProcListPtr

section .text

		; K_HandleEvent - immediate event handling.
		; Input: EDX=PID,
		;	 EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - return.
proc K_HandleEvent
%define	.selector	ebp-4				; Gate selector (far)
%define	.evhandler	ebp-8				; Handler address ()

		prologue 8
		push	ebx

		xchg	eax,edx
		mPID2PDA				; Get PDA
		mov	eax,[ebx+tProcDesc.EventHandler]
		test	byte [ebx+tProcDesc.Flags],PDFL_USER ; Intersegment?
		jz	.Kernel				; No,  call
		mov	[.selector],eax			; Else far call
		mov	dword [.evhandler],0

		mov	eax,edx
		call	dword far [.evhandler]
		jmp	short .Exit

.Kernel:	xchg	eax,edx
		call	edx

.Exit:		pop	ebx
		epilogue
		ret
endp		;---------------------------------------------------------------

