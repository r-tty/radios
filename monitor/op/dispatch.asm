.386
Ideal

include "segments.ah"

	public	TableDispatch

segment KCODE

; Core dispatch routine.  Calls the subfunction indicated in AL
; and then set the return address to after the dispatch table
; This expects a subfunction code to be on the stack
;
proc TableDispatch near
	ENTER	0,0
	xchg	ebx,[ebp+4]		; xchg ret address & ebx
	cmp	al,[cs:ebx]		; Limit check
	ja	short noaction		; Error if too big
	; Here we call the routine
	push	offset finishup		; Return address
	sub	ah,ah			; Make key a dword
	cwde				;
	push	[dword ptr cs:ebx + 4 * eax + 4]	; Get code address to stack
	xchg	ebx,[ebp+4]		; put things as they were
	mov	eax,[ebp + 8]		; Get the subkey
	cld				; Assume move dir up
	ret				; Go to subroutine
	
noaction:
	xchg	ebx,[ebp+4]		; Put things as they were
	call	nofunction		; Register bad function error
finishup:
	; Now we have to find the return address
	xchg	ebx,[ebp+4]		; Get return address
	push	eax
	mov	eax,[cs:ebx]
	lea	ebx,[ebx + 4 * eax + 8]	; Get offset to return address
	pop	eax
	xchg	ebx,[ebp+4]		; Xchg with orig value of ebx
	LEAVE
	ret	4
ENDP	TableDispatch

PROC	nofunction
	mov	eax,100h		; Ill function error
	stc				; Set carry flag
	ret
ENDP	nofunction

ends
end
	