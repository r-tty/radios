;*******************************************************************************
;  barekld.as - load kernel from disk using BIOS int 13h functions.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

%include "biosxma.ah"

; --- Exports ---

global StartupCHSD


; --- Imports ---

extern _WrString, _main


; --- Definitions ---

%define	BOOTSECADDR	7C00h


; --- Code ---

section .text
bits 16

		jmp	Start

		; Call loaded boot sector.
proc CallBoot
		mov	si,BOOTSECADDR			; Move loaded boot
		mov	di,si				; sector from current
		xor	ax,ax				; segment to 0:7C00h
		mov	es,ax
		mov	cx,256
		cld
		rep	movsw
		mov	ds,ax				; DS=0
		cli
		mov	ss,ax				; SS:SP=0:FFF0h
		mov	sp,0FFF0h
		sti
		jmp	0:BOOTSECADDR			; Jump to moved sector
endp		;---------------------------------------------------------------


		; Halt when fatal error occurs.
proc Halt
		push	word MsgSysHalt
		call	_WrString
		jmp	$
endp		;---------------------------------------------------------------


		; Boot sector loads system loader at 70h:100h and passes
		; execution here.
proc Start
		mov	ax,cs
		mov	ds,ax
		mov	es,ax

		mov	[StartupCHSD],dx		; Keep CHS and drive
		mov	[StartupCHSD+2],cx		; passed by boot sector

.MainLoop:	call	_main
		or	ax,ax
		jz	near CallBoot
		cmp	ax,8
		jae	Halt
		jmp	.MainLoop
endp		;---------------------------------------------------------------


; --- Data ---

section .data

MsgSysHalt	DB	"System halted.",0


; --- Variables ---

section .bss

StartupCHSD	RESD	1
