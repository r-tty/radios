;-------------------------------------------------------------------------------
;  _ztest.asm - RadiOS modules test program.
;-------------------------------------------------------------------------------

.386p
ideal

_DEBUG=1

macro	ADDRCONV RMofs,Targ32
	push	eax
	xor	eax,eax
	mov	ax,cs
	shl	eax,4
	add	eax,offset RMofs
	mov	Targ32,eax
	pop	eax
endm

segment	ZTESTSEG	'code' use16
		assume	CS:ZTESTSEG
		org 0

include "KERNEL\errdefs.ah"
include "KERNEL\sysdata.ah"
include "DRIVERS\harddevs.asm"
include "KERNEL\UTILS\utils.asm"

ZOSTEST:
		cli
		mov	ax,ZSTACKSEG
		mov	ss,ax
		mov	sp,2048
		sti

		push	cs
		pop	ds
		mov	ax,3D00h		; Read test file
		mov	dx,offset TestFile
		int	21h
		jc	Exit
		mov	[FHnd],ax

		mov	bx,[FHnd]
		mov	cx,[FLen]
		mov	dx,offset TWA
		mov	ah,3Fh
		int	21h
		jc	Exit

		xor	ax,ax			; Set SREGS to 0
		mov	ds,ax
		mov	es,ax

		mov	bh,1			; Set VPage=1
		call	VGATX_SetActPage
		mov	eax,0B9000h
		mov	[dword eax],':#'
		mov	bh,1
		mov	dx,100h
		call	VGATX_MoveCursor

		xor	esi,esi
		mov	si,cs			; Write test file
		shl	esi,4	
		xor	eax,eax
		mov	ax,offset TWA
		add	esi,eax
		mov	cx,[FLen]
WrFloop:	lods	[byte esi]
		call	VGATX_WrCharTTY
		dec	cx
		jcxz    TestTTY
		jmp	WrFloop

TestTTY:	xor	ah,ah
		int	16h
		cmp	al,27
		je	Read8253
		call	VGATX_WrCharTTY
		cmp	al,13
		jne	TestTTY
		mov	al,10
		call	VGATX_HandleCTRL
		jmp	TestTTY

Read8253:	in	al,PORT_KBC_1			; Enable GATE2
		and	al,not 2
		or	al,1
		PORTDELAY
		out	PORT_KBC_1,al

		xor	eax,eax
		mov	dx,24				; Test Calibrate DL
TestCDL:	mov	cx,1024
		call	TMR_CountCPUspeed
		mov	eax,ecx
;		xor	al,al
;		stc
;		call	TMR_ReadOnFly
		call	ddecout
		mov	al,9
		call	VGATX_HandleCTRL
;		mov	al,10
;		call	VGATX_HandleCTRL
		dec	dx
		jnz	TestCDL
		xor	ah,ah
		int	16h


Ring:		mov	bh,1
		mov	ah,7
		stc
		call	VGATX_ClrVidPage
		mov	al,7				; Test beep
		call	VGATX_HandleCTRL

		xor	bh,bh
		call	VGATX_SetActPage
		xor	bh,bh
		clc
		call	VGATX_ClrVidPage
		xor	dl,dl
		mov	dh,2
		xor	bh,bh
		call	VGATX_MoveCursor

		ADDRCONV CntDelMsg,esi
		call	puts
		mov	cx,1024
		call	TMR_CountCPUspeed
		mov	eax,ecx
		call	ddecout
		xor	ah,ah
		int	16h
		jmp	Exit

_Exit:		xor	bh,bh
		call	VGATX_SetActPage
Exit:		mov	ax,4C00h
		int	21h

BIOStimecount	EQU	46Ch
TimerTicksLo	EQU	dword ptr BIOStimecount

CntDelMsg	DB	'Counting CPU speed... ',0

TestFile	DB	'_rtest.dta',0
FHnd		DW	?
FLen		DW	32
TWA		DB	4096 dup (?)

ends


segment	ZSTACKSEG	stack 'STACK' use16
		DB	2048 dup (?)
ends

end	ZOSTEST