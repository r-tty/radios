;*******************************************************************************
;  hello.as - "Hello, World!" for RadiOS.
;*******************************************************************************

; --- Definitions ---
bits 32

; --- Externals ---
library KERNEL					; Export from 'KERNEL'
extern Exit					; Exit procedure

library KERNEL.MISC				; Export from 'KERNEL.MISC'
extern WrString					; Write string procedure


; --- Publics ---
global ??hello,stack


; --- Data ---
section .data
MsgHello	DB	'Hello, World!',0Ah,0


; --- Stack ---
section .bss
stack		RESB	128


; --- Code ---
section .text
??hello:	mov	esi,MsgHello		; ESI = message offset
		call	far WrString		; Call 'write string'

		xor	eax,eax			; Exit code = 0 (success)
		call	far Exit		; Exit process

end
