;*******************************************************************************
;  kernel.as - RadiOS head kernel file.
;  Copyright (c) 1999,2000 RET & COM research.
;*******************************************************************************

module kernel

%include "sys.ah"
%include "errors.ah"
%include "signal.ah"
%include "biosdata.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "sema.ah"
%include "pool.ah"
%include "process.ah"
%include "i386/descript.ah"
%include "i386/tss.ah"
%include "i386/paging.ah"
%include "hw/ports.ah"
%include "hw/pic.ah"
%include "asciictl.ah"


; --- Exports ---

global DrvNULL, KernelEventHandler
global K_CheckCPU, K_InitFPU 
global K_GetCPUtypeStr, K_GetFPUtypeStr

global K_DescriptorAddress
global K_GetDescriptorBase, K_SetDescriptorBase
global K_GetDescriptorLimit, K_SetDescriptorLimit
global K_GetDescriptorAR, K_SetDescriptorAR
global K_GetGateSelector, K_SetGateSelector
global K_GetGateOffset, K_SetGateOffset, K_SetGateCount
global K_GetExceptionVec, K_SetExceptionVec

global K_RemapToSystem, K_MapStackToSystem, K_UnmapStack

global KernTSS, DrvTSS
global IDTaddr
global ?CPUtype, ?CPUspeed
global DrvId_Con, DrvId_BIOS32, DrvId_RD, DrvId_RFS
global ?TimerTicksLo, ?TimerTicksHi
global ?BaseMemSz, ?ExtMemSz
global ?PhysMemPages, ?VirtMemPages, ?TotalMemPages
global ?HeapBegin, ?HeapEnd
global ?DHlpSymAddr, ?UAPIsymAddr


; --- Imports ---

library init
extern SysReboot:near

library kernel.driver
extern DRV_CallDriver:near

library kernel.mt
extern K_SwitchTask:near

library kernel.onboard
extern CMOS_HandleInt:near, CMOS_ReadBaseMemSz:near, CMOS_ReadExtMemSz:near
extern CPU_GetType:near
extern TMR_CountCPUspeed:near
extern PIC_EnbIRQ:near
extern SPK_Tick:near

library kernel.misc
extern StrEnd:near, StrCopy:near, StrAppend:near
extern DecD2Str:near
extern K_LDelayMs:near


; --- Data ---

section .data

%include "pmdata.as"

FPUinitMsg	DB	"FPU init: ",0
FPUtest_X	DD	4195835,0
FPUtest_Y	DD	3145727,0
FPUstr_Emul	DB	"floating-point emulation library, version 1.0",0
FPUstr_387	DB	"387, using IRQ13 error reporting",0
FPUstr_486	DB	"486+ (built-in), using exception 16 error reporting",0
FPUstr_none	DB	"not present or buggy",0

FPUtypeStrs	DD	FPUstr_none,FPUstr_Emul,FPUstr_Emul
		DD	FPUstr_387,FPUstr_486

MemInitMsg	DB	"Memory init: ",0
MemDISSbase	DB	" KB base, ",0
MemDISSext	DB	" KB extended",0

CPUinitMsg	DB	"CPU init: ",0

Msg_CPU386	DB	"i80386 compatible",0
Msg_CPU486	DB	"i486 compatible",0
Msg_CPUPENT	DB	"Intel Pentium",0
Msg_CPUPPRO	DB	"Intel Pentium Pro",0
Msg_CPUPMMX	DB	"Intel Pentium MMX",0
Msg_CPUP2	DB	"Intel Pentium II",0
Msg_CPUK5	DB	"AMD K5 (5k86)",0
Msg_CPUK6	DB	"AMD K6",0
Msg_CPUK62	DB	"AMD K6-2",0
Msg_CPUM1	DB	"Cyrix/IBM 6x86",0
Msg_CPUM2	DB	"Cyrix/IBM 6x86MX",0
Msg_CPUIDT	DB	"IDT C6",0
Msg_Unknown	DB	"Unknown",0

Msg_SpdInd	DB	", speed index=",0

Msg_NotInst	DB	"not installed",0

Msg_Reboot	DB	NL,NL,"CTRL_ALT_DEL signal received.",NL,0


; --- Variables ---

section .bss

IDTaddr		RESD	1			; IDT address

ExceptionNum	RESB	1			; Last exception number
ExcPrintPos	RESB	1

FPU_ExcFlags	RESB	1			; FPU exception flags

; CPU and FPU type & CPU speed index
?CPUtype	RESB	1
?FPUtype	RESB	1
?CPUspeed	RESD	1

; Memory sizes (in kilobytes)
?BaseMemSz	RESD	1
?ExtMemSz	RESD	1

; Number of extended memory pages
?PhysMemPages	RESD	1			; Number of ext. mem. pages
?VirtMemPages	RESD	1			; Virtual memory pages
?TotalMemPages	RESD	1			; Total number of pages (Ext+VM)

; Heap (user segment) begin and end address
?HeapBegin	RESD	1
?HeapEnd	RESD	1

; Timer ticks counter
?TimerTicksLo	RESD	1			; Low dword
?TimerTicksHi	RESD	1			; High dword

; Installed drivers IDs
DrvId_Con	RESD	1
DrvId_BIOS32	RESD	1
DrvId_RD	RESD	1
DrvId_RFS	RESD	1

; API symbol tables addresses
?DHlpSymAddr	RESD	1
?UAPIsymAddr	RESD	1


; --- Procedures ---

section .text

%include "ints.as"
%include "memdet.as"

		; K_DescriptorAddress - get address of descriptor.
		; Input: DX=descriptor.
		; Output: EBX=descriptor address.
proc K_DescriptorAddress
		push	edi
		movzx	edx,dx
		test	dx,SELECTOR_LDT		; See if in LDT
		jz	.GetGDT
		xor	ebx,ebx			; If so get LDT selector
		sldt	bx
		and	ebx,~SELECTOR_STATUS	; Strip off RPL and TI
		add	ebx,offset GDT		; Find position in GDT
		call	K_GetDescriptorBase	; Load up the LDT base address
		mov	ebx,edi
		jmp	short .GotLDT
.GetGDT:	mov	ebx,offset GDT		; Otherwise just get the GDT table
.GotLDT:	and	edx,~SELECTOR_STATUS	; Strip off RPL and TI of descriptor
		add	ebx,edx			; Add in to table base
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; K_GetDescriptorBase - get base fields of descriptor.
		; Input: EBX=descriptor address.
		; Output: EDI=base address.
proc K_GetDescriptorBase
		push	eax
		mov	al,[ebx+tDesc.BaseHLB]
		mov	ah,[ebx+tDesc.BaseHHB]
		shl	eax,16
		mov	ax,[ebx+tDesc.BaseLW]
		mov	edi,eax
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_SetDescriptorBase - set base fields of descriptor.
		; Input: EBX=descriptor address,
		;	 EDI=base address.
		; Output: none.
proc K_SetDescriptorBase
		push	eax
		mov	eax,edi
		mov	[ebx+tDesc.BaseLW],ax
		shr	eax,16
		mov	[ebx+tDesc.BaseHLB],al
		mov	[ebx+tDesc.BaseHHB],ah
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_GetDescriptorLimit - get limit fields of descriptor.
		; Input: EBX=descriptor address.
		; Output: EAX=limit.
proc K_GetDescriptorLimit
		mov	al,[ebx+tDesc.LimHiMode]
		and	ax,15
		shl	eax,16
		mov	ax,[ebx+tDesc.LimitLo]
		test	byte [ebx+tDesc.LimHiMode],AR_Granlr
		jz	.Exit
		shl	eax,12
		or	eax,PAGESIZE-1
.Exit:		ret
endp		;---------------------------------------------------------------


		; K_SetDescriptorLimit - set limit fields of descriptor.
		; Input: EBX=descriptor address,
		;	 EAX=limit.
		; Output: none.
proc K_SetDescriptorLimit
		push	eax
		and	byte [ebx+tDesc.LimHiMode],~AR_Granlr
		test	eax,0FFF00000h
		jz	.LowGrn
		or	byte [ebx+tDesc.LimHiMode],AR_Granlr
		shr	eax,12
.LowGrn:	mov	[ebx+tDesc.LimitLo],ax
		shr	eax,16
		and	byte [ebx+tDesc.LimHiMode],0F0h
		or	byte [ebx+tDesc.LimHiMode],al
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_GetDescriptorAR - get access rights fields of descriptor.
		; Input: EBX=descriptor address.
		; Output: AX=ARs.
proc K_GetDescriptorAR
		mov	al,[ebx+tDesc.AR]
		mov	ah,[ebx+tDesc.LimHiMode]
		and	ah,15
		ret
endp		;---------------------------------------------------------------


		; K_SetDescriptorAR - get access rights fields of descriptor.
		; Input: EBX=descriptor address,
		;	 AX=ARs.
		; Output: none.
proc K_SetDescriptorAR
		mov	[ebx+tDesc.AR],al
		and	ah,15
		or	[ebx+tDesc.LimHiMode],ah
		ret
endp		;---------------------------------------------------------------


		; K_GetGateSelector - get selector field of gate descriptor.
		; Input: EBX=descriptor address.
		; Output: DX=selector.
proc K_GetGateSelector
		mov	dx,[ebx+tGateDesc.Selector]
		ret
endp		;---------------------------------------------------------------


		; K_SetGateSelector - set selector field of gate descriptor.
		; Input: EBX=descriptor address,
		;	 DX=selector.
proc K_SetGateSelector
		mov	[ebx+tGateDesc.Selector],dx
		ret
endp		;---------------------------------------------------------------


		; K_GetGateOffset - get offset field of gate descriptor.
		; Input: EBX=descriptor address,
		; Output: EAX=offset.
proc K_GetGateOffset
		mov	ax,[ebx+tGateDesc.OffsetHi]
		shl	eax,16
		mov	ax,[ebx+tGateDesc.OffsetLo]
		ret
endp		;---------------------------------------------------------------


		; K_SetGateOffset - set offset field of gate descriptor.
		; Input: EBX=descriptor address,
		;	 EAX=offset.
proc K_SetGateOffset
		mov	[ebx+tGateDesc.OffsetLo],ax
		shr	ax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		ret
endp		;---------------------------------------------------------------


		; K_SetGateCount - set gate descriptor count field.
		; Input: EBX=descriptor address,
		;	 AL=count.
proc K_SetGateCount
		mov	[ebx+tGateDesc.Count],al
		ret
endp		;---------------------------------------------------------------


		; K_GetExceptionVec - get exception handler selector
		;		      and offset.
		; Input: AL=vector number.
		; Output: DX=handler selector,
		;	  EBX=handler offset.
proc K_GetExceptionVec
		push	eax
		movzx	ebx,al
		shl	ebx,3				; Count gate address
		add	ebx,[IDTaddr]
		call	K_GetGateOffset
		call	K_GetGateSelector
		mov	ebx,eax
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_SetExceptionVec - set exception vector.
		; Input: DX=handler selector,
		;	 EBX=handler offset,
		;	 AL=vector number.
proc K_SetExceptionVec
		mpush	eax,ebx
		movzx	eax,al
		shl	eax,3				; Count gate address
		add	eax,[IDTaddr]
                xchg	eax,ebx
		call	K_SetGateOffset
		call	K_SetGateSelector
		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


		; K_CheckCPU - determine CPU type and speed index.
		; Input: none.
		; Output: none.
proc K_CheckCPU
		push	ecx
		call	CPU_GetType
		mov	[?CPUtype],al
		call	TMR_CountCPUspeed
		mov	[?CPUspeed],ecx
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; K_GetCPUtypeStr - get CPU type string.
		; Input: ESI=buffer pointer.
		; Output: none.
proc K_GetCPUtypeStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,CPUinitMsg
		call	StrCopy

		mov	al,[?CPUtype]
		cmp	al,3
		je	.386
		cmp	al,4
		je	.486
		cmp	al,5
		je	.586
		mov	esi,Msg_Unknown
		jmp	short .BldStr

.386:		mov	esi,Msg_CPU386
		jmp	short .BldStr
.486:		mov	esi,Msg_CPU486
		jmp	short .BldStr
.586:		mov	esi,Msg_CPUPENT
		jmp	short .BldStr


.BldStr:	call	StrAppend
		mov	esi,Msg_SpdInd
		call	StrAppend
		mov	esi,edi
		call	StrEnd
		mov	esi,edi
		mov	eax,[?CPUspeed]
		call	DecD2Str

		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; K_InitFPU - initialize FPU.
		; Input: AL=1 - use emulation library if 387 not installed.
		; Output: none.
proc K_InitFPU
%define	.fcw		ebp-4
%define	.fdiv_bug	ebp-8

		prologue 8
		push	ecx

		mov	[?FPUtype],al
		test	byte [BIOSDA_Begin+tBIOSDA.Hardware],2	; FPU installed?
		jnz	short .Test387
		cmp	al,1				; Use emulation lib?
		jne	near .Exit
		call	FPU_InitEmuLib
		jmp	.Exit

.Test387:	cli
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
		mov	byte [FPU_ExcFlags],0
		fldz
		fld1
		fdiv	st0,st1

		mov	ecx,100				; Delay 0.1 sec
		call	K_LDelayMs
		test	byte [FPU_ExcFlags],1		; IRQ13 happened?
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

.FdivBug:	mov	byte [?FPUtype],0

.Exit:		pop	ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; FPU_HandleEvents - handle IRQ13 on a 387.
		; Input: none.
		; Output: none.
proc FPU_HandleEvents
		or	byte [FPU_ExcFlags],1
		ret
endp		;---------------------------------------------------------------


		; K_GetFPUtypeStr - get FPU type string.
		; Input: ESI=pointer to buffer.
		; Output: none.
proc K_GetFPUtypeStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,FPUinitMsg
		call	StrCopy
		call	StrEnd
		xor	eax,eax
		mov	al,[?FPUtype]
		mov	esi,[FPUtypeStrs+eax*4]
		call	StrCopy
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; FPU_InitEmuLib - initialize floating point emulation library.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FPU_InitEmuLib
		ret
endp		;---------------------------------------------------------------



; --- Kernel event handler ---

		; KernelEventHandler - handle kernel events.
		; Input: EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc KernelEventHandler
		push	eax
		ror	eax,16
		cmp	ax,EV_SIGNAL
		pop	eax
		je	short .Signal
		stc
		ret

.Signal:	cmp	ax,SIG_CTRLALTDEL
		je	short .Reboot
		ret

.Reboot:	mPICACK 0
		sti
		jmp	SysReboot
endp		;---------------------------------------------------------------


; --- Another common routines ---

		; K_TableSearch - search in table.
		; Input: EBX=table address,
		;	 ECX=number of elements in table,
		;	 EAX=searching mask,
		;	 DL=size of table element,
		;	 DH=offset to target field in table element.
		; Output: CF=0 - OK:
		;	   EDX=element number,
		;	   EBX=element address;
		;	  CF=1 - not found.
proc K_TableSearch
		mpush	edx,esi,edi
		movzx	esi,dl
		movzx	edi,dh
		xor	edx,edx
.Loop:		test	[ebx+edi],eax
		jz	short .Found
		add	ebx,esi
		inc	edx
		cmp	edx,ecx
		je	short .NotFound
		jmp	.Loop
.Found:		clc
.Exit:		mpop	edi,esi,edx
		ret
.NotFound:	stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; DrvNULL - NULL device driver.
		; Action: simply does RET.
proc DrvNULL
		ret
endp		;---------------------------------------------------------------
