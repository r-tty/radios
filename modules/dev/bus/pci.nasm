;*******************************************************************************
; pci.nasm - PCI bus routines.
; Copyright (c) 2000-2002 RET & COM Research.
;*******************************************************************************

module $pci

%include "hw/ports.ah"

section .text

		; PCI_Init - initialize controller.
		; Input: none.
		; Output: CF=0 - OK:
		;		  DL=number of buses,
		;		  DH=number of devices;
		;	  CF=1 - error, AX=error code.
proc PCI_Init
		ret
endp		;---------------------------------------------------------------


		; PCI_ReadByte - read a byte from the register and device.
		; Input: EDX (high word) = PFA (bits 15..8=bus,
		;				bits 7..3=device,
		;				bits 2..0=function),
		;	 DH=register.
		; Output: DL=register contents.
proc PCI_ReadByte
		mpush	eax,ecx
		mov	ch,dh
		shr	edx,16
		mov	eax,0800000h
		mov	ax,dx			; Get PFA
		shl	eax,8			; Make room for register
		mov	al,ch			; Place register info in location
		and	al,0FCh			; Strip off alignment data.
		mov	dx,PORT_PCI
		out	dx,eax
		PORTDELAY
		call	PCI_PointToByte		; Align the PCI data port to out byte.
		in	al,dx			; Fetch the data.
		mov	dl,al
		mpop    ecx,eax
		ret
endp		;---------------------------------------------------------------


		; PCI_WriteByte - write a byte to the register and device.
		; Input: EDX (high word) = PFA (bits 15..8=bus,
		;				bits 7..3=device,
		;				bits 2..0=function),
		;	 DH=register,
		;	 DL=value.
		; Output: none.
proc PCI_WriteByte
		mpush	eax,ecx,edx
		mov	ecx,edx
		shr	edx,16
		mov	eax,0800000h
		mov	ax,dx			; Get PFA
		shl	eax,8			; Make room for register
		mov	al,ch			; Place register info in location
		and	al,0FCh			; Strip off alignment data
		mov	dx,PORT_PCI
		out	dx,eax
		PORTDELAY
		call	PCI_PointToByte		; Align the PCI data port to out byte
		mov	al,cl			; Get value back
		out	dx,ax
		mpop	edx,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; PCI_PointToByte
		; Input:
		; Output:
proc PCI_PointToByte
		push	ecx
		and	cx,0300h		; Strip all but byte information
		xchg    ch, cl			; Swap the LSB and MSB
		mov	dx,PORT_PCI_BASE	; Base PCI IO port
		add     dx,cx			; Point to our register
		pop	ecx
		ret
endp		;---------------------------------------------------------------
