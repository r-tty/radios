;*******************************************************************************
;  pnp.asm - Plug and Play devices control module.
;  Copyrigh (c) 1999 Sergey V. Daniloff.
;*******************************************************************************

; --- Publics ---


; --- Definitions ---


; --- Procedures ---

		; PNP_Reset - reset PnP devices.
		; Input: none.
		; Output: none.
proc PNP_Reset near
		mov	dx,PORT_PNP_Command
		xor	al,al
		out	dx,al
		call	PNP_Delay
		out	dx,al
		call	PNP_Delay
		mov	al,6Ah
		mov	cx,20h
@@Loop:		out	dx,al
		mov	ah,al
		shr	al,1
		xor	ah,al
		shl	ah,7
		or	al,ah
		loop	@@Loop
		ret
endp		;---------------------------------------------------------------


		; PNP_Delay - delay procedure for PnP I/O
		; Input: none.
		; Output: none.
proc PNP_Delay near
		push	ecx
		mov	ecx,1
		call	K_LDelay
		pop	ecx
		ret
endp		;---------------------------------------------------------------
