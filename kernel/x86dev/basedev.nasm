;*******************************************************************************
;  basedev.nasm - built-in devices support (CMOS,PIC,DMA etc.)
;  Copyright (c) 1999-2002 RET & COM Research.
;*******************************************************************************

module kernel.x86.basedev

%include "sys.ah"
%include "errors.ah"
%include "biosdata.ah"
%include "hw/ports.ah"

%include "8042.nasm"
%include "cmosrtc.nasm"
%include "dma.nasm"
%include "pic.nasm"
%include "timer.nasm"

%define	SpeakerBeepTone	1200

; --- Exports ---
publicproc CPU_Init, FPU_Init, FPU_HandleException
publicproc SPK_Sound, SPK_Beep, SPK_Tick
publicdata ?CPUinfo


; --- Imports ---

library kernel.misc
extern K_TTDelay, K_LDelayMs


; --- Data ---
section .data

FPUtest_X	DD	4195835,0
FPUtest_Y	DD	3145727,0


; --- Variables ---
section .bss

?CPUinfo	RESB	tCPUinfo_size		; Only 1 CPU currently
?FPUtype	RESB	1
?FPUexcFlags	RESB	1			; FPU exception flags

; --- Code ---
section .text

		; CPU_Init - initialize CPU information structure and internal
		;	     registers (if any).
		; Input: none.
		; Output: CF=1 - can't determine CPU type;
		;	  CF=0 - OK.
		; Note: destroys [almost] all registers.
proc CPU_Init
		locals r_eflags
		prologue 4
		
		; First, we should have at least 386SX
		mov	word [?CPUinfo+tCPUinfo.Family],CPU_386SX
		mov	eax,cr0
		mov	ebx,eax			; Save original CR0
		or	al,CR0_ET		; Set bit
		mov	cr0,eax
		mov	eax,cr0
		mov	cr0,ebx
		test	al,CR0_ET		; Did it set?
		jz	near .OK		; No, it's 386SX

		; Perhaps it's 386DX?
		mov	word [?CPUinfo+tCPUinfo.Family],CPU_386DX
		mov	ecx,esp			; Store original ESP
		pushfd				;  and EFLAGS
		pop	dword [%$r_eflags]
		and	esp,~3			; Align stack to prevent 486
						;  fault when AC is flipped
		mov	eax,[%$r_eflags]
		xor	eax,FLAG_AC		; Flip AC flag
		push	eax			; Store it
		popfd
		pushfd				; Read it back
		pop	eax
		push	dword [%$r_eflags]	; Restore EFLAGS
		popfd
		mov	esp,ecx			; Restore ESP
		cmp	eax,[%$r_eflags]	; Compare old/new AC bits
		je	.OK			; AC doesn't change => 386DX

		; Check for ability to set/clear ID flag (Bit 21) in EFLAGS
		; which indicates that we can execute CPUID. If not, then
		; we have an old 486 or 487 processor.
		mov	word [?CPUinfo+tCPUinfo.Family],CPU_486OLD
		mov	eax,[%$r_eflags]
		xor	eax,FLAG_ID		; Flip ID bit in EFLAGS
		push	eax
		popfd
		pushfd
		pop	eax
		xor	eax,[%$r_eflags]	; Compare with original EFLAGS
		jz	.OK			; Can't toggle, it's an old 486
		
		; Execute CPUID to determine vendor, family, model, stepping
		; and features.
		mov	word [?CPUinfo+tCPUinfo.Family],CPU_486
		xor	eax,eax
		cpuid
		mov	[?CPUinfo+tCPUinfo.CPUIDlevel],al
		mov	[?CPUinfo+tCPUinfo.VendorID],ebx
		mov	[?CPUinfo+tCPUinfo.VendorID+4],edx
		mov	[?CPUinfo+tCPUinfo.VendorID+8],ecx
		or	eax,eax			; Can we get CPU features?
		jz	.OK			; No, it's some DX4 clone
		
		; Get family/model/stepping/features
.CheckFeat:	mov	eax,1
		cpuid                                          
		mov	[?CPUinfo+tCPUinfo.Features],ebx
		mov	[?CPUinfo+tCPUinfo.Features+4],edx
		mov	[?CPUinfo+tCPUinfo.Features+8],ecx

		shr	eax,8			; isolate family
		and	eax,0Fh
		mov	[?CPUinfo+tCPUinfo.Family],al
		
.OK:		clc
		epilogue
		ret
endp		;---------------------------------------------------------------


		; FPU_Init - initialize FPU.
		; Input: none.
		; Output: none.
proc FPU_Init
%define	.fcw		ebp-4
%define	.fdiv_bug	ebp-8

		prologue 8
		push	ecx

		mov	[?FPUtype],al
		test	byte [BDA(Hardware)],2		; FPU installed?
		jz	near .Exit

		cli
		mov	ecx,cr0
		or	ecx,CR0_NE			; Enable exception 16
		mov	cr0,ecx
		mov	al,13				; Enable 387 IRQ
		call	PIC_EnbIRQ
		sti

		clts					; Clear TS in CR0
		fninit
		fnstcw	[.fcw]
		wait
		and	word [ebp-.fcw],0FFC0h
		fldcw	[.fcw]
		wait
		mov	byte [?FPUexcFlags],0
		fldz
		fld1
		fdiv	st0,st1

		mov	ecx,100				; Delay 0.1 sec
		call	K_LDelayMs
		test	byte [?FPUexcFlags],1		; IRQ13 happened?
		jz	short .Test487
		mov	byte [?FPUtype],3
		jmp	short .Exit

.Test487:	fninit
		fld	qword [FPUtest_X]
		fdiv	qword [FPUtest_Y]
		fmul	qword [FPUtest_Y]
		fld	qword [FPUtest_X]
		fsubp	st1,st0
		fistp	dword [.fdiv_bug]
		wait
		fninit

		cmp	dword [.fdiv_bug],0
		jne	.FdivBug
		mov	byte [?FPUtype],4
		jmp	short .Exit

.FdivBug:	or	byte [?CPUinfo+tCPUinfo.Bugs],CPUBUG_FDIV
		mov	byte [?FPUtype],0

.Exit:		pop	ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; FPU_HandleException - handle a FPU exception.
		; Input: none.
		; Output: none.
proc FPU_HandleException
		or	byte [?FPUexcFlags],1
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
