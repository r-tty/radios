;-------------------------------------------------------------------------------
; tmif.nasm - privileged kernel entries, used only by a task manager.
;-------------------------------------------------------------------------------

module kernel.tmif

%include "sys.ah"
%include "errors.ah"
%include "cpu/stkframe.ah"

publicproc K_Ring0

externproc K_HashAdd, K_HashLookup, K_HashRelease
externproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk
externproc K_PoolChunkNumber, K_PoolChunkAddr
externproc PG_Alloc, PG_Dealloc
externproc K_CopyFromAct, K_CopyToAct
externproc K_RegisterLDT, K_UnregisterLDT

%define R0_NUMFUNC	14

section .data

Ring0functions	DD	K_HashAdd		; 0
		DD	K_HashLookup		; 1
		DD	K_HashRelease		; 2
		DD	K_PoolInit		; 3
		DD	K_PoolAllocChunk	; 4
		DD	K_PoolFreeChunk		; 5
		DD	K_PoolChunkNumber	; 6
		DD	K_PoolChunkAddr		; 7
		DD	PG_Alloc		; 8
		DD	PG_Dealloc		; 9
		DD	K_CopyFromAct		; 0Ah
		DD	K_CopyToAct		; 0Bh
		DD	K_RegisterLDT		; 0Ch
		DD	K_UnregisterLDT		; 0Dh

section .text

		; K_Ring0 - ring0 private interface (for taskman only).
		; Register frame is on the top of stack.
		; Function number is on the user's stack.
proc K_Ring0
		mov	eax,[esp+4+tStackFrame.ESP]
		mov	eax,[eax+USERAREASTART]		; Function number to EAX
		cmp	eax,R0_NUMFUNC
		cmc
		jc	.Err
		mov	eax,[Ring0functions+eax*4]
		xchg	eax,[esp+4+tStackFrame.EAX]
		call	dword [esp+4+tStackFrame.EAX]
		mov	[esp+4+tStackFrame.EAX],eax
		mov	[esp+4+tStackFrame.EBX],ebx
		mov	[esp+4+tStackFrame.ECX],ecx
		mov	[esp+4+tStackFrame.EDX],edx
		mov	[esp+4+tStackFrame.ESI],esi
		mov	[esp+4+tStackFrame.EDI],edi
.Exit:		sahf
		mov	[esp+4+tStackFrame.EFLAGS],ah
		ret

.Err:		mov	word [esp+4+tStackFrame.EAX],-ENOSYS
		jmp	.Exit
endp		;---------------------------------------------------------------
