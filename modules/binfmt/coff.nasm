;*******************************************************************************
;  coff.nasm - COFF binary format support.
;  Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module binfmt.coff

%include "sys.ah"
%include "errors.ah"

exportproc module_init, module_exit

section .text

proc module_init
		ret
endp		;---------------------------------------------------------------

proc module_exit
		ret
endp		;---------------------------------------------------------------
