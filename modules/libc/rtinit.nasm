;-------------------------------------------------------------------------------
; rtinit.nasm - run-time initialization code.
;-------------------------------------------------------------------------------

module libc.rtinit

%include "module.ah"

exportdata ModuleInfo

externproc _main, _fini

library $libc
importproc _atexit, _exit


section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
    field(Entry,	DD	Start)
iend


section .text

proc Start
		mov	ebx,edx
		mov	esi,[esp]			; argc
		lea	ecx,[esp+4]			; argv
		lea	eax,[ecx+esi*4]			; envp
		lea	edi,[eax+4]
		lea	edx,[eax+8]
		cmp	dword [eax+4],0
		je	.DoneArgv

		; Scan for auxv
.Loop:		mov	eax,[edx]
		add	edx,byte 4
		test	eax,eax
		jnz	.Loop
		
.DoneArgv:	mpush	ebx,edx,edi,ecx,esi
		call	rt_prepare

		; Leave the args on the stack, we will pass them to main()
		Ccall	_atexit, dword _fini

.Main:		call	_main
		push	eax
		call	_exit
		jmp	$
endp		;---------------------------------------------------------------


		; Prepare run-time environment.
proc rt_prepare
		ret
endp		;---------------------------------------------------------------
