;-------------------------------------------------------------------------------
;  launcher.as - kernel thread that's being executed after enable multitasking.
;-------------------------------------------------------------------------------

		; INIT_Launcher - continue booting after enable multitasking.
		; Input: none.
		; Output: none.
proc INIT_Launcher
.IDLE: inc byte [0xB8000+158]
		jmp	.IDLE
endp		;---------------------------------------------------------------

