;-------------------------------------------------------------------------------
; tm_head.nasm - module header.
;-------------------------------------------------------------------------------

module $taskman

%include "module.ah"

exportdata ModuleInfo

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_KERNEL)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	-1)
    field(Entry,	DD	-1)
iend

