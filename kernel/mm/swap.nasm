;-------------------------------------------------------------------------------
;  swap.nasm - routines for page swapping.
;-------------------------------------------------------------------------------

; --- Exports ---

global MM_SwapActivate, MM_SwapDeactivate


; --- Code ---

section .text

		; MM_SwapActivate - activate a swap partition.
		; Input:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_SwapActivate
		ret
endp		;---------------------------------------------------------------


		; MM_SwapDeactivate - deactivate a swap partition.
		; Input:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MM_SwapDeactivate
		ret
endp		;---------------------------------------------------------------
