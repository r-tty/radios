;-------------------------------------------------------------------------------
;  procstat.asm - get/set process status routines.
;-------------------------------------------------------------------------------

		; K_GetCurrDirIndex - get process current directory index.
		; Input: EAX=PID.
		; Output: CF=0 - OK, EBX=index;
		;	  CF=1 - error, AX=error code.
proc K_GetCurrDirIndex near
		ret
endp		;---------------------------------------------------------------