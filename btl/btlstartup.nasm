;*******************************************************************************
; btlstartup.nasm - RadiOS boot-time linker startup.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

%include "bootdefs.ah"

extern ConsInit, ServiceEntry, cmain

section .text

		; Execution begins here
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

Start:		mov	esp,1000h
		call	ConsInit			; Initialize console
		
		push	ebx				; Multiboot info
		push	edx				; Multiboot magic
		call	cmain
		add	esp,byte 8
		mov	dword [BOOTPARM(ServiceEntry)],ServiceEntry
		jmp	eax


section .data

GDTaddrLim	DW	23				; GDT address and limit
		DD	GDT
GDT		DD	0,0
		DW	0FFFFh,0			; Code segment
		DB	0,9Ah,0CFh,0
		DW	0FFFFh,0			; Data segment
		DB	0,92h,0CFh,0
