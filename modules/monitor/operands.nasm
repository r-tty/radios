;-------------------------------------------------------------------------------
; operands.nasm - handle x86 operands as dictated by the opcode table;
;		  handle formatting output.
;-------------------------------------------------------------------------------

module monitor.operands

%include "sys.ah"
%include "monitor.ah"
%include "opcodes.ah"
%include "operands.ah"

publicproc ReadOverrides, DispatchOperands, FormatDisassembly
publicproc TabTo, put2
publicdata ?CodeAddress


externproc HexD2Str, HexW2Str, HexB2Str


section .data

regs		DB	"alcldlblahchdhbhaxcxdxbxspbpsidi"
psegs		DB	"escsssdsfsgs"
crreg		DB	"CR0?23????"
drreg		DB	"DR0123??67"
trreg		DB	"TR??????67"
sudreg		DB	"?R????????"
scales		DB	" + *2+*4+*8+"
stalone		DB	"ST",0
st_repz		DB	"repz ",0
st_repnz	DB	"repnz ",0

base0		DB	"bx+si",0
base1		DB	"bx+di",0
base2		DB	"bp+si",0
base3		DB	"bp+di",0
base4		DB	"si",0
base5		DB	"di",0
base6		DB	"bp",0
base7		DB	"bx",0
_ST0		DB	"fword",0	; Should be DWORD for MATH, FWORD for jmp/call
_ST1		DB	"dword",0
_ST2		DB	"qword",0
_ST3		DB	"word",0
_ST4		DB	"tbyte"
_ST5		DB	0
byptr		DB	"byte ",0
dwptr		DB	"d"
woptr		DB	"word ",0
stsreg		DB	"st(",0
	align 4
based		DD	base0,base1,base2,base3,base4,base5,base6,base7
sts		DD	_ST0,_ST1,_ST2,_ST3,_ST4,_ST5,_ST5,_ST5
	align 4

OPprocedures	DD	42
		DD	op1, op2, op3, op4, op5, op6, op7, op8, op9, op10
		DD	op11,op12,op13,op14,op15,op16,op17,op18,op19,op20
		DD	op21,op22,op23,op24,op25,op26,op27,op28,op29,op30
		DD	op31,op32,op33,op34,op35,op36,op37,op38,op39,op40
		DD	op41,op42,op43

FOMprocedures	DD	17
		DD	FOM_Based,FOM_Segment,FOM_Reg,FOM_Immediate
		DD	FOM_Absolute,FOM_FarBranch,FOM_LongBranch
		DD	FOM_ShortBranch,FOM_Return,FOM_Shift,FOM_Int
		DD	FOM_Port,FOM_SUD,0,FOM_TRX,FOM_DRX,FOM_CRX,FOM_FstReg


FSYprocedures	DD	14
		DD	FSY_SignedOfs,FSY_WordOfs,FSY_ByteOfs,FSY_Absolute
		DD	FSY_SignedImm,FSY_WordImm,FSY_ByteImm,FSY_Port
		DD	FSY_Intr,FSY_Return,FSY_AbsBranch,FSY_LongBranch
		DD	FSY_ShortBranch,FSY_Shift,FSY_Segment


section .bss

?CodeAddress	RESD	1
?Dest2		RESD	1
?Source2	RESD	1
?Segs		RESD	1
?ExtraOperand	RESB	tOperand_size
?Source		RESB	tOperand_size
?Dest		RESB	tOperand_size
?Mnemonic	RESB	10
?StrictOp	RESB	1


section .text

		; CallTableProc - call procedure from table.
		; Input: AL=procedure number,
		;	 dword [ESP+4]=subfunction number,
		;	 dword [ESP+8]=table address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc CallTableProc
		arg	subfn, tableaddr
		locals	calladdr
		prologue

		xor	ah,ah
		cwde
		push	ebx
		mov	ebx,[%$tableaddr]
		cmp	eax,[ebx]
		ja	.Err
		mov	eax,[ebx+eax*4+4]
		mov	[%$calladdr],eax
		pop	ebx
		mov	eax,[%$subfn]
		call	dword [%$calladdr]
.Done:		epilogue
		ret	%$ac-4

.Err:		pop	ebx
		stc
		jmp	.Done
endp		;---------------------------------------------------------------


		; Get a string length.
		; Input: ESI=string address.
		; Output: EAX=string size
proc strlen
		mpush	ecx,edi
		mov	edi,esi
		mov	ecx,-1
		xor	al,al
		repnz	scasb
		mov	eax,ecx
		neg	eax
		dec	eax
		dec	eax
		mpop	edi,ecx
		ret
endp		;---------------------------------------------------------------


		; Copy one string to another.
		; Input: ESI=source string address,
		;	 EDI=destination string address.
		; Output: none.
		; Note: doesn't preserve ESI and EDI.
proc strcpy
.Loop:		lodsb
		stosb
		or	al,al
		jnz	.Loop
		ret
endp		;---------------------------------------------------------------


		; Append "source" string to "destination".
		; Input: ESI=source string address,
		;	 EDI=destination string address.
		; Note: destination buffer must be big enough - no check made.
proc strcat
		mov	al,[edi]
		inc	edi
		or	al,al
		jnz	strcat
		dec	edi
		jmp	strcpy
endp		;---------------------------------------------------------------


		; Copy extra operand.
proc CopyExtra
		mpush	esi,edi
		mov	esi,?ExtraOperand
		xchg	esi,edi
		mov	ecx,tOperand_size
		rep	movsb
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; Set tab position
proc TabTo
		cbw
		cwde
		mov	ecx,eax
		call	strlen
		xchg	eax,ecx
		sub	eax,ecx
		jnc	.NoOver
		add	eax,ecx
		add	esi,eax
		jmp	.Done
.NoOver:
		add	esi,ecx
		mov	ecx,eax
.Loop:
		mov	byte [esi],' '
		inc	esi
		loop	.Loop
.Done:
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


		; Put a word and terminating zero byte to the string.
		; Input: ESI=string address,
		;	 AX=word.
		; Output: ESI=pointer to zero terminator byte.
proc put2
		mov	[esi],ah
		inc	esi
		mov	[esi],al
		inc	esi
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


		; Put three bytes and terminating zero to the string.
		; Input: ESI=string address,
		;	 EAX=what to put (24 bits).
proc put3
		push	eax
		shr	eax,8
		mov	[esi],ah
		inc	esi
		pop	eax
		call	put2
		ret
endp		;---------------------------------------------------------------


proc SetSeg
		mov	byte [?StrictOp],FALSE
		mov	byte [edi+tOperand.Code],OM_SEGMENT
		mov	[edi+tOperand.TheReg],al
		ret
endp		;---------------------------------------------------------------


proc SetReg
		mov	byte [?StrictOp],FALSE
		mov	byte [edi+tOperand.Code],OM_REG
		mov	[edi+tOperand.TheReg],al
		ret
endp		;---------------------------------------------------------------


proc ReadRM
		push	ecx
		sub	ecx,ecx
		mov	cl,2
		RM	esi
		mov	[edi + tOperand.TheReg],al
		MODX	esi
		mov	ch,al
		cmp	ch,MOD_REG
		jnz	.NotRegReg
		mov	byte [edi + tOperand.Code],OM_REG
		mov	byte [?StrictOp],FALSE
		sub	eax,eax
		pop	ecx
		ret
.NotRegReg:
		bt	word [edi + tOperand.Flags],OMF_ADR32
		jnc	.Adr16
		cmp	byte [edi + tOperand.TheReg],RM_32_SCALED
		jnz	.NotScaled
		inc	cl
		RM	esi+1
		mov	[edi + tOperand.TheReg],al
		REG	esi+1
		mov	[edi + tOperand.ScaleReg],al
		MODX	esi+1
		mov	[edi + tOperand.Scale],al
		cmp	byte [edi + tOperand.ScaleReg],RM_32_STACKINDEX
		jz	.HasSP
		bts	word [edi + tOperand.Flags],OMF_SCALED
.HasSP:
		cmp	byte [edi + tOperand.TheReg],RM_32_ABSOLUTE
		jnz	.BasedAndScaled
		cmp	ch,MOD_NOOFS
		jnz	.BasedAndScaled
		mov	byte [edi + tOperand.Code],OM_ABSOLUTE
		LONG	esi+3
		mov	[edi + tOperand.Address],eax
		sub	eax,eax
		mov	al,5
		pop	ecx
		ret
.NotScaled:
		cmp	ch,MOD_NOOFS
		jnz	.BasedAndScaled
		cmp	byte [edi + tOperand.TheReg], RM_32_ABSOLUTE
		jnz	.BasedAndScaled
		mov	byte [edi + tOperand.Code], OM_ABSOLUTE
		LONG	esi+2
		mov	[edi + tOperand.Address],eax
		sub	eax,eax
		mov	al,4
		pop	ecx
		ret
.Adr16:
		cmp	ch,MOD_NOOFS
		jnz	.BasedAndScaled
		cmp	byte [edi + tOperand.TheReg], RM_16_ABSOLUTE
		jnz	.BasedAndScaled
		mov	byte [edi + tOperand.Code], OM_ABSOLUTE
		UINT	esi+2
		mov	[edi + tOperand.Address],eax
		sub	eax,eax
		mov	al,2
		pop	ecx
		ret
.BasedAndScaled:
		mov	byte [edi + tOperand.Code], OM_BASED
		cmp	ch,MOD_ADDR
		jnz	.CheckSigned
		bts	word [edi + tOperand.Flags], OMF_WORD_OFFSET
		push	ecx
		sub	ch,ch
		mov	eax,[gs:esi+ecx]
		pop	ecx
		bt	word [edi + tOperand.Flags], OMF_ADR32
		jc	.Dword
		and	eax,0ffffh
		sub	cl,2
.Dword:
		mov	[edi + tOperand.Address],eax
		add	cl,4
		jmp	.Done
.CheckSigned:
		cmp	ch, MOD_SIGNED
		jnz	.Done
		bts	word [edi + tOperand.Flags],OMF_SIGNED_OFFSET
		push	ecx
		sub	ch,ch
		sub	eax,eax
		mov	al,[gs:esi+ecx]
		pop	ecx
		mov	[edi + tOperand.Address],eax
		inc	cl
.Done:
		mov	eax,ecx
		sub	al,2
		cbw
		cwde
		pop	ecx
		ret
endp		;---------------------------------------------------------------


proc RegRM
		mov	edi,[?Dest2]
		REG	esi
		call	SetReg
		mov	edi,[?Source2]
		call	ReadRM
		ret
endp		;---------------------------------------------------------------


proc Immediate
		push	ecx
		sub	ecx,ecx
		mov	byte [edi + tOperand.Code],OM_IMMEDIATE
		bt	word [edi + tOperand.Flags],OMF_BYTE
		jnc	.NotByte
		inc	cl
		sub	eax,eax
		mov	al,[gs:esi]
		jmp	.Done
.NotByte:
		bt	word [edi + tOperand.Flags], OMF_OP32
		jnc	.Word
		add	cl,4
		LONG	esi
		jmp	.Done
.Word:
		add	cl,2
		UINT	esi
.Done:
		mov	[edi + tOperand.Address],eax
		mov	eax,ecx
		pop	ecx
		ret
endp		;---------------------------------------------------------------


proc MnemonicChar
		push	edi
		mov	edi,?Mnemonic
.Loop:		inc	edi
		cmp	byte [edi-1],0
		jnz	.Loop
		mov	[edi-1],al
		mov	byte [edi],0
		pop	edi
		ret
endp		;---------------------------------------------------------------


;--- OP routines ---------------------------------------------------------------

		; Op1 - word reg from bits 0 - 2 of opcode
proc op1
		btr	word [edi + tOperand.Flags],OMF_BYTE
		mov	al,[gs:esi]
		B02
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op2 - acc, reg bits 0-2 of opcode
proc op2
		mov	al,REG_EAX
		btr	word [edi+tOperand.Flags],OMF_BYTE
		call	SetReg
		mov	edi,ebx
		mov	al,[gs:esi]
		B02
		btr	word [edi+tOperand.Flags],OMF_BYTE
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op3 - seg from b3-5 of opcode
proc op3
		mov	al,[gs:esi]
		B35
		call	SetSeg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op4 - REGRM with b1 of opcode set reg is dest else source
proc op4
		bt	dword [gs:esi],1
		jc	.NoXch
		xchg	ebx,edi
.NoXch:		mov	[?Dest2],edi
		mov	[?Source2],ebx
		call	RegRM
		ret
endp		;---------------------------------------------------------------


		; Op5 - use RM only
proc op5
		jmp	ReadRM
endp		;---------------------------------------------------------------


		; Op6 - READRM for shift
proc op6
		call	ReadRM
		sub	ecx,ecx
		mov	cl,al
		mov	edi,ebx
		mov	byte [edi + tOperand.Code],OM_SHIFT
		bt	dword [gs:esi],4
		jnc	.Cnt
		bt	dword [gs:esi],1
		jnc	.1
		bts	word [edi + tOperand.Flags],OMF_CL
		jmp	.Done
.1:		mov	dword [edi + tOperand.Address],1
		jmp	.Done

.Cnt:		sub	eax,eax
		movzx	eax,byte [gs:esi+ecx+2]
		inc	cl
		mov	[edi + tOperand.Address],eax

.Done:		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op7 - regrm with reg dest
proc op7
		mov	[?Dest2],edi
		mov	[?Source2],ebx
		call	RegRM
		ret
endp		;---------------------------------------------------------------


		; Op8 - word regrm with reg dest
proc op8
		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [ebx + tOperand.Flags],OMF_BYTE
		jmp	op7
endp		;---------------------------------------------------------------


		; Op9 - interrupts
proc op9
		mov	byte [?StrictOp],FALSE
		sub	eax,eax
		mov	al,3
		bt	dword [gs:esi],0
		jnc	.Int3
		mov	al,[gs:esi+1]
.Int3:		mov	[edi + tOperand.Address],eax
		mov	byte [edi + tOperand.Code],OM_INT
		sub	al,al
		ret
endp		;---------------------------------------------------------------


		; Op10 - relative branch
proc op10
		mov	byte [?StrictOp],FALSE
		mov	byte [edi + tOperand.Code],OM_SHORTBRANCH
		movsx	eax,byte [gs:esi+1]
		inc	eax
		inc	eax
		add	eax,[?CodeAddress]
		mov	[edi + tOperand.Address],eax
		bt	word [edi + tOperand.Flags],OMF_OP32
		jc	.NotWord
		and	dword [edi + tOperand.Address],0ffffh
.NotWord:	sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; op11 - RM, immediate
proc op11
		call	ReadRM
		movzx	ecx,al
		mov	edi,ebx
		push	esi
		add	esi,ecx
		add	esi,byte 2
		call	Immediate
		add	cl,al
		pop	esi
		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op12 - acc, immediate
proc op12
		mov	al,REG_EAX
		call	SetReg
		mov	edi,ebx
		inc	esi
		call	Immediate
		dec	esi
		ret
endp		;---------------------------------------------------------------


		; Op13 - absolute, acc
proc op13
		sub	ecx,ecx
		mov	byte [edi + tOperand.Code],OM_ABSOLUTE
		bt	word [edi + tOperand.Flags],OMF_ADR32
		jnc	.Word
		LONG	esi+1
		inc	cl
		inc	cl
		jmp	.1
.Word:		UINT	esi+1
.1:		mov	[edi + tOperand.Address],eax
		mov	edi,ebx
		mov	al,REG_EAX
		call	SetReg
		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op14 - RM, immediate, B01 of opcode != 1 for byte
proc op14
		call	ReadRM
		movzx	ecx,al
		mov	al,[gs:esi]
		B01
		jnz	.CheckByte
		bts	word [ebx + tOperand.Flags],OMF_BYTE
		bts	word [edi + tOperand.Flags],OMF_BYTE
		jmp	.Source
.CheckByte:
		btr	word [ebx + tOperand.Flags],OMF_BYTE
		cmp	al,1
		jz	.1
		bts	word [ebx + tOperand.Flags],OMF_BYTE
.1:		btr	word [edi + tOperand.Flags],OMF_BYTE
.Source:	mov	edi,ebx
		push	esi
		add	esi,ecx
		add	esi,byte 2
		call	Immediate
		pop	esi
		add	cl,al
		mov	al,[gs:esi]
		B01
		cmp	al,3
		jnz	.Done
		bt	word [edi + tOperand.Flags],OMF_BYTE
		jnc	.Done
		bts	word [edi + tOperand.Flags],OMF_SIGNED
		mov	eax,[edi + tOperand.Address]
		cbw
		cwde
		mov	[edi + tOperand.Address],eax

.Done:		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op15 - acc, immediate, B3 of opcode clear for byte
proc op15
		mov	al,[gs:esi]
		B02
		call	SetReg
		bt	dword [gs:esi],3
		jnc	.Byte
		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [ebx + tOperand.Flags],OMF_BYTE
		jmp	.Source
.Byte:
		bts	word [edi + tOperand.Flags],OMF_BYTE
		bts	word [ebx + tOperand.Flags],OMF_BYTE
.Source:
		mov	edi,ebx
		inc	esi
		call	Immediate
		dec	esi
		ret
endp		;---------------------------------------------------------------

		; Op16 - seg, readrm, if B1 of opcode seg is dest else source
proc op16
		bt	dword [gs:esi],1
		jc	.NoSwap
		xchg	ebx,edi
.NoSwap:
		REG	esi
		call	SetSeg
		mov	edi,ebx
		btr	word [edi + tOperand.Flags],OMF_BYTE
		call	ReadRM
		ret
endp		;---------------------------------------------------------------


		; Op17 - far return
proc op17
		mov	byte [?StrictOp],FALSE
		mov	byte [edi + tOperand.Code],OM_RETURN
		btr	word [edi + tOperand.Flags],OMF_ADR32
		btr	word [edi + tOperand.Flags],OMF_OP32
		btr	word [edi + tOperand.Flags],OMF_BYTE
		UINT	esi+1
		mov	[edi + tOperand.Address],eax
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op18 - far branch/call
proc op18
		sub	ecx,ecx
		mov	byte [?StrictOp],FALSE
		mov	byte [edi + tOperand.Code],OM_FARBRANCH
		btr	word [edi + tOperand.Flags],OMF_BYTE
		bt	word [edi + tOperand.Flags],OMF_OP32
		jnc	.Word
		inc	cl
		inc	cl
		LONG	esi+1
		jmp	.Fin
.Word:
		UINT	esi+1
.Fin:
		mov	[edi + tOperand.Address],eax
		UINT	esi+ecx+3
		mov	[edi + tOperand.Seg],ax
		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op19 - ESC, mnem of bits 0-2 of opcode, imm, readrm
proc op19
		mov	byte [edi + tOperand.Code],OM_IMMEDIATE
		bts	word [edi + tOperand.Flags],OMF_BYTE
		mov	al,[gs:esi]
		and	al,7
		shl	al,3
		mov	ah,[gs:esi+1]
		shr	ah,3
		and	ah,7
		or	al,ah
		sub	ah,ah
		cwde
		mov	[edi+ tOperand.Address],eax
		mov	edi,ebx
		call	ReadRM
		ret
endp		;---------------------------------------------------------------


		; Op20 - long branch
proc op20
		mov	byte [?StrictOp],FALSE
		sub	ecx,ecx
		mov	byte [edi + tOperand.Code],OM_LONGBRANCH
		bt	word [edi + tOperand.Flags],OMF_OP32
		jnc	.Word
		LONG	esi+1
		inc	cl
		inc	cl
		jmp	.Fin
.Word:		UINT	esi+1
.Fin:		add	eax,[?CodeAddress]
		add	eax,ecx
		add	eax,3
		bt	word [edi + tOperand.Flags],OMF_OP32
		jc	.Done
		and	eax,0ffffh
.Done:
		mov	[edi + tOperand.Address],eax
		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op21 - acc, dx
proc op21
		mov	al,REG_EAX
		call	SetReg
		mov	edi,ebx
		btr	word [edi + tOperand.Flags],OMF_OP32
		btr	word [edi + tOperand.Flags],OMF_BYTE
		mov	al,REG_DX
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op22 - dx,acc
proc op22
		btr	word [edi + tOperand.Flags],OMF_OP32
		btr	word [edi + tOperand.Flags],OMF_BYTE
		mov	al,REG_DX
		call	SetReg
		mov	edi,ebx
		mov	al,REG_EAX
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op23 - port,acc where B1 of opcode set is port dest
proc op23
		bt	dword [gs:esi],1
		jc	.NoSwap
		xchg	ebx,edi
.NoSwap:
		bts	word [edi + tOperand.Flags],OMF_BYTE
		mov	byte [edi + tOperand.Code],OM_PORT
		movzx	eax,byte [gs:esi+1]
		mov	[edi + tOperand.Address],eax
		mov	edi,ebx
		mov	al,REG_EAX
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op24 - acc, absolute
proc op24
		sub	ecx,ecx
		mov	al,REG_EAX
		call	SetReg
		mov	edi,ebx
		mov	byte [edi + tOperand.Code],OM_ABSOLUTE
		bt	word [edi + tOperand.Flags],OMF_ADR32
		jnc	.Word
		inc	cl
		inc	cl
		LONG	esi+1
		jmp	.Done
.Word:		UINT	esi+1
.Done:		mov	[edi + tOperand.Address],eax
		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op 25 - immediate byte or word
proc op25
		mov	byte [?StrictOp],FALSE
		bts	word [edi + tOperand.Flags],OMF_BYTE
		bt	dword [gs:esi],1
		jc	.Fin
		btr	word [edi + tOperand.Flags],OMF_BYTE
.Fin:		push	esi
		inc	esi
		call	Immediate
		pop	esi
		ret
endp		;---------------------------------------------------------------


		; Op26 - immediate 2byte, byte
proc op26
		mov	byte [?StrictOp],FALSE
		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [edi + tOperand.Flags],OMF_OP32
		push	esi
		inc	esi
		call	Immediate
		mov	edi,ebx
		bts	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [edi + tOperand.Flags],OMF_OP32
		inc	esi
		inc	esi
		call	Immediate
		pop	esi
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op27 - string
proc op27
		mov	al,'d'
		bt	word [edi + tOperand.Flags],OMF_OP32
		jc	.1
		mov	al,'w'
.1:		call	MnemonicChar
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op28 - source = REG, dest = RM
proc op28
		REG	esi
		call	SetReg
		mov	edi,ebx
		RM	esi
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op29 - dest = RM, immediate
proc op29
		bts	word [edi + tOperand.Flags],OMF_BYTE
		RM	esi
		call	SetReg
		mov	edi,ebx
		bts	word [edi + tOperand.Flags],OMF_BYTE
		push	esi
		inc	esi
		inc	esi
		call	Immediate
		pop	esi
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op30 - RM, shift with B3 of stream selecting COUNT or CL
proc op30
		call	ReadRM
		mov	ecx,eax
		mov	edi,ebx
		mov	dword [edi + tOperand.Code],OM_SHIFT
		bt	dword [gs:esi],3
		jnc	.CL
		mov	eax,[esi+ecx+2]
		inc	ecx
		jmp	.Done
.CL:		bts	word [edi + tOperand.Flags],OMF_CL
.Done:		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op31 - reg, rm, count where B1 of opcode = byte/word
proc op31
		call	CopyExtra
		REG	esi
		call	SetReg
		mov	edi,ebx
		call	ReadRM
		mov	ecx,eax
		mov	edi,?ExtraOperand
		bts	word [edi + tOperand.Flags],OMF_BYTE
		bt	dword [gs:esi],1
		jc	.Byte
		btr	word [edi + tOperand.Flags],OMF_BYTE
.Byte:
		push	esi
		inc	esi
		inc	esi
		call	Immediate
		pop	esi
		add	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op32 - 386 special regs
proc op32
		movzx	ecx,word [gs:esi]
		and	cx,0c005h
		cmp	cx,0c000h
		mov	al,OM_CRX
		jz	.1
		cmp	cx,0c001h
		mov	al,OM_DRX
		jz	.1
		cmp	cx,0c004h
		mov	al,OM_TRX
		jz	.1
		mov	al,OM_SUD
.1:		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [ebx + tOperand.Flags],OMF_BYTE
		bts	word [edi + tOperand.Flags],OMF_OP32
		bts	word [ebx + tOperand.Flags],OMF_OP32

		bt	dword [gs:esi],1
		jc	.NoSwap
		xchg	ebx,edi
.NoSwap:	mov	[edi + tOperand.Code],al
		REG	esi
		mov	[edi + tOperand.TheReg],al
		mov	edi,ebx
		RM	esi
		call	SetReg
		sub	eax,eax
		ret
endp		;---------------------------------------------------------------


		; Op33 - reg,rm,shiftcnt where B3 = reg source, b0 = shift cl
proc op33
		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [ebx + tOperand.Flags],OMF_BYTE
		call	CopyExtra
		call	ReadRM
		mov	ecx,eax
		REG	esi
		mov	edi,ebx
		call	SetReg
		mov	edi,?ExtraOperand
		mov	byte [edi + tOperand.Code],OM_SHIFT
		bt	dword [gs:esi],0
		jnc	.GetOfs
		bts	word [edi + tOperand.Flags],OMF_CL
		jmp	.Done
.GetOfs:	movzx	eax,byte [esi+ecx+2]

.Done:		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op34 - push & pop word
proc op34
		test	dword [?Segs],SG_TWOBYTEOP
		jnz	.TwoByte
		test	dword [?Segs],SG_OPSIZ
		jnz	.Fin
		mov	byte [?StrictOp],FALSE
.Fin:		call	ReadRM
		ret

.TwoByte:	btr	word [edi+tOperand.Flags],OMF_OP32
		btr	word [edi+tOperand.Flags],OMF_OP32
		jmp	.Fin
endp		;---------------------------------------------------------------


		; Op35 - floating RM
proc op35
		mov	byte [?StrictOp],FALSE
		mov	ax,[gs:esi]
		and	ax,0D0DEh
		cmp	ax,0D0DEh
		jnz	.Nop
		mov	al,'p'
		call	MnemonicChar
.Nop:
		MODX	esi
		cmp	al,3
		jnz	.FstTab
		bts	word [edi + tOperand.Flags],OMF_FST
		jmp	.Fin
.FstTab:
		bts	word [edi + tOperand.Flags],OMF_FSTTAB
		movzx	eax,byte [gs:edi]
		B12
		shl	eax, OM_FTAB
		or	[edi + tOperand.Flags],ax
.Fin:
		call	ReadRM
		ret
endp		;---------------------------------------------------------------


		; Op36 - sized floating RM
proc op36
		mov	cx,SZ_QWORD
		mov	byte [?StrictOp],FALSE
		mov	ax,[gs:esi]
		and	ax,2807h
		cmp	ax,2807h
		jz	op36notbyte
		mov	cx,SZ_TBYTE
op36notbyte:
		bts	word [edi + tOperand.Flags],OMF_FSTTAB
		shl	ecx,OM_FTAB
		or	[edi + tOperand.Flags],cx
		call	ReadRM
		ret
endp		;---------------------------------------------------------------


		; Op37 - floating math
proc op37
		sub	edx,edx
		mov	byte [?StrictOp],FALSE
		mov	ax,[gs:esi]
		and	ax,0C0DEh
		cmp	ax,0C0DEh
		jnz	.NoFlop
		inc	edx
.NoFlop:
		REG	esi
		and	al,5
		xor	al,dl
		cmp	al,5
		jnz	.NoR
		mov	al,'r'
		call	MnemonicChar
.NoR:
		MODX	esi
		cmp	al,3
		jz	.Reg
		bts	word [edi + tOperand.Flags],OMF_FSTTAB
		mov	al,[gs:esi]
		B12
		shl	eax,OM_FTAB
		or	[edi + tOperand.Flags],ax
		call	ReadRM
		jmp	.Done
.Reg:
		test	byte [gs:esi],6
		jz	.NoP
		mov	al,'p'
		call	MnemonicChar
.NoP:
		bt	dword [gs:esi],2
		jc	.NoSwap
		xchg	ebx,edi
.NoSwap:
		RM	esi
		call	SetReg
		bts	word [edi + tOperand.Flags],OMF_FST
		mov	edi,ebx
		mov	byte [edi + tOperand.Code],OM_FSTREG
		sub	eax,eax
.Done:		ret
endp		;---------------------------------------------------------------


		; Op38
proc op38
		mov	byte [?StrictOp],FALSE
		bts	word [edi + tOperand.Flags],OMF_FSTTAB
		call	ReadRM
		ret
endp		;---------------------------------------------------------------


		; Op39 - word regrm with reg source
proc op39
		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [ebx + tOperand.Flags],OMF_BYTE
		call	op40
		ret
endp		;---------------------------------------------------------------


		; Op40 - regrm with reg source
proc op40
		mov	[?Dest2],ebx
		mov	[?Source2],edi
		call	RegRM
		ret
endp		;---------------------------------------------------------------


		; Op41 - reg, bitnum
proc op41
		btr	word [edi+tOperand.Flags],OMF_BYTE
		call	ReadRM
		mov	ecx,eax
		mov	edi,ebx
		bts	word [edi+tOperand.Flags],OMF_BYTE
		push	esi
		add	esi,ecx
		add	esi,2
		call	Immediate
		pop	esi
		mov	eax,ecx
		ret
endp		;---------------------------------------------------------------


		; Op42 - mixed regrm with reg dest & strictness enforced
proc op42
		mov	[?Dest2],edi
		mov	[?Source2],ebx
		btr	word [edi + tOperand.Flags],OMF_BYTE
		btr	word [ebx + tOperand.Flags],OMF_OP32
		mov	byte [?StrictOp],FALSE
		call	RegRM
		ret
endp		;---------------------------------------------------------------


		; op 43: CWDE
proc op43
		bt	word [edi + tOperand.Flags],OMF_OP32
		jnc	.NoChange
		push	esi
		mov	esi,?Mnemonic + 1
		mov	eax,"wde"
		mov	[esi],eax
		pop	esi
		sub	eax,eax
.NoChange:	ret
endp		;---------------------------------------------------------------


;--- FOM routines --------------------------------------------------------------

proc FOM_FstReg
		mov	edi,esi
		mov	esi,stalone
		call	strcat
		ret
endp 		;---------------------------------------------------------------


proc FOM_CRX
		mov	ebx,crreg
		call	GetSpecial
		ret
endp 		;---------------------------------------------------------------


proc FOM_DRX
		mov	ebx,drreg
		call	GetSpecial
		ret
endp 		;---------------------------------------------------------------


proc FOM_TRX
		mov	ebx,trreg
		call	GetSpecial
		ret
endp 		;---------------------------------------------------------------


proc FOM_SUD
		mov	ebx,sudreg
		call	GetSpecial
		ret
endp 		;---------------------------------------------------------------


proc FOM_Port
		mov	al,SY_PORT
		jmp	FormatValue
endp 		;---------------------------------------------------------------


proc FOM_Int
		mov	al,SY_INTR
		jmp	FormatValue
endp 		;---------------------------------------------------------------


proc FOM_Shift
		bt	word [edi + tOperand.Flags],OMF_CL
		jnc	.NotCL
		mov	eax,"cl"
		mov	[esi],eax
		add	esi,byte 2
		ret
.NotCL:
		cmp	dword [edi + tOperand.Address],1
		mov	al,SY_SHIFT
		jnz	near FormatValue
		mov	byte [esi],'1'
		inc	esi
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FOM_Return
		mov	al,SY_RETURN
		jmp	FormatValue
endp		;---------------------------------------------------------------


proc FOM_ShortBranch
		mov	al,SY_SHORTBRANCH
		jmp	FormatValue
endp		;---------------------------------------------------------------


proc FOM_LongBranch
		mov	al,SY_LONGBRANCH
		jmp	FormatValue
endp		;---------------------------------------------------------------


proc FOM_FarBranch
		mov	al,SY_SEGMENT
		call	FormatValue
		mov	byte [esi],':'
		inc	esi
		mov	al,SY_ABSBRANCH
		call	FormatValue
		ret
endp		;---------------------------------------------------------------


proc FOM_Absolute
		call	DoStrict
		call	SegOverride
		mov	byte [esi],'['
		inc	esi
		mov	byte [esi],0
		bt	word [edi + tOperand.Flags],OMF_SCALED
		jnc	.NotScaled
		mov	al,SY_WORDOFS
		call	FormatValue
		sub	eax,eax
		call	Scaled
		jmp	.Fin
.NotScaled:
		mov	al,SY_ABSOLUTE
		call	FormatValue
.Fin:
		mov	byte [esi],']'
		inc	esi
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FOM_Immediate
		bt	word [edi + tOperand.Flags],OMF_BYTE
		mov	al,SY_WORDIMM
		jnc	.AbsFormat
		mov	al,SY_SIGNEDIMM
		bt	word [edi + tOperand.Flags],SY_SIGNEDIMM
		jc	.AbsFormat
		mov	al,SY_SIGNEDIMM
.AbsFormat:	jmp	FormatValue
endp		;---------------------------------------------------------------


proc FOM_Reg
		bt	word [edi + tOperand.Flags],OMF_FST
		jnc	.FOreg
		call	GetST
		ret
.FOreg:		mov	al,[edi + tOperand.TheReg]
		call	GetReg
		ret
endp		;---------------------------------------------------------------


proc FOM_Based
		call	DoStrict
		call	SegOverride
		mov	byte [esi],'['
		inc	esi
		mov	byte [esi],0
		bt	word [edi + tOperand.Flags],OMF_ADR32
		jnc	.NotScaled
		mov	al,1
		call	Scaled
		jmp	.1
.NotScaled:
		mpush	edi,esi
		movzx	eax,byte [edi + tOperand.TheReg]
		xchg	esi,edi
		mov	esi,based
		mov	esi,[esi + eax * 4]
		call	strcpy
		mpop	esi,edi
		call	strlen
		add	esi,eax
.1:
		test	word [edi + tOperand.Flags],OMF_OFFSET
		jz	.NoOfs
		bt	word [edi + tOperand.Flags],OMF_SIGNED_OFFSET
		mov	al,SY_SIGNEDOFS
		jc	.Format
		mov	al,SY_WORDOFS
		bt	word [edi + tOperand.Flags],OMF_WORD_OFFSET
		jc	.Format
		mov	al,SY_BYTEOFS
.Format:	call	FormatValue
.NoOfs:		mov	byte [esi],']'
		inc	esi
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FOM_Segment
		movzx	ecx,byte [edi + tOperand.TheReg]
		sub	eax,eax
		call	GetSeg
		ret
endp		;---------------------------------------------------------------


;--- FSY routines --------------------------------------------------------------


proc FSY_SignedOfs
		bt	dword [edi + tOperand.Address],31
		mov	eax,"+os_"
		jnc	.Pos
		mov	eax,"-os_"
.Pos:		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.Address]
		call	ABSX
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_WordOfs
		mov	eax,"+ow_"
		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.Address]
		call	HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_ByteOfs
		mov	eax,"+ob_"
		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.Address]
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_Absolute
		mov	eax,"ab_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_SignedImm
		bt	dword [edi + tOperand.Address],31
		mov	eax,"+is_"
		jnc	.Pos
		mov	eax,"-is_"
.Pos:		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.Address]
		call	ABSX
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_WordImm
		mov	eax,"iw_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_ByteImm
		mov	eax,"ib_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_Port
		mov	eax,"p_"
		mov	[esi],eax
		add	esi,byte 2
		mov	eax,[edi + tOperand.Address]
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_Intr
		mov	eax,"it_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_Return
		mov	eax,"rt_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexW2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_AbsBranch
		mov	eax,"ba_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_LongBranch
		mov	eax,"bl_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_ShortBranch
		mov	eax,"bs_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_Shift
		mov	eax,"ib_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.Address]
		call	HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FSY_Segment
		mov	eax,"sg_"
		mov	[esi],eax
		add	esi,byte 3
		mov	ax,[edi + tOperand.Seg]
		call	HexW2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


;--- Interface routines --------------------------------------------------------

proc ReadOverrides
.Loop:		sub	eax,eax
	gs	lodsb
		cmp	al,64h
		jc	.TestSeg
		cmp	al,68h
		jnc	.TestSeg
		sub	al,64h
		mov	ebx,SG_FS
.Found:
		mov	cl,al
		shl	ebx,cl
		or	[?Segs],ebx
		jmp	.Loop
.TestSeg:
		push	eax
		and	al,0E7h
		cmp	al,026h
		pop	eax
		jnz	.TestRep
		mov	ebx,1
		shr	eax,3
		and	al,3
		jmp	.Found
.TestRep:
		sub	al,0F2h
		cmp	al,2
		jnc	.Done
		mov	ebx,SG_REPNZ
		jmp	.Found
.Done:		dec	esi
		ret
endp		;---------------------------------------------------------------


proc DispatchOperands
		push	ebx
		mov	edi,?Mnemonic
		push	esi
		mov	esi,[ebx + tOpCode.Mnemonic]
		call	strcpy
		pop	esi
		mov	byte [?StrictOp],TRUE
		movzx	eax,byte [ebx + tOpCode.Operands]
		push	eax
		mov	edi,?Dest
		mov	ebx,?Source
		cmp	byte [gs:esi],0fh
		jnz	.NoTwoByte
		or	dword [?Segs],SG_TWOBYTEOP
		inc	esi
.NoTwoByte:
		mov	eax,?ExtraOperand
		mov	byte [eax + tOperand.Code],0
		mov	byte [edi + tOperand.Code],0
		mov	byte [ebx + tOperand.Code],0
		mov	word [edi + tOperand.Flags],0
		mov	word [ebx + tOperand.Flags],0

		bt	dword [gs:esi],0
		jc	.NotByte
		bts	word [edi + tOperand.Flags],OMF_BYTE
		bts	word [ebx + tOperand.Flags],OMF_BYTE
.NotByte:
		test	dword [?Segs],SG_ADRSIZ
		jnz	.Word1
		bts	word [edi + tOperand.Flags],OMF_ADR32
		bts	word [ebx + tOperand.Flags],OMF_ADR32
.Word1:
		test	dword [?Segs],SG_OPSIZ
		jnz	.Word2
		bts	word [edi + tOperand.Flags],OMF_OP32
		bts	word [ebx + tOperand.Flags],OMF_OP32
.Word2:
		pop	eax
		or	eax,eax
		jz	.NoDispatch
		dec	al
		push	dword OPprocedures
		push	dword 0
		call	CallTableProc
		add	esi,eax

.NoDispatch:	pop	ebx
		movzx	eax,byte [ebx + tOpCode.Length]
		add	esi,eax
		ret
endp		;---------------------------------------------------------------


proc FormatDisassembly
		locauto	buf, DISFMTBUFSIZE
		prologue

		push	esi
		lea	edi,[%$buf]
		mov	byte [edi],0
		test	dword [?Segs],SG_REPZ
		push	edi
		jz	.NotRepZ
		mov	esi,st_repz
		call	strcpy
.NotRepZ:
		test	dword [?Segs],SG_REPNZ
		jz	.NotRepNZ
		mov	esi,st_repnz
		call	strcpy
.NotRepNZ:
		pop	edi
		xchg	esi,edi
		call	strlen
		add	esi,eax
		xchg	esi,edi
		mov	esi,?Mnemonic
		call	strcat
		lea	esi,[%$buf]
		sub	eax,eax
		mov	al,TAB_ARGPOS
		call	TabTo
		mov	edi,?Dest
		call	PutOperand
		mov	edi,?Source
		test	byte [edi + tOperand.Code],-1
		jz	.NoSource
		mov	byte [esi],','
		inc	esi
		mov	byte [esi],0
		call	PutOperand
.NoSource:
		mov	edi,?ExtraOperand
		test	byte [edi + tOperand.Code],-1
		jz	.NoExtra
		mov	byte [esi],','
		inc	esi
		mov	byte [esi],0
		call	PutOperand
.NoExtra:
		pop	esi
		mov	byte [esi],0
		call	SegOverride
		mov	edi,esi
		lea	esi,[%$buf]
		call	strcat

		epilogue
		ret
endp		;---------------------------------------------------------------


;--- Other utility routines ----------------------------------------------------

proc PutOperand
		call	strlen
		add	esi,eax
		mov	al,[edi + tOperand.Code]
		dec	al
		js	.Done
		push	dword FOMprocedures
		push	dword 0
		call	CallTableProc

.Done:		ret
endp		;---------------------------------------------------------------


proc FormatValue
		dec	al
		push	dword FSYprocedures
		push	dword 0
		call	CallTableProc
		ret
endp		;---------------------------------------------------------------


proc DoStrict
		mpush	edi,esi
		test	byte [?StrictOp],-1
		jz	.Float
		bt	word [edi + tOperand.Flags],OMF_BYTE
		jnc	.chkdwptr
		mov	edi,esi
		mov	esi,byptr
		jmp	.end
		
.chkdwptr:	bt	word [edi + tOperand.Flags],OMF_OP32
		mov	edi,esi
		jnc	.mkwordptr
		mov	esi,dwptr
		jmp	.end

.mkwordptr:	mov	esi,woptr
  		jmp	.end
		
.Float:		bt	word [edi + tOperand.Flags],OMF_FSTTAB
		jnc	.Done
		movzx	eax,word [edi + tOperand.Flags]
		shr	eax,OM_FTAB
		and	eax,7
		mov	edi,esi
		push	edi
		mov	esi,sts
		mov	esi,[esi + eax * 4]
		call	strcat
		pop	edi
		jmp	.Done
		
.end:		call	strcat
.Done:		pop	esi
		call	strlen
		add	esi,eax
		pop	edi
		ret
endp		;---------------------------------------------------------------


proc GetST
		mov	al,[edi + tOperand.TheReg]
		mov	edi,esi
		mov	esi,stsreg
		push	eax
		call	strcpy
		pop	eax
		xchg	esi,edi
		dec	esi
		add	al,'0'
		mov	[esi],al
		inc	esi
		mov	word [esi],')'
		inc	esi
		ret
endp 		;---------------------------------------------------------------


proc GetStdReg
		push	edi
		or	al,al
		jnz	.1
		mov	byte [esi],'e'
		inc	esi
.1:		mov	edi,regs
		mov	ax,[edi + ecx*2]
		mov	[esi],al
		inc	esi
		mov	[esi],ah
		inc	esi
		mov	byte [esi],0
		pop	edi
		ret
endp		;---------------------------------------------------------------


proc GetReg
		movzx	ecx,al
		sub	al,al
		inc	al
		bt	word [edi + tOperand.Flags],OMF_BYTE
		jc	.No32
		bt	word [edi + tOperand.Flags],OMF_OP32
		jnc	.No32
		dec	al
.No32:
		bt	word [edi + tOperand.Flags],OMF_BYTE
		jc	.IsByte
		or	cl,8
.IsByte:
		call	GetStdReg
		ret
endp 		;---------------------------------------------------------------


proc GetSpecial
		mov	al,[ebx]
		mov	[esi],al
		inc	esi
		inc	ebx
		mov	al,[ebx]
		mov	[esi],al
		inc	esi
		inc	ebx
		movzx	eax,byte [edi + tOperand.TheReg]
		mov	al,[ebx+eax]
		mov	[esi],al
		inc	esi
		mov	byte [esi],0
		ret
endp 		;---------------------------------------------------------------


proc GetSeg
		push	edi
		push	eax
		mov	edi,psegs
		mov	ax,[edi + ecx *2]
		mov	[esi],al
		inc	esi
		mov	[esi],ah
		inc	esi
		pop	eax
		or	al,al
		mov	al,':'
		jz	.NoColon
		mov	[esi],al
		inc	esi
.NoColon:
		mov	byte [esi],0
		pop	edi
		ret
endp		;---------------------------------------------------------------


proc SegOverride
		mov	al,1
		sub	ecx,ecx
		test	dword [?Segs],SG_ES
		jz	.TestCS
		call	GetSeg
.TestCS:
		inc	ecx
		test	dword [?Segs],SG_CS
		jz	.TestSS
		call	GetSeg
.TestSS:
		inc	ecx
		test	dword [?Segs],SG_SS
		jz	.TestDS
		call	GetSeg
.TestDS:
		inc	ecx
		test	dword [?Segs],SG_DS
		jz	.TestFS
		call	GetSeg
.TestFS:
		inc	ecx
		test	dword [?Segs],SG_FS
		jz	.TestGS
		call	GetSeg
.TestGS:
		inc	ecx
		test	dword [?Segs],SG_GS
		jz	.Done
		call	GetSeg
.Done:
		mov	dword [?Segs],0
		ret
endp		;---------------------------------------------------------------


proc Scaled
		push	dword [edi + tOperand.Flags]
		btr	word [edi + tOperand.Flags],OMF_BYTE
		bts	word [edi + tOperand.Flags],OMF_OP32
		or	al,al
		jz	.NotBased
		sub	al,al
		mov	al,[edi + tOperand.TheReg]
		call	GetReg
.NotBased:
		bt	word [edi + tOperand.Flags],OMF_SCALED
		jnc	.NotScaled
		movzx	ecx,byte [edi + tOperand.Scale]
		mov	eax,ecx
		add	ecx,ecx
		add	ecx,eax
		add	ecx,scales
		mov	eax,[ecx]
		call	put3
		or	al,1
		mov	al,[edi + tOperand.ScaleReg]
		call	GetReg
.NotScaled:
		pop	dword [edi + tOperand.Flags]
		ret
endp		;---------------------------------------------------------------


proc ABSX
		bt	eax,31
		jnc	.NoAbs
		neg	eax
.NoAbs:		ret
endp		;---------------------------------------------------------------
