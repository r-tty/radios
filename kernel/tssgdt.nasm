;-------------------------------------------------------------------------------
; tssgdt.nasm - TSS, GDT and routines for descriptor manipulations.
;-------------------------------------------------------------------------------

module kernel.tssgdt

%include "sys.ah"
%include "cpu/paging.ah"
%include "cpu/tss.ah"

exportproc K_DescriptorAddress
exportproc K_GetDescriptorBase, K_SetDescriptorBase
exportproc K_GetDescriptorLimit, K_SetDescriptorLimit
exportproc K_GetDescriptorAR, K_SetDescriptorAR
exportproc K_GetGateSelector, K_SetGateSelector
exportproc K_GetGateOffset, K_SetGateOffset, K_SetGateCount
exportproc K_RegisterLDT, K_UnregisterLDT
publicproc K_BuildGDT
publicdata GDTlimAddr, KernTSS

externproc ExitKernel


section .data

KernLDT		DD	0,0

KernTSS istruc tTSS
	 at tTSS.Link,		DD	0
	 at tTSS.ESP0,		DD	90000h
	 at tTSS.SS0,		DD	KERNELDATA
	 at tTSS.ESP1,		DD	0
	 at tTSS.SS1,		DD	0
	 at tTSS.ESP2,		DD	0
	 at tTSS.SS2,		DD	0
	 at tTSS.CR3,		DD	0
	 at tTSS.EIP,		DD	ExitKernel
	 at tTSS.EFLAGS,	DD	202h
	 at tTSS.EAX,		DD	0
	 at tTSS.ECX,		DD	0
	 at tTSS.EDX,		DD	0
	 at tTSS.EBX,		DD	0
	 at tTSS.ESP,		DD	0
	 at tTSS.EBP,		DD	0
	 at tTSS.ESI,		DD	0
	 at tTSS.EDI,		DD	0
	 at tTSS.ES,		DD	KERNELDATA
	 at tTSS.CS,		DD	KERNELCODE
	 at tTSS.SS,		DD	KERNELDATA
	 at tTSS.DS,		DD	KERNELDATA
	 at tTSS.FS,		DD	KERNELDATA
	 at tTSS.GS,		DD	KERNELDATA
	 at tTSS.LDT,		DD	KLDT
	 at tTSS.Trap,		DW	0
	 at tTSS.IOBM,		DW	0FFh
	iend

GDTlimAddr	DW	GDT_limit
		DD	?GDT


section .bss

alignb 16
?GDT		RESB	GDT_limit+1


section .text

		; K_BuildGDT - build a GDT.
		; Input: none.
		; Output: none.
proc K_BuildGDT
		lea	edi,[?GDT]

		; Null descriptor
		xor	eax,eax
		stosd
		stosd

		; Kernel code (08h) - low 2G, execute and read
		mov	eax,0FFFFh
		stosd
		mov	eax,((ARsegment+ARpresent+AR_CS_XR+AR_DPL0) << 8) + ((7+AR_DfltSz+AR_Granlr) << 16)
		stosd

		; Kernel data (10h) - entire 4G, read and write
		mov	eax,0FFFFh
		stosd
		mov	eax,((ARsegment+ARpresent+AR_DS_RW+AR_DPL0) << 8) + ((0Fh+AR_DfltSz+AR_Granlr) << 16)
		stosd

		; User code (18h) - upper 2G, execute and read
		mov	eax,0FFFFh
		stosd
		mov	eax,((ARsegment+ARpresent+AR_CS_XR+AR_DPL3) << 8) + ((7+AR_DfltSz+AR_Granlr) << 16) + (80h << 24)
		stosd

		; User data (20h) - upper 2G, read and write
		mov	eax,0FFFFh
		stosd
		mov	eax,((ARsegment+ARpresent+AR_DS_RW+AR_DPL3) << 8) + ((7+AR_DfltSz+AR_Granlr) << 16) + (80h << 24)
		stosd

		; Kernel TSS (28h)
		mov	word [edi],tTSS_size-1
		mov	ebx,KernTSS
		mov	[edi+tDesc.BaseLW],bx
		shr	ebx,16
		mov	[edi+tDesc.BaseHLB],bl
		mov	byte [edi+tDesc.AR],AR_AvlTSS+ARpresent+AR_DPL0
		xor	bl,bl
		mov	[edi+tDesc.LimHiMode],bx
		add	edi,byte 8

		; Kernel LDT (30h)
		mov	word [edi],KLDT_limit
		mov	ebx,KernLDT
		mov	[edi+tDesc.BaseLW],bx
		shr	ebx,16
		mov	[edi+tDesc.BaseHLB],bl
		mov	byte [edi+tDesc.AR],AR_LDTdesc+ARpresent+AR_DPL0
		xor	bl,bl
		mov	[edi+tDesc.LimHiMode],bx
		add	edi,byte 8

		; Exit gate (38h)
		mov	dword [edi],KERNELCODE << 16
		mov	dword [edi+4],(AR_CallGate+ARpresent+AR_DPL3) << 8
		add	edi,byte 8

		ret
endp		;---------------------------------------------------------------


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
		add	ebx,?GDT		; Find position in GDT
		call	K_GetDescriptorBase	; Load up the LDT base address
		mov	ebx,edi
		jmp	.GotLDT
.GetGDT:	mov	ebx,?GDT		; Otherwise just get the GDT table
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
		shr	eax,16
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


		; K_RegisterLDT - fill in a LDT descriptor of GDT.
		; Input: EAX=GDT slot number,
		;	 EBX=address of LDT.
		; Output: CF=0 - OK, DX=LDT descriptor;
		;	  CF=1 - error.
proc K_RegisterLDT
		push	edi
		mov	edx,eax
		shl	edx,3
		add	edx,byte ULDTBASE
		cmp	edx,GDT_limit
		cmc
		jc	.Exit

		lea	edi,[?GDT+edx]
		mov	word [edi],ULDT_limit
		mov	[edi+2],bx
		ror	ebx,16
		mov	[edi+4],bl
		mov	byte [edi+5],ARpresent+AR_LDTdesc+AR_DPL0
		mov	byte [edi+6],0
		mov	[edi+7],bh
		rol	ebx,16
		clc

.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; K_UnregisterLDT - free a GDT descriptor.
		; Input: DX=LDT descriptor.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error.
proc K_UnregisterLDT
		cmp	edx,GDT_limit
		cmc
		jc	.Exit
		xor	eax,eax
		mov	[?GDT+edx],eax
		mov	[?GDT+edx+4],eax
.Exit:		ret
endp		;---------------------------------------------------------------
