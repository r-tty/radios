;*******************************************************************************
;  main.asm - RadiOS initializer.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

.386p
ideal

include "initdefs.ah"
include "biosdata.ah"
include "DRIVERS\SOFT\consoles.ah"

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
include "ETC\dbgudos.asm"
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

		extrn GetCPUtype:	near

		extrn PIC_Init:		near
		extrn PIC_SetIRQmask:	near

		extrn TMR_CountCPUspeed: near

		extrn SPK_Beep:		near

;------------------------------ BIOS data area ---------------------------------

RMIntsTbl	tRMIntsTbl	<>
BIOSData	tBIOSDA		<>

		DB BIOSDAsize-(size RMIntsTbl)-(size BIOSData) dup (?)


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


		; INIT_ShowCPUNPU - show CPU & NPU type
proc INIT_ShowCPUNPU near
		mov	esi,offset INFO_MainCPU
		call	INIT_WrString
		mov	al,[CPUtype]
		cmp	al,3
		je	DetCPU_386
		cmp	al,4
		je	DetCPU_486
		cmp	al,5
		je	DetCPU_586
		mov	esi,offset INFO_Unknown
                jmp	DetCPU_WrS
DetCPU_386:	mov	esi,offset INFO_CPU386
                jmp	DetCPU_WrS
DetCPU_486:     mov	esi,offset INFO_CPU486
                jmp	DetCPU_WrS
DetCPU_586:     mov	esi,offset INFO_CPUPENT
                jmp	DetCPU_WrS


DetCPU_WrS:	call	INIT_WrString
		mov	esi,offset INFO_SpdInd
		call	INIT_WrString
		mov	eax,[CPUspeed]
		call	ddecout
		mov	al,NL
		call	INIT_WrChar
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

		; Detect CPU & NPU type, count CPU speed index
		call	GetCPUtype
		mov	[CPUtype],al
		mov	cx,1024
		call	TMR_CountCPUspeed
		mov	[CPUspeed],ecx

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

		; Detect hardware devices using by consoles
		call	CON_DetectDevs
		jc	Init_SysHalt

		; Prepare console 0 for output
		xor	bh,bh
		call	CON_SetActive
		mov	ah,7
		stc
		call	CON_ClrScr
		xor	edx,edx
		call	CON_MoveCursor

		; Show CPU & NPU type
		call	INIT_ShowCPUNPU

		; Show kernel version message
		mov	esi,offset INFO_RadiOS
		call	INIT_WrString

		; Call debugger
		call	DebugEntry

		; Halt system
Init_SysHalt:	call	SPK_Beep
Init_Halt:	jmp	Init_Halt

ends

end	RMstart
