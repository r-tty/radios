;*******************************************************************************
;  hello.as - "Hello, World!" for RadiOS.
;*******************************************************************************

module hello					; Module name

; --- Externals ---
library kernel.mt				; Export from 'kernel.mt'
extern Exit					; Exit procedure

library kernel.misc				; Export from 'kernel.misc'
extern WrString					; Write string procedure


; --- Publics ---
global Start					; Start entry point
global Stack					; Stack reservation


; --- Data ---

section .data

MsgHello	DB	'Hello, World!',0Ah,0


; --- Stack ---

section .bss

stack		RESB	128


; --- Code ---

section .text

Start:		mov	esi,MsgHello		; ESI = message offset
		call	far WrString		; Call 'write string'

		xor	eax,eax			; Exit code = 0 (success)
		call	far Exit		; Exit process

