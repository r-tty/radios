;-------------------------------------------------------------------------------
; exit.nasm - various functions for process termination.
;-------------------------------------------------------------------------------

module libc.exit

%include "lib/stdlib.ah"

exportproc _abort, _atexit, _exit, __exit


externproc _malloc, _ThreadDestroy


section .bss

atexit_list	RESP	1			; Head of atexit() list


section .text

		; void abort(void);
proc _abort
		ret
endp		;---------------------------------------------------------------


		; int atexit(void (*function)(void));
proc _atexit
		arg	func
		prologue

		Ccall _malloc, tAtExitFunc_size
		test	eax,eax
		jz	.Failure
		mov	ebx,[%$func]
		mov	[eax+tAtExitFunc.Func],ebx
		mov	ebx,[atexit_list]
		mov	[eax+tAtExitFunc.Next],ebx
		mov	[atexit_list],eax
		xor	eax,eax
.Done:		epilogue
		ret

.Failure:	dec	eax
		jmp	.Done
endp		;---------------------------------------------------------------


		; void _exit(int status);
proc __exit
		mov	eax,[esp+4]
		xor	edx,edx
		not	edx
		Ccall	_ThreadDestroy, edx, edx, eax
		ret
endp		;---------------------------------------------------------------


		; void exit(int status);
proc _exit
		mov	ebx,[atexit_list]
		or	ebx,ebx
		jz	.CloseFiles
.Loop:		call	dword [ebx+tAtExitFunc.Func]
		mov	ebx,[ebx+tAtExitFunc.Next]
		or	ebx,ebx
		jnz	.Loop

.CloseFiles:
		jmp	__exit
endp		;---------------------------------------------------------------
