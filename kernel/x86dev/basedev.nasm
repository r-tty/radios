;*******************************************************************************
;  basedev.nasm - built-in devices support (CMOS,PIC,DMA etc.)
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module kernel.x86.basedev

%include "sys.ah"
%include "errors.ah"
%include "hw/ports.ah"

%include "8042.nasm"
%include "cmosrtc.nasm"
%include "dma.nasm"
%include "pic.nasm"
%include "timer.nasm"


; --- Miscellaneous ------------------------------------------------------------

; --- Exports ---

global CPU_GetType:proc
global SPK_Sound:proc, SPK_Beep:proc, SPK_Tick:proc


; --- Imports ---

library kernel.misc
extern K_TTDelay:near


;  CPU types
%define	CPU_386SX	3
%define	CPU_386DX	3
%define	CPU_486		4
%define	CPU_586		5

; Speaker, etc.
%define	SpeakerBeepTone	1200


section .text

		; CPU_GetType - determine type of CPU.
		; Input: none.
		; Output: CF=1 - can't determine CPU type;
		;	  CF=0 - All OK, CPU type in AL:
		;		  3 - i386 compatible,
		;		  4 - i486 compatible,
		;		  5 - Pentium compatible.
proc CPU_GetType
		push	ebx
		mov	eax,cr0
		mov	ebx,eax			; Original CR0 into EBX
		or	al,10h			; Set bit
		mov	cr0,eax			; Store it
		mov	eax,cr0			; Read it back
		mov	cr0,ebx			; Restore CR0
		test	al,10h			; Did it set?
		jnz	.Test386DX		; Go if not 386SX

                mov	al,CPU_386SX
                jmp	.OK

.Test386DX:	mov	ecx,esp			; Original ESP in ECX
		pushfd				; Original EFLAGS in EBX
		pop	ebx
		and	esp,~3			; Align stack to prevent 486
						;  fault when AC is flipped
		mov	eax,ebx			; EFLAGS => EAX
		xor	eax,40000h		; Flip AC flag
		push	eax			; Store it
		popfd
		pushfd				; Read it back
		pop	eax
		push	ebx			; Restore EFLAGS
		popfd
		mov	esp,ecx			; Restore ESP
		cmp	eax,ebx			; Compare old/new AC bits
		jne	.Test486		; If AC changes, not 386

		mov	al,CPU_386DX
		jmp	short .OK

.Test486:	mov	al,CPU_486		;Until the Pentium appears...

.OK:		clc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; SPK_Sound - play sound signal on PC-speaker.
		; Input: ECX - sound tone (high word) and length (low word).
proc SPK_Sound
		push	eax
		mov	al,TMRCW_Mode3+TMRCW_LH+TMRCW_CT2
		ror	ecx,16
		call	TMR_InitCounter
		call	KBC_SpeakerON
		shr	ecx,16
		call	K_TTDelay
		call	KBC_SpeakerOFF
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SPK_Beep - play ASC_BEL.
proc SPK_Beep
		push	ecx
		mov	ecx,SpeakerBeepTone
		shl	ecx,16
		mov	cl,5
		call	SPK_Sound
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; SPK_Tick - play short sound tick.
proc SPK_Tick
		mpush	eax,ecx
		mov	al,TMRCW_Mode3+TMRCW_LH+TMRCW_CT2
		mov	cx,SpeakerBeepTone/4
		call	TMR_InitCounter
		call	KBC_SpeakerON
		mov	cx,5000
		call	TMR_Delay
		call	KBC_SpeakerOFF
		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------


		; BCDW2Dec - convert a BCD word to decimal;
		; BCDB2Dec - convert a BCD byte to decimal.
		; Input: AX=BCD word.
		; Output: AX=converted word.
proc BCDW2Dec
		call	BCDB2Dec
		xchg	al,ah
		call	BCDB2Dec
		xchg	al,ah
		ret

BCDB2Dec:	push	ecx
		movzx	ecx,ah
		shl	ecx,16
		mov	cl,al
		mov	ch,10
		and	al,0F0h
		shr	al,4
		xor	ah,ah
		mul	ch
		and	cl,0Fh
		add	al,cl
		shr	ecx,16
		mov	ah,cl
		pop	ecx
		ret
endp		;---------------------------------------------------------------
