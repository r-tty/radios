;------------------------------------------------------------------------------
; head.nasm - module header.
;------------------------------------------------------------------------------

module $librm

%include "module.ah"

exportdata ModuleInfo

library $libc

%define SHLIB_BASE 50100000h

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_LIBRARY)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	SHLIB_BASE)
    field(Entry,	DD	-1)
iend
