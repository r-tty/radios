;*******************************************************************************
; setjmp.h - setjmp/longjmp pair.
; Copyright (c) 1996 Andy Valencia (original VSTa version)
;*******************************************************************************

module kernel.setjmp

%include "i386/setjmp.ah"

; --- Exports ---

global K_SetJmp, K_LongJmp


; --- Code ---

		; K_SetJmp - save context, returning 0 (C-style).
		; Input: address of tJmpBuf structure must be in a stack.
		; Output: EAX=0.
proc K_SetJmp
		push	edi
		mov	edi,[esp+8]			; JmpBuf pointer
		mov	eax,[esp+4]			; Return address
		mov	[edi+tJmpBuf.R_EIP],eax
		pop	eax				; EAX=original EDI value
		mov	[edi+tJmpBuf.R_EDI],eax
		mov	[edi+tJmpBuf.R_ESI],esi
		mov	[edi+tJmpBuf.R_EBP],ebp
		mov	[edi+tJmpBuf.R_ESP],esp
		mov	[edi+tJmpBuf.R_EBX],ebx
		mov	[edi+tJmpBuf.R_EDX],edx
		mov	[edi+tJmpBuf.R_ECX],ecx
		mov	edi,[edi+tJmpBuf.R_EDI]		; Restore EDI value
		xor	eax,eax
		ret
endp		;---------------------------------------------------------------


		; K_LongJmp - restore context, returning a specified result
		;	      (C-style).
		; Input: EDI=address of tJmpBuf structure,
		;	 EAX=value (0 or 1).
		; Output: none.
proc K_LongJmp
		mov	[edi+tJmpBuf.R_EAX],eax
		mov	esp,[edi+tJmpBuf.R_ESP]
		mov	eax,[edi+tJmpBuf.R_EIP]
		mov	[esp],eax
		mov	esi,[edi+tJmpBuf.R_ESI]
		mov	ebp,[edi+tJmpBuf.R_EBP]
		mov	ebx,[edi+tJmpBuf.R_EBX]
		mov	edx,[edi+tJmpBuf.R_EDX]
		mov	ecx,[edi+tJmpBuf.R_ECX]
		mov	eax,[edi+tJmpBuf.R_EAX]
		mov	edi,[edi+tJmpBuf.R_EDI]
		sti
		ret
endp		;---------------------------------------------------------------

