;-------------------------------------------------------------------------------
;  keyboard.asm - Keyboard control routines.
;-------------------------------------------------------------------------------

; --- Equates ---

; Pressed keys
KB_Prs_LShift		EQU	1
KB_Prs_LCtrl		EQU	2
KB_Prs_LAlt		EQU	4
KB_Prs_RShift		EQU	8
KB_Prs_RCtrl		EQU	16
KB_Prs_CapsLock		EQU	32
KB_Prs_NumLock		EQU	64
KB_Prs_ScrollLock	EQU	128

; On/off switches
KB_Sw_CapsLock		EQU	1
KB_Sw_NumLock		EQU	2
KB_Sw_ScrollLock	EQU	4
KB_Sw_Insert		EQU	8

; Functional keys definitions


; --- Keyboard data ---

; Default keyboard layout table
KB_DfltTbl1		DB ASC_NUL,ASC_ESC,"1234567890-=",ASC_BS,ASC_HT
			DB "qwertyuiop[]",ASC_CR,0,"asdfghjkl;'`",0
			DB "\zxcvbnm,./",0,0," ",0


; --- Keyboard variables ---
KB_PrsFlags		DB	?		; Keypressing flags
KB_SwFlags		DB	?		; Switches status
KB000			DD	0B8040h


; --- Routines ---

		; AnlsKBcode - convert keyboard codes into ASCII or scan-codes
		;	     and put them in current virtual terminal variables.
		; Input: AL=keyboard code (from KB interrupt handler).
		; Output: none.
proc AnlsKBcode	near
		test	al,80h
		jnz	AKC00
		mov	ebx,offset KB_DfltTbl1
		xlat
		mov	ebx,[KB000]
		mov	[byte ebx],al
		inc	[KB000]
		inc	[KB000]
	AKC00:	ret
endp		