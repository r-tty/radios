;-------------------------------------------------------------------------------
; tmlaunch.nasm - routines for Task Manager initialization and launching.
;-------------------------------------------------------------------------------

%include "thread.ah"

library kernel
extern BZero

library kernel.paging
extern PG_NewDir, PG_MapArea

library kernel.strutil
extern StrComp

section .data

MsgTMmodName	DB	"$taskman",0
MsgTaskMan	DB	"Task manager ",0
MsgLoaded	DB	"loaded",NL,0
MsgNotFound	DB	"not found",NL,0

section .text

		; Look if Task Manager module is loaded.
		; Input: none.
		; Output: CF=0 - OK, EBX=address of taskman's BMD;
		;	  CF=1 - module not found.
proc FindTMmodule
		mpush	ecx,esi,edi
		mov	ecx,[BOOTPARM(NumModules)]
		jecxz	.NotFound
		mov	ebx,[BOOTPARM(BMDmodules)]
		mov	edi,MsgTMmodName
.Loop:		lea	esi,[ebx+tBMD.Name]
		call	StrComp
		or	al,al
		jz	.Exit
		add	ebx,tBMD_size
		loop	.Loop
.NotFound:	stc
.Exit:		mpop	esi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; Map shared libraries onto task manager's address space
		; Input: EDX=address of TM's page directory.
		; Output: none.
proc MapShLibs
		mpush	ebx,ecx,esi,edi
		mov	ecx,[BOOTPARM(NumModules)]
		jecxz	.OK
		mov	ebx,[BOOTPARM(BMDmodules)]
.Loop:		cmp	byte [ebx+tBMD.Type],MODTYPE_LIBRARY
		jne	.Next
		mov	eax,PG_PRESENT | PG_USERMODE
		mov	esi,[ebx+tBMD.CodeStart]
		mov	edi,[ebx+tBMD.VirtAddr]
		add	edi,USERAREASTART
		push	ecx
		mov	ecx,[ebx+tBMD.Size]
		call	PG_MapArea
		pop	ecx
		jc	.Exit
.Next:		add	ebx,tBMD_size
		loop	.Loop
.OK:		clc
.Exit:		mpop	edi,esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; Initialize Task Manager thread.
		; Input: none.
		; Output: CF=0 - OK, EBX=Task Manager's TCB;
		;	  CF=1 - error, AX=error code.
proc INIT_CreateTMthread
		locals	tm_tcb
		prologue

		mServPrintStr MsgTaskMan
		call	FindTMmodule
		jc	.Err
		mServPrintStr MsgLoaded

		; Create TM page directory
		call	PG_NewDir
		jc	.Exit

		; Create TM thread
		xor	ecx,ecx
		push	ebx
		mov	ebx,[ebx+tBMD.Entry]
		call	MT_CreateThread
		mov	[%$tm_tcb],ebx
		mov	dword [ebx+tTCB.Stack],USTACKTOP-4
		pop	ebx
		jc	.Exit

		; Map its address space
		mov	eax,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		mov	esi,[ebx+tBMD.CodeStart]
		mov	edi,[ebx+tBMD.VirtAddr]
		add	edi,USERAREASTART
		mov	ecx,[ebx+tBMD.Size]
		call	PG_MapArea
		jc	.Exit

		; Allocate space for a stack and zero it
		push	edx
		mov	dl,1
		mov	ecx,UMINSTACK
		call	PG_AllocContBlock
		pop	edx
		jc	.Exit
		call	BZero

		; Map the stack
		mov	esi,ebx
		mov	edi,(USTACKTOP-UMINSTACK) + USERAREASTART
		mov	eax,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		call	PG_MapArea
		jc	.Exit

		; Map shared libraries
		call	MapShLibs
		jc	.Exit

		mov	ebx,[%$tm_tcb]

.Exit:		epilogue
		ret

.Err:		mServPrintStr MsgNotFound
		jmp	FatalError
endp		;---------------------------------------------------------------
