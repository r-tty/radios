;-------------------------------------------------------------------------------
;  operands.as - handle 386 operands as dictated by the opcode table;
;		 handle formatting output.
;-------------------------------------------------------------------------------

module monitor.operands

%include "sys.ah"

%include "opcodes.ah"
%include "operands.ah"

; --- Exports ---

global ReadOverrides, DispatchOperands, FormatDisassembly
global TabTo, code_address, put2


; --- Imports ---

library kernel.misc
extern K_HexD2Str, K_HexW2Str, K_HexB2Str


; --- Variables ---

section .bss

code_address	RESD	1
dest2		RESD	1
source2		RESD	1
segs		RESD	1
extraoperand	RESB	tOperand_size
source		RESB	tOperand_size
dest		RESB	tOperand_size
mnemonic	RESB	10
strict		RESB	1


; --- Data ---

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
		DD	FOM_BASED,FOM_SEGMENT,FOM_REG,FOM_IMMEDIATE
		DD	FOM_ABSOLUTE,FOM_FARBRANCH,FOM_LONGBRANCH
		DD	FOM_SHORTBRANCH,FOM_RETURN,FOM_SHIFT,FOM_INT
		DD	FOM_PORT,FOM_SUD,0,FOM_TRX,FOM_DRX,FOM_CRX,FOM_FSTREG


FSYprocedures	DD	14
		DD	FSY_SIGNEDOFS,FSY_WORDOFS,FSY_BYTEOFS,FSY_ABSOLUTE
		DD	FSY_SIGNEDIMM,FSY_WORDIMM,FSY_BYTEIMM,FSY_PORT
		DD	FSY_INTR,FSY_RETURN,FSY_ABSBRANCH,FSY_LONGBRANCH
		DD	FSY_SHORTBRANCH,FSY_SHIFT,FSY_SEGMENT


; --- Procedures ---

section .text

		; CallTableProc - call procedure from table.
		; Input: AL=procedure number,
		;	 dword [ESP+4]=subfunction number,
		;	 dword [ESP+8]=table address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc CallTableProc
%define	.SubFn		ebp+8
%define	.TableAddr	ebp+12
%define	.CallAddr	ebp-4
		prologue 4
		xor	ah,ah
		cwde
		push	ebx
		mov	ebx,[.TableAddr]
		cmp	eax,[ebx]
		ja	.Err
		mov	eax,[ebx+eax*4+4]
		mov	[.CallAddr],eax
		pop	ebx
		mov	eax,[.SubFn]
		call	dword [.CallAddr]
.Done:		epilogue
		ret	8

.Err:		pop	ebx
		stc
		jmp	.Done
endp		;---------------------------------------------------------------


proc strlen
	push	edi
	push	esi
	push	ecx
	push	es
	push	ds
	pop	es
	mov	edi,esi
	mov	ecx,-1
	sub	al,al
	repnz	scasb
	mov	eax,ecx
	neg	eax
	dec	eax
	dec	eax
	pop	es
	pop	ecx
	pop	esi
	pop	edi
	ret
endp

proc strcpy
		push	es
		push	ds
		pop	es
.Loop:		lodsb
		stosb
		or	al,al
		jnz	.Loop
		pop	es
		ret
endp

proc strcat
		mov	al,[edi]
		inc	edi
		or	al,al
		jnz	strcat
		dec	edi
		jmp	strcpy
endp

proc CopyExtra
	push	esi
	push	edi
	mov	esi,offset extraoperand
	xchg	esi,edi
	push	es
	push	ds
	pop	es
	mov	ecx,tOperand_size
	rep	movsb
	pop	es
	pop	edi
	pop	esi
	ret
endp


proc put2
	mov	[esi],ah
	inc	esi
	mov	[esi],al
	inc	esi
	mov	byte [esi],0
	ret
endp

proc put3
	push	eax
	shr	eax,8
	mov	[esi],ah
	inc	esi
	pop	eax
	call	put2
	ret
endp


proc SetSeg
		mov	byte [strict],FALSE
		mov	byte [edi+tOperand.CODE],OM_SEGMENT
		mov	[edi+tOperand.THEREG],al
		ret
endp		;---------------------------------------------------------------

proc SetReg
		mov	byte [strict],FALSE
		mov	byte [edi+tOperand.CODE],OM_REG
		mov	[edi+tOperand.THEREG],al
		ret
endp		;---------------------------------------------------------------

proc ReadRM
		push	ecx
		sub	ecx,ecx
		mov	cl,2
		RM	esi
		mov	[edi + tOperand.THEREG],al
		MODX	esi
		mov	ch,al
		cmp	ch,MOD_REG
		jnz	short notregreg
		mov	byte [edi + tOperand.CODE],OM_REG
		mov	byte [strict],FALSE
		sub	eax,eax
		pop	ecx
		ret
notregreg:
		bt	word [edi + tOperand.FLAGS],OMF_ADR32
		jnc	adr16
		cmp	byte [edi + tOperand.THEREG],RM_32_SCALED
		jnz	notscaled
		inc	cl
		RM	esi+1
		mov	[edi + tOperand.THEREG],al
		REG	esi+1
		mov	[edi + tOperand.SCALEREG],al
		MODX	esi+1
		mov	[edi + tOperand.SCALE],al
		cmp	byte [edi + tOperand.SCALEREG],RM_32_STACKINDEX
		jz	hassp
		bts	word [edi + tOperand.FLAGS],OMF_SCALED
hassp:
		cmp	byte [edi + tOperand.THEREG],RM_32_ABSOLUTE
		jnz	basedAndScaled
		cmp	ch,MOD_NOOFS
		jnz	short basedAndScaled
		mov	byte [edi + tOperand.CODE],OM_ABSOLUTE
		LONG	esi+3
		mov	[edi + tOperand.ADDRESS],eax
		sub	eax,eax
		mov	al,5
		pop	ecx
		ret
notscaled:
		cmp	ch,MOD_NOOFS
		jnz	basedAndScaled
		cmp	byte [edi + tOperand.THEREG], RM_32_ABSOLUTE
		jnz	basedAndScaled
		mov	byte [edi + tOperand.CODE], OM_ABSOLUTE
		LONG	esi+2
		mov	[edi + tOperand.ADDRESS],eax
		sub	eax,eax
		mov	al,4
		pop	ecx
		ret
adr16:
		cmp	ch,MOD_NOOFS
		jnz	basedAndScaled
		cmp	byte [edi + tOperand.THEREG], RM_16_ABSOLUTE
		jnz	basedAndScaled
		mov	byte [edi + tOperand.CODE], OM_ABSOLUTE
		UINT	esi+2
		mov	[edi + tOperand.ADDRESS],eax
		sub	eax,eax
		mov	al,2
		pop	ecx
		ret
basedAndScaled:
		mov	byte [edi + tOperand.CODE], OM_BASED
		cmp	ch,MOD_ADDR
		jnz	short checksigned
		bts	word [edi + tOperand.FLAGS], OMF_WORD_OFFSET
		push	ecx
		sub	ch,ch
		mov	eax,[gs:esi+ecx]
		pop	ecx
		bt	word [edi + tOperand.FLAGS], OMF_ADR32
		jc	dwordx
		and	eax,0ffffh
		sub	cl,2
dwordx:
		mov	[edi + tOperand.ADDRESS],eax
		add	cl,4
		jmp	short readrmdone
checksigned:
		cmp	ch, MOD_SIGNED
		jnz	short readrmdone
		bts	word [edi + tOperand.FLAGS],OMF_SIGNED_OFFSET
		push	ecx
		sub	ch,ch
		sub	eax,eax
		mov	al,[gs:esi+ecx]
		pop	ecx
		mov	[edi + tOperand.ADDRESS],eax
		inc	cl
readrmdone:
		mov	eax,ecx
		sub	al,2
		cbw
		cwde
		pop	ecx
		ret
endp		;---------------------------------------------------------------

proc RegRM
		mov	edi,[dest2]
		REG	esi
		call	SetReg
		mov	edi,[source2]
		call	ReadRM
		ret
endp		;---------------------------------------------------------------

proc Immediate
		push	ecx
		sub	ecx,ecx
		mov	byte [edi + tOperand.CODE],OM_IMMEDIATE
		bt	word [edi + tOperand.FLAGS],OMF_BYTE
		jnc	short inotbyte
		inc	cl
		sub	eax,eax
		mov	al,[gs:esi]
		jmp	short i_ret
inotbyte:
		bt	word [edi + tOperand.FLAGS], OMF_OP32
		jnc	iword
		add	cl,4
		LONG	esi
		jmp	short i_ret
iword:
		add	cl,2
		UINT	esi
i_ret:
		mov	[edi + tOperand.ADDRESS],eax
		mov	eax,ecx
		pop	ecx
		ret
endp		;---------------------------------------------------------------

proc MnemonicChar
		push	edi
		mov	edi,offset mnemonic
mc2:
		inc	edi
		cmp	byte [edi-1],0
		jnz	mc2
		mov	[edi-1],al
		mov	byte [edi],0
		pop	edi
		ret
endp		;---------------------------------------------------------------


;/*****************************************************************************/

;/* op 1- word reg from bits 0 - 2 of opcode */
proc op1
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	mov	al,[gs:esi]
	B02
	call	SetReg
	sub	eax,eax
	ret
endp

;/* op2 acc, reg bits 0-2 of opcode */
proc op2
	mov	al,REG_EAX
	btr	word [edi+tOperand.FLAGS],OMF_BYTE	; Bugfix in original
	call	SetReg
	mov	edi,ebx
	mov	al,[gs:esi]
	B02						; Bugfix in original
	btr	word [edi+tOperand.FLAGS],OMF_BYTE	; Bugfix in original
	call	SetReg
	sub	eax,eax
	ret
endp

;/* op3 - seg from b3-5 of opcode */
proc op3
	mov	al,[gs:esi]
	B35
	call	SetSeg
	sub	eax,eax
	ret
endp

;/* op4 - REGRM with b1 of opcode set reg is dest else source */
proc op4
	bt	dword [gs:esi],1
	jc	short op4nox
	xchg	ebx,edi
op4nox:
	mov	[dest2],edi
	mov	[source2],ebx
	call	RegRM
	ret
endp

;/* op5 - use RM only */
proc op5
	call	ReadRM
	ret
endp

;/* op6 READRM for shift */
proc op6
	call	ReadRM
	sub	ecx,ecx
	mov	cl,al
	mov	edi,ebx
	mov	byte [edi + tOperand.CODE],OM_SHIFT
	bt	dword [gs:esi],4
	jnc	short op6cnt
	bt	dword [gs:esi],1
	jnc	op61
	bts	word [edi + tOperand.FLAGS],OMF_CL
	jmp	short op6done
op61:
	mov	dword [edi + tOperand.ADDRESS],1
	jmp	short op6done
op6cnt:
	sub	eax,eax
	movzx	eax,byte [gs:esi+ecx+2]
	inc	cl
	mov	[edi + tOperand.ADDRESS],eax
op6done:
	mov	eax,ecx
	ret
endp

;/* op 7 regrm with reg dest */
proc op7
	mov	[dest2],edi
	mov	[source2],ebx
	call	RegRM
	ret
endp

;/* op8 - word regrm with reg dest */
proc op8
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [ebx + tOperand.FLAGS],OMF_BYTE
	jmp	op7
endp

;/* op 9 - interrupts */
proc op9
	mov	byte [strict],FALSE
	sub	eax,eax
	mov	al,3
	bt	dword [gs:esi],0
	jnc	short op9int3
	mov	al,[gs:esi+1]
op9int3:
	mov	[edi + tOperand.ADDRESS],eax
	mov	byte [edi + tOperand.CODE],OM_INT
	sub	al,al
	ret
endp
;/* op 10, short relative branch */
proc op10
	mov	byte [strict],FALSE
	mov	byte [edi + tOperand.CODE],OM_SHORTBRANCH
	movsx	eax,byte [gs:esi+1]
	inc	eax
	inc	eax
	add	eax,[code_address]
	mov	[edi + tOperand.ADDRESS],eax
	bt	word [edi + tOperand.FLAGS],OMF_OP32
	jc	short op10notword
	and	dword [edi + tOperand.ADDRESS],0ffffh
op10notword:
	sub	eax,eax
	ret
endp
;/* op 11 RM, immediate */
proc op11
	call	ReadRM
	movzx	ecx,al
	mov	edi,ebx
	push	esi
	add	esi,ecx
	add	esi,2
	call	Immediate
	add	cl,al
	pop	esi
	mov	eax,ecx
	ret
endp
;/* op 12 - acc, immediate */
proc op12
	mov	al,REG_EAX
	call	SetReg
	mov	edi,ebx
	inc	esi
	call	Immediate
	dec	esi
	ret
endp
;/* op 13 absolute, acc*/
proc op13
	sub	ecx,ecx
	mov	byte [edi + tOperand.CODE],OM_ABSOLUTE
	bt	word [edi + tOperand.FLAGS],OMF_ADR32
	jnc	short op13word
	LONG	esi+1
	inc	cl
	inc	cl
	jmp	short op13fin
op13word:
	UINT	esi+1
op13fin:
	mov	[edi + tOperand.ADDRESS],eax
	mov	edi,ebx
	mov	al,REG_EAX
	call	SetReg
	mov	eax,ecx
	ret
endp
;/* op 14 - RM, immediate, b01 of opcode != 1 for byte */
proc op14
	call	ReadRM
	movzx	ecx,al
	mov	al,[gs:esi]
	B01
	jnz	short op14checkbyte
	bts	word [ebx + tOperand.FLAGS],OMF_BYTE
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	jmp	short op14source
op14checkbyte:
	btr	word [ebx + tOperand.FLAGS],OMF_BYTE
	cmp	al,1
	jz	short op14check2
	bts	word [ebx + tOperand.FLAGS],OMF_BYTE
op14check2:
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
op14source:
	mov	edi,ebx
	push	esi
	add	esi,ecx
	add	esi,2
	call	Immediate
	pop	esi
	add	cl,al
	mov	al,[gs:esi]
	B01
	cmp	al,3
	jnz	op14done
	bt	word [edi + tOperand.FLAGS],OMF_BYTE
	jnc	op14done
	bts	word [edi + tOperand.FLAGS],OMF_SIGNED
	mov	eax,[edi + tOperand.ADDRESS]
	cbw
	cwde
	mov	[edi + tOperand.ADDRESS],eax
op14done:
	mov	eax,ecx
	ret
endp
;/* op 15 - acc, immediate, B3 of opcode clear for byte */
proc op15
	mov	al,[gs:esi]
	B02
	call	SetReg
	bt	dword [gs:esi],3
	jnc	op15byte
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [ebx + tOperand.FLAGS],OMF_BYTE
	jmp	short op15source
op15byte:
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	bts	word [ebx + tOperand.FLAGS],OMF_BYTE
op15source:
	mov	edi,ebx
	inc	esi
	call	Immediate
	dec	esi
	ret
endp
;/* op 16 - seg,readrm, if B1 of opcode seg is dest else source */
proc op16
	bt	dword [gs:esi],1
	jc	noswap
	xchg	ebx,edi
noswap:
	REG	esi
	call	SetSeg
	mov	edi,ebx
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	call	ReadRM
	ret
endp
;/* op 17, far return */
proc op17
	mov	byte [strict],FALSE
	mov	byte [edi + tOperand.CODE],OM_RETURN
	btr	word [edi + tOperand.FLAGS],OMF_ADR32
	btr	word [edi + tOperand.FLAGS],OMF_OP32
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	UINT	esi+1
	mov	[edi + tOperand.ADDRESS],eax
	sub	eax,eax
	ret
endp
;/* op 18, far branch/call */
proc op18
	sub	ecx,ecx
	mov	byte [strict],FALSE
	mov	byte [edi + tOperand.CODE],OM_FARBRANCH
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	bt	word [edi + tOperand.FLAGS],OMF_OP32
	jnc	short op18word
	inc	cl
	inc	cl
	LONG	esi+1
	jmp	short	op18fin
op18word:
	UINT	esi+1
op18fin:
	mov	[edi + tOperand.ADDRESS],eax
	UINT	esi+ecx+3
	mov	[edi + tOperand.SEG],ax
	mov	eax,ecx
	ret
endp
;/* op 19 - ESC, mnem of bits 0-2 of opcode, imm,readrm */
proc op19
	mov	byte [edi + tOperand.CODE],OM_IMMEDIATE
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	mov	al,[gs:esi]
	and	al,7
	shl	al,3
	mov	ah,[gs:esi+1]
	shr	ah,3
	and	ah,7
	or	al,ah
	sub	ah,ah
	cwde
	mov	[edi+ tOperand.ADDRESS],eax
	mov	edi,ebx
	call	ReadRM
	ret
endp
;/* op 20 - long branch */
proc op20
	mov	byte [strict],FALSE
	sub	ecx,ecx
	mov	byte [edi + tOperand.CODE],OM_LONGBRANCH
	bt	word [edi + tOperand.FLAGS],OMF_OP32
	jnc	short op20word
	LONG	esi+1
	inc	cl
	inc	cl
	jmp	short op20fin
op20word:
	UINT	esi+1
op20fin:
	add	eax,[code_address]
	add	eax,ecx
	add	eax,3
	bt	word [edi + tOperand.FLAGS],OMF_OP32
	jc	op20done
	and	eax,0ffffh
op20done:
	mov	[edi + tOperand.ADDRESS],eax
	mov	eax,ecx
	ret
endp
;/* op21 acc,dx */
proc op21
	mov	al,REG_EAX
	call	SetReg
	mov	edi,ebx
	btr	word [edi + tOperand.FLAGS],OMF_OP32
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	mov	al,REG_DX
	call	SetReg
	sub	eax,eax
	ret
endp
;/* op22 - dx,acc */
proc op22
	btr	word [edi + tOperand.FLAGS],OMF_OP32
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	mov	al,REG_DX
	call	SetReg
	mov	edi,ebx
	mov	al,REG_EAX
	call	SetReg
	sub	eax,eax
	ret
endp
;/* op23 - port,acc where B1 of opcode set is port dest */
proc op23
	bt	dword [gs:esi],1
	jc	short @@NoSwap
	xchg	ebx,edi
@@NoSwap:
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	mov	byte [edi + tOperand.CODE],OM_PORT
	movzx	eax,byte [gs:esi+1]
	mov	[edi + tOperand.ADDRESS],eax
	mov	edi,ebx
	mov	al,REG_EAX
	call	SetReg
	sub	eax,eax
	ret
endp
;/* op 24 acc, absolute */
proc op24
	sub	ecx,ecx
	mov	al,REG_EAX
	call	SetReg
	mov	edi,ebx
	mov	byte [edi + tOperand.CODE],OM_ABSOLUTE
	bt	word [edi + tOperand.FLAGS],OMF_ADR32
	jnc	short op24word
	inc	cl
	inc	cl
	LONG	esi+1
	jmp	short op24done
op24word:
	UINT	esi+1
op24done:
	mov	[edi + tOperand.ADDRESS],eax
	mov	eax,ecx
	ret
endp
;/* op 25 - immediate byte or word */
proc op25
	mov	byte [strict],FALSE
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	bt	dword [gs:esi],1
	jc	short op25fin
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
op25fin:
	push	esi
	inc	esi
	call	Immediate
	pop	esi
	ret
endp
;/* op 26, immediate 2byte,byte */
proc op26
	mov	byte [strict],FALSE
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [edi + tOperand.FLAGS],OMF_OP32
	push	esi
	inc	esi
	call	Immediate
	mov	edi,ebx
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [edi + tOperand.FLAGS],OMF_OP32
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	sub	eax,eax
	ret
endp
;/* op 27 - string */
proc op27
	mov	al,'d'
	bt	word [edi + tOperand.FLAGS],OMF_OP32
	jc	short op27pc
	mov	al,'w'
op27pc:
	call	MnemonicChar
	sub	eax,eax
	ret
endp
;/* op 28 - source = REG, dest = RM */
proc op28
	REG	esi
	call	SetReg
	mov	edi,ebx
	RM	esi
	call	SetReg
	sub	eax,eax
	ret
endp
;/* op 29 - dest = RM, immediate */
proc op29
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	RM	esi
	call	SetReg
	mov	edi,ebx
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	push	esi
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	sub	eax,eax
	ret
endp
;/* op30 - RM, shift with B3 of stream selecting COUNT or CL*/
proc op30
	call	ReadRM
	mov	ecx,eax
	mov	edi,ebx
	mov	dword [edi + tOperand.CODE],OM_SHIFT
	bt	dword [gs:esi],3
	jnc	op30cl
	mov	eax,[esi+ecx+2]
	inc	ecx
	jmp	short op30done
op30cl:
	bts	word [edi + tOperand.FLAGS],OMF_CL
op30done:
	mov	eax,ecx
	ret
endp
;/* op 31- reg, rm, count where B1 of opcode = byte/word */
proc op31
	call	CopyExtra
	REG	esi
	call	SetReg
	mov	edi,ebx
	call	ReadRM
	mov	ecx,eax
	mov	edi,offset extraoperand
	bts	word [edi + tOperand.FLAGS],OMF_BYTE
	bt	dword [gs:esi],1
	jc	short op31byte
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
op31byte:
	push	esi
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	add	eax,ecx
	ret
endp

;/* op32 - 386 special regs */
proc op32
	movzx	ecx,word [gs:esi]
	and	cx,0c005h
	cmp	cx,0c000h
	mov	al,OM_CRX
	jz	short op32gotype
	cmp	cx,0c001h
	mov	al,OM_DRX
	jz	short op32gotype
	cmp	cx,0c004h
	mov	al,OM_TRX
	jz	short op32gotype
	mov	al,OM_SUD
op32gotype:
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [ebx + tOperand.FLAGS],OMF_BYTE
	bts	word [edi + tOperand.FLAGS],OMF_OP32
	bts	word [ebx + tOperand.FLAGS],OMF_OP32
	bt	dword [gs:esi],1
	jc	op32noswap
	xchg	ebx,edi
op32noswap:
	mov	[edi + tOperand.CODE],al
	REG	esi
	mov	[edi + tOperand.THEREG],al
	mov	edi,ebx
	RM	esi
	call	SetReg
	sub	eax,eax
	ret
endp
;/* op33 - reg,rm,shiftcnt where B3 = reg source, b0 = shift cl */
proc op33
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [ebx + tOperand.FLAGS],OMF_BYTE
	call	CopyExtra
	call	ReadRM
	mov	ecx,eax
	REG	esi
	mov	edi,ebx
	call	SetReg
	mov	edi,offset extraoperand
	mov	byte [edi + tOperand.CODE],OM_SHIFT
	bt	dword [gs:esi],0
	jnc	short getofs
	bts	word [edi + tOperand.FLAGS],OMF_CL
	jmp	short op33done
getofs:
	movzx	eax,byte [esi+ecx+2]
op33done:
	mov	eax,ecx
	ret
endp
;/* op 34 - push & pop word */
proc op34
	test	dword [segs],SG_TWOBYTEOP
	jnz	short op34twobyte
	test	dword [segs],SG_OPSIZ
	jnz	short op34fin
	mov	byte [strict],FALSE
op34fin:
	call	ReadRM
	ret
op34twobyte:
	btr	word [edi+tOperand.FLAGS],OMF_OP32
	btr	word [edi+tOperand.FLAGS],OMF_OP32
	jmp	op34fin
endp
;/* op 35 -floating RM */
proc op35
	mov	byte [strict],FALSE
	mov	ax,[gs:esi]
	and	ax,0d0deh
	cmp	ax,0d0deh
	jnz	short op35nop
	mov	al,'p'
	call	MnemonicChar
op35nop:
	MODX	esi
	cmp	al,3
	jnz	short op35fsttab
	bts	word [edi + tOperand.FLAGS],OMF_FST
	jmp	short op35fin
op35fsttab:
	bts	word [edi + tOperand.FLAGS],OMF_FSTTAB
	movzx	eax,byte [gs:edi]
	B12
	shl	eax, OM_FTAB
	or	[edi + tOperand.FLAGS],ax
op35fin:
	call	ReadRM
	ret
endp
;/* op 36 - sized floating RM */
proc op36
	mov	cx,SZ_QWORD
	mov	byte [strict],FALSE
	mov	ax,[gs:esi]
	and	ax,2807h
	cmp	ax,2807h
	jz	short op36notbyte
	mov	cx,SZ_TBYTE
op36notbyte:
	bts	word [edi + tOperand.FLAGS],OMF_FSTTAB
	shl	ecx,OM_FTAB
	or	[edi + tOperand.FLAGS],cx
	call	ReadRM
	ret
endp
;/* OP 37 - floating MATH */
proc op37
	sub	edx,edx
	mov	byte [strict],FALSE
	mov	ax,[gs:esi]
	and	ax,0c0deh
	cmp	ax,0c0deh
	jnz	short op37noflop
	inc	edx
op37noflop:
	REG	esi
	and	al,5
	xor	al,dl
	cmp	al,5
	jnz	short op37nor
	mov	al,'r'
	call	MnemonicChar
op37nor:
	MODX	esi
	cmp	al,3
	jz	op37reg
	bts	word [edi + tOperand.FLAGS],OMF_FSTTAB
	mov	al,[gs:esi]
	B12
	shl	eax,OM_FTAB
	or	[edi + tOperand.FLAGS],ax
	call	ReadRM
	jmp	short op37done
op37reg:
	test	byte [gs:esi],6
	jz	short op37nop
	mov	al,'p'
	call	MnemonicChar
op37nop:
	bt	dword [gs:esi],2
	jc	short op37noswap
	xchg	ebx,edi
op37noswap:
	RM	esi
	call	SetReg
	bts	word [edi + tOperand.FLAGS],OMF_FST
	mov	edi,ebx
	mov	byte [edi + tOperand.CODE],OM_FSTREG
	sub	eax,eax
op37done:
	ret
endp
proc op38
	mov	byte [strict],FALSE
	bts	word [edi + tOperand.FLAGS],OMF_FSTTAB
	call	ReadRM
	ret
endp
;/* OP39 - word regrm with reg source */
proc op39
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [ebx + tOperand.FLAGS],OMF_BYTE
	call	op40
	ret
endp
;/* op 40 regrm with reg source */
proc op40
	mov	[dest2],ebx
	mov	[source2],edi
	call	RegRM
	ret
endp
;/* op 41 reg, bitnum */
proc op41
	btr	word [edi+tOperand.FLAGS],OMF_BYTE
	call	ReadRM
	mov	ecx,eax
	mov	edi,ebx
	bts	word [edi+tOperand.FLAGS],OMF_BYTE
	push	esi
	add	esi,ecx
	add	esi,2
	call	Immediate
	pop	esi
	mov	eax,ecx
	ret
endp
;/* op 42 mixed regrm with reg dest & strictness enforced */
proc op42
	mov	[dest2],edi
	mov	[source2],ebx
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	btr	word [ebx + tOperand.FLAGS],OMF_OP32
	mov	byte [strict],FALSE
	call	RegRM
	ret
endp
; op 43 CWDE
proc op43
		bt	word [edi + tOperand.FLAGS],OMF_OP32
		jnc	short .NoChange
		push	esi
		mov	esi,offset mnemonic + 1
		mov	eax,"wde"
		mov	[esi],eax
		pop	esi
		sub	eax,eax
.NoChange:	ret
endp		;---------------------------------------------------------------

proc ReadOverrides      	
.Loop:	
		sub	eax,eax
	gs	lodsb
		cmp	al,64h
		jc	short .TestSeg
		cmp	al,68h
		jnc	short .TestSeg
		sub	al,64h
		mov	ebx,SG_FS
.Found:
		mov	cl,al
		shl	ebx,cl
		or	[segs],ebx
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
		mov	edi,offset mnemonic
		push	esi
		mov	esi,[ebx + tOpCode.MNEMONIC]
		call	strcpy
		pop	esi
		mov	byte [strict],TRUE
		movzx	eax,byte [ebx + tOpCode.OPERANDS]
		push	eax
		mov	edi,offset dest
		mov	ebx,offset source
		cmp	byte [gs:esi],0fh
		jnz	short notwobyte
		or	dword [segs],SG_TWOBYTEOP
		inc	esi
notwobyte:
		mov	eax,offset extraoperand
		mov	byte [eax + tOperand.CODE],0
		mov	byte [edi + tOperand.CODE],0
		mov	byte [ebx + tOperand.CODE],0
		mov	word [edi + tOperand.FLAGS],0
		mov	word [ebx + tOperand.FLAGS],0

		bt	dword [gs:esi],0
		jc	notbyte
		bts	word [edi + tOperand.FLAGS],OMF_BYTE
		bts	word [ebx + tOperand.FLAGS],OMF_BYTE
notbyte:
		test	dword [segs],SG_ADRSIZ
		jnz	do_word1
		bts	word [edi + tOperand.FLAGS],OMF_ADR32
		bts	word [ebx + tOperand.FLAGS],OMF_ADR32
do_word1:
		test	dword [segs],SG_OPSIZ
		jnz	do_word2
		bts	word [edi + tOperand.FLAGS],OMF_OP32
		bts	word [ebx + tOperand.FLAGS],OMF_OP32
do_word2:
		pop	eax
		or	eax,eax
		jz	nodispatch
		dec	al
		push	dword OPprocedures
		push	dword 0
		call	CallTableProc
		add	esi,eax

nodispatch:	pop	ebx
		movzx	eax,byte [ebx + tOpCode.LENGTH]
		add	esi,eax
		ret
endp		;---------------------------------------------------------------

proc DoStrict
	push	edi
	push	esi
	test	byte [strict],-1
	jz	short floatstrict
	bt	word [edi + tOperand.FLAGS],OMF_BYTE
	jnc	chkdwptr
	mov	edi,esi
	mov	esi,offset byptr
	jmp	short strictend
chkdwptr:
	bt	word [edi + tOperand.FLAGS],OMF_OP32
	mov	edi,esi
	jnc	mkwordptr
	mov	esi,offset dwptr
	jmp	short strictend
mkwordptr:
	mov	esi,offset woptr
  	jmp	short strictend
floatstrict:
	bt	word [edi + tOperand.FLAGS],OMF_FSTTAB
	jnc	strictdone
	movzx	eax,word [edi + tOperand.FLAGS]
	shr	eax,OM_FTAB
	and	eax,7
	mov	edi,esi
	push	edi
	mov	esi,offset sts
	mov	esi,[esi + eax * 4]
	call	strcat
	pop	edi
		jmp	short strictdone
strictend:
	call	strcat
strictdone:
	pop	esi
	call	strlen
	add	esi,eax
	pop	edi
	ret
endp

proc TabTo
	cbw
	cwde
	mov	ecx,eax
	call	strlen
	xchg	eax,ecx
	sub	eax,ecx
	jnc	tt_noover
	add	eax,ecx
	add	esi,eax
	jmp	short tt_done
tt_noover:
	add	esi,ecx
	mov	ecx,eax
tabtlp:
	mov	byte [esi],' '
	inc	esi
	loop	tabtlp
tt_done:
	mov	byte [esi],0
	ret
endp

proc GetST
		mov	al,[edi + tOperand.THEREG]
		mov	edi,esi
		mov	esi,offset stsreg
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
	jnz	short gsrnoe
	mov	byte [esi],'e'
	inc	esi
gsrnoe:
	mov	edi,offset regs
	mov	ax,[edi + ecx *2]
	mov	[esi],al
	inc	esi
	mov	[esi],ah
	inc	esi
	mov	byte [esi],0
	pop	edi
	ret
endp

proc GetReg
		movzx	ecx,al
		sub	al,al
		inc	al
		bt	word [edi + tOperand.FLAGS],OMF_BYTE
		jc	short grno32
		bt	word [edi + tOperand.FLAGS],OMF_OP32
		jnc	short grno32
		dec	al
grno32:
		bt	word [edi + tOperand.FLAGS],OMF_BYTE
		jc	short isbyte
		or	cl,8
isbyte:
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
		movzx	eax,byte [edi + tOperand.THEREG]
		mov	al,[ebx+eax]
		mov	[esi],al
		inc	esi
		mov	byte [esi],0
		ret
endp 		;---------------------------------------------------------------

proc GetSeg
		push	edi
		push	eax
		mov	edi,offset psegs
		mov	ax,[edi + ecx *2]
		mov	[esi],al
		inc	esi
		mov	[esi],ah
		inc	esi
		pop	eax
		or	al,al
		mov	al,':'
		jz	short nocolon
		mov	[esi],al
		inc	esi
nocolon:
		mov	byte [esi],0
		pop	edi
		ret
endp
proc SegOverride
	mov	al,1
	sub	ecx,ecx
	test	dword [segs],SG_ES
	jz	short so_testcs
	call	GetSeg
so_testcs:
	inc	ecx
	test	dword [segs],SG_CS
	jz	short so_testss
	call	GetSeg
so_testss:
	inc	ecx
	test	dword [segs],SG_SS
	jz	short so_testds
	call	GetSeg
so_testds:
	inc	ecx
	test	dword [segs],SG_DS
	jz	short so_testfs
	call	GetSeg
so_testfs:
	inc	ecx
	test	dword [segs],SG_FS
	jz	short so_testgs
	call	GetSeg
so_testgs:
	inc	ecx
	test	dword [segs],SG_GS
	jz	short so_done
	call	GetSeg
so_done:
	mov	dword [segs],0
	ret
endp

proc Scaled
	push	dword [edi + tOperand.FLAGS]
	btr	word [edi + tOperand.FLAGS],OMF_BYTE
	bts	word [edi + tOperand.FLAGS],OMF_OP32
	or	al,al
	jz	short notbased
	sub	al,al
	mov	al,[edi + tOperand.THEREG]
	call	GetReg
notbased:
	bt	word [edi + tOperand.FLAGS],OMF_SCALED
	jnc	short notscaled2
	movzx	ecx,byte [edi + tOperand.SCALE]
	mov	eax,ecx
	add	ecx,ecx
	add	ecx,eax
	add	ecx,offset scales
	mov	eax,[ecx]
	call	put3
	or	al,1
	mov	al,[edi + tOperand.SCALEREG]
	call	GetReg
notscaled2:
	pop	dword [edi + tOperand.FLAGS]
	ret
endp

proc FOM_FSTREG
		mov	edi,esi
		mov	esi,offset stalone
		call	strcat
		ret
endp 		;---------------------------------------------------------------

proc FOM_CRX
	mov	ebx,offset crreg
	call	GetSpecial
	ret
endp
proc FOM_DRX
	mov	ebx,offset drreg
	call	GetSpecial
	ret
endp
proc FOM_TRX
	mov	ebx,offset trreg
	call	GetSpecial
	ret
endp
proc FOM_SUD
	mov	ebx,offset sudreg
	call	GetSpecial
	ret
endp
proc FOM_PORT
	mov	al,SY_PORT
format:
	call	FormatValue
	ret
endp

proc FOM_INT
	mov	al,SY_INTR
	jmp	short format
endp

proc FOM_SHIFT
		bt	word [edi + tOperand.FLAGS],OMF_CL
		jnc	.NotCL
		mov	eax,"cl"
		mov	[esi],eax
		add	esi,byte 2
		ret
.NotCL:
		cmp	dword [edi + tOperand.ADDRESS],1
		mov	al,SY_SHIFT
		jnz	format
		mov	byte [esi],'1'
		inc	esi
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FOM_RETURN
	mov	al,SY_RETURN
	jmp	format
endp
proc FOM_SHORTBRANCH
	mov	al,SY_SHORTBRANCH
	jmp	format
endp
proc FOM_LONGBRANCH
	mov	al,SY_LONGBRANCH
	jmp	format
endp
proc FOM_FARBRANCH
	mov	al,SY_SEGMENT
	call	format
	mov	byte [esi],':'
	inc	esi
	mov	al,SY_ABSBRANCH
	call	format
	ret
endp
proc FOM_ABSOLUTE
	call	DoStrict
	call	SegOverride
	mov	byte [esi],'['
	inc	esi
	mov	byte [esi],0
	bt	word [edi + tOperand.FLAGS],OMF_SCALED
	jnc	foa_notscaled
	mov	al,SY_WORDOFS
	call	FormatValue
	sub	eax,eax
	call	Scaled
	jmp	short foa_finish
foa_notscaled:
	mov	al,SY_ABSOLUTE
	call	FormatValue
foa_finish:
	mov	byte [esi],']'
	inc	esi
	mov	byte [esi],0
	ret
endp
proc FOM_IMMEDIATE
	bt	word [edi + tOperand.FLAGS],OMF_BYTE
	mov	al,SY_WORDIMM
	jnc	short absformat
	mov	al,SY_SIGNEDIMM
	bt	word [edi + tOperand.FLAGS],SY_SIGNEDIMM
	jc	short absformat
	mov	al,SY_SIGNEDIMM
absformat:
	jmp	format
endp

proc FOM_REG
		bt	word [edi + tOperand.FLAGS],OMF_FST
		jnc	short .FOreg
		call	GetST
		ret
.FOreg:		mov	al,[edi + tOperand.THEREG]
		call	GetReg
		ret
endp		;---------------------------------------------------------------

proc FOM_BASED
	call	DoStrict
	call	SegOverride
	mov	byte [esi],'['
	inc	esi
	mov	byte [esi],0
	bt	word [edi + tOperand.FLAGS],OMF_ADR32
	jnc	fob_notscaled
	mov	al,1
	call	Scaled
	jmp	short fob2
fob_notscaled:
	push	edi
	push	esi
	movzx	eax,byte [edi + tOperand.THEREG]
	xchg	esi,edi
	mov	esi,offset based
	mov	esi,[esi + eax * 4]
	call	strcpy
	pop	esi
	pop	edi
	call	strlen
	add	esi,eax
fob2:
	test	word [edi + tOperand.FLAGS],OMF_OFFSET
	jz	short fob_noofs
	bt	word [edi + tOperand.FLAGS],OMF_SIGNED_OFFSET
	mov	al,SY_SIGNEDOFS
	jc	fob_format
	mov	al,SY_WORDOFS
	bt	word [edi + tOperand.FLAGS],OMF_WORD_OFFSET
	jc	fob_format
	mov	al,SY_BYTEOFS
fob_format:
	call	FormatValue
fob_noofs:
	mov	byte [esi],']'
	inc	esi
	mov	byte [esi],0
	ret
endp
proc FOM_SEGMENT
	movzx	ecx,byte [edi + tOperand.THEREG]
	sub	eax,eax
	call	GetSeg
	ret
endp

proc PutOperand
	call	strlen
	add	esi,eax
	mov	al,[edi + tOperand.CODE]
	dec	al
	js	short po_none
		push	dword FOMprocedures
		push	dword 0
		call	CallTableProc

po_none:	ret
endp		;---------------------------------------------------------------

proc FormatDisassembly
		prologue 256
		push	esi
		lea	edi,[ebp-256]
		mov	byte [edi],0
		test	dword [segs],SG_REPZ
		push	edi
		jz	fd_notrepz
		mov	esi,offset st_repz
		call	strcpy
fd_notrepz:
		test	dword [segs],SG_REPNZ
		jz	fd_notrepnz
		mov	esi,offset st_repnz
		call	strcpy
fd_notrepnz:
		pop	edi
		xchg	esi,edi
		call	strlen
		add	esi,eax
		xchg	esi,edi
		mov	esi,offset mnemonic
		call	strcat
		lea	esi,[ebp-256]
		sub	eax,eax
		mov	al,TAB_ARGPOS
		call	TabTo
		mov	edi,offset dest
		call	PutOperand
		mov	edi,offset source
		test	byte [edi + tOperand.CODE],-1
		jz	short nosource
		mov	byte [esi],','
		inc	esi
		mov	byte [esi],0
		call	PutOperand
nosource:
		mov	edi,offset extraoperand
		test	byte [edi + tOperand.CODE],-1
		jz	short noextra
		mov	byte [esi],','
		inc	esi
		mov	byte [esi],0
		call	PutOperand
noextra:
		pop	esi
		mov	byte [esi],0
		call	SegOverride
		mov	edi,esi
		lea	esi,[ebp-256]
		call	strcat
		epilogue
		ret
endp		;---------------------------------------------------------------


proc ABSX
		bt	eax,31
		jnc	.NoAbs
		neg	eax
.NoAbs:		ret
endp		;---------------------------------------------------------------


;--- FSY routines --------------------------------------------------------------

proc FSY_SIGNEDOFS
		bt	dword [edi + tOperand.ADDRESS],31
		mov	eax,"+os_"
		jnc	.Pos
		mov	eax,"-os_"
.Pos:		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.ADDRESS]
		call	ABSX
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_WORDOFS
		mov	eax,"+ow_"
		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_BYTEOFS
		mov	eax,"+ob_"
		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_ABSOLUTE
		mov	eax,"ab_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_SIGNEDIMM
		bt	dword [edi + tOperand.ADDRESS],31
		mov	eax,"+is_"
		jnc	.Pos
		mov	eax,"-is_"
.Pos:		mov	[esi],eax
		add	esi,byte 4
		mov	eax,[edi + tOperand.ADDRESS]
		call	ABSX
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_WORDIMM
		mov	eax,"iw_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_BYTEIMM
		mov	eax,"ib_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_PORT
		mov	eax,"p_"
		mov	[esi],eax
		add	esi,byte 2
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_INTR
		mov	eax,"it_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_RETURN
		mov	eax,"rt_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexW2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_ABSBRANCH
		mov	eax,"ba_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_LONGBRANCH
		mov	eax,"bl_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_SHORTBRANCH
		mov	eax,"bs_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexD2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_SHIFT
		mov	eax,"ib_"
		mov	[esi],eax
		add	esi,byte 3
		mov	eax,[edi + tOperand.ADDRESS]
		call	K_HexB2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------

proc FSY_SEGMENT
		mov	eax,"sg_"
		mov	[esi],eax
		add	esi,byte 3
		mov	ax,[edi + tOperand.SEG]
		call	K_HexW2Str
		mov	byte [esi],0
		ret
endp		;---------------------------------------------------------------


proc FormatValue
		dec	al
		push	dword FSYprocedures
		push	dword 0
		call	CallTableProc
		ret
endp		;---------------------------------------------------------------
