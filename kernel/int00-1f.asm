;-------------------------------------------------------------------------------
;  int00-1f.asm - CPU exceptions handlers.
;-------------------------------------------------------------------------------

align 4
		; Exception 0: division by zero.
		; Action: terminate process and release it's memory blocks.
proc Int00handler
		iret
endp		;---------------------------------------------------------------


		; Exception 1: debugging.
		; Action: call internal debugger.
proc Int01handler
		iret
endp		;---------------------------------------------------------------


		; Exception 2: non-maskable interrupt.
		; Action: freeze all processes and call internal debugger.
proc Int02handler
		iret
endp		;---------------------------------------------------------------


		; Exception 3: breakpoint.
		; Action: call internal debugger.
proc Int03handler
		iret
endp		;---------------------------------------------------------------


		; Exception 4: INTO overflow.
		; Action: terminate process and release it's memory blocks.
proc Int04handler
		iret
endp		;---------------------------------------------------------------


		; Exception 5: bound range exceed.
		; Action: terminate process and release it's memory blocks.
proc Int05handler
		iret
endp		;---------------------------------------------------------------


proc Int06handler
		iret
endp		;---------------------------------------------------------------


proc Int07handler
		iret
endp		;---------------------------------------------------------------


proc Int08handler
		iret
endp		;---------------------------------------------------------------


proc Int09handler
		iret
endp		;---------------------------------------------------------------


proc Int0Ahandler
		iret
endp		;---------------------------------------------------------------


proc Int0Bhandler
		iret
endp		;---------------------------------------------------------------


proc Int0Chandler
		iret
endp		;---------------------------------------------------------------


proc Int0Dhandler
		iret
endp		;---------------------------------------------------------------


proc Int0Ehandler
		iret
endp		;---------------------------------------------------------------


proc Int10handler
		iret
endp		;---------------------------------------------------------------


proc Int11handler
		iret
endp		;---------------------------------------------------------------


proc Int12_1Fhandler
		iret
endp		;---------------------------------------------------------------

