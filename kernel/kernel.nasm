;*******************************************************************************
;  kernel.nasm - RadiOS head kernel file.
;  Copyright (c) 1999,2000 RET & COM research.
;*******************************************************************************

module kernel

%include "sys.ah"
%include "errors.ah"
%include "signal.ah"
%include "biosdata.ah"
%include "pool.ah"
%include "process.ah"
%include "x86/descript.ah"
%include "x86/tss.ah"
%include "x86/paging.ah"
%include "hw/ports.ah"
%include "hw/pic.ah"
%include "boot/bootdefs.ah"
%include "asciictl.ah"


; --- Exports ---



global K_DescriptorAddress
global K_GetDescriptorBase, K_SetDescriptorBase
global K_GetDescriptorLimit, K_SetDescriptorLimit
global K_GetDescriptorAR, K_SetDescriptorAR
global K_GetGateSelector, K_SetGateSelector
global K_GetGateOffset, K_SetGateOffset, K_SetGateCount
global K_GetExceptionVec, K_SetExceptionVec

global K_RemapToSystem, K_MapStackToSystem, K_UnmapStack
global MemSet, BZero

global KernTSS:data, DrvTSS:data, ?IDTaddr:data
global ?DHlpSymAddr, ?UAPIsymAddr


; --- Imports ---

library init
extern SysReboot


; --- Data ---

section .data

%include "pmdata.nasm"


; --- Variables ---

section .bss

?IDTaddr	RESD	1			; IDT address

?ExceptionNum	RESB	1			; Last exception number


; Memory sizes (in kilobytes)

; API symbol tables addresses
?DHlpSymAddr	RESD	1
?UAPIsymAddr	RESD	1


; --- Procedures ---

section .text

%include "ints.nasm"

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
		add	ebx,GDT			; Find position in GDT
		call	K_GetDescriptorBase	; Load up the LDT base address
		mov	ebx,edi
		jmp	short .GotLDT
.GetGDT:	mov	ebx,GDT			; Otherwise just get the GDT table
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
		add	ebx,[?IDTaddr]
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
		add	eax,[?IDTaddr]
                xchg	eax,ebx
		call	K_SetGateOffset
		call	K_SetGateSelector
		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


; --- Another useful routines ---

		; MemSet - fill memory with a constant byte.
		; Input: EBX=block address,
		;	 ECX=block size,
		;	 AL=value.
		; Output: none.
proc MemSet
		mpush	eax,ecx,edi
		mov	edi,ebx
		mov	ah,al
		cld
		shr	ecx,byte 1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; BZero - fill memory with a NULL.
		; Input: EBX=block address,
		;	 ECX=block size.
		; Output: none.
proc BZero
		mpush	eax,ecx,edi
		mov	edi,ebx
		xor	eax,eax
		cld
		shr	ecx,1
		rep	stosw
		adc	ecx,ecx
		rep	stosb
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------


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