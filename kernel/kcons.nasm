;-------------------------------------------------------------------------------
; kcons.nasm - elementary console routines (actually BTL service wrappers).
;-------------------------------------------------------------------------------

module kernel.cons

%include "serventry.ah"
%include "asciictl.ah"

exportproc PrintChar, PrintCharRaw, PrintString
exportproc PrintByteDec, PrintWordDec, PrintDwordDec
exportproc PrintByteHex, PrintWordHex, PrintDwordHex
exportproc ReadChar, ReadString
exportproc DebugKDOutput


section .text

		; PrintCharRaw - print a character in "raw" mode.
		; Input: AL=character.
		; Note: cursor moves as usual.
proc PrintCharRaw
		mServPrintCharRaw
		ret
endp		;---------------------------------------------------------------


		; PrintChar - print a character in TTY mode.
		; Input: AL=character code.
proc PrintChar
		mServPrintChar
		ret
endp		;---------------------------------------------------------------


		; PrintString - print an ASCIIZ string.
		; Input: ESI=string address.
		; Output: none.
proc PrintString
		mServPrintStr
		ret
endp		;---------------------------------------------------------------


		; PrintByteDec - print byte in decimal form.
		; Input: AL=byte.
		; Output: none.
proc PrintByteDec
		mpush	eax
		movzx	eax,al
		mServPrintDec
		mpop	eax
		ret
endp		;---------------------------------------------------------------


		; PrintWordDec - print word in decimal form.
		; Input: AX=word.
		; Output: none.
proc PrintWordDec
		mpush	eax
		movzx	eax,ax
		mServPrintDec
		mpop	eax
		ret
endp		;---------------------------------------------------------------


		; PrintDwordDec - print dword in decimal.
		; Input: EAX=dword.
		; Output: none.
proc PrintDwordDec
		mServPrintDec
		ret
endp		;---------------------------------------------------------------


		; PrintByteHex - print byte in hexadecimal form.
		; Input: AL=byte.
		; Output: none.
proc PrintByteHex
		mServPrint8h
		ret
endp		;---------------------------------------------------------------


		; PrintWordHex - print word in hexadecimal form.
		; Input: AX=word.
		; Output: none.
proc PrintWordHex
		mServPrint16h
		ret
endp		;---------------------------------------------------------------


		; PrintDwordHex - print double word in hexadecimal form.
		; Input: EAX=dword.
		; Output: none.
proc PrintDwordHex
		mServPrint32h
		ret
endp		;---------------------------------------------------------------


		; ReadChar - read a character from kernel console.
		; Input: none:
		; Output: AL=character.
proc ReadChar
		mServReadKey
		ret
endp		;---------------------------------------------------------------


		; ReadString - read string from kernel console in the buffer.
		; Input: ESI=buffer address,
		;	 CL=maximum string length.
		; Output: none.
proc ReadString
		mServReadString
		ret
endp		;---------------------------------------------------------------
