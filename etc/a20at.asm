;*******************************************************************************
; Copyright (c) 1989 Microsoft Corporation. All rights reserved.
;*******************************************************************************

;*--------------------------------------------------------------------------*
;*									    *
;*  AT_A20Handler -					    HARDWARE DEP.   *
;*									    *
;*	Enable/Disable the A20 line on non-PS/2 machines		    *
;*									    *
;*  ARGS:   AX = 0 for Disable, 1 for Enable				    *
;*  RETS:   AX = 1 for success, 0 otherwise				    *
;*  REGS:   AX, CX and Flags clobbered					    *
;*									    *
;*--------------------------------------------------------------------------*

proc AT_A20Handler	near

	    or	    ax,ax
	    jz	    short AAHDisable

AAHEnable:  call    Sync8042	; Make sure the Keyboard Controller is Ready
	    jnz     short AAHErr

	    mov	    al,0D1h	; Send D1h
	    out	    64h,al
	    call    Sync8042
	    jnz     short AAHErr

	    mov	    al,0DFh	; Send DFh
	    out	    60h,al
	    call    Sync8042
	    jnz     short AAHErr

	    ; Wait for the A20 line to settle down (up to 20usecs)
	    mov	    al,0FFh	; Send FFh (Pulse Output Port NULL)
	    out	    64h,al
	    call    Sync8042
	    jnz     short AAHErr
	    jmp	    short AAHExit

AAHDisable: call    Sync8042	; Make sure the Keyboard Controller is Ready
	    jnz     short AAHErr

	    mov	    al,0D1h	; Send D1h
	    out	    64h,al
	    call    Sync8042
	    jnz     short AAHErr

	    mov	    al,0DDh	; Send DDh
	    out	    60h,al
	    call    Sync8042
	    jnz     short AAHErr

	    ; Wait for the A20 line to settle down (up to 20usecs)
	    mov	    al,0FFh	; Send FFh (Pulse Output Port NULL)
	    out	    64h,al
	    call    Sync8042
	    
AAHExit:    mov	    ax,1
	    ret
	    
AAHErr:	    xor	    ax,ax
	    ret
	    
endp


;*--------------------------------------------------------------------------*

proc Sync8042	near

	    xor	    cx,cx
S8InSync:   in	    al,64h
	    and	    al,2
	    loopnz  S8InSync
	    ret

endp
