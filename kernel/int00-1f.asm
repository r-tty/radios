;-------------------------------------------------------------------------------
;  int00-1f.asm - CPU exceptions handlers.
;-------------------------------------------------------------------------------

align 4
		; Exception 0: division by zero.
		; Action: terminate process and release it's memory blocks.
proc		Int00handler	far
		iret
endp		;---------------------------------------------------------------


		; Exception 1: debugging.
		; Action: call internal debugger.
proc		Int01handler	far
		iret
endp		;---------------------------------------------------------------


		; Exception 2: non-maskable interrupt.
		; Action: freeze all processes and call internal debugger.
proc		Int02handler	far
		iret
endp		;---------------------------------------------------------------


		; Exception 3: breakpoint.
		; Action: call internal debugger.
proc		Int03handler	far
		iret
endp		;---------------------------------------------------------------


		; Exception 4: INTO overflow.
		; Action: terminate process and release it's memory blocks.
proc		Int04handler	far
		iret
endp		;---------------------------------------------------------------


		; Exception 5: bound range exceed.
		; Action: terminate process and release it's memory blocks.
proc		Int05handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int06handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int07handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int08handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int09handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int0Ahandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int0Bhandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int0Chandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int0Dhandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int0Ehandler	far
		iret
endp		;---------------------------------------------------------------


proc		Int10handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int11handler	far
		iret
endp		;---------------------------------------------------------------


proc		Int12_1Fhandler	far
		iret
endp		;---------------------------------------------------------------

