;*******************************************************************************
;  main.asm - RadiOS initializer.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
ideal

include "initdefs.ah"

DEBUGUNDERDOS=1
DEBUG=1


;*********************** Protected mode starting segment ***********************

segment		PMSTARTSEG 'code' use16
		assume CS:PMSTARTSEG, DS:PMSTARTSEG, ES:RADIOSKRNLSEG
		org 0

		; Now program is in real mode.
		; This	code sets GDT and IDT, then enter protected mode.
RMstart:	cli

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

DBG_MOVEKRNL:	mov	ax,RADIOSKRNLSEG		; Move kernel code
		mov	ds,ax				; to 0:1000h
		xor	ax,ax
		mov	es,ax
		mov	si,1000h
		mov	di,si
		mov	cx,0F000h
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
		PMJF16	KernelCode,PMinit		; Far jump to PM kernel

GDTptr		DF	(size GDT)-1
IDTptr		DF	(size tDescriptor)*256-1

ends


;**************************** Kernel segment ***********************************

segment		RADIOSKRNLSEG public 'code' use32
		assume CS:RADIOSKRNLSEG, DS:RADIOSKRNLSEG
		org 0

;-------------------- External and global procedures and data-------------------

		; Console procedures (consoles.asm)
		extrn CON_InitAll:	near
		extrn CON_WrCharTTY:	near
		extrn CON_ClearCon:	near
		extrn CON_SetActive:	near
		extrn CON_MoveCursor:	near
		extrn CON_HandleCTRL:	near

		extrn PIC_Init:		near
		extrn PIC_SetIRQmask:	near

		extrn SPK_Beep:near

;------------------------------ BIOS data area ---------------------------------

include "KERNEL\V86BIOS\biosdata.ah"

V86INTSTBL	tRVINTSTBL	<>
BIOSDATA	tBIOSDA		<>

		DB BIOSDAsize-(size V86INTSTBL)-(size BIOSDATA) dup (?)
label BIOSstack near


;------------------------------- Kernel body -----------------------------------

include "KERNEL\kernel.asm"


;------------------------- Initialization procedures ---------------------------

		; INIT_WrChar - write character (used before setting up
		;		video driver).
		; Input: AL=character code.
		; Output: none.
		; Note: handles ASCII BEL,BS,HT codes;
		;	use LF as CRLF (UNIX-style).
proc INIT_WrChar near
		call	CON_WrCharTTY
		cmp	al,ASC_LF
		jne	INITWC_Exit
		push	eax
		mov	al,ASC_CR
		call	CON_HandleCTRL
		pop	eax
INITWC_Exit:	ret
endp		;---------------------------------------------------------------


		; INIT_WrString - write string (used before setting up
		;		  video driver).
		; Input: ESI=pointer to ASCIIZ-string.
		; Output: none.
		; Note: use only ASC_LF (0Ah) instead CRLF.
proc INIT_WrString near
		push	esi
		push	eax
INITWS_Loop:	mov	al,[byte esi]
		or	al,al
		jz	INITWS_Exit
		call	INIT_WrChar
                inc	esi
		jmp	short INITWS_Loop
INITWS_Exit:	pop	eax
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; INIT_DetectCPU - detect CPU type and write on screen
proc INIT_DetectCPU near
		mov	esi,offset INFO_MainCPU
		call	INIT_WrString
		ret
endp		;---------------------------------------------------------------

;----------------------- Inititialization entry point --------------------------

label PMinit far

		; Disable interrupts
		cli

		; Set segment registers
		mov	ax,offset (tRGDT).KernelData
		mov	ds,ax
		mov	es,ax
		mov	gs,ax
		mov	fs,ax
		mov	ss,ax
		mov	esp,InitESP

		; Initialize consoles
		call	CON_InitAll
		jc	Init_SysHalt

		; Prepare console 0 for output
		xor	bh,bh
		call	CON_SetActive
		mov	ah,7
		stc
		call	CON_ClearCon
		xor	edx,edx
		call	CON_MoveCursor

		; Detecting CPU type
		call	INIT_DetectCPU

		; Initialize interrupt controller (PIC)
		xor	ah,ah
		mov	al,IRQ0int
		call	PIC_Init
		inc	ah
		mov	al,IRQ8int
		call	PIC_Init
		xor	eax,eax
		call	PIC_SetIRQmask
		not	eax
		call	PIC_SetIRQmask


		sti
		mov	al,'}'
		call	CON_WrCharTTY


Init_SysHalt:	call	SPK_Beep
Init_Halt:	jmp	Init_Halt

ends

end	RMstart
