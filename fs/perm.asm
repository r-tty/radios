;-------------------------------------------------------------------------------
;  perm.asm - permission checking.
;-------------------------------------------------------------------------------

		; CFS_ChkIndPerm - check index permission.
		; Input: EAX=PID,
		;	 ESI=index address.
		; Output: CF=0 - OK, permission enabled;
		;	  CF=1 - error, AX=error code.
proc CFS_ChkIndPerm near
		ret
endp		;---------------------------------------------------------------
