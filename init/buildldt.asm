;-------------------------------------------------------------------------------
;  buildldt.asm - building and initializing the user's and drivers' LDTs.
;-------------------------------------------------------------------------------

segment KCODE
		; INIT_BuildUserLDT - build the user LDT.
		; Input: EBX=address of memory block for LDT.
proc INIT_BuildUserLDT near
		mov	esi,offset UserAPIsTable
		cld
@@Loop:		lodsd
		or	eax,eax
		jz	short @@Exit
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	[ebx+tGateDesc.Selector],KERNELCODE
		mov	[ebx+tGateDesc.Count],0
		mov	[ebx+tGateDesc.Type],AR_CallGate+AR_DPL3+ARpresent
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		add	ebx,8
		jmp	@@Loop
@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_BuildDriversLDT - build the drivers LDT.
		; Input: EBX=address of memory block for LDT.
proc INIT_BuildDriversLDT near
		mov	esi,offset DrvAPIsTable
		cld
@@Loop:		lodsd
		or	eax,eax
		jz	short @@Exit
		mov	[ebx+tGateDesc.OffsetLo],ax
		mov	[ebx+tGateDesc.Selector],KERNELCODE
		mov	[ebx+tGateDesc.Count],0
		mov	[ebx+tGateDesc.Type],AR_CallGate+AR_DPL1+ARpresent
		shr	eax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		add	ebx,8
		jmp	@@Loop
@@Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitLDTs - initialize the LDTs.
proc INIT_InitLDTs near
		mov	esi,offset UserAPIsTable
		call	@@GetDDarrLen
		jecxz	@@Exit
		shl	ecx,3
		push	ecx
		call	KH_Alloc
		push	ebx
		call	INIT_BuildUserLDT
		pop	edi ecx
		mov	dx,ULDT
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		dec	ecx
		call	K_SetDescriptorLimit

		mov	esi,offset DrvAPIsTable
		call	@@GetDDarrLen
		jecxz	@@Exit
		shl	ecx,3
		push	ecx
		call	KH_Alloc
		push	ebx
		call	INIT_BuildUserLDT
		pop	edi ecx
		mov	dx,DLDT
		call	K_DescriptorAddress
		call	K_SetDescriptorBase
		dec	ecx
		call	K_SetDescriptorLimit

@@Exit:		ret

@@GetDDarrLen:	xor	ecx,ecx
		cld
@@Loop:		lodsd
		or	eax,eax
		jz	@@Exit
		inc	ecx
		jmp	@@Loop
endp		;---------------------------------------------------------------

ends
