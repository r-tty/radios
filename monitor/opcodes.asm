;-------------------------------------------------------------------------------
;  opcodes.asm - Locate the opcode table entry for a given opcode byte
;-------------------------------------------------------------------------------

; Definitions
OP_CODEONLY		EQU	0
OP_WREG02		EQU	1
OP_ACCREG02		EQU	2
OP_SEG35		EQU	3
OP_REGRMREG		EQU	4
OP_RM			EQU	5
OP_RMSHIFT		EQU	6
OP_REGRM		EQU	7
OP_WORDREGRM		EQU	8
OP_INTR			EQU	9
OP_SHORTBRANCH		EQU	10
OP_RMIMM		EQU	11
OP_ACCIMM		EQU	12
OP_ABSACC		EQU	13
OP_RMIMMSIGNED		EQU	14
OP_ACCIMMB3		EQU	15
OP_SEGRMSEG		EQU	16
OP_RET			EQU	17
OP_SEGBRANCH		EQU	18
OP_ESC			EQU	19
OP_BRANCH		EQU	20
OP_ACCDX		EQU	21
OP_DXACC		EQU	22
OP_PORTACCPORT		EQU	23
OP_ACCABS		EQU	24
OP_IMM			EQU	25
OP_ENTER		EQU	26
OP_INSWORDSIZE		EQU	27
OP_REGMOD		EQU	28
OP_MODIMM		EQU	29
OP_RMSHIFTB3		EQU	30
OP_IMUL			EQU	31
OP_386REG		EQU	32
OP_REGRMSHIFT		EQU	33
OP_NOSTRICTRM		EQU	34
OP_FLOATRM		EQU	35
OP_SIZEFLOATRM		EQU	36
OP_FLOATMATH		EQU	37
OP_FLOATNOPTR		EQU	OP_NOSTRICTRM
OP_FARRM		EQU	38
OP_WORDRMREG		EQU	39
OP_RMREG		EQU	40
OP_BITNUM		EQU	41
OP_MIXEDREGRM		EQU	42
OP_CBW			EQU	43

struc OPCODE
 MSK		DW	?
 COMPARE	DW	?
 MNEMONIC	DD	?
 OPERANDS	DB	?
 LENGTH		DB	?
ends

OPCODESIZE		EQU	10


segment KDATA
; This is a table of mnemonics for the dissassembler
opn_add		DB	"add",0
opn_push	DB	"push",0
opn_pop		DB	"pop",0
opn_or		DB	"or",0
opn_adc		DB	"adc",0
opn_sbb		DB	"sbb",0
opn_and		DB	"and",0
opn_daa		DB	"daa",0
opn_sub		DB	"sub",0
opn_das		DB	"das",0
opn_xor		DB	"xor",0
opn_aaa		DB	"aaa",0
opn_cmp		DB	"cmp",0
opn_aas		DB	"aas",0
opn_inc		DB	"inc",0
opn_dec		DB	"dec",0
opn_pusha	DB	"pusha",0
opn_popa	DB	"popa",0
opn_bound	DB	"bound",0
opn_arpl	DB	"arpl",0
opn_imul	DB	"imul",0
opn_insb	DB	"insb",0
opn_ins		DB	"ins",0
opn_outsb	DB	"outsb",0
opn_outs	DB	"outs",0
opn_jo		DB	"jo",0
opn_jno		DB	"jno",0
opn_jb		DB	"jb",0
opn_jnb		DB	"jnb",0
opn_jz		DB	"jz",0
opn_jnz		DB	"jnz",0
opn_jbe		DB	"jbe",0
opn_ja		DB	"ja",0
opn_js		DB	"js",0
opn_jns		DB	"jns",0
opn_jp		DB	"jp",0
opn_jnp		DB	"jnp",0
opn_jl		DB	"jl",0
opn_jge		DB	"jge",0
opn_jle		DB	"jle",0
opn_jg		DB	"jg",0
opn_test	DB	"test",0
opn_xchg	DB	"xchg",0
opn_mov		DB	"mov",0
opn_lea		DB	"lea",0
opn_nop		DB	"nop",0
opn_cbw		DB	"cbw",0
opn_cwd		DB	"cwd",0
opn_call	DB	"call",0
opn_wait	DB	"wait",0
opn_pushf	DB	"pushf",0
opn_popf	DB	"popf",0
opn_sahf	DB	"sahf",0
opn_lahf	DB	"lahf",0
opn_movs	DB	"movs",0
opn_cmps	DB	"cmps",0
opn_stos	DB	"stos",0
opn_lods	DB	"lods",0
opn_scas	DB	"scas",0
opn_movsb	DB	"movsb",0
opn_cmpsb	DB	"cmpsb",0
opn_stosb	DB	"stosb",0
opn_lodsb	DB	"lodsb",0
opn_scasb	DB	"scasb",0
opn_rol		DB	"rol",0
opn_ror		DB	"ror",0
opn_rcl		DB	"rcl",0
opn_rcr		DB	"rcr",0
opn_shl		DB	"shl",0
opn_shr		DB	"shr",0
opn_sar		DB	"sar",0
opn_ret		DB	"ret",0
opn_les		DB	"les",0
opn_lds		DB	"lds",0
opn_enter	DB	"enter",0
opn_retf	DB	"retf",0
opn_int		DB	"int",0
opn_into	DB	"into",0
opn_iret	DB	"iret",0
opn_leave	DB	"leave",0
opn_aam		DB	"aam",0
opn_aad		DB	"aad",0
opn_xlat	DB	"xlat",0
opn_loopnz	DB	"loopnz",0
opn_loopz	DB	"loopz",0
opn_loop	DB	"loop",0
opn_jcxz	DB	"jcxz",0
opn_in		DB	"in",0
opn_out		DB	"out",0
opn_jmp		DB	"jmp",0
opn_lock	DB	"lock",0
opn_repnz	DB	"repnz",0
opn_repz	DB	"repz",0
opn_hlt		DB	"hlt",0
opn_cmc		DB	"cmc",0
opn_not		DB	"not",0
opn_neg		DB	"neg",0
opn_mul		DB	"mul",0
opn_div		DB	"div",0
opn_idiv	DB	"idiv",0
opn_clc		DB	"clc",0
opn_stc		DB	"stc",0
opn_cli		DB	"cli",0
opn_sti		DB	"sti",0
opn_cld		DB	"cld",0
opn_std		DB	"std",0
opn_movsx	DB	"movsx",0
opn_movzx	DB	"movzx",0
opn_lfs		DB	"lfs",0
opn_lgs		DB	"lgs",0
opn_lss		DB	"lss",0
opn_clts	DB	"clts",0
opn_shld	DB	"shld",0
opn_shrd	DB	"shrd",0
opn_bsf		DB	"bsf",0
opn_bsr		DB	"bsr",0
opn_bt		DB	"bt",0
opn_bts		DB	"bts",0
opn_btr		DB	"btr",0
opn_btc		DB	"btc",0
opn_ibts	DB	"ibts",0
opn_xbts	DB	"xbts",0
opn_seto	DB	"seto",0
opn_setno	DB	"setno",0
opn_setb	DB	"setb",0
opn_setnb	DB	"setnb",0
opn_setz	DB	"setz",0
opn_setnz	DB	"setnz",0
opn_setbe	DB	"setbe",0
opn_seta	DB	"seta",0
opn_sets	DB	"sets",0
opn_setns	DB	"setns",0
opn_setp	DB	"setp",0
opn_setnp	DB	"setnp",0
opn_setl	DB	"setl",0
opn_setge	DB	"setge",0
opn_setle	DB	"setle",0
opn_setg	DB	"setg",0
opn_lar		DB	"lar",0
opn_lsl		DB	"lsl",0
opn_lgdt	DB	"lgdt",0
opn_lidt	DB	"lidt",0
opn_lldt	DB	"lldt",0
opn_lmsw	DB	"lmsw",0
opn_ltr		DB	"ltr",0
opn_sgdt	DB	"sgdt",0
opn_sidt	DB	"sidt",0
opn_sldt	DB	"sldt",0
opn_smsw	DB	"smsw",0
opn_str		DB	"str",0
opn_verr	DB	"verr",0
opn_verw	DB	"verw",0
opn_fnop	DB	"fnop",0
opn_fchs	DB	"fchs",0
opn_fabs	DB	"fabs",0
opn_ftst	DB	"ftst",0
opn_fxam	DB	"fxam",0
opn_fld1	DB	"fld1",0
opn_fldl2t	DB	"fldl2t",0
opn_fldl2e	DB	"fldl2e",0
opn_fldpi	DB	"fldpi",0
opn_fldlg2	DB	"fldlg2",0
opn_fldln2	DB	"fldln2",0
opn_fldz	DB	"fldz",0
opn_f2xm1	DB	"f2xm1",0
opn_fyl2x	DB	"fyl2x",0
opn_fptan	DB	"fptan",0
opn_fpatan	DB	"fpatan",0
opn_fprem1	DB	"fprem1",0
opn_fxtract	DB	"fxtract",0
opn_fdecstp	DB	"fdecstp",0
opn_fincstp	DB	"fincstp",0
opn_fprem	DB	"fprem",0
opn_fyl2xp1	DB	"fyl2xp1",0
opn_fsqrt	DB	"fsqrt",0
opn_fsincos	DB	"fsincos",0
opn_frndint	DB	"frndint",0
opn_fscale	DB	"fscale",0
opn_fsin	DB	"fsin",0
opn_fcos	DB	"fcos",0
opn_fucompp	DB	"fucompp",0
opn_feni	DB	"feni",0
opn_fdisi	DB	"fdisi",0
opn_fclex	DB	"fclex",0
opn_finit	DB	"finit",0
opn_fsetpm	DB	"fsetpm",0
opn_fcompp	DB	"fcompp",0
opn_fld		DB	"fld",0
opn_fxch	DB	"fxch",0
opn_fstp	DB	"fstp",0
opn_esc		DB	"esc",0
opn_fldenv	DB	"fldenv",0
opn_fldcw	DB	"fldcw",0
opn_fstenv	DB	"fstenv",0
opn_fstcw	DB	"fstcw",0
opn_ffree	DB	"ffree",0
opn_fst		DB	"fst",0
opn_fucom	DB	"fucom",0
opn_fucomp	DB	"fucomp",0
opn_frstor	DB	"frstor",0
opn_fsave	DB	"fsave",0
opn_fstsw	DB	"fstsw",0
opn_fbld	DB	"fbld",0
opn_fild	DB	"fild",0
opn_fbstp	DB	"fbstp",0
opn_fistp	DB	"fistp",0
opn_fmul	DB	"fmul",0
opn_fcom	DB	"fcom",0
opn_fsub	DB	"fsub",0
opn_fdiv	DB	"fdiv",0
opn_fadd	DB	"fadd",0
opn_fcomp	DB	"fcomp",0
opn_fiadd	DB	"fiadd",0
opn_fimul	DB	"fimul",0
opn_ficom	DB	"ficom",0
opn_ficomp	DB	"ficomp",0
opn_fisub	DB	"fisub",0
opn_fidiv	DB	"fidiv",0
opn_fist	DB	"fist",0

; Table of opcodes.  Each entry consists of a mask value,
; a comparison value, a pointer to the name, the addressing mode to be
; used in dissassembly, and the base length of the instruction (possibly
; modified by the exact addressing mode encountered)
;
base0		DW	0FCh
		DW	00h
		DD	opn_add
		DB	 OP_REGRMREG
		DB	2

		DW	0E7h
		DW	06h
		DD	opn_push
		DB	 OP_SEG35
		DB	1

		DW	0FEh
		DW	04h
		DD	opn_add
		DB	 OP_ACCIMM
		DB	1

		DW	0E7h
		DW	07h
		DD	opn_pop
		DB	 OP_SEG35
		DB	1

		DW	0FCh
		DW	08h
		DD	opn_or
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	0Ch
		DD	opn_or
		DB	 OP_ACCIMM
		DB	1

		DW	0FCh
		DW	010h
		DD	opn_adc
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	014h
		DD	opn_adc
		DB	 OP_ACCIMM
		DB	1

		DW	0FCh
		DW	018h
		DD	opn_sbb
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	01Ch
		DD	opn_sbb
		DB	 OP_ACCIMM
		DB	1

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base1		DW	0FCh
		DW	020h
		DD	opn_and
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	024h
		DD	opn_and
		DB	 OP_ACCIMM
		DB	1

		DW	0FFh
		DW	027h
		DD	opn_daa
		DB	 OP_CODEONLY
		DB	1

		DW	0FCh
		DW	028h
		DD	opn_sub
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	02ch
		DD	opn_sub
		DB	 OP_ACCIMM
		DB	1

		DW	0FFh
		DW	02Fh
		DD	opn_das
		DB	 OP_CODEONLY
		DB	1

		DW	0FCh
		DW	030h
		DD	opn_xor
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	034h
		DD	opn_xor
		DB	 OP_ACCIMM
		DB	1

		DW	0FFh
		DW	037h
		DD	opn_aaa
		DB	 OP_CODEONLY
		DB	1

		DW	0FCh
		DW	038h
		DD	opn_cmp
		DB	 OP_REGRMREG
		DB	2

		DW	0FEh
		DW	03Ch
		DD	opn_cmp
		DB	 OP_ACCIMM
		DB	1

		DW	0FFh
		DW	03Fh
		DD	opn_aas
		DB	 OP_CODEONLY
		DB	1

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base2		DW	0f8h
		DW	040h
		DD	opn_inc
		DB	 OP_WREG02
		DB	1

		DW	0f8h
		DW	048h
		DD	opn_dec
		DB	 OP_WREG02
		DB	1

		DW	0f8h
		DW	050h
		DD	opn_push
		DB	 OP_WREG02
		DB	1

		DW	0f8h
		DW	058h
		DD	opn_pop
		DB	 OP_WREG02
		DB	1

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base3		DW	0ffh
		DW	060h
		DD	opn_pusha
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	061h
		DD	opn_popa
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	062h
		DD	opn_bound
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	063h
		DD	opn_arpl
		DB	 OP_WORDRMREG
		DB	2

		DW	0fdh
		DW	068h
		DD	opn_push
		DB	 OP_IMM
		DB	1

		DW	0fdh
		DW	069h
		DD	opn_imul
		DB	 OP_IMUL
		DB	2

		DW	0ffh
		DW	06ch
		DD	opn_insb
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	06dh
		DD	opn_ins
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	06eh
		DD	opn_outsb
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	06fh
		DD	opn_outs
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	070h
		DD	opn_jo
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	071h
		DD	opn_jno
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	072h
		DD	opn_jb
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	073h
		DD	opn_jnb
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	074h
		DD	opn_jz
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	075h
		DD	opn_jnz
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	076h
		DD	opn_jbe
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	077h
		DD	opn_ja
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	078h
		DD	opn_js
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	079h
		DD	opn_jns
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	07ah
		DD	opn_jp
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	07bh
		DD	opn_jnp
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	07ch
		DD	opn_jl
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	07dh
		DD	opn_jge
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	07eh
		DD	opn_jle
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	07fh
		DD	opn_jg
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base4		DW	038fch
		DW	080h
		DD	opn_add
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038feh
		DW	0880h
		DD	opn_or
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	0880h
		DD	opn_or
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	01080h
		DD	opn_adc
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	01880h
		DD	opn_sbb
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038feh
		DW	02080h
		DD	opn_and
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	02080h
		DD	opn_and
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	02880h
		DD	opn_sub
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038feh
		DW	03080h
		DD	opn_xor
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	03080h
		DD	opn_xor
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	038fch
		DW	03880h
		DD	opn_cmp
		DB	 OP_RMIMMSIGNED
		DB	2

		DW	0feh
		DW	084h
		DD	opn_test
		DB	 OP_REGRM
		DB	2

		DW	0feh
		DW	086h
		DD	opn_xchg
		DB	 OP_REGRM
		DB	2

		DW	0fch
		DW	088h
		DD	opn_mov
		DB	 OP_REGRMREG
		DB	2

		DW	020fdh
		DW	08ch
		DD	opn_mov
		DB	 OP_SEGRMSEG
		DB	2

		DW	0fdh
		DW	08ch
		DD	opn_mov
		DB	 OP_SEGRMSEG
		DB	2

		DW	0ffh
		DW	08dh
		DD	opn_lea
		DB	 OP_WORDREGRM
		DB	2

		DW	038ffh
		DW	08fh
		DD	opn_pop
		DB	 OP_NOSTRICTRM
		DB	2

		DW	0ffh
		DW	090h
		DD	opn_nop
		DB	 OP_CODEONLY
		DB	1

		DW	0f8h
		DW	090h
		DD	opn_xchg
		DB	 OP_ACCREG02
		DB	1

		DW	0ffh
		DW	098h
		DD	opn_cbw
		DB	 OP_CBW
		DB	1

		DW	0ffh
		DW	099h
		DD	opn_cwd
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	09ah
		DD	opn_call
		DB	 OP_SEGBRANCH
		DB	5

		DW	0ffh
		DW	09bh
		DD	opn_wait
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	09ch
		DD	opn_pushf
		DB	 OP_INSWORDSIZE
		DB	1

		DW	0ffh
		DW	09dh
		DD	opn_popf
		DB	 OP_INSWORDSIZE
		DB	1

		DW	0ffh
		DW	09eh
		DD	opn_sahf
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	09fh
		DD	opn_lahf
		DB	 OP_CODEONLY
		DB	1

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base5		DW	0feh
		DW	0a0h
		DD	opn_mov
		DB	 OP_ACCABS
		DB	3

		DW	0feh
		DW	0a2h
		DD	opn_mov
		DB	 OP_ABSACC
		DB	3

		DW	0ffh
		DW	0a5h
		DD	opn_movs
		DB	 OP_INSWORDSIZE
		DB	1

		DW	0ffh
		DW	0a7h
		DD	opn_cmps
		DB	 OP_INSWORDSIZE
		DB	1
	
		DW	0feh
		DW	0a8h
		DD	opn_test
		DB	 OP_ACCIMM
		DB	1

		DW	0ffh
		DW	0abh
		DD	opn_stos
		DB	 OP_INSWORDSIZE
		DB	1

		DW	0ffh
		DW	0adh
		DD	opn_lods
		DB	 OP_INSWORDSIZE
		DB	1

		DW	0ffh
		DW	0afh
		DD	opn_scas
		DB	 OP_INSWORDSIZE
		DB	1

		DW	0ffh
		DW	0a4h
		DD	opn_movsb
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0a6h
		DD	opn_cmpsb
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0aah
		DD	opn_stosb
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0ach
		DD	opn_lodsb
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0aeh
		DD	opn_scasb
		DB	 OP_CODEONLY
		DB	1

		DW	0f0h
		DW	0b0h
		DD	opn_mov
		DB	 OP_ACCIMMB3
		DB	1

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base6		DW	038feh
		DW	0c0h
		DD	opn_rol
		DB	 OP_RMSHIFT
		DB	2

		DW	038feh
		DW	08c0h
		DD	opn_ror
		DB	 OP_RMSHIFT
		DB	2

		DW	038feh
		DW	010c0h
		DD	opn_rcl
		DB	 OP_RMSHIFT
		DB	2

		DW	038feh
		DW	018c0h
		DD	opn_rcr
		DB	 OP_RMSHIFT
		DB	2

		DW	038feh
		DW	020c0h
		DD	opn_shl
		DB	 OP_RMSHIFT
		DB	2

		DW	038feh
		DW	028c0h
		DD	opn_shr
		DB	 OP_RMSHIFT
		DB	2

		DW	038feh
		DW	038c0h
		DD	opn_sar
		DB	 OP_RMSHIFT
		DB	2

		DW	0ffh
		DW	0c2h
		DD	opn_ret
		DB	 OP_RET
		DB	3

		DW	0ffh
		DW	0c3h
		DD	opn_ret
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0c4h
		DD	opn_les
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	0c5h
		DD	opn_lds
		DB	 OP_WORDREGRM
		DB	2

		DW	038feh
		DW	0c6h
		DD	opn_mov
		DB	 OP_RMIMM
		DB	2

		DW	0ffh
		DW	0c8h
		DD	opn_enter
		DB	 OP_ENTER
		DB	4

		DW	0ffh
		DW	0cah
		DD	opn_retf
		DB	 OP_RET
		DB	3

		DW	0ffh
		DW	0cbh
		DD	opn_retf
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0cch
		DD	opn_int
		DB	 OP_INTR
		DB	1

		DW	0ffh
		DW	0cdh
		DD	opn_int
		DB	 OP_INTR
		DB	2

		DW	0ffh
		DW	0ceh
		DD	opn_into
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0cfh
		DD	opn_iret
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0c9h
		DD	opn_leave
		DB	 OP_CODEONLY
		DB	1

		DW	038fch
		DW	0d0h
		DD	opn_rol
		DB	 OP_RMSHIFT
		DB	2

		DW	038fch
		DW	08d0h
		DD	opn_ror
		DB	 OP_RMSHIFT
		DB	2

		DW	038fch
		DW	010d0h
		DD	opn_rcl
		DB	 OP_RMSHIFT
		DB	2

		DW	038fch
		DW	018d0h
		DD	opn_rcr
		DB	 OP_RMSHIFT
		DB	2

		DW	038fch
		DW	020d0h
		DD	opn_shl
		DB	 OP_RMSHIFT
		DB	2

		DW	038fch
		DW	028d0h
		DD	opn_shr
		DB	 OP_RMSHIFT
		DB	2

		DW	038fch
		DW	038d0h
		DD	opn_sar
		DB	 OP_RMSHIFT
		DB	2

		DW	0ffffh
		DW	0ad4h
		DD	opn_aam
		DB	 OP_CODEONLY
		DB	2
	
		DW	0ffffh
		DW	0ad5h
		DD	opn_aad
		DB	 OP_CODEONLY
		DB	2

		DW	0ffh
		DW	0d7h
		DD	opn_xlat
		DB	 OP_CODEONLY
		DB	1

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base7		DW	0ffh
		DW	0e0h
		DD	opn_loopnz
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	0e1h
		DD	opn_loopz
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	0e2h
		DD	opn_loop
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0ffh
		DW	0e3h
		DD	opn_jcxz
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0feh
		DW	0e4h
		DD	opn_in
		DB	 OP_PORTACCPORT
		DB	2

		DW	0feh
		DW	0e6h
		DD	opn_out
		DB	 OP_PORTACCPORT
		DB	2

		DW	0ffh
		DW	0e8h
		DD	opn_call
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	0e9h
		DD	opn_jmp
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	0eah
		DD	opn_jmp
		DB	 OP_SEGBRANCH
		DB	5

		DW	0ffh
		DW	0ebh
		DD	opn_jmp
		DB	 OP_SHORTBRANCH
		DB	2

		DW	0feh
		DW	0ech
		DD	opn_in
		DB	 OP_ACCDX
		DB	1

		DW	0feh
		DW	0eeh
		DD	opn_out
		DB	 OP_DXACC
		DB	1

		DW	0ffh
		DW	0f0h
		DD	opn_lock
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0f2h
		DD	opn_repnz
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0f3h
		DD	opn_repz
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0f4h
		DD	opn_hlt
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0f5h
		DD	opn_cmc
		DB	 OP_CODEONLY
		DB	1

		DW	038feh
		DW	0f6h
		DD	opn_test
		DB	 OP_RMIMM
		DB	2

		DW	038feh
		DW	010f6h
		DD	opn_not
		DB	 OP_RM
		DB	2

		DW	038feh
		DW	018f6h
		DD	opn_neg
		DB	 OP_RM
		DB	2

		DW	038feh
		DW	020f6h
		DD	opn_mul
		DB	 OP_RM
		DB	2

		DW	038feh
		DW	028f6h
		DD	opn_imul
		DB	 OP_RM
		DB	2

		DW	038feh
		DW	030f6h
		DD	opn_div
		DB	 OP_RM
		DB	2

		DW	038feh
		DW	038f6h
		DD	opn_idiv
		DB	 OP_RM
		DB	2

		DW	0ffh
		DW	0f8h
		DD	opn_clc
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0f9h
		DD	opn_stc
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0fah
		DD	opn_cli
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0fbh
		DD	opn_sti
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0fch
		DD	opn_cld
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0fdh
		DD	opn_std
		DB	 OP_CODEONLY
		DB	1

		DW	038feh
		DW	0feh
		DD	opn_inc
		DB	 OP_RM
		DB	2

		DW	038feh
		DW	08feh
		DD	opn_dec
		DB	 OP_RM
		DB	2

		DW	038ffh
		DW	010ffh
		DD	opn_call
		DB	 OP_RM
		DB	2

		DW	038ffh
		DW	018ffh
		DD	opn_call
		DB	 OP_FARRM
		DB	2

		DW	038ffh
		DW	020ffh
		DD	opn_jmp
		DB	 OP_RM
		DB	2

		DW	038ffh
		DW	028ffh
		DD	opn_jmp
		DB	 OP_FARRM
		DB	2

		DW	038ffh
		DW	030ffh
		DD	opn_push
		DB	 OP_NOSTRICTRM
		DB	2

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

base386		DW	0feh
		DW	0beh
		DD	opn_movsx
		DB	 OP_MIXEDREGRM
		DB	2

		DW	0feh
		DW	0b6h
		DD	opn_movzx
		DB	 OP_MIXEDREGRM
		DB	2

		DW	0f7h
		DW	0a0h
		DD	opn_push
		DB	 OP_SEG35
		DB	1

		DW	0f7h
		DW	0a1h
		DD	opn_pop
		DB	 OP_SEG35
		DB	1

		DW	0ffh
		DW	0b4h
		DD	opn_lfs
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	0b5h
		DD	opn_lgs
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	0b2h
		DD	opn_lss
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	06h
		DD	opn_clts
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0afh
		DD	opn_imul
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	0a4h
		DD	opn_shld
		DB	 OP_REGRMSHIFT
		DB	3

		DW	0ffh
		DW	0a5h
		DD	opn_shld
		DB	 OP_REGRMSHIFT
		DB	2

		DW	0ffh
		DW	0ach
		DD	opn_shrd
		DB	 OP_REGRMSHIFT
		DB	3

		DW	0ffh
		DW	0adh
		DD	opn_shrd
		DB	 OP_REGRMSHIFT
		DB	2

		DW	0ffh
		DW	0bch
		DD	opn_bsf
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	0bdh
		DD	opn_bsr
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	0a3h
		DD	opn_bt
		DB	 OP_WORDRMREG
		DB	2

		DW	0ffh
		DW	0abh
		DD	opn_bts
		DB	 OP_WORDRMREG
		DB	2

		DW	0ffh
		DW	0b3h
		DD	opn_btr
		DB	 OP_WORDRMREG
		DB	2

		DW	0ffh
		DW	0bbh
		DD	opn_btc
		DB	 OP_WORDRMREG
		DB	2

		DW	038ffh
		DW	020bah
		DD	opn_bt
		DB	 OP_BITNUM
		DB	3

		DW	038ffh
		DW	028bah
		DD	opn_bts
		DB	 OP_BITNUM
		DB	3

		DW	038ffh
		DW	030bah
		DD	opn_btr
		DB	 OP_BITNUM
		DB	3

		DW	038ffh
		DW	038bah
		DD	opn_btc
		DB	 OP_BITNUM
		DB	3

		DW	0ffh
		DW	0a7h
		DD	opn_ibts
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	0a6h
		DD	opn_xbts
		DB	 OP_CODEONLY
		DB	1

		DW	0ffh
		DW	080h
		DD	opn_jo
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	081h
		DD	opn_jno
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	082h
		DD	opn_jb
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	083h
		DD	opn_jnb
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	084h
		DD	opn_jz
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	085h
		DD	opn_jnz
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	086h
		DD	opn_jbe
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	087h
		DD	opn_ja
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	088h
		DD	opn_js
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	089h
		DD	opn_jns
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	08ah
		DD	opn_jp
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	08bh
		DD	opn_jnp
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	08ch
		DD	opn_jl
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	08dh
		DD	opn_jge
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	08eh
		DD	opn_jle
		DB	 OP_BRANCH
		DB	3

		DW	0ffh
		DW	08fh
		DD	opn_jg
		DB	 OP_BRANCH
		DB	3

		DW	038ffh
		DW	090h
		DD	opn_seto
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	091h
		DD	opn_setno
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	092h
		DD	opn_setb
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	093h
		DD	opn_setnb
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	094h
		DD	opn_setz
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	095h
		DD	opn_setnz
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	096h
		DD	opn_setbe
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	097h
		DD	opn_seta
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	098h
		DD	opn_sets
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	099h
		DD	opn_setns
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	09ah
		DD	opn_setp
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	09bh
		DD	opn_setnp
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	09ch
		DD	opn_setl
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	09dh
		DD	opn_setge
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	09eh
		DD	opn_setle
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	09fh
		DD	opn_setg
		DB	 OP_NOSTRICTRM
		DB	2

		DW	0c0fdh
		DW	0c020h
		DD	opn_mov
		DB	 OP_386REG
		DB	2

		DW	0c0fdh
		DW	0c021h
		DD	opn_mov
		DB	 OP_386REG
		DB	2

		DW	0c0fdh
		DW	0c024h
		DD	opn_mov
		DB	 OP_386REG
		DB	2

		DW	0ffh
		DW	02h
		DD	opn_lar
		DB	 OP_WORDREGRM
		DB	2

		DW	0ffh
		DW	03h
		DD	opn_lsl
		DB	 OP_WORDREGRM
		DB	2

		DW	038ffh
		DW	01001h
		DD	opn_lgdt
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	01801h
		DD	opn_lidt
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	01000h
		DD	opn_lldt
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	03001h
		DD	opn_lmsw
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	01800h
		DD	opn_ltr
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	01h
		DD	opn_sgdt
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	0801h
		DD	opn_sidt
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	00h
		DD	opn_sldt
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	02001h
		DD	opn_smsw
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	0800h
		DD	opn_str
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	02000h
		DD	opn_verr
		DB	 OP_NOSTRICTRM
		DB	2

		DW	038ffh
		DW	02800h
		DD	opn_verw
		DB	 OP_NOSTRICTRM
		DB	2

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

;/* single byte commands */
floats		DW	0ffffh
		DW	0d0d9h
		DD	opn_fnop
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e0d9h
		DD	opn_fchs
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e1d9h
		DD	opn_fabs
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e4d9h
		DD	opn_ftst
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e5d9h
		DD	opn_fxam
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e8d9h
		DD	opn_fld1
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e9d9h
		DD	opn_fldl2t
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0ead9h
		DD	opn_fldl2e
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0ebd9h
		DD	opn_fldpi
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0ecd9h
		DD	opn_fldlg2
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0edd9h
		DD	opn_fldln2
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0eed9h
		DD	opn_fldz
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f0d9h
		DD	opn_f2xm1
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f1d9h
		DD	opn_fyl2x
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f2d9h
		DD	opn_fptan
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f3d9h
		DD	opn_fpatan
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f5d9h
		DD	opn_fprem1
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f4d9h
		DD	opn_fxtract
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f6d9h
		DD	opn_fdecstp
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f7d9h
		DD	opn_fincstp
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f8d9h
		DD	opn_fprem
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0f9d9h
		DD	opn_fyl2xp1
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0fad9h
		DD	opn_fsqrt
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0fbd9h
		DD	opn_fsincos
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0fcd9h
		DD	opn_frndint
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0fdd9h
		DD	opn_fscale
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0fed9h
		DD	opn_fsin
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0ffd9h
		DD	opn_fcos
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e9dah
		DD	opn_fucompp
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e0dbh
		DD	opn_feni
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e1dbh
		DD	opn_fdisi
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e2dbh
		DD	opn_fclex
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e3dbh
		DD	opn_finit
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0e4dbh
		DD	opn_fsetpm
		DB	 OP_CODEONLY
		DB	2

		DW	0ffffh
		DW	0d9deh
		DD	opn_fcompp
		DB	 OP_CODEONLY
		DB	2


;  /* Group 1, RM 3 */
		DW	0f8ffh
		DW	0c0d9h
		DD	opn_fld
		DB	 OP_FLOATRM
		DB	2

		DW	0f8ffh
		DW	0c8d9h
		DD	opn_fxch
		DB	 OP_FLOATRM
		DB	2

		DW	0f8fbh
		DW	0d8d9h
		DD	opn_fstp
		DB	 OP_FLOATRM
		DB	2

		DW	0c0ffh
		DW	0c0d9h
		DD	opn_esc
		DB	 OP_ESC
		DB	2


;  /* Group 1, RM0-2 */
		DW	038ffh
		DW	020d9h
		DD	opn_fldenv
		DB	 OP_FLOATNOPTR
		DB	2

		DW	038ffh
		DW	028d9h
		DD	opn_fldcw
		DB	 OP_FLOATNOPTR
		DB	2

		DW	038ffh
		DW	030d9h
		DD	opn_fstenv
		DB	 OP_FLOATNOPTR
		DB	2

		DW	038ffh
		DW	038d9h
		DD	opn_fstcw
		DB	 OP_FLOATNOPTR
		DB	2


;  /* Group 5, RM3 */
		DW	0f8ffh
		DW	0c0ddh
		DD	opn_ffree
		DB	 OP_FLOATRM
		DB	2

		DW	0f8ffh
		DW	0d0ddh
		DD	opn_fst
		DB	 OP_FLOATRM
		DB	2

		DW	0f8ffh
		DW	0e0ddh
		DD	opn_fucom
		DB	 OP_FLOATRM
		DB	2

		DW	0f8ffh
		DW	0e8ddh
		DD	opn_fucomp
		DB	 OP_FLOATRM
		DB	2


		DW	0c0ffh
		DW	0c0ddh
		DD	opn_esc
		DB	 OP_ESC
		DB	2


;  /* Group 5, RM0-2 */
		DW	038ffh
		DW	020ddh
		DD	opn_frstor
		DB	 OP_FLOATNOPTR
		DB	2

		DW	038ffh
		DW	030ddh
		DD	opn_fsave
		DB	 OP_FLOATNOPTR
		DB	2

		DW	038ffh
		DW	038ddh
		DD	opn_fstsw
		DB	 OP_FLOATNOPTR
		DB	2


;  /* Group 3 & 7*/
		DW	0c0fbh
		DW	0c0dbh
		DD	opn_esc
		DB	 OP_ESC
		DB	2

		DW	038ffh
		DW	028dbh
		DD	opn_fld
		DB	 OP_SIZEFLOATRM
		DB	2

		DW	038ffh
		DW	038dbh
		DD	opn_fstp
		DB	 OP_SIZEFLOATRM
		DB	2


;  /* Group 7 */
		DW	038ffh
		DW	020dfh
		DD	opn_fbld
		DB	 OP_SIZEFLOATRM
		DB	2

		DW	038ffh
		DW	028dfh
		DD	opn_fild
		DB	 OP_SIZEFLOATRM
		DB	2

		DW	038ffh
		DW	030dfh
		DD	opn_fbstp
		DB	 OP_SIZEFLOATRM
		DB	2

		DW	038ffh
		DW	038dfh
		DD	opn_fistp
		DB	 OP_SIZEFLOATRM
		DB	2


;  /* Math, group 0,2,4,6 special RM 3*/
		DW	0c0ffh
		DW	0c0dah
		DD	opn_esc
		DB	 OP_ESC
		DB	2

		DW	0f8ffh
		DW	0c0deh
		DD	opn_fadd
		DB	 OP_FLOATMATH
		DB	2

		DW	0f8ffh
		DW	0c8deh
		DD	opn_fmul
		DB	 OP_FLOATMATH
		DB	2

		DW	0f8ffh
		DW	0d0deh
		DD	opn_fcom
		DB	 OP_FLOATRM
		DB	2

		DW	0f8ffh
		DW	0d8deh
		DD	opn_esc
		DB	 OP_ESC
		DB	2

		DW	0f0ffh
		DW	0e0deh
		DD	opn_fsub
		DB	 OP_FLOATMATH
		DB	2

		DW	0f0ffh
		DW	0f0deh
		DD	opn_fdiv
		DB	 OP_FLOATMATH
		DB	2


;  /* Math, other */
		DW	038fbh
		DW	0d8h
		DD	opn_fadd
		DB	 OP_FLOATMATH
		DB	2

		DW	038fbh
		DW	08d8h
		DD	opn_fmul
		DB	 OP_FLOATMATH
		DB	2

		DW	038fbh
		DW	010d8h
		DD	opn_fcom
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	018d8h
		DD	opn_fcomp
		DB	 OP_FLOATRM
		DB	2

		DW	030fbh
		DW	020d8h
		DD	opn_fsub
		DB	 OP_FLOATMATH
		DB	2

		DW	030fbh
		DW	030d8h
		DD	opn_fdiv
		DB	 OP_FLOATMATH
		DB	2

		DW	038fbh
		DW	0dah
		DD	opn_fiadd
		DB	 OP_FLOATMATH
		DB	2

		DW	038fbh
		DW	08dah
		DD	opn_fimul
		DB	 OP_FLOATMATH
		DB	2

		DW	038fbh
		DW	010dah
		DD	opn_ficom
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	018dah
		DD	opn_ficomp
		DB	 OP_FLOATRM
		DB	2

		DW	030fbh
		DW	020dah
		DD	opn_fisub
		DB	 OP_FLOATMATH
		DB	2

		DW	030fbh
		DW	030dah
		DD	opn_fidiv
		DB	 OP_FLOATMATH
		DB	2


;  /* groups 1, 3, 5, 7 */
;  /* keep the follwing from going into error, RM3 */
		DW	0e0f9h
		DW	0c0d9h
		DD	opn_esc
		DB	 OP_ESC
		DB	2

		DW	038fbh
		DW	0d9h
		DD	opn_fld
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	010d9h
		DD	opn_fst
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	018d9h
		DD	opn_fstp
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	0dbh
		DD	opn_fild
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	010dbh
		DD	opn_fist
		DB	 OP_FLOATRM
		DB	2

		DW	038fbh
		DW	018dbh
		DD	opn_fistp
		DB	 OP_FLOATRM
		DB	2


;  /* Catch-all */
		DW	0f8h
		DW	0d8h
		DD	opn_esc
		DB	 OP_ESC
		DB	2

		DW	0
		DW	0
		DD	0
		DW	0
		DW	0

indexes		DD	base0,base1,base2,base3,base4,base5,base6,base7
ends

		; FindOpCode - find operation code in table.
		; Input: GS:ESI - address.
		; Output: CF=0 - found;
		;	  CF=1 - not found.
proc FindOpcode near
		mov	ebx,offset base386	; Assume it is an 0F opcode
		inc	esi			; Point to next byte
		cmp	[byte gs:esi-1],0Fh	; Is it?
		je	short @@GoTable		; Yes, go parse second byte
		dec	esi			; Else point back to first byte
		mov	ebx,offset floats	; Assume floating
		xor	eax,eax			;
		mov	al,[gs:esi]		; Get the opcode
		and	al,0F8h			; Apply the FLOAT mask
		cmp	al,0D8h			; Apply FLOAT compare
		je	short @@GoTable		; Yes, go look for opcode
		shr	al,5			; Else use upper three bits of
		mov	ebx,[indexes+eax*4]	; opcode to select a table
@@GoTable:	test	[word ebx],-1		; See if at end of table
		jz	short @@NoEntry		; Yes, not found
		mov	ax,[gs:esi]		; Get the opcode
		and	ax,[ebx+OPCODE.MSK]	; Mask it
		cmp	ax,[ebx+OPCODE.COMPARE]	; Compare with the compare value
		je	short @@GotEntry	; Quit if found
		add	ebx,OPCODESIZE		; Else go to next entry
		jmp	@@GoTable			
@@GotEntry:	clc				; Found, exit
		ret
@@NoEntry:	stc				; Not found, exit
		ret
endp		;---------------------------------------------------------------

