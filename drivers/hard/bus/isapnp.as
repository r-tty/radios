;*******************************************************************************
;  isapnp.as - ISA Plug and Play devices control routines.
;  (c) 2000 RET & COM Research.
;*******************************************************************************

module pnp

%include "hw/ports.ah"


; --- Imports ---

library kernel.misc
extern K_LDelay


; --- Procedures ---

section .text

		; PNP_Reset - reset PnP devices.
		; Input: none.
		; Output: none.
proc PNP_Reset
		mov	dx,PORT_PNP_Command
		xor	al,al
		out	dx,al
		call	PNP_Delay
		out	dx,al
		call	PNP_Delay
		mov	al,6Ah
		mov	cx,20h
.Loop:		out	dx,al
		mov	ah,al
		shr	al,1
		xor	ah,al
		shl	ah,7
		or	al,ah
		loop	.Loop
		ret
endp		;---------------------------------------------------------------


		; PNP_Delay - delay procedure for PnP I/O
		; Input: none.
		; Output: none.
proc PNP_Delay
		push	ecx
		mov	ecx,1
		call	K_LDelay
		pop	ecx
		ret
endp		;---------------------------------------------------------------
