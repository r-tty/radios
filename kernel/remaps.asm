;-------------------------------------------------------------------------------
;  remaps.asm - provide services for remapping user pointers into the system
;		(PSUEDO_PHYSICAL data space):
;		  handle remapping a user pointer to the system,
;		  handle mapping the system stack in and out of the system
;		  data space.
;-------------------------------------------------------------------------------


		; K_RemapToSystem - remap a user address to the system
		;		    address space.
		; Input: AX=selector,
		;	 EBX=address,
		;	 EDI=LDT base, segment offset,
		;	 ESI=page table directory address (physical).
		; Output: EAX=linear address.
proc K_RemapToSystem near
		push	ebx esi edi		; Save regs
		test	ax,SELECTOR_LDT		; See if is in LDT
		jnz	@@GoTable		; Yes, LDT already in EDI
		mov	edi,offset GDT		; Else get GDT
@@GoTable:	and	eax,not SELECTOR_STATUS	; Mask off selector RPL and TI
		add	edi,eax			; Get descriptor address
		push	ebx
		mov	ebx,edi
		call	K_GetDescriptorBase	; Pull the base
		pop	ebx
		add	ebx,edi			; Offset to calling seg
		mov	eax,ebx			; Get upper 10 bits of address
		shr	eax,22
		mov	eax,[esi+eax*4]		; To index the page dir
		bt	eax,0			; If no page table we have an error
		jnc	short @@BadPage		
		and	eax,not (PageSize-1)	; Otherwise convert to seg offset
		mov	esi,eax			
		mov	eax,ebx			; Get middle 10 bits of address
		shr	eax,12			
		and	eax,03FFh		
		mov	eax,[esi+eax*4]		; Index this page table with that
		bt	eax,0			; Error if no page entry
		jnc	@@BadPage			
		and	eax,not (PageSize-1)	; Get page address
		and	ebx,(PageSize-1)	; Else get lower 12 bits of address
		add	eax,ebx			; Add it in
		clc
		jmp	short @@Exit
@@BadPage:	stc				; Error, set carry
@@Exit:		pop	edi esi ebx
		ret
endp		;---------------------------------------------------------------


		; K_MapStackToSystem - map the private task stack into 
		;		       the system space.
proc K_MapStackToSystem near
		xchg	[esp],edx		; Save EDX and get ret address
		push	ecx ebx eax esi edi	; Save all regs
		push	ebp
		mov	ebp,esp			; Point EBP at regs
		push	[dword ebp]		; Save original EBP
		sldt	ax			; Load up LDT base address
		call	K_DescriptorAddress	
		call	K_GetDescriptorBase
		mov	eax,ss			; EAX:EBX = stack
		mov	ebx,esp			
		push	eax                     ; Save stack on stack
		push	ebx			
		sub	[ebp-4],esp		; Get offset of original EBP
		sub	ebp,esp			; Get EBP offset
		mov	esi,cr3			; Get Page directory
		mov	ebx,esp			; Get stack offset to translate
		call	K_RemapToSystem		; Remap stack
		mov	ebx,ds			; Set new stack in data seg
		mov	ss,ebx			
		mov	esp,eax			
		add	ebp,esp			; Offset BP to new stack
		add	[ebp-4],esp		; Offset original EBP to new stack
		push	ebp			; Save base pointer
		push	edx			; Save return address
		mov	edi,[ebp+4]		; Reload regs
		mov	esi,[ebp+8]		
		mov	eax,[ebp+12]		
		mov	ebx,[ebp+16]		
		mov	ecx,[ebp+20]		
		mov	edx,[ebp+24]		
		mov	ebp,[ebp-4]		; Reload EBP
		ret
endp		;---------------------------------------------------------------


		; K_UnmapStack - map back to the private task stack.
proc K_UnmapStack near
		mov	ebp,[esp + 4]		; Load EBP with stack frame
		mov	[ebp + 24],edx		; Save regs we will wipe
		mov	[ebp + 20],ecx		
		mov	[ebp + 16],ebx		
		pop	edx			; EDX = return address
		pop	ecx			; Clear EBP from stack
		pop	ecx			; EBX:ECX = original stack
		pop	ebx			
		mov	ss,ebx			; Restore stack
		mov	esp,ecx			
		pop	ebp			; Wipe offsetted base pointer
		pop	ebp			; Restore base pointer pushed by ENTER
		pop	ebx			; Add ESP,12 slower but without
		pop	ebx			; changing flags
		pop	ebx			; This rids unchanged regs from stack
		pop	ebx			; Restore wiped regs
		pop	ecx			;
		xchg	[esp],edx		; And put return address on stack
		ret
endp		;---------------------------------------------------------------
