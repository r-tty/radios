;-------------------------------------------------------------------------------
;  launcher.as - kernel thread that's being executed after enable multitasking.
;-------------------------------------------------------------------------------

		; INIT_Launcher - continue booting after enable multitasking.
		; Input:
		; Output:
proc INIT_Launcher
.IDLE:	inc byte [0B8000h]
		jmp	.IDLE
endp		;---------------------------------------------------------------

