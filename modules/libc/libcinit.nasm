;-------------------------------------------------------------------------------
; libcinit.nasm - initialize libc components.
;-------------------------------------------------------------------------------

module $libc

%include "sys.ah"
%include "module.ah"

exportdata ModuleInfo

extern libc_init_syscall
extern libc_init_stdlib
extern libc_init_string

%define SHLIB_BASE 50000000h

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_LIBRARY)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	SHLIB_BASE)
    field(Entry,	DD	libc_initialize)
iend

section .text

proc libc_initialize
		call	libc_init_syscall
		call	libc_init_stdlib
		call	libc_init_string
		ret
endp		;---------------------------------------------------------------
