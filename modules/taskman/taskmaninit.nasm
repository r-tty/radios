;*******************************************************************************
; taskmaninit.nasm - RadiOS task manager, initialization.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module $taskman

%include "bootdefs.ah"

exportproc Start, Exit
exportdata ModuleInfo

extern tm_memman_init

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
iend

; --- Code ---

section .text

		; Startup
proc Start
		prologue

		call	tm_memman_init
		
		jmp	$
		
		epilogue
		ret
endp		;---------------------------------------------------------------


		; Exit
proc Exit
		ret
endp		;---------------------------------------------------------------
