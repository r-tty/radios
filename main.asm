;*******************************************************************************
;  main.asm - ZealOS initializer.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
ideal

include "initdefs.ah"

DEBUGUNDERDOS=1

;*********************** Protected mode starting segment ***********************

segment		PMSTARTSEG 'code' use16
		assume CS:PMSTARTSEG, DS:PMSTARTSEG, ES:ZMAINSEG
		org 0

		; Now program is in real mode.
		; This	code sets GDT and IDT, then enter protected mode.
ZRMstart:	cli

IFDEF	DEBUGUNDERDOS
		jmp	ENBLA20
include "ETC\a20at.asm"
ENBLA20:	mov	ax,1				; Activating A20
		call	AT_A20Handler
		mov	ax,PMSTARTSEG			; Move PM start code
		mov	ds,ax				; to HMA
		mov	ax,0FFFFh
		mov	es,ax
		mov	si,offset DBG_MOVEKRNL
		mov	di,si
		mov	cx,100h
		cld
		rep	movsb
		DB	0EAh				; Far jump in HMA
		DW	offset DBG_MOVEKRNL
		DW	0FFFFh

DBG_MOVEKRNL:	mov	ax,ZMAINSEG			; Move kernel code
		mov	ds,ax				; to 0:1000h
		xor	ax,ax
		mov	es,ax
		mov	si,1000h
		mov	di,si
		mov	cx,0FFFFh
		cld
		rep	movsb
ENDIF
		mov	ax,cs
		mov	ds,ax
		mov	eax,offset GDT			; Prepare for LGDT
		mov	[dword	GDTptr+2],eax
    		mov	eax,offset IDT			; Prepare for LIDT
    		mov	[dword	IDTptr+2],eax
		lgdt	[GDTptr]
		lidt	[IDTptr]
		mov	eax,cr0
		or	al,1
		mov	cr0,eax				; Enter PM
		PMJF16	KernelCode,ZPMinit		; Far jump to PM kernel

GDTptr		DF	(size GDT)-1
IDTptr		DF	(size tDescriptor)*256-1

ends


;**************************** Kernel segment ***********************************

segment		ZMAINSEG 'code' use32
		assume CS:ZMAINSEG, DS:ZMAINSEG
		org 0

;-------------------------------- Externals ------------------------------------

		extrn V86VidBIOS:	near

;------------------------------ BIOS data area ---------------------------------

include "KERNEL\V86BIOS\biosdata.ah"

V86INTSTBL	tRVINTSTBL	<>
BIOSDATA	tBIOSDA		<>

		DB BIOSDAsize-(size V86INTSTBL)-(size BIOSDATA) dup (?)
label BIOSstack near

;-------------------------------- Kernel body ----------------------------------

include "KERNEL\kernel.asm"

;------------------------- Initialization procedures ---------------------------

		; Initialize interrupt	descriptors table
proc InitIDT	near

		ret
endp

;----------------------- Inititialization entry point --------------------------

label ZPMinit	far

		; Set segment registers
		mov	ax,offset (tZGDT).KernelData
		mov	ds,ax
		mov	es,ax
		mov	gs,ax
		mov	fs,ax
		mov	ss,ax
		mov	esp,InitESP

		; Initialize interrupt controller (PIC)
		xor	ah,ah
		mov	al,IRQ0int
		call	InitPIC
		inc	ah
		mov	al,IRQ8int
		call	InitPIC
		xor	eax,eax
		call	SetIRQmask
		not	eax
		call	SetIRQmask
		sti

		mov	eax,0B8000h
		mov	[byte eax],'#'
		add	eax,2
		mov	[byte eax],':'
Halt:		jmp	Halt

ends

end	ZRMstart
