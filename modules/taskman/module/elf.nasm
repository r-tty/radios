;*******************************************************************************
;  elf.nasm - ELF32 binary format support.
;  Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module binfmt.elf

%include "sys.ah"

exportproc module_init, module_exit

section .text

proc module_init
		ret
endp		;---------------------------------------------------------------

proc module_exit
		ret
endp		;---------------------------------------------------------------
