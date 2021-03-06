;*******************************************************************************
; basedev.nasm - legacy PC chips support (CMOS,PIC,DMA etc.)
; Copyright (c) 1999-2002 RET & COM Research.
;*******************************************************************************

module kernel.x86.basedev

%include "sys.ah"
%include "errors.ah"
%include "biosdata.ah"
%include "hw/ports.ah"
%include "cpu/tss.ah"


publicproc CPU_Init, FPU_Init, FPU_HandleException
publicdata ?CPUinfo


externproc K_Sysenter
externdata KernTSS
externproc K_TTDelay, K_LDelayMs


section .data

FPUtest_X	DD	4195835,0
FPUtest_Y	DD	3145727,0


section .bss

?CPUinfo	RESB	tCPUinfo_size		; Only 1 CPU currently
?FPUtype	RESB	1
?FPUexcFlags	RESB	1			; FPU exception flags


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
		mov	[?CPUinfo+tCPUinfo.Features],edx

		shr	eax,8			; isolate family
		and	eax,0Fh
		mov	[?CPUinfo+tCPUinfo.Family],al
		
		call	CPU_InitMSR
		call	CPU_InitModelName
		
.OK:		clc
		epilogue
		ret
endp		;---------------------------------------------------------------


		; CPU_InitMSR - init MSRs on processors that support them.
		; Input: none.
		; Output: none.
proc CPU_InitMSR
		test	dword [?CPUinfo+tCPUinfo.Features],CPUCAP_MSR
		jz	.Exit
		test	dword [?CPUinfo+tCPUinfo.Features],CPUCAP_SEP
		jz	.Exit
		mov	eax,KERNELCODE
		xor	edx,edx
		mov	ecx,CPU_MSR_SYSENTER_CS
		wrmsr
		mov	eax,K_Sysenter
		mov	ecx,CPU_MSR_SYSENTER_EIP
		wrmsr
		mov	eax,[KernTSS+tTSS.ESP0]
		mov	ecx,CPU_MSR_SYSENTER_ESP
		wrmsr
.Exit:		ret
endp		;---------------------------------------------------------------


		; CPU_InitModelName - fill in model name (if possible).
		; Input: none.
		; Output: none.
proc CPU_InitModelName
		mov	eax,80000000h
		cpuid
		cmp	eax,80000004h
		jb	.Ret

		mov	edi,?CPUinfo+tCPUinfo.ModelID
		mov	eax,80000002h
		cpuid
		mov	[edi],eax
		mov	[edi+4],ebx
		mov	[edi+8],ecx
		mov	[edi+12],edx
		add	edi,byte 16
		mov	eax,80000003h
		cpuid
		mov	[edi],eax
		mov	[edi+4],ebx
		mov	[edi+8],ecx
		mov	[edi+12],edx
		add	edi,byte 16
		mov	eax,80000004h
		cpuid
		mov	[edi],eax
		mov	[edi+4],ebx
		mov	[edi+8],ecx
		mov	[edi+12],edx
		mov	byte [edi+16],0

		; Intel processors put the text right-adjusted. Not nice.
		mov	esi,?CPUinfo+tCPUinfo.ModelID
		mov	edi,esi
		mov	al,' '
		cld
		repe	scasb
		dec	edi
		cmp	edi,esi
		jbe	.Ret
		xchg	esi,edi
.Loop:		lodsb
		or	al,al
		jz	.PadZero
		stosb
		jmp	.Loop

.PadZero:	cmp	edi,?CPUinfo+tCPUinfo.ModelID+64
		je	.Ret
		stosb
		jmp	.PadZero
.Ret:		ret
endp		;---------------------------------------------------------------


		; FPU_Init - initialize FPU.
		; Input: none.
		; Output: none.
proc FPU_Init
		locals	fcw, fdivbug
		prologue
		push	ecx

		mov	[?FPUtype],al
		test	byte [BDA(Hardware)],2		; FPU installed?
		jz	near .Exit

		cli
		mov	ecx,cr0
		or	ecx,CR0_NE			; Enable exception 16
		mov	cr0,ecx
		mov	al,13				; Enable 387 IRQ
		call	PIC_EnableIRQ
		sti

		clts					; Clear TS in CR0
		fninit
		fnstcw	[%$fcw]
		wait
		and	word [%$fcw],0FFC0h
		fldcw	[%$fcw]
		wait
		mov	byte [?FPUexcFlags],0
		fldz
		fld1
		fdiv	st0,st1

		mov	ecx,100				; Delay 0.1 sec
		call	K_LDelayMs
		test	byte [?FPUexcFlags],1		; IRQ13 happened?
		jz	.Test487
		mov	byte [?FPUtype],3
		jmp	.Exit

.Test487:	fninit
		fld	qword [FPUtest_X]
		fdiv	qword [FPUtest_Y]
		fmul	qword [FPUtest_Y]
		fld	qword [FPUtest_X]
		fsubp	st1,st0
		fistp	dword [%$fdivbug]
		wait
		fninit

		cmp	dword [%$fdivbug],0
		jne	.FdivBug
		mov	byte [?FPUtype],4
		jmp	.Exit

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


%include "cmosrtc.nasm"
%include "dma.nasm"
%include "pic.nasm"
%include "pit.nasm"
