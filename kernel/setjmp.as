;*******************************************************************************
; setjmp.h - setjmp/longjmp pair.
; Copyright (c) 1996 Andy Valencia (original VSTa version)
;*******************************************************************************

module kernel.setjmp


; --- Exports ---

global K_SetJmp, K_LongJmp


; --- Code ---

		; K_SetJmp - save context, returning 0.
		; Input: EBX=address of JmpBuf.
		; Output: AL=0 if returning directly,
		;	  AL=1 if returning from K_LongJmp.
proc K_SetJmp
		ret
endp		;---------------------------------------------------------------


		; K_LongJmp - restore context, returning a specified result.
		; Input: EBX=address of JmpBuf,
		;	 AL=result (0 or 1).
		; Output: none.
proc K_LongJmp
		ret
endp		;---------------------------------------------------------------

