;-------------------------------------------------------------------------------
; libcinit.nasm - initialize different libc components.
;-------------------------------------------------------------------------------

module $libc

%include "bootdefs.ah"

exportdata ModuleInfo, Start

extern libc_init_syscall
extern libc_init_signal
extern libc_init_stdio
extern libc_init_stdlib
extern libc_init_string
extern libc_init_termios
extern libc_init_unistd

%define SHLIB_BASE 40000000h

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_LIBRARY)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	SHLIB_BASE)
iend

section .text

proc Start
		call	libc_init_syscall
		call	libc_init_signal
		call	libc_init_stdio
		call	libc_init_stdlib
		call	libc_init_string
		call	libc_init_termios
		call	libc_init_unistd
		ret
endp		;---------------------------------------------------------------
