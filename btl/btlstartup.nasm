;*******************************************************************************
; btlstartup.nasm - RadiOS boot-time linker startup.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

%include "bootdefs.ah"

publicproc Reboot

externproc ConsInit, ServiceEntry
externproc _cmain, _printf, _getc

%define BTLSTACK	10FFF0h

section .text

		; Set up our own GDT and load segment registers
		lgdt	[GDTaddrLim]
		mov	edx,eax				; Save multiboot magic
		xor	eax,eax
		mov	al,10h
		mov	ds,eax
		mov	es,eax
		mov	fs,eax
		mov	gs,eax
		mov	ss,eax
		jmp	Start

		; Initialize stack and clear the BSS area
proc Start
		mov	esp,BTLSTACK
		mov	edi,bss_start
		xor	eax,eax
		mov	ecx,esp
		sub	ecx,edi
		shr	ecx,2
		cld
		rep	stosd

		; Initialize console
		call	ConsInit			

		; Call _cmain. It will return kernel start address.
		push	ebx				; Multiboot info
		push	edx				; Multiboot magic
		call	_cmain
		add	esp,byte 8
		mov	dword [BOOTPARM(ServiceEntry)],ServiceEntry

		; Real fun starts here
		call	eax

		; Kernel may return some error code
		Ccall	_printf, TxtKernRet, eax
Reboot:		Ccall	_printf, TxtPressKey
		call	_getc
		mov	al,254
		out	64h,al
		hlt
		jmp	$
endp		;---------------------------------------------------------------


section .data

GDTaddrLim	DW	23				; GDT address and limit
		DD	GDT
GDT		DD	0,0
		DW	0FFFFh,0			; Code segment
		DB	0,9Ah,0CFh,0
		DW	0FFFFh,0			; Data segment
		DB	0,92h,0CFh,0

TxtKernRet	DB	10,"Kernel returned with exit code %d",0
TxtPressKey	DB	10,"Press any key to reboot...",0

section .bss

bss_start:
