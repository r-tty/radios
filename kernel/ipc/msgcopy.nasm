;*******************************************************************************
; msgcopy.nasm - message copying routines.
; Copyright (c) 2003 RET & COM Research.
;*******************************************************************************

section .text

		; Calculate an offset address in source IOV.
		; Input: ESI=address of IOV (kernel),
		;	 ECX=number of parts in IOV,
		;	 EDX=page directory address,
		;	 EAX=offset.
		; Output: CF=0 - OK:
		;		     EAX=offset inside IOV (in bytes),
		;		     EBX=physical address of target IOV,
		;		     ECX=number of IOVs remaining,
		;		     ESI=linear address of target IOV (kernel);
		;	  CF=1 - error.
		; Note: assumes that ECX is always positive.
proc CalcSIOVoffs
		jecxz	.Exit
.Loop:		call	SLin2Phys
		jc	.Exit
		cmp	eax,[ebx+tIOV.Len]
		jl	.OK
		sub	eax,[ebx+tIOV.Len]
		add	esi,byte tIOV_size
		cmp	esi,USERAREACHECK
		cmc
		jc	.Exit
		loop	.Loop
.OK:		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Calculate an offset address in destination IOV.
		; Input: EDI=address of IOV (kernel),
		;	 ECX=number of parts in IOV,
		;	 EDX=page directory address,
		;	 EAX=offset.
		; Output: CF=0 - OK:
		;		     EAX=offset inside IOV (in bytes),
		;		     EBX=physical address of target IOV,
		;		     ECX=number of IOVs remaining,
		;		     EDI=linear address of target IOV (kernel);
		;	  CF=1 - error.
		; Note: assumes that ECX is always positive.
proc CalcDIOVoffs
		jecxz	.Exit
.Loop:		call	DLin2Phys
		jc	.Exit
		cmp	eax,[ebx+tIOV.Len]
		jl	.OK
		sub	eax,[ebx+tIOV.Len]
		add	edi,byte tIOV_size
		cmp	edi,USERAREACHECK
		cmc
		jc	.Exit
		loop	.Loop
.OK:		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Multipart copy from send-source to receive buffers.
		; Input: EBX=address of TCB,
		;	 ECX=number of dest. parts (or negated size in bytes),
		;	 EDX=offset in source (in bytes),
		;	 EDI=address of destination IOV or buffer (user).
		; Output: CF=0 - OK, EAX=number of bytes copied;
		;	  CF=1 - error, EAX=errno.
proc CopyVtoAct
		locals	sparts, dparts, sladdr, dladdr, offs
		locals	sbytes, dbytes
		prologue
		mpush	ebx,esi,edi

		; Prepare EDX - set it to source process page directory address
		mov	[%$offs],edx
		mov	eax,[ebx+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]

		; Destination or source size/nparts may be zero.
		; In this case just do nothing.
		xor	eax,eax
		test	ecx,ecx
		jz	near .Exit
		mov	eax,[ebx+tTCB.SendSize]
		test	eax,eax
		jz	near .Exit
		
		; If ECX is negative - destination is linear buffer, not IOV
		mov	esi,[ebx+tTCB.SendBuf]
		mov	[%$dparts],ecx
		test	ecx,ecx
		jns	near .Dvector
		neg	ecx
		mov	[%$dbytes],ecx
		mov	[%$dladdr],edi

		; If the source is also scalar - we have a simplest case
		test	eax,eax
		jns	.Vect2scal
		neg	eax
		sub	eax,[%$offs]
		jc	near .Fault
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mpush	ebx,ecx,esi,edi
		add	esi,[%$offs]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	near .Fault

		; Return number of bytes copied
		mov	eax,ecx
		jmp	.Exit

		; Vector-to-scalar copy. Take care about offset too..
.Vect2scal:	add	esi,USERAREASTART
		jc	near .Fault
		mov	ecx,eax
		mov	eax,[%$offs]
		call	CalcSIOVoffs
		jc	near .Fault
		
.V2Sloop:	mpush	ebx,ecx,esi,edi
		mov	esi,[ebx+tIOV.Base]
		add	esi,eax
		mov	ecx,[ebx+tIOV.Len]
		sub	ecx,eax
		jz	.V2Snext
		mov	eax,[%$dbytes]
		cmp	eax,ecx
		jge	.2
		mov	ecx,eax
.2:		sub	[%$dbytes],ecx
		add	[%$dladdr],ecx
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	near .Fault
.V2Snext:	cmp	dword [%$dbytes],0
		jle	.V2Sdone
		add	esi,byte tIOV_size
		call	SLin2Phys
		jc	near .Exit
		mov	edi,[%$dladdr]
		loop	.V2Sloop

		; Return number of bytes copied
.V2Sdone:	mov	eax,[%$dparts]
		neg	eax
		sub	eax,[%$dbytes]
		jmp	.Exit

		; Destination is a vector. Check the source as well.
.Dvector:	add	edi,USERAREASTART
		jc	near .SrvFault
		test	eax,eax
		jns	.Vect2vect

		; Scalar-to-vector copy - a bit simpler than previous.
		neg	eax
		sub	eax,[%$offs]
		jc	near .Fault
		add	esi,[%$offs]
		mov	[%$sladdr],esi
		mov	[%$sbytes],eax
		mov	[%$sparts],eax

.S2Vloop:	mpush	ebx,ecx,esi,edi
		mov	ecx,[edi+tIOV.Len]
		mov	eax,[%$sbytes]
		cmp	eax,ecx
		jge	.3
		mov	ecx,eax
.3:		sub	[%$sbytes],ecx
		add	[%$sladdr],ecx
		mov	edi,[edi+tIOV.Base]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	.Fault
		cmp	dword [%$sbytes],0
		jle	.S2Vdone
		add	edi,byte tIOV_size
		mov	esi,[%$sladdr]
		loop	.S2Vloop

		; Return number of bytes copied
.S2Vdone:	mov	eax,[%$sparts]
		sub	eax,[%$sbytes]
		jmp	.Exit

		; Vector-to-vector copy. Complicated.
.Vect2vect:	add	esi,USERAREASTART
		jc	near .Fault
		mov	[%$dparts],ecx
		mov	ecx,eax
		mov	eax,[%$offs]
		call	CalcSIOVoffs
		jc	.Fault
		mov	dword [%$sbytes],0

.V2Vloop:	mpush	ebx,ecx,esi,edi
		mov	esi,[ebx+tIOV.Base]
		add	esi,eax
		mov	ecx,[ebx+tIOV.Len]
		sub	ecx,eax
		jz	.V2Vnext
		mov	eax,[edi+tIOV.Len]
		cmp	eax,ecx
		jge	.4
		mov	ecx,eax
.4:		add	[%$sbytes],ecx
		mov	edi,[edi+tIOV.Base]
		call	K_CopyToAct
		mpop	edi,esi,ecx,ebx
		jc	.Fault
.V2Vnext:	dec	dword [%$dparts]
		jz	.V2Vdone
		add	esi,byte tIOV_size
		add	edi,byte tIOV_size
		loop	.V2Vloop

		; Return number of bytes copied
.V2Vdone:	mov	eax,[%$sbytes]
		clc

.Exit:		mpop	edi,esi,ebx
		epilogue
		ret

.Fault:		mov	eax,-EFAULT
		jmp	.Exit

.SrvFault:	mov	eax,-ESRVRFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Multipart copy from reply to send-reply buffers.
		; Input: EBX=address of TCB,
		;	 ECX=number of source parts (or negated size in bytes),
		;	 EDX=offset in destination (in bytes),
		;	 ESI=address of source IOV or buffer (user).
		; Output: CF=0 - OK, EAX=number of bytes copied;
		;	  CF=1 - error, EAX=errno.
proc CopyVfromAct
		locals	sparts, dparts, sladdr, dladdr, offs
		locals	sbytes, dbytes
		prologue
		mpush	ebx,esi,edi

		; Prepare EDX - set it to destination process page dir address
		mov	[%$offs],edx
		mov	eax,[ebx+tTCB.PCB]
		mov	edx,[eax+tProcDesc.PageDir]

		; Destination or source size/nparts may be zero.
		; In this case just do nothing.
		xor	eax,eax
		test	ecx,ecx
		jz	near .Exit
		mov	eax,[ebx+tTCB.ReplySize]
		test	eax,eax
		jz	near .Exit
		
		; If ECX is negative - source is linear buffer, not IOV
		mov	edi,[ebx+tTCB.ReplyBuf]
		mov	[%$sparts],ecx
		test	ecx,ecx
		jns	near .Svector
		neg	ecx
		mov	[%$sbytes],ecx
		mov	[%$sladdr],esi

		; If the destination is also scalar - we have a simplest case
		test	eax,eax
		jns	.Scal2vect
		neg	eax
		sub	eax,[%$offs]
		jc	near .Fault
		cmp	eax,ecx
		jge	.1
		mov	ecx,eax

		; Copy the data
.1:		mpush	ebx,ecx,esi,edi
		add	edi,[%$offs]
		call	K_CopyFromAct
		mpop	edi,esi,ecx,ebx
		jc	near .Fault

		; Return number of bytes copied
		mov	eax,ecx
		jmp	.Exit

		; Scalar-to-vector copy. Take care about offset too..
.Scal2vect:	add	edi,USERAREASTART
		jc	near .Fault
		mov	ecx,eax
		mov	eax,[%$offs]
		call	CalcDIOVoffs
		jc	near .Fault
		
.S2Vloop:	mpush	ebx,ecx,esi,edi
		mov	edi,[ebx+tIOV.Base]
		add	edi,eax
		mov	ecx,[ebx+tIOV.Len]
		sub	ecx,eax
		jz	.S2Vnext
		mov	eax,[%$dbytes]
		cmp	eax,ecx
		jge	.2
		mov	ecx,eax
.2:		sub	[%$sbytes],ecx
		add	[%$sladdr],ecx
		call	K_CopyFromAct
		mpop	edi,esi,ecx,ebx
		jc	near .Fault
.S2Vnext:	cmp	dword [%$sbytes],0
		jle	.S2Vdone
		add	edi,byte tIOV_size
		call	DLin2Phys
		jc	near .Exit
		mov	esi,[%$sladdr]
		loop	.S2Vloop

		; Return number of bytes copied
.S2Vdone:	mov	eax,[%$sparts]
		neg	eax
		sub	eax,[%$sbytes]
		jmp	.Exit

		; Source is a vector. Check the destination as well.
.Svector:	add	esi,USERAREASTART
		jc	near .SrvFault
		test	eax,eax
		jns	.Vect2vect

		; Vector-to-scalar copy - a bit simpler than previous.
		neg	eax
		sub	eax,[%$offs]
		jc	near .Fault
		add	edi,[%$offs]
		mov	[%$dladdr],edi
		mov	[%$dbytes],eax
		mov	[%$dparts],eax

.V2Sloop:	mpush	ebx,ecx,esi,edi
		mov	ecx,[esi+tIOV.Len]
		mov	eax,[%$dbytes]
		cmp	eax,ecx
		jge	.3
		mov	ecx,eax
.3:		sub	[%$dbytes],ecx
		add	[%$dladdr],ecx
		mov	esi,[esi+tIOV.Base]
		call	K_CopyFromAct
		mpop	edi,esi,ecx,ebx
		jc	.Fault
		cmp	dword [%$dbytes],0
		jle	.V2Sdone
		add	esi,byte tIOV_size
		mov	edi,[%$dladdr]
		loop	.V2Sloop

		; Return number of bytes copied
.V2Sdone:	mov	eax,[%$dparts]
		sub	eax,[%$dbytes]
		jmp	.Exit

		; Vector-to-vector copy. Complicated.
.Vect2vect:	add	edi,USERAREASTART
		jc	near .Fault
		mov	[%$sparts],ecx
		mov	ecx,eax
		mov	eax,[%$offs]
		call	CalcDIOVoffs
		jc	.Fault
		mov	dword [%$dbytes],0

.V2Vloop:	mpush	ebx,ecx,esi,edi
		mov	edi,[ebx+tIOV.Base]
		add	edi,eax
		mov	ecx,[ebx+tIOV.Len]
		sub	ecx,eax
		jz	.V2Vnext
		mov	eax,[esi+tIOV.Len]
		cmp	eax,ecx
		jge	.4
		mov	ecx,eax
.4:		add	[%$dbytes],ecx
		mov	esi,[esi+tIOV.Base]
		call	K_CopyFromAct
		mpop	edi,esi,ecx,ebx
		jc	.Fault
.V2Vnext:	dec	dword [%$dparts]
		jz	.V2Vdone
		add	esi,byte tIOV_size
		add	edi,byte tIOV_size
		loop	.V2Vloop

		; Return number of bytes copied
.V2Vdone:	mov	eax,[%$dbytes]
		clc

.Exit:		mpop	edi,esi,ebx
		epilogue
		ret

.Fault:		mov	eax,-EFAULT
		jmp	.Exit

.SrvFault:	mov	eax,-ESRVRFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Copy the pulse to receive buffer (or IOV) and fill in scoid.
		; Input: EBX=message descriptor,
		;	 ECX=number of dest. parts (or negated size of buffer),
		;	 EDI=address of destination buffer or IOV.
		; Output: CF=0 - OK, EDI=physical address of dest. buffer;
		;	  CF=1 - error, EAX=errno.
		; Note: clobbers ECX.
proc CopyPulseToAct
		push	esi
		add	edi,USERAREASTART
		jc	.BadBuf
		neg	ecx
		test	ecx,ecx
		jns	.Scalar
		mov	ecx,[edi+tIOV.Len]
		mov	edi,[edi+tIOV.Base]
		add	edi,USERAREASTART
		jc	.BadBuf
		
.Scalar:	cmp	ecx,tPulse_size
		jl	.BadBuf
		add	ecx,edi
		jc	.BadBuf
		
		; Copy the pulse data
		push	edi
		mov	esi,ebx
		mov	ecx,tPulse_size / 4
		cld
		rep	movsd
		pop	edi

		; Fill in the scoid
		mov	esi,[ebx+tPulseDesc.ConnDesc]
		call	K_PoolChunkNumber
		mov	[edi+tPulse.SCoID],eax

.Exit:		pop	esi
		ret

.BadBuf:	mov	eax,-ESRVRFAULT
		jmp	.Exit
endp		;---------------------------------------------------------------
