;
; operands.asm
;
; Function: Handle 386 operands as dictated by the opcode table
;   Handle formatting output
;
; Sorry, I didn't have time to document this one yet
;

.386
Ideal

;DEBUG=1

include "opcodes.asi"
include "operands.asi"
include "op.asg"
include "segments.ah"

IFDEF DEBUG
include "misc.ah"
ENDIF

	extrn TableDispatch:	near


segment KVARS
code_address	dd	0
dest2		dd	0
source2		dd	0
segs		dd	0
extraoperand	OPERAND ?
source		OPERAND	?
dest		OPERAND	?
mnemonic	db	10 DUP (?)
strict		db	0
	align
regs		db	"alcldlblahchdhbhaxcxdxbxspbpsidi"
psegs		db	"escsssdsfsgs"
crreg		db	"CR0?23????"
drreg		db	"DR0123??67"
trreg		db	"TR??????67"
sudreg		db	"?R????????"
scales		db	" + *2+*4+*8+"
stalone		db	"ST",0
st_repz		db	"repz ",0
st_repnz	db	"repnz ",0


base0		db	"bx+si",0
base1		db	"bx+di",0
base2		db	"bp+si",0
base3		db	"bp+di",0
base4		db	"si",0
base5		db	"di",0
base6		db	"bp",0
base7		db	"bx",0
st0		db	"fword",0	; Should be DWORD for MATH, FWORD for jmp/call
st1		db	"dword",0
st2		db	"qword",0
st3		db	"word",0
st4		db	"tbyte"
st5		db	0
byptr		db	"byte ptr ",0
dwptr		db	"d"
woptr		db	"word"
theptr		db	" ptr ",0
stsreg		db	"ST(",0
	align
based		dd	base0,base1,base2,base3,base4,base5,base6,base7
sts		dd	st0,st1,st2,st3,st4,st5,st5,st5
ends

segment KCODE

PROC	strlen
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
ENDP	strlen

PROC	strcpy
	push	es
	push	ds
	pop	es
@@Loop:
	lodsb
	stosb
	or	al,al
	jnz	@@Loop
	pop	es
	ret
ENDP	strcpy

PROC	strcat
	mov	al,[edi]
	inc	edi
	or	al,al
	jnz	strcat
	dec	edi
	jmp	strcpy
ENDP	strcat

PROC	CopyExtra
	push	esi
	push	edi
	mov	esi,offset extraoperand
	xchg	esi,edi
	push	es
	push	ds
	pop	es
	mov	ecx,OPERANDSIZE
	rep	movsb
	pop	es
	pop	edi
	pop	esi
	ret
ENDP	CopyExtra


PROC	put2
	mov	[esi],ah
	inc	esi
	mov	[esi],al
	inc	esi
	mov	[byte ptr esi],0
	ret
ENDP	put2

PROC	put3
	push	eax
	shr	eax,8
	mov	[esi],ah
	inc	esi
	pop	eax
	call	put2
	ret
ENDP	put3

PROC	put4
	push	eax
	shr	eax,16
	call	put2
	pop	eax
	call	put2
	ret
ENDP	put4

PROC	SetSeg
	mov	[strict],FALSE
	mov	[edi + OPERAND.CODE],OM_SEGMENT
	mov	[edi + OPERAND.THEREG],al
	ret
ENDP	SetSeg

PROC	SetReg
	mov	[strict],FALSE
	mov	[edi + OPERAND.CODE],OM_REG
	mov	[edi + OPERAND.THEREG],al
	ret
ENDP	SetReg

PROC	ReadRM
	push	ecx
	sub	ecx,ecx
	mov	cl,2
	RM	esi
	mov	[edi + OPERAND.THEREG],al
	MODX	esi
	mov	ch,al
	cmp	ch,MOD_REG
	jnz	short notregreg
	mov	[edi + OPERAND.CODE],OM_REG
	mov	[strict],FALSE
	sub	eax,eax
	pop	ecx
	ret

notregreg:
	bt	[edi + OPERAND.FLAGS],OMF_ADR32
	jnc	adr16
	cmp	[edi + OPERAND.THEREG],RM_32_SCALED
	jnz	notscaled
	inc	cl
	RM	esi+1
	mov	[edi + OPERAND.THEREG],al
	REG	esi+1
	mov	[edi + OPERAND.SCALEREG],al
	MODX	esi+1
	mov	[edi + OPERAND.SCALE],al
	cmp	[edi + OPERAND.SCALEREG],RM_32_STACKINDEX
	jz	hassp
	bts	[edi + OPERAND.FLAGS],OMF_SCALED
hassp:
	cmp	[edi + OPERAND.THEREG],RM_32_ABSOLUTE
	jnz	basedAndScaled
	cmp	ch,MOD_NOOFS
	jnz	short basedAndScaled
	mov	[edi + OPERAND.CODE],OM_ABSOLUTE
	LONG	esi+3
	mov	[edi + OPERAND.ADDRESS],eax
	sub	eax,eax
	mov	al,5
	pop	ecx
	ret

notscaled:	
	cmp	ch,MOD_NOOFS
	jnz	basedAndScaled
	cmp	[edi + OPERAND.THEREG], RM_32_ABSOLUTE
	jnz	basedAndScaled
	mov	[edi + OPERAND.CODE], OM_ABSOLUTE
	LONG	esi+2
	mov	[edi + OPERAND.ADDRESS],eax
	sub	eax,eax
	mov	al,4
	pop	ecx
	ret

adr16:
	cmp	ch,MOD_NOOFS
	jnz	basedAndScaled
	cmp	[edi + OPERAND.THEREG], RM_16_ABSOLUTE
	jnz	basedAndScaled
	mov	[edi + OPERAND.CODE], OM_ABSOLUTE
	UINT	esi+2
	mov	[edi + OPERAND.ADDRESS],eax
	sub	eax,eax
	mov	al,2
	pop	ecx
	ret
basedAndScaled:
	mov	[edi + OPERAND.CODE], OM_BASED
	cmp	ch,MOD_ADDR
	jnz	short checksigned
	bts	[edi + OPERAND.FLAGS], OMF_WORD_OFFSET
	push	ecx
	sub	ch,ch
	mov	eax,[gs:esi+ecx]
	pop	ecx
	bt	[edi + OPERAND.FLAGS], OMF_ADR32
	jc	dwordx
	and	eax,0ffffh
	sub	cl,2
dwordx:
	mov	[edi + OPERAND.ADDRESS],eax
	add	cl,4
	jmp	short readrmdone
checksigned:
	cmp	ch, MOD_SIGNED
	jnz	short readrmdone
	bts	[edi + OPERAND.FLAGS],OMF_SIGNED_OFFSET
	push	ecx
	sub	ch,ch
	sub	eax,eax
	mov	al,[gs:esi+ecx]
	pop	ecx
	mov	[edi + OPERAND.ADDRESS],eax
	inc	cl
readrmdone:
	mov	eax,ecx
	sub	al,2
	cbw
	cwde
	pop	ecx
	ret
ENDP	ReadRM

PROC	RegRM
	mov	edi,[dest2]
	REG	esi
	call	SetReg
	mov	edi,[source2]
	call	ReadRM
	ret
ENDP	RegRM

PROC	Immediate
	push	ecx
	sub	ecx,ecx
	mov	[edi + OPERAND.CODE],OM_IMMEDIATE
	bt	[edi + OPERAND.FLAGS],OMF_BYTE
	jnc	short inotbyte
	inc	cl
	sub	eax,eax
	mov	al,[gs:esi]
	jmp	short i_ret
inotbyte:
	bt	[edi + OPERAND.FLAGS], OMF_OP32
	jnc	iword
	add	cl,4
	LONG	esi
	jmp	short i_ret
iword:
	add	cl,2
	UINT	esi
i_ret:
	mov	[edi + OPERAND.ADDRESS],eax
	mov	eax,ecx
	pop	ecx
	ret
ENDP	Immediate

PROC	MnemonicChar
	push	edi
	mov	edi,offset mnemonic
mc2:
	inc	edi
	cmp	[byte ptr edi-1],0
	jnz	mc2
	mov	[edi-1],al
	mov	[byte ptr edi],0
	pop	edi
	ret
ENDP	MnemonicChar

;/* op 1- word reg from bits 0 - 2 of opcode */
PROC	op1
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	mov	al,[gs:esi]
	B02
	call	SetReg
	sub	eax,eax
	ret
ENDP	op1

;/* op2 acc, reg bits 0-2 of opcode */
PROC	op2
	mov	al,REG_EAX
	btr	[edi+OPERAND.FLAGS],OMF_BYTE		; Bugfix in original
	call	SetReg
	mov	edi,ebx
	mov	al,[gs:esi]
	B02						; Bugfix in original
	btr	[edi+OPERAND.FLAGS],OMF_BYTE		; Bugfix in original
	call	SetReg
	sub	eax,eax
	ret
ENDP	op2

;/* op3 - seg from b3-5 of opcode */
PROC	op3
	mov	al,[gs:esi]
	B35
	call	SetSeg
	sub	eax,eax
	ret
ENDP	op3

;/* op4 - REGRM with b1 of opcode set reg is dest else source */
PROC	op4
	bt	[dword ptr gs:esi],1
	jc	short op4nox
	xchg	ebx,edi
op4nox:
	mov	[dest2],edi
	mov	[source2],ebx
	call	RegRM
	ret
ENDP	op4

;/* op5 - use RM only */
PROC	op5
	call	ReadRM
	ret
ENDP	op5

;/* op6 READRM for shift */
PROC	op6
	call	ReadRM
	sub	ecx,ecx
	mov	cl,al
	mov	edi,ebx
	mov	[edi + OPERAND.CODE],OM_SHIFT
	bt	[dword ptr gs:esi],4
	jnc	short op6cnt
	bt	[dword ptr gs:esi],1
	jnc	op61
	bts	[edi + OPERAND.FLAGS],OMF_CL
	jmp	short op6done
op61:
	mov	[edi + OPERAND.ADDRESS],1
	jmp	short op6done
op6cnt:
	sub	eax,eax
	movzx	eax,[byte ptr gs:esi+ecx+2]
	inc	cl
	mov	[edi + OPERAND.ADDRESS],eax
op6done:
	mov	eax,ecx
	ret
ENDP	op6

;/* op 7 regrm with reg dest */
PROC	op7
	mov	[dest2],edi
	mov	[source2],ebx
	call	RegRM
	ret
ENDP	op7

;/* op8 - word regrm with reg dest */
PROC	op8
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[ebx + OPERAND.FLAGS],OMF_BYTE
	jmp	op7
ENDP	op8

;/* op 9 - interrupts */
PROC	op9
	mov	[strict],FALSE
	sub	eax,eax
	mov	al,3
	bt	[dword ptr gs:esi],0
	jnc	short op9int3
	mov	al,[gs:esi+1]
op9int3:
	mov	[edi + OPERAND.ADDRESS],eax
	mov	[byte ptr edi + OPERAND.CODE],OM_INT
	sub	al,al
	ret
ENDP	op9
;/* op 10, short relative branch */
PROC	op10
	mov	[strict],FALSE
	mov	[edi + OPERAND.CODE],OM_SHORTBRANCH
	movsx	eax,[byte ptr gs:esi+1]
	inc	eax
	inc	eax
	add	eax,[code_address]
	mov	[edi + OPERAND.ADDRESS],eax
	bt	[edi + OPERAND.FLAGS],OMF_OP32
	jc	short op10notword
	and	[edi + OPERAND.ADDRESS],0ffffh
op10notword:
	sub	eax,eax
	ret
ENDP	op10
;/* op 11 RM, immediate */
PROC	op11
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
ENDP	op11
;/* op 12 - acc, immediate */
PROC	op12
	mov	al,REG_EAX
	call	SetReg
	mov	edi,ebx
	inc	esi
	call	Immediate
	dec	esi
	ret
ENDP	op12
;/* op 13 absolute, acc*/
PROC	op13
	sub	ecx,ecx
	mov	[edi + OPERAND.CODE],OM_ABSOLUTE
	bt	[edi + OPERAND.FLAGS],OMF_ADR32
	jnc	short op13word
	LONG	esi+1
	inc	cl
	inc	cl
	jmp	short op13fin
op13word:
	UINT	esi+1
op13fin:
	mov	[edi + OPERAND.ADDRESS],eax
	mov	edi,ebx
	mov	al,REG_EAX
	call	SetReg
	mov	eax,ecx
	ret
ENDP	op13
;/* op 14 - RM, immediate, b01 of opcode != 1 for byte */
PROC	op14
	call	ReadRM
	movzx	ecx,al
	mov	al,[gs:esi]
	B01
	jnz	short op14checkbyte
	bts	[ebx + OPERAND.FLAGS],OMF_BYTE
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	jmp	short op14source
op14checkbyte:
	btr	[ebx + OPERAND.FLAGS],OMF_BYTE
	cmp	al,1
	jz	short op14check2
	bts	[ebx + OPERAND.FLAGS],OMF_BYTE
op14check2:
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
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
	bt	[edi + OPERAND.FLAGS],OMF_BYTE
	jnc	op14done
	bts	[edi + OPERAND.FLAGS],OMF_SIGNED
	mov	eax,[edi + OPERAND.ADDRESS]
	cbw
	cwde
	mov	[edi + OPERAND.ADDRESS],eax
op14done:
	mov	eax,ecx
	ret
ENDP	op14
;/* op 15 - acc, immediate, B3 of opcode clear for byte */
PROC	op15
	mov	al,[gs:esi]
	B02
	call	SetReg
	bt	[dword ptr gs:esi],3
	jnc	op15byte
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[ebx + OPERAND.FLAGS],OMF_BYTE
	jmp	short op15source
op15byte:
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	bts	[ebx + OPERAND.FLAGS],OMF_BYTE
op15source:
	mov	edi,ebx
	inc	esi
	call	Immediate
	dec	esi
	ret
ENDP	op15
;/* op 16 - seg,readrm, if B1 of opcode seg is dest else source */
PROC	op16
	bt	[dword ptr gs:esi],1
	jc	noswap
	xchg	ebx,edi
noswap:
	REG	esi
	call	SetSeg
	mov	edi,ebx
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	call	ReadRM
	ret
ENDP	op16
;/* op 17, far return */
PROC	op17
	mov	[strict],FALSE
	mov	[edi + OPERAND.CODE],OM_RETURN
	btr	[edi + OPERAND.FLAGS],OMF_ADR32
	btr	[edi + OPERAND.FLAGS],OMF_OP32
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	UINT	esi+1
	mov	[edi + OPERAND.ADDRESS],eax
	sub	eax,eax
	ret
ENDP	op17
;/* op 18, far branch/call */
PROC	op18
	sub	ecx,ecx
	mov	[strict],FALSE
	mov	[edi + OPERAND.CODE],OM_FARBRANCH
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	bt	[edi + OPERAND.FLAGS],OMF_OP32
	jnc	short op18word
	inc	cl
	inc	cl
	LONG	esi+1
	jmp	short	op18fin
op18word:
	UINT	esi+1
op18fin:
	mov	[edi + OPERAND.ADDRESS],eax
	UINT	esi+ecx+3
	mov	[edi + OPERAND.SEG],ax
	mov	eax,ecx
	ret
ENDP	op18
;/* op 19 - ESC, mnem of bits 0-2 of opcode, imm,readrm */
PROC	op19
	mov	[edi + OPERAND.CODE],OM_IMMEDIATE
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	mov	al,[gs:esi]
	and	al,7
	shl	al,3
	mov	ah,[gs:esi+1]
	shr	ah,3
	and	ah,7
	or	al,ah
	sub	ah,ah
	cwde
	mov	[edi+ OPERAND.ADDRESS],eax
	mov	edi,ebx
	call	ReadRM
	ret
ENDP	op19
;/* op 20 - long branch */
PROC	op20
	mov	[strict],FALSE
	sub	ecx,ecx
	mov	[edi + OPERAND.CODE],OM_LONGBRANCH
	bt	[edi + OPERAND.FLAGS],OMF_OP32
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
	bt	[edi + OPERAND.FLAGS],OMF_OP32
	jc	op20done
	and	eax,0ffffh
op20done:
	mov	[edi + OPERAND.ADDRESS],eax
	mov	eax,ecx
	ret
ENDP	op20
;/* op21 acc,dx */
PROC	op21
	mov	al,REG_EAX
	call	SetReg
	mov	edi,ebx
	btr	[edi + OPERAND.FLAGS],OMF_OP32
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	mov	al,REG_DX
	call	SetReg
	sub	eax,eax
	ret
ENDP	op21
;/* op22 - dx,acc */
PROC	op22
	btr	[edi + OPERAND.FLAGS],OMF_OP32
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	mov	al,REG_DX
	call	SetReg
	mov	edi,ebx
	mov	al,REG_EAX
	call	SetReg
	sub	eax,eax
	ret
ENDP	op22
;/* op23 - port,acc where B1 of opcode set is port dest */
PROC	op23
	bt	[dword ptr gs:esi],1
	jc	short @@NoSwap
	xchg	ebx,edi
@@NoSwap:
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	mov	[edi + OPERAND.CODE],OM_PORT
	movzx	eax,[byte ptr gs:esi+1]
	mov	[edi + OPERAND.ADDRESS],eax
	mov	edi,ebx
	mov	al,REG_EAX
	call	SetReg
	sub	eax,eax
	ret
ENDP	op23
;/* op 24 acc, absolute */
PROC	op24
	sub	ecx,ecx
	mov	al,REG_EAX
	call	SetReg
	mov	edi,ebx
	mov	[edi + OPERAND.CODE],OM_ABSOLUTE
	bt	[edi + OPERAND.FLAGS],OMF_ADR32
	jnc	short op24word
	inc	cl
	inc	cl
	LONG	esi+1
	jmp	short op24done
op24word:
	UINT	esi+1
op24done:
	mov	[edi + OPERAND.ADDRESS],eax
	mov	eax,ecx
	ret
ENDP	op24
;/* op 25 - immediate byte or word */
PROC	op25
	mov	[strict],FALSE
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	bt	[dword ptr gs:esi],1
	jc	short op25fin
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
op25fin:
	push	esi
	inc	esi
	call	Immediate
	pop	esi
	ret
ENDP	op25
;/* op 26, immediate 2byte,byte */
PROC	op26
	mov	[strict],FALSE
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[edi + OPERAND.FLAGS],OMF_OP32
	push	esi
	inc	esi
	call	Immediate
	mov	edi,ebx
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[edi + OPERAND.FLAGS],OMF_OP32
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	sub	eax,eax
	ret
ENDP	op26
;/* op 27 - string */
PROC	op27
	mov	al,'d'
	bt	[edi + OPERAND.FLAGS],OMF_OP32
	jc	short op27pc
	mov	al,'w'
op27pc:
	call	MnemonicChar
	sub	eax,eax
	ret
ENDP	op27	
;/* op 28 - source = REG, dest = RM */
PROC	op28
	REG	esi
	call	SetReg
	mov	edi,ebx
	RM	esi
	call	SetReg
	sub	eax,eax
	ret
ENDP	op28
;/* op 29 - dest = RM, immediate */
PROC	op29
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	RM	esi
	call	SetReg
	mov	edi,ebx
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	push	esi
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	sub	eax,eax
	ret
ENDP	op29
;/* op30 - RM, shift with B3 of stream selecting COUNT or CL*/
PROC	op30
	call	ReadRM
	mov	ecx,eax
	mov	edi,ebx
	mov	[edi + OPERAND.CODE],OM_SHIFT
	bt	[dword ptr gs:esi],3
	jnc	op30cl
	mov	eax,[esi+ecx+2]
	inc	ecx
	jmp	short op30done
op30cl:
	bts	[edi + OPERAND.FLAGS],OMF_CL
op30done:
	mov	eax,ecx
	ret
ENDP	op30
;/* op 31- reg, rm, count where B1 of opcode = byte/word */
PROC	op31
	call	CopyExtra
	REG	esi
	call	SetReg
	mov	edi,ebx
	call	ReadRM
	mov	ecx,eax
	mov	edi,offset extraoperand
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	bt	[dword ptr gs:esi],1
	jc	short op31byte
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
op31byte:
	push	esi
	inc	esi
	inc	esi
	call	Immediate
	pop	esi
	add	eax,ecx
	ret
ENDP	op31

;/* op32 - 386 special regs */
PROC	op32
	movzx	ecx,[word ptr gs:esi]
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
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[ebx + OPERAND.FLAGS],OMF_BYTE
	bts	[edi + OPERAND.FLAGS],OMF_OP32
	bts	[ebx + OPERAND.FLAGS],OMF_OP32
	bt	[dword ptr gs:esi],1
	jc	op32noswap
	xchg	ebx,edi
op32noswap:
	mov	[edi + OPERAND.CODE],al
	REG	esi
	mov	[edi + OPERAND.THEREG],al
	mov	edi,ebx
	RM	esi
	call	SetReg
	sub	eax,eax
	ret
ENDP	op32
;/* op33 - reg,rm,shiftcnt where B3 = reg source, b0 = shift cl */
PROC	op33
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[ebx + OPERAND.FLAGS],OMF_BYTE
	call	CopyExtra
	call	ReadRM
	mov	ecx,eax
	REG	esi
	mov	edi,ebx
	call	SetReg
	mov	edi,offset extraoperand
	mov	[edi + OPERAND.CODE],OM_SHIFT
	bt	[dword ptr gs:esi],0
	jnc	short getofs
	bts	[edi + OPERAND.FLAGS],OMF_CL
	jmp	short op33done
getofs:
	movzx	eax,[byte ptr esi+ecx+2]
op33done:
	mov	eax,ecx
	ret
ENDP	op33
;/* op 34 - push & pop word */
PROC	op34
	test	[segs],SG_TWOBYTEOP
	jnz	short op34twobyte
	test	[segs],SG_OPSIZ
	jnz	short op34fin
	mov	[strict],FALSE
op34fin:
	call	ReadRM
	ret
op34twobyte:
	btr	[edi+OPERAND.FLAGS],OMF_OP32
	btr	[edi + OPERAND.FLAGS],OMF_OP32
	jmp	op34fin
ENDP	op34
;/* op 35 -floating RM */
PROC	op35
	mov	[strict],FALSE
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
	bts	[edi + OPERAND.FLAGS],OMF_FST
	jmp	short op35fin
op35fsttab:
	bts	[edi + OPERAND.FLAGS],OMF_FSTTAB
	movzx	eax,[byte ptr gs:edi]
	B12
	shl	eax, OM_FTAB
	or	[edi + OPERAND.FLAGS],ax
op35fin:
	call	ReadRM
	ret
ENDP	op35
;/* op 36 - sized floating RM */
PROC	op36
	mov	cx,SZ_QWORD
	mov	[strict],FALSE
	mov	ax,[gs:esi]
	and	ax,2807h
	cmp	ax,2807h
	jz	short op36notbyte
	mov	cx,SZ_TBYTE
op36notbyte:
	bts	[edi + OPERAND.FLAGS],OMF_FSTTAB
	shl	ecx,OM_FTAB
	or	[edi + OPERAND.FLAGS],cx
	call	ReadRM
	ret
ENDP	op36
;/* OP 37 - floating MATH */
PROC	op37
	sub	edx,edx
	mov	[strict],FALSE
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
	bts	[edi + OPERAND.FLAGS],OMF_FSTTAB
	mov	al,[gs:esi]
	B12
	shl	eax,OM_FTAB
	or	[edi + OPERAND.FLAGS],ax
	call	ReadRM
	jmp	short op37done
op37reg:
	test	[byte ptr gs:esi],6
	jz	short op37nop
	mov	al,'p'
	call	MnemonicChar
op37nop:
	bt	[dword ptr gs:esi],2
	jc	short op37noswap
	xchg	ebx,edi
op37noswap:
	RM	esi
	call	SetReg
	bts	[edi + OPERAND.FLAGS],OMF_FST
	mov	edi,ebx
	mov	[edi + OPERAND.CODE],OM_FSTREG
	sub	eax,eax
op37done:
	ret
ENDP	op37
PROC	op38
	mov	[strict],FALSE
	bts	[edi + OPERAND.FLAGS],OMF_FSTTAB
	call	ReadRM
	ret
ENDP	op38
;/* OP39 - word regrm with reg source */
PROC	op39
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[ebx + OPERAND.FLAGS],OMF_BYTE
	call	op40
	ret
ENDP	op39
;/* op 40 regrm with reg source */
PROC	op40
	mov	[dest2],ebx
	mov	[source2],edi
	call	RegRM
	ret
ENDP	op40
;/* op 41 reg, bitnum */
PROC	op41
	btr	[edi+OPERAND.FLAGS],OMF_BYTE
	call	ReadRM
	mov	ecx,eax
	mov	edi,ebx
	bts	[edi+OPERAND.FLAGS],OMF_BYTE
	push	esi
	add	esi,ecx
	add	esi,2
	call	Immediate
	pop	esi
	mov	eax,ecx
	ret
ENDP	op41
;/* op 42 mixed regrm with reg dest & strictness enforced */
PROC	op42
	mov	[dest2],edi
	mov	[source2],ebx
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	btr	[ebx + OPERAND.FLAGS],OMF_OP32
	mov	[strict],FALSE
	call	RegRM
	ret
ENDP	op42
;/* op 43 CWDE
PROC	op43
	bt	[edi + OPERAND.FLAGS],OMF_OP32
	jnc	short op43nochng
	push	esi
	mov	esi,offset mnemonic + 1
	mov	eax,"wde"
	call	put3
	mov	[byte ptr esi],0
	pop	esi
	sub	eax,eax
op43nochng:
	ret
ENDP	op43

PROC	ReadOverrides      	
ro_lp:
	sub	eax,eax
	lods	[byte ptr gs:esi]
	cmp	al,64h
	jc	short testseg
	cmp	al,68h
	jnc	short testseg
	sub	al,64h
	mov	ebx,SG_FS
ro_found:
	mov	cl,al
	shl	ebx,cl
	or	[segs],ebx
	jmp	short ro_lp
testseg:
	push	eax
	and	al,0e7h
	cmp	al,026h
	pop	eax
	jnz	testrep
	mov	ebx,1
	shr	eax,3
	and	al,3
	jmp	ro_found
testrep:
	sub	al,0f2h
	cmp	al,2
	jnc	ro_done
	mov	ebx,SG_REPNZ
	jmp	short ro_found
ro_done:
	dec	esi
	ret
ENDP	ReadOverrides

PROC	DispatchOperands
	push	ebx
	mov	edi,offset mnemonic
	push	esi
	mov	esi,[ebx + OPCODE.MNEMONIC]
	call	strcpy
	pop	esi
	mov	[strict],TRUE
	movzx	eax,[ebx + OPCODE.OPERANDS]
	push	eax
	mov	edi,offset dest
	mov	ebx,offset source
	cmp	[byte ptr gs:esi],0fh
	jnz	short notwobyte
	or	[segs],SG_TWOBYTEOP
	inc	esi
notwobyte:
	mov	eax,offset extraoperand
	mov	[eax + OPERAND.CODE],0
	mov	[edi + OPERAND.CODE],0
	mov	[ebx + OPERAND.CODE],0
	mov	[edi + OPERAND.FLAGS],0
	mov	[ebx + OPERAND.FLAGS],0

	bt	[dword ptr gs:esi],0
	jc	notbyte
	bts	[edi + OPERAND.FLAGS],OMF_BYTE
	bts	[ebx + OPERAND.FLAGS],OMF_BYTE
notbyte:
	test	[segs],SG_ADRSIZ
	jnz	do_word1
	bts	[edi + OPERAND.FLAGS],OMF_ADR32
	bts	[ebx + OPERAND.FLAGS],OMF_ADR32
do_word1:
	test	[segs],SG_OPSIZ
	jnz	do_word2
	bts	[edi + OPERAND.FLAGS],OMF_OP32
	bts	[ebx + OPERAND.FLAGS],OMF_OP32

do_word2:	
	pop	eax
	or	eax,eax
	jz	nodispatch
	dec	al
	push	0
	call	TableDispatch
	dd	42
	dd	op1, op2, op3, op4, op5, op6, op7, op8, op9, op10
	dd	op11, op12, op13, op14, op15, op16, op17, op18, op19, op20
	dd	op21, op22, op23, op24, op25, op26, op27, op28, op29, op30
	dd	op31, op32, op33, op34, op35, op36, op37, op38, op39, op40
	dd	op41, op42, op43
	add	esi,eax
nodispatch:
	pop	ebx
	movzx	eax,[ebx + OPCODE.LENGTH]
	add	esi,eax
	ret
ENDP	DispatchOperands

PROC	DoStrict
	push	edi
	push	esi
	test	[strict],-1
	jz	short floatstrict
	bt	[edi + OPERAND.FLAGS],OMF_BYTE
	jnc	chkdwptr
	mov	edi,esi
	mov	esi,offset byptr
	jmp	short strictend
chkdwptr:
	bt	[edi + OPERAND.FLAGS],OMF_OP32
	mov	edi,esi
	jnc	mkwordptr
	mov	esi,offset dwptr
	jmp	short strictend
mkwordptr:
	mov	esi,offset woptr
  	jmp	short strictend
floatstrict:
	bt	[edi + OPERAND.FLAGS],OMF_FSTTAB
	jnc	strictdone
	movzx	eax,[edi + OPERAND.FLAGS]
	shr	eax,OM_FTAB
	and	eax,7
	mov	edi,esi
	push	edi
	mov	esi,offset sts
	mov	esi,[esi + eax * 4]
	call	strcat
	mov	esi,offset theptr
	pop	edi
strictend:
	call	strcat
strictdone:
	pop	esi
	call	strlen
	add	esi,eax
	pop	edi
	ret
ENDP	DoStrict

PROC	TabTo
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
	mov	[byte ptr esi],' '
	inc	esi
	loop	tabtlp
tt_done:
	mov	[byte ptr esi],0
	ret
ENDP	TabTo

proc GetST near
		mov	al,[edi + OPERAND.THEREG]
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
		mov	[word esi],')'
		inc	esi
		ret
endp		;---------------------------------------------------------------

PROC	GetStdReg
	push	edi
	or	al,al
	jnz	short gsrnoe
	mov	[byte esi],'e'
	inc	esi
gsrnoe:
	mov	edi,offset regs
	mov	ax,[edi + ecx *2]
	mov	[esi],al
	inc	esi
	mov	[esi],ah
	inc	esi
	mov	[byte ptr esi],0
	pop	edi
	ret
ENDP	GetStdReg

proc GetReg near
		movzx	ecx,al
		sub	al,al
		inc	al
		bt	[edi + OPERAND.FLAGS],OMF_BYTE
		jc	short grno32
		bt	[edi + OPERAND.FLAGS],OMF_OP32
		jnc	short grno32
		dec	al
grno32:
		bt	[edi + OPERAND.FLAGS],OMF_BYTE
		jc	short isbyte
		or	cl,8
isbyte:
		call	GetStdReg
		ret
endp		;---------------------------------------------------------------

proc GetSpecial near
		mov	al,[ebx]
		mov	[esi],al
		inc	esi
		inc	ebx
		mov	al,[ebx]
		mov	[esi],al
		inc	esi
		inc	ebx
		movzx	eax,[edi + OPERAND.THEREG]
		mov	al,[ebx +eax]
		mov	[esi],al
		inc	esi
		mov	[byte ptr esi],0
		ret
endp		;---------------------------------------------------------------

PROC	GetSeg
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
	mov	[byte ptr esi],0
	pop	edi
	ret
ENDP	GetSeg
PROC	SegOverride
	mov	al,1
	sub	ecx,ecx
	test	[segs],SG_ES
	jz	short so_testcs
	call	GetSeg
so_testcs:
	inc	ecx
	test	[segs],SG_CS
	jz	short so_testss
	call	GetSeg
so_testss:
	inc	ecx
	test	[segs],SG_SS
	jz	short so_testds
	call	GetSeg
so_testds:
	inc	ecx
	test	[segs],SG_DS
	jz	short so_testfs
	call	GetSeg
so_testfs:
	inc	ecx
	test	[segs],SG_FS
	jz	short so_testgs
	call	GetSeg
so_testgs:
	inc	ecx
	test	[segs],SG_GS
	jz	short so_done
	call	GetSeg
so_done:
	mov	[segs],0
	ret
ENDP	SegOverride
PROC	Scaled
	push	[dword ptr edi + OPERAND.FLAGS]
	btr	[edi + OPERAND.FLAGS],OMF_BYTE
	bts	[edi + OPERAND.FLAGS],OMF_OP32
	or	al,al
	jz	short notbased
	sub	al,al
	mov	al,[edi + OPERAND.THEREG]
	call	GetReg
notbased:
	bt	[edi + OPERAND.FLAGS],OMF_SCALED
	jnc	short notscaled2
	movzx	ecx,[edi + OPERAND.SCALE]
	mov	eax,ecx
	add	ecx,ecx
	add	ecx,eax
	add	ecx,offset scales
	mov	eax,[ecx]
	call	put3
	or	al,1
	mov	al,[edi + OPERAND.SCALEREG]
	call	GetReg
notscaled2:
	pop	[dword ptr edi + OPERAND.FLAGS]
	ret
ENDP	Scaled

proc FOM_FSTREG near
		mov	edi,esi
		mov	esi,offset stalone
		call	strcat
		ret
endp		;---------------------------------------------------------------

PROC	FOM_CRX
	mov	ebx,offset crreg
	call	GetSpecial
	ret
ENDP	FOM_CRX
PROC	FOM_DRX
	mov	ebx,offset drreg
	call	GetSpecial
	ret
ENDP	FOM_DRX
PROC	FOM_TRX
	mov	ebx,offset trreg
	call	GetSpecial
	ret
ENDP	FOM_TRX
PROC	FOM_SUD
	mov	ebx,offset sudreg
	call	GetSpecial
	ret
ENDP	FOM_SUD
PROC	FOM_PORT
	mov	al,SY_PORT
format:
	call	FormatValue
	ret
ENDP	FOM_PORT
PROC	FOM_INT
	mov	al,SY_INTR
	jmp	short format
ENDP	FOM_INT
PROC	FOM_SHIFT
	bt	[edi + OPERAND.FLAGS],OMF_CL
	jnc	fos_notcl
	mov	ax,"cl"
	call	put2
	ret
fos_notcl:
	cmp	[edi + OPERAND.ADDRESS],1
	mov	al,SY_SHIFT
	jnz	format
	mov	[byte ptr esi],'1'
	inc	esi
	mov	[byte ptr esi],0
	ret
ENDP	FOM_SHIFT
PROC	FOM_RETURN
	mov	al,SY_RETURN
	jmp	format
ENDP	FOM_RETURN
PROC	FOM_SHORTBRANCH
	mov	al,SY_SHORTBRANCH
	jmp	format
ENDP	FOM_SHORTBRANCH
PROC	FOM_LONGBRANCH
	mov	al,SY_LONGBRANCH
	jmp	format
ENDP	FOM_LONGBRANCH
PROC	FOM_FARBRANCH
	mov	al,SY_SEGMENT
	call	format
	mov	[byte ptr esi],':'
	inc	esi
	mov	al,SY_ABSBRANCH
	call	format
	ret
ENDP	FOM_FARBRANCH
PROC	FOM_ABSOLUTE
	call	DoStrict
	call	SegOverride
	mov	[byte ptr esi],'['
	inc	esi
	mov	[byte ptr esi],0
	bt	[edi + OPERAND.FLAGS],OMF_SCALED
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
	mov	[byte ptr esi],']'
	inc	esi
	mov	[byte ptr esi],0
	ret
ENDP	FOM_ABSOLUTE
PROC	FOM_IMMEDIATE
	bt	[edi + OPERAND.FLAGS],OMF_BYTE
	mov	al,SY_WORDIMM
	jnc	short absformat
	mov	al,SY_SIGNEDIMM
	bt	[edi + OPERAND.FLAGS],SY_SIGNEDIMM
	jc	short absformat
	mov	al,SY_SIGNEDIMM
absformat:
	jmp	format
ENDP	FOM_IMMEDIATE

proc FOM_REG near
		bt	[edi + OPERAND.FLAGS],OMF_FST
		jnc	short @@FOreg
		call	GetST
		ret
@@FOreg:	mov	al,[edi + OPERAND.THEREG]
		call	GetReg
		ret
endp		;---------------------------------------------------------------

PROC	FOM_BASED
	call	DoStrict
	call	SegOverride
	mov	[byte ptr esi],'['
	inc	esi
	mov	[byte ptr esi],0
	bt	[edi + OPERAND.FLAGS],OMF_ADR32
	jnc	fob_notscaled
	mov	al,1
	call	Scaled
	jmp	short fob2
fob_notscaled:
	push	edi
	push	esi
	movzx	eax,[byte ptr edi + OPERAND.THEREG]
	xchg	esi,edi
	mov	esi,offset based
	mov	esi,[esi + eax * 4]
	call	strcpy
	pop	esi
	pop	edi
	call	strlen
	add	esi,eax
fob2:
	test	[edi + OPERAND.FLAGS],OMF_OFFSET
	jz	short fob_noofs
	bt	[edi + OPERAND.FLAGS],OMF_SIGNED_OFFSET
	mov	al,SY_SIGNEDOFS
	jc	fob_format
	mov	al,SY_WORDOFS
	bt	[edi + OPERAND.FLAGS],OMF_WORD_OFFSET
	jc	fob_format
	mov	al,SY_BYTEOFS
fob_format:
	call	FormatValue
fob_noofs:
	mov	[byte ptr esi],']'
	inc	esi
	mov	[byte ptr esi],0
	ret
ENDP	FOM_BASED
PROC	FOM_SEGMENT
	movzx	ecx,[edi + OPERAND.THEREG]
	sub	eax,eax
	call	GetSeg
	ret
ENDP	FOM_SEGMENT

PROC	PutOperand
	call	strlen
	add	esi,eax
	mov	al,[edi + OPERAND.CODE]
	dec	al
	js	short po_none
	push	0
	call	TableDispatch
	dd	17
	dd	FOM_BASED
	dd	FOM_SEGMENT
	dd	FOM_REG
	dd	FOM_IMMEDIATE
	dd	FOM_ABSOLUTE
	dd	FOM_FARBRANCH
	dd	FOM_LONGBRANCH
	dd	FOM_SHORTBRANCH
	dd	FOM_RETURN
	dd	FOM_SHIFT
	dd	FOM_INT
	dd	FOM_PORT
	dd	FOM_SUD
	dd	0
	dd	FOM_TRX
	dd	FOM_DRX
	dd	FOM_CRX
	dd	FOM_FSTREG
po_none:
	ret
ENDP	PutOperand

PROC	FormatDisassembly
	ENTER	256,0
	push	esi
	lea	edi,[ebp-256]
	mov	[byte ptr edi],0
	test	[segs],SG_REPZ
	push	edi
	jz	fd_notrepz
	mov	esi,offset st_repz
	call	strcpy
fd_notrepz:
	test	[segs],SG_REPNZ
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
	test	[edi + OPERAND.CODE],-1
	jz	short nosource
	mov	[byte ptr esi],','
	inc	esi
	mov	[byte ptr esi],0
	call	PutOperand
nosource:
	mov	edi,offset extraoperand
	test	[edi + OPERAND.CODE],-1
	jz	short noextra
	mov	[byte ptr esi],','
	inc	esi
	mov	[byte ptr esi],0
	call	PutOperand
noextra:
	pop	esi	
	mov	[byte ptr esi],0
	call	SegOverride
	mov	edi,esi
	lea	esi,[ebp-256]
	call	strcat
	LEAVE
	ret
ENDP	FormatDisassembly

putdword:
	push	eax		; To print a dword
	shr	eax,16		; Print the high 16 bits
	call	putword
	pop	eax		; And the low 16 bits
putword:
	push	eax		; To print a word
	mov	al,ah		; Print the high byte
	call	putbyte
	pop	eax		; And the low byte
putbyte:
	push	eax		; To print a byte
	shr	eax,4		; Print the high nibble
	call	putnibble
	pop	eax		; And the low nibble
putnibble:
	and	al,0fh		; Get a nibble
	add	al,'0'		; Make it numeric
	cmp	al,'9'		; If supposed to be alphabetic
	jle	onib
	add	al,7		; Add 7
onib:
	mov	[esi],al
	inc	esi
	retn

PROC	ABSX
	bt	eax,31
	jnc	noabs
	neg	eax
noabs:
	ret
ENDP	ABSX
PROC	FSY_SIGNEDOFS
	bt	[edi + OPERAND.ADDRESS],31
	mov	eax,"+os_"
	jnc	fso_pos
	mov	eax,"-os_"
fso_pos:
	call	put4
	mov	eax,[edi + OPERAND.ADDRESS]
	call	ABSX
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_SIGNEDOFS
PROC	FSY_WORDOFS
	mov	eax,"+ow_"
	call	put4
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putdword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_WORDOFS
PROC	FSY_BYTEOFS
	mov	eax,"+ob_"
	call	put4
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_BYTEOFS
PROC	FSY_ABSOLUTE
	mov	eax,"ab_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putdword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_ABSOLUTE
PROC	FSY_SIGNEDIMM
	bt	[edi + OPERAND.ADDRESS],31
	mov	eax,"+is_"
	jnc	fsi_pos
	mov	eax,"-is_"
fsi_pos:
	call	put4
	mov	eax,[edi + OPERAND.ADDRESS]
	call	ABSX
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_SIGNEDIMM
PROC	FSY_WORDIMM
	mov	eax,"iw_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putdword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_WORDIMM
PROC	FSY_BYTEIMM
	mov	eax,"ib_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_BYTEIMM
PROC	FSY_PORT
	mov	eax,"p_"
	call	put2
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_PORT
PROC	FSY_INTR
	mov	eax,"it_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_INTR
PROC	FSY_RETURN
	mov	eax,"rt_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_RETURN
PROC	FSY_ABSBRANCH
	mov	eax,"ba_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putdword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_ABSBRANCH
PROC	FSY_LONGBRANCH
	mov	eax,"bl_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putdword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_LONGBRANCH
PROC	FSY_SHORTBRANCH
	mov	eax,"bs_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putdword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_SHORTBRANCH
PROC	FSY_SHIFT
	mov	eax,"ib_"
	call	put3
	mov	eax,[edi + OPERAND.ADDRESS]
	call	putbyte
	mov	[byte ptr esi],0
	ret
ENDP	FSY_SHIFT
PROC	FSY_SEGMENT
	mov	eax,"sg_"
	call	put3
	mov	ax,[edi + OPERAND.SEG]
	call	putword
	mov	[byte ptr esi],0
	ret
ENDP	FSY_SEGMENT
PROC  	FormatValue
	dec	al
	push	0
	call	TableDispatch
	dd	14
	dd	FSY_SIGNEDOFS,FSY_WORDOFS,FSY_BYTEOFS,FSY_ABSOLUTE
	dd	FSY_SIGNEDIMM,FSY_WORDIMM,FSY_BYTEIMM,FSY_PORT
	dd	FSY_INTR,FSY_RETURN,FSY_ABSBRANCH,FSY_LONGBRANCH
	dd	FSY_SHORTBRANCH,FSY_SHIFT,FSY_SEGMENT
	ret
ENDP	FormatValue

ENDS
END