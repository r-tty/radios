;-------------------------------------------------------------------------------
;  buildxdt.nasm - building and initializing IDT and LDTs.
;-------------------------------------------------------------------------------

library kernel
extern ?DHlpSymAddr, ?UAPIsymAddr

library kernel.paging
extern PG_AllocContBlock:near

; --- Code ---

		; INIT_BuildIDT - build and initialize IDT.
proc INIT_BuildIDT
		mov	ecx,IDT_size
		xor	dl,dl
		call	PG_AllocContBlock
		mov	[?IDTaddr],ebx
		mov	esi,TrapHandlersArr
		mov	ecx,IDT_size/tGateDesc_size
		cld

.LoopBuildIDT:	lodsd
		mov	[ebx],ax
		mov	word [ebx+2],KERNELCODE
		mov	word [ebx+4],(AR_IntGate+AR_DPL3+ARpresent) << 8
		shr	eax,16
		mov	[ebx+6],ax
		add	ebx,byte 8
		loop	.LoopBuildIDT
		ret
endp		;---------------------------------------------------------------


		; INIT_BuildUserLDT - build the user LDT.
		; Input: EBX=address of memory block for LDT.
proc INIT_BuildUserLDT
		mov	esi,[UserAPIsTableAddr]
		cld
.Loop:		lodsb					; Get RDF record type
		or	al,al				; Export?
		jz	short .Exit			; No, done
		lodsb
		movzx	edx,al				; EDX=record length
		mov	eax,[esi+1]			; EAX=offset of API
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	word [ebx+tGateDesc.Selector],KERNELCODE
		mov	byte [ebx+tGateDesc.Count],0
		mov	byte [ebx+tGateDesc.Type],AR_CallGate+AR_DPL3+ARpresent
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		add	ebx,byte 8
		add	esi,edx
		jmp	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_BuildDriversLDT - build the drivers LDT.
		; Input: EBX=address of memory block for LDT.
proc INIT_BuildDriversLDT
		mov	esi,[DrvHlpTableAddr]
		cld
.Loop:		lodsb					; AL=RDF record type
		or	al,al				; Export?
		jz	short .Exit			; No, done
		lodsb
		movzx	edx,al				; EDX=record length
		mov	eax,[esi+1]			; EAX=address of API
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	word [ebx+tGateDesc.Selector],KERNELCODE
		mov	byte [ebx+tGateDesc.Count],0
		mov	byte [ebx+tGateDesc.Type],AR_CallGate+AR_DPL1+ARpresent
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		add	ebx,byte 8
		add	esi,edx
		jmp	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitLDTs - initialize the LDTs.
proc INIT_InitLDTs
		mov	esi,[UserAPIsTableAddr]
		mov	[?UAPIsymAddr],esi
		call	.GetDDarrLen
		jecxz	.Exit
		shl	ecx,3
		push	ecx
		xor	dl,dl
		call	PG_AllocContBlock
		push	ebx
		call	INIT_BuildUserLDT
		mpop	edi,ecx
		mov	dx,ULDT
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		dec	ecx
		call	K_SetDescriptorLimit

		mov	esi,[DrvHlpTableAddr]
		mov	[?DHlpSymAddr],esi
		call	.GetDDarrLen
		jecxz	.Exit
		shl	ecx,3
		push	ecx
		xor	dl,dl
		call	PG_AllocContBlock
		push	ebx
		call	INIT_BuildDriversLDT
		mpop	edi,ecx
		mov	dx,DLDT
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		dec	ecx
		call	K_SetDescriptorLimit

.Exit:		ret

.GetDDarrLen:	xor	ecx,ecx
		cld
.Loop:		lodsb
		or	al,al
		jz	.Exit
		lodsb
		movzx	edx,al
		add	esi,edx
		inc	ecx
		jmp	.Loop
endp		;---------------------------------------------------------------
