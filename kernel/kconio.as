;*******************************************************************************
;  kconio.as - kernel console I/O.
;  These routines are used by various kernel subsystems for debugging.
;*******************************************************************************

module kernel.kconio

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "asciictl.ah"


; --- Exports ---

global PrintChar, PrintString
global K_WrDecD, K_WrHexB, K_WrHexW, K_WrHexD
global PrintByteDec, PrintByteHex
global PrintWordDec, PrintWordHex
global PrintDwordDec, PrintDwordHex
global ReadChar, ReadString
global K_PopUp


; --- Imports ---

library kernel
extern DrvId_Con

library kernel.driver
extern DRV_CallDriver:near


; --- Code ---

section .text

		; PrintChar - write character to active console.
		; Input: AL=character code.
proc PrintChar
		push	edx
		mCallDriver dword [DrvId_Con], byte DRVF_Write
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; PrintString - print an ASCIIZ string.
		; Input: ESI=string address.
		; Output: none.
proc PrintString
		push	edx
		push	dword [DrvId_Con]
		push	dword DRVF_Control + (DRVCTL_CON_WrString << 16)
		call	DRV_CallDriver
		pop	edx
		ret
endp		;---------------------------------------------------------------


		; PrintByteDec - print byte in decimal form.
		; Input: AL=byte.
		; Output: none.
proc PrintByteDec
		mpush	eax,edi
		mov	edi,PrintChar
		movzx	eax,al
		call	K_WrDecD
		mpop	edi,eax
		ret
endp		;---------------------------------------------------------------


		; PrintByteHex - print byte in hexadecimal form.
		; Input: AL=byte.
		; Output: none.
proc PrintByteHex
		push	edi
		mov	edi,PrintChar
		call	K_WrHexB
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; PrintWordDec - print word in decimal form.
		; Input: AX=word.
		; Output: none.
proc PrintWordDec
		push	edi
		mov	edi,PrintChar
		call	K_WrDecW
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; PrintWordHex - print word in hexadecimal form.
		; Input: AX=word.
		; Output: none.
proc PrintWordHex
		push	edi
		mov	edi,PrintChar
		call	K_WrHexW
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; PrintDwordDec - print dword in decimal.
		; Input: EAX=dword.
		; Output: none.
proc PrintDwordDec
		push	edi
		mov	edi,PrintChar
		call	K_WrDecD
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; PrintDwordHex - print double word in hexadecimal form.
		; Input: EAX=dword.
		; Output: none.
proc PrintDwordHex
		push	edi
		mov	edi,PrintChar
		call	K_WrHexD
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; K_WrDecD - write decimal dword.
		; Input: EAX=dword,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrDecD
		mpush	eax,ebx,ecx,edx
		mov	ebx,1000000000
		xor	cl,cl
		or	eax,eax
		jnz	short .Loop
		mov	al,'0'
                call	edi
                jmp	short .Exit

.Loop:		xor	edx,edx
		div	ebx
		or	al,al
		jnz	short .NZ
		or	cl,cl
		jz	short .Z

.NZ:		mov	cl,1
		add	al,48
		call	edi
.Z:		mov	eax,edx
                xor	edx,edx
                push	eax
                mov	eax,ebx
                mov	ebx,10
                div	ebx
                mov	ebx,eax
                pop	eax
                or	ebx,ebx
                jnz	.Loop

.Exit:		mpop	edx,ecx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; K_WrDecW - write decimal word.
		; Input: AX=word,
		;	 EDI=address of "Write char" procedure
		; Output: none.
proc K_WrDecW
		push	eax
		movzx	eax,ax
		call	K_WrDecD
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_WrHexB - write byte in hex.
		; Input: AL=byte,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrHexB
		push	eax
		mov	ah,al
		shr	al,4
		call	.1
		mov	al,ah
		call	.1
		pop	eax
		ret

.1:		and	al,0Fh
		cmp	al,0Ah
		jb	short .2
		add	al,7
.2:		add	al,30h
		call	edi
		ret
endp		;---------------------------------------------------------------


		; K_WrHexW - write word in hex.
		; Input: AX=word,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrHexW
		ror	ax,8
		call	K_WrHexB
		ror	ax,8
		call	K_WrHexB
		ret
endp		;---------------------------------------------------------------


		; K_WrHexD - write double word in hex.
		; Input: EAX=dword,
		;	 EDI=address of "Write char" procedure.
		; Output: none.
proc K_WrHexD
		ror	eax,16
		call	K_WrHexW
		ror	eax,16
		call	K_WrHexW
		ret
endp		;---------------------------------------------------------------


		; ReadChar - read a character from kernel console.
		; Input: none:
		; Output: AL=character.
proc ReadChar
		push	dword [DrvId_Con]
		push	byte DRVF_Read
		call	DRV_CallDriver
		ret
endp		;---------------------------------------------------------------


		; ReadString - read string from kernel console in buffer.
		; Input: ESI=buffer address,
		;	 CL=maximum string length.
		; Output: CL=number of read characters.
		; Note: destroys CH and high word of ECX.
proc ReadString
		prologue 0
		movzx	ecx,cl			; Allocate memory
		sub	esp,ecx			; for local buffer

		mpush	eax,esi,edi

		mov	edi,ebp
		sub	edi,ecx
		push	edi			; EDI=local buffer address
		push	ecx
		cld
		rep	movsb
		pop	ecx
		pop	edi
		mov	esi,edi			; ESI=EDI=local buffer address

.ReadKey:	mCallDriver dword [DrvId_Con], byte DRVF_Read
		or	al,al
		jz	.FuncKey
		cmp	al,ASC_BS
		je	.BS
		cmp	al,ASC_CR
		je	.Done
		cmp	al,' '			; Another ASCII CTRL?
		jb	.ReadKey		; Yes, ignore it.
		cmp	edi,ebp			; Buffer full?
		je	.ReadKey		; Yes, ignore it.
		mov	[edi],al		; Store read character
		inc	edi
		mCallDriver dword [DrvId_Con], byte DRVF_Write
		jmp	.ReadKey

.FuncKey:	jmp	.ReadKey

.BS:		cmp	edi,esi
		je	.ReadKey
		dec	edi
		mCallDriver dword [DrvId_Con], byte DRVF_Write
		jmp	.ReadKey

.Done:		mov	ecx,edi
		sub	ecx,esi
		mov	edi,[esp+4]		; EDI=target buffer address
		push	ecx			; ECX=number of read characters
		cld
		rep	movsb
		pop	ecx

		mpop	edi,esi,eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; K_PopUp - draw a "pop-up" window on system console and wait
		;	    until a key will be pressed.
		; Input: ESI=address to string with message.
		; Output: none.
		; Note: the string must be in such form:
		;	   ":TITLE:procedure_name:message"
proc K_PopUp
		ret
endp		;---------------------------------------------------------------
