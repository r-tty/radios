;-------------------------------------------------------------------------------
; setjmp.nasm - setjmp/longjmp pair, VSTa based.
;-------------------------------------------------------------------------------

module kernel.setjmp

%include "cpu/setjmp.ah"

publicproc K_SetJmp, K_LongJmp


section .text

		; K_SetJmp - save context, returning 0.
		; Input: EDI=address of tJmpBuf structure.
		; Output: EAX=0.
proc K_SetJmp
		mov	eax,[esp]			; Return address
		mov	[edi+tJmpBuf.R_EIP],eax
		mov	[edi+tJmpBuf.R_EDI],edi
		mov	[edi+tJmpBuf.R_ESI],esi
		mov	[edi+tJmpBuf.R_EBP],ebp
		mov	[edi+tJmpBuf.R_ESP],esp
		mov	[edi+tJmpBuf.R_EBX],ebx
		mov	[edi+tJmpBuf.R_EDX],edx
		mov	[edi+tJmpBuf.R_ECX],ecx
		xor	eax,eax
		ret
endp		;---------------------------------------------------------------


		; K_LongJmp - restore context, returning a specified result.
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
