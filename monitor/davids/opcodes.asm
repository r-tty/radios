;
; opcodes.asm
;
; Locate the opcode table entry for a given opcode byte
;
	IDEAL
	P386
include "segs.asi"
include "opcodes.asi"

	PUBLIC	FindOpcode

SEGMENT	seg386data
; This is a table of mnemonics for the dissassembler
;
opn_add	db	"add",0
opn_push	db	"push",0
opn_pop	db	"pop",0
opn_or	db	"or",0
opn_adc	db	"adc",0
opn_sbb	db	"sbb",0
opn_and	db	"and",0
opn_daa	db	"daa",0
opn_sub	db	"sub",0
opn_das	db	"das",0
opn_xor	db	"xor",0
opn_aaa	db	"aaa",0
opn_cmp	db	"cmp",0
opn_aas	db	"aas",0
opn_inc	db	"inc",0
opn_dec	db	"dec",0
opn_pusha	db	"pusha",0
opn_popa	db	"popa",0
opn_bound	db	"bound",0
opn_arpl	db	"arpl",0
opn_imul	db	"imul",0
opn_insb	db	"insb",0
opn_ins	db	"ins",0
opn_outsb	db	"outsb",0
opn_outs	db	"outs",0
opn_jo	db	"jo",0
opn_jno	db	"jno",0
opn_jb	db	"jb",0
opn_jnb	db	"jnb",0
opn_jz	db	"jz",0
opn_jnz	db	"jnz",0
opn_jbe	db	"jbe",0
opn_ja	db	"ja",0
opn_js	db	"js",0
opn_jns	db	"jns",0
opn_jp	db	"jp",0
opn_jnp	db	"jnp",0
opn_jl	db	"jl",0
opn_jge	db	"jge",0
opn_jle	db	"jle",0
opn_jg	db	"jg",0
opn_test	db	"test",0
opn_xchg	db	"xchg",0
opn_mov	db	"mov",0
opn_lea	db	"lea",0
opn_nop	db	"nop",0
opn_cbw	db	"cbw",0
opn_cwd	db	"cwd",0
opn_call	db	"call",0
opn_wait	db	"wait",0
opn_pushf	db	"pushf",0
opn_popf	db	"popf",0
opn_sahf	db	"sahf",0
opn_lahf	db	"lahf",0
opn_movs	db	"movs",0
opn_cmps	db	"cmps",0
opn_stos	db	"stos",0
opn_lods	db	"lods",0
opn_scas	db	"scas",0
opn_movsb	db	"movsb",0
opn_cmpsb	db	"cmpsb",0
opn_stosb	db	"stosb",0
opn_lodsb	db	"lodsb",0
opn_scasb	db	"scasb",0
opn_rol	db	"rol",0
opn_ror	db	"ror",0
opn_rcl	db	"rcl",0
opn_rcr	db	"rcr",0
opn_shl	db	"shl",0
opn_shr	db	"shr",0
opn_sar	db	"sar",0
opn_ret	db	"ret",0
opn_les	db	"les",0
opn_lds	db	"lds",0
opn_enter	db	"enter",0
opn_retf	db	"retf",0
opn_int	db	"int",0
opn_into	db	"into",0
opn_iret	db	"iret",0
opn_leave	db	"leave",0
opn_aam	db	"aam",0
opn_aad	db	"aad",0
opn_xlat	db	"xlat",0
opn_loopnz	db	"loopnz",0
opn_loopz	db	"loopz",0
opn_loop	db	"loop",0
opn_jcxz	db	"jcxz",0
opn_in	db	"in",0
opn_out	db	"out",0
opn_jmp	db	"jmp",0
opn_lock	db	"lock",0
opn_repnz	db	"repnz",0
opn_repz	db	"repz",0
opn_hlt	db	"hlt",0
opn_cmc	db	"cmc",0
opn_not	db	"not",0
opn_neg	db	"neg",0
opn_mul	db	"mul",0
opn_div	db	"div",0
opn_idiv	db	"idiv",0
opn_clc	db	"clc",0
opn_stc	db	"stc",0
opn_cli	db	"cli",0
opn_sti	db	"sti",0
opn_cld	db	"cld",0
opn_std	db	"std",0
opn_movsx	db	"movsx",0
opn_movzx	db	"movzx",0
opn_lfs	db	"lfs",0
opn_lgs	db	"lgs",0
opn_lss	db	"lss",0
opn_clts	db	"clts",0
opn_shld	db	"shld",0
opn_shrd	db	"shrd",0
opn_bsf	db	"bsf",0
opn_bsr	db	"bsr",0
opn_bt	db	"bt",0
opn_bts	db	"bts",0
opn_btr	db	"btr",0
opn_btc	db	"btc",0
opn_ibts	db	"ibts",0
opn_xbts	db	"xbts",0
opn_seto	db	"seto",0
opn_setno	db	"setno",0
opn_setb	db	"setb",0
opn_setnb	db	"setnb",0
opn_setz	db	"setz",0
opn_setnz	db	"setnz",0
opn_setbe	db	"setbe",0
opn_seta	db	"seta",0
opn_sets	db	"sets",0
opn_setns	db	"setns",0
opn_setp	db	"setp",0
opn_setnp	db	"setnp",0
opn_setl	db	"setl",0
opn_setge	db	"setge",0
opn_setle	db	"setle",0
opn_setg	db	"setg",0
opn_lar	db	"lar",0
opn_lsl	db	"lsl",0
opn_lgdt	db	"lgdt",0
opn_lidt	db	"lidt",0
opn_lldt	db	"lldt",0
opn_lmsw	db	"lmsw",0
opn_ltr	db	"ltr",0
opn_sgdt	db	"sgdt",0
opn_sidt	db	"sidt",0
opn_sldt	db	"sldt",0
opn_smsw	db	"smsw",0
opn_str	db	"str",0
opn_verr	db	"verr",0
opn_verw	db	"verw",0
opn_fnop	db	"fnop",0
opn_fchs	db	"fchs",0
opn_fabs	db	"fabs",0
opn_ftst	db	"ftst",0
opn_fxam	db	"fxam",0
opn_fld1	db	"fld1",0
opn_fldl2t	db	"fldl2t",0
opn_fldl2e	db	"fldl2e",0
opn_fldpi	db	"fldpi",0
opn_fldlg2	db	"fldlg2",0
opn_fldln2	db	"fldln2",0
opn_fldz	db	"fldz",0
opn_f2xm1	db	"f2xm1",0
opn_fyl2x	db	"fyl2x",0
opn_fptan	db	"fptan",0
opn_fpatan	db	"fpatan",0
opn_fprem1	db	"fprem1",0
opn_fxtract	db	"fxtract",0
opn_fdecstp	db	"fdecstp",0
opn_fincstp	db	"fincstp",0
opn_fprem	db	"fprem",0
opn_fyl2xp1	db	"fyl2xp1",0
opn_fsqrt	db	"fsqrt",0
opn_fsincos	db	"fsincos",0
opn_frndint	db	"frndint",0
opn_fscale	db	"fscale",0
opn_fsin	db	"fsin",0
opn_fcos	db	"fcos",0
opn_fucompp	db	"fucompp",0
opn_feni	db	"feni",0
opn_fdisi	db	"fdisi",0
opn_fclex	db	"fclex",0
opn_finit	db	"finit",0
opn_fsetpm	db	"fsetpm",0
opn_fcompp	db	"fcompp",0
opn_fld	db	"fld",0
opn_fxch	db	"fxch",0
opn_fstp	db	"fstp",0
opn_esc	db	"esc",0
opn_fldenv	db	"fldenv",0
opn_fldcw	db	"fldcw",0
opn_fstenv	db	"fstenv",0
opn_fstcw	db	"fstcw",0
opn_ffree	db	"ffree",0
opn_fst	db	"fst",0
opn_fucom	db	"fucom",0
opn_fucomp	db	"fucomp",0
opn_frstor	db	"frstor",0
opn_fsave	db	"fsave",0
opn_fstsw	db	"fstsw",0
opn_fbld	db	"fbld",0
opn_fild	db	"fild",0
opn_fbstp	db	"fbstp",0
opn_fistp	db	"fistp",0
opn_fmul	db	"fmul",0
opn_fcom	db	"fcom",0
opn_fsub	db	"fsub",0
opn_fdiv	db	"fdiv",0
opn_fadd	db	"fadd",0
opn_fcomp	db	"fcomp",0
opn_fiadd	db	"fiadd",0
opn_fimul	db	"fimul",0
opn_ficom	db	"ficom",0
opn_ficomp	db	"ficomp",0
opn_fisub	db	"fisub",0
opn_fidiv	db	"fidiv",0
opn_fist	db	"fist",0

;
; Following is a table of opcodes.  Each entry consists of a mask value,
; a comparison value, a pointer to the name, the addressing mode to be
; used in dissassembly, and the base length of the instruction (possibly
; modified by the exact addressing mode encountered)
;
base0	dw	0fch
	dw	00h
	dd	opn_add
	db	 OP_REGRMREG
	db	2

	dw	0e7h
	dw	06h
	dd	opn_push
	db	 OP_SEG35
	db	1

	dw	0feh
	dw	04h
	dd	opn_add
	db	 OP_ACCIMM
	db	1

	dw	0e7h
	dw	07h
	dd	opn_pop
	db	 OP_SEG35
	db	1

	dw	0fch
	dw	08h
	dd	opn_or
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	0ch
	dd	opn_or
	db	 OP_ACCIMM
	db	1

	dw	0fch
	dw	010h
	dd	opn_adc
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	014h
	dd	opn_adc
	db	 OP_ACCIMM
	db	1

	dw	0fch
	dw	018h
	dd	opn_sbb
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	01ch
	dd	opn_sbb
	db	 OP_ACCIMM
	db	1

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base1	dw	0fch
	dw	020h
	dd	opn_and
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	024h
	dd	opn_and
	db	 OP_ACCIMM
	db	1

	dw	0ffh
	dw	027h
	dd	opn_daa
	db	 OP_CODEONLY
	db	1

	dw	0fch
	dw	028h
	dd	opn_sub
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	02ch
	dd	opn_sub
	db	 OP_ACCIMM
	db	1

	dw	0ffh
	dw	02fh
	dd	opn_das
	db	 OP_CODEONLY
	db	1

	dw	0fch
	dw	030h
	dd	opn_xor
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	034h
	dd	opn_xor
	db	 OP_ACCIMM
	db	1

	dw	0ffh
	dw	037h
	dd	opn_aaa
	db	 OP_CODEONLY
	db	1

	dw	0fch
	dw	038h
	dd	opn_cmp
	db	 OP_REGRMREG
	db	2

	dw	0feh
	dw	03ch
	dd	opn_cmp
	db	 OP_ACCIMM
	db	1

	dw	0ffh
	dw	03fh
	dd	opn_aas
	db	 OP_CODEONLY
	db	1

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base2	dw	0f8h
	dw	040h
	dd	opn_inc
	db	 OP_WREG02
	db	1

	dw	0f8h
	dw	048h
	dd	opn_dec
	db	 OP_WREG02
	db	1

	dw	0f8h
	dw	050h
	dd	opn_push
	db	 OP_WREG02
	db	1

	dw	0f8h
	dw	058h
	dd	opn_pop
	db	 OP_WREG02
	db	1

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base3	dw	0ffh
	dw	060h
	dd	opn_pusha
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	061h
	dd	opn_popa
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	062h
	dd	opn_bound
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	063h
	dd	opn_arpl
	db	 OP_WORDRMREG
	db	2

	dw	0fdh
	dw	068h
	dd	opn_push
	db	 OP_IMM
	db	1

	dw	0fdh
	dw	069h
	dd	opn_imul
	db	 OP_IMUL
	db	2

	dw	0ffh
	dw	06ch
	dd	opn_insb
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	06dh
	dd	opn_ins
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	06eh
	dd	opn_outsb
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	06fh
	dd	opn_outs
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	070h
	dd	opn_jo
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	071h
	dd	opn_jno
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	072h
	dd	opn_jb
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	073h
	dd	opn_jnb
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	074h
	dd	opn_jz
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	075h
	dd	opn_jnz
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	076h
	dd	opn_jbe
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	077h
	dd	opn_ja
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	078h
	dd	opn_js
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	079h
	dd	opn_jns
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	07ah
	dd	opn_jp
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	07bh
	dd	opn_jnp
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	07ch
	dd	opn_jl
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	07dh
	dd	opn_jge
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	07eh
	dd	opn_jle
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	07fh
	dd	opn_jg
	db	 OP_SHORTBRANCH
	db	2

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base4	dw	038fch
	dw	080h
	dd	opn_add
	db	 OP_RMIMMSIGNED
	db	2

	dw	038feh
	dw	0880h
	dd	opn_or
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	0880h
	dd	opn_or
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	01080h
	dd	opn_adc
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	01880h
	dd	opn_sbb
	db	 OP_RMIMMSIGNED
	db	2

	dw	038feh
	dw	02080h
	dd	opn_and
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	02080h
	dd	opn_and
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	02880h
	dd	opn_sub
	db	 OP_RMIMMSIGNED
	db	2

	dw	038feh
	dw	03080h
	dd	opn_xor
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	03080h
	dd	opn_xor
	db	 OP_RMIMMSIGNED
	db	2

	dw	038fch
	dw	03880h
	dd	opn_cmp
	db	 OP_RMIMMSIGNED
	db	2

	dw	0feh
	dw	084h
	dd	opn_test
	db	 OP_REGRM
	db	2

	dw	0feh
	dw	086h
	dd	opn_xchg
	db	 OP_REGRM
	db	2

	dw	0fch
	dw	088h
	dd	opn_mov
	db	 OP_REGRMREG
	db	2

	dw	020fdh
	dw	08ch
	dd	opn_mov
	db	 OP_SEGRMSEG
	db	2

	dw	0fdh
	dw	08ch
	dd	opn_mov
	db	 OP_SEGRMSEG
	db	2

	dw	0ffh
	dw	08dh
	dd	opn_lea
	db	 OP_WORDREGRM
	db	2

	dw	038ffh
	dw	08fh
	dd	opn_pop
	db	 OP_NOSTRICTRM
	db	2

	dw	0ffh
	dw	090h
	dd	opn_nop
	db	 OP_CODEONLY
	db	1

	dw	0f8h
	dw	090h
	dd	opn_xchg
	db	 OP_ACCREG02
	db	1

	dw	0ffh
	dw	098h
	dd	opn_cbw
	db	 OP_CBW
	db	1

	dw	0ffh
	dw	099h
	dd	opn_cwd
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	09ah
	dd	opn_call
	db	 OP_SEGBRANCH
	db	5

	dw	0ffh
	dw	09bh
	dd	opn_wait
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	09ch
	dd	opn_pushf
	db	 OP_INSWORDSIZE
	db	1

	dw	0ffh
	dw	09dh
	dd	opn_popf
	db	 OP_INSWORDSIZE
	db	1

	dw	0ffh
	dw	09eh
	dd	opn_sahf
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	09fh
	dd	opn_lahf
	db	 OP_CODEONLY
	db	1

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base5	dw	0feh
	dw	0a0h
	dd	opn_mov
	db	 OP_ACCABS
	db	3

	dw	0feh
	dw	0a2h
	dd	opn_mov
	db	 OP_ABSACC
	db	3

	dw	0ffh
	dw	0a5h
	dd	opn_movs
	db	 OP_INSWORDSIZE
	db	1

	dw	0ffh
	dw	0a7h
	dd	opn_cmps
	db	 OP_INSWORDSIZE
	db	1

	dw	0feh
	dw	0a8h
	dd	opn_test
	db	 OP_ACCIMM
	db	1

	dw	0ffh
	dw	0abh
	dd	opn_stos
	db	 OP_INSWORDSIZE
	db	1

	dw	0ffh
	dw	0adh
	dd	opn_lods
	db	 OP_INSWORDSIZE
	db	1

	dw	0ffh
	dw	0afh
	dd	opn_scas
	db	 OP_INSWORDSIZE
	db	1

	dw	0ffh
	dw	0a4h
	dd	opn_movsb
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0a6h
	dd	opn_cmpsb
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0aah
	dd	opn_stosb
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0ach
	dd	opn_lodsb
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0aeh
	dd	opn_scasb
	db	 OP_CODEONLY
	db	1

	dw	0f0h
	dw	0b0h
	dd	opn_mov
	db	 OP_ACCIMMB3
	db	1

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base6	dw	038feh
	dw	0c0h
	dd	opn_rol
	db	 OP_RMSHIFT
	db	2

	dw	038feh
	dw	08c0h
	dd	opn_ror
	db	 OP_RMSHIFT
	db	2

	dw	038feh
	dw	010c0h
	dd	opn_rcl
	db	 OP_RMSHIFT
	db	2

	dw	038feh
	dw	018c0h
	dd	opn_rcr
	db	 OP_RMSHIFT
	db	2

	dw	038feh
	dw	020c0h
	dd	opn_shl
	db	 OP_RMSHIFT
	db	2

	dw	038feh
	dw	028c0h
	dd	opn_shr
	db	 OP_RMSHIFT
	db	2

	dw	038feh
	dw	038c0h
	dd	opn_sar
	db	 OP_RMSHIFT
	db	2

	dw	0ffh
	dw	0c2h
	dd	opn_ret
	db	 OP_RET
	db	3

	dw	0ffh
	dw	0c3h
	dd	opn_ret
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0c4h
	dd	opn_les
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	0c5h
	dd	opn_lds
	db	 OP_WORDREGRM
	db	2

	dw	038feh
	dw	0c6h
	dd	opn_mov
	db	 OP_RMIMM
	db	2

	dw	0ffh
	dw	0c8h
	dd	opn_enter
	db	 OP_ENTER
	db	4

	dw	0ffh
	dw	0cah
	dd	opn_retf
	db	 OP_RET
	db	3

	dw	0ffh
	dw	0cbh
	dd	opn_retf
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0cch
	dd	opn_int
	db	 OP_INTR
	db	1

	dw	0ffh
	dw	0cdh
	dd	opn_int
	db	 OP_INTR
	db	2

	dw	0ffh
	dw	0ceh
	dd	opn_into
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0cfh
	dd	opn_iret
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0c9h
	dd	opn_leave
	db	 OP_CODEONLY
	db	1

	dw	038fch
	dw	0d0h
	dd	opn_rol
	db	 OP_RMSHIFT
	db	2

	dw	038fch
	dw	08d0h
	dd	opn_ror
	db	 OP_RMSHIFT
	db	2

	dw	038fch
	dw	010d0h
	dd	opn_rcl
	db	 OP_RMSHIFT
	db	2

	dw	038fch
	dw	018d0h
	dd	opn_rcr
	db	 OP_RMSHIFT
	db	2

	dw	038fch
	dw	020d0h
	dd	opn_shl
	db	 OP_RMSHIFT
	db	2

	dw	038fch
	dw	028d0h
	dd	opn_shr
	db	 OP_RMSHIFT
	db	2

	dw	038fch
	dw	038d0h
	dd	opn_sar
	db	 OP_RMSHIFT
	db	2

	dw	0ffffh
	dw	0ad4h
	dd	opn_aam
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0ad5h
	dd	opn_aad
	db	 OP_CODEONLY
	db	2

	dw	0ffh
	dw	0d7h
	dd	opn_xlat
	db	 OP_CODEONLY
	db	1

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base7	dw	0ffh
	dw	0e0h
	dd	opn_loopnz
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	0e1h
	dd	opn_loopz
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	0e2h
	dd	opn_loop
	db	 OP_SHORTBRANCH
	db	2

	dw	0ffh
	dw	0e3h
	dd	opn_jcxz
	db	 OP_SHORTBRANCH
	db	2

	dw	0feh
	dw	0e4h
	dd	opn_in
	db	 OP_PORTACCPORT
	db	2

	dw	0feh
	dw	0e6h
	dd	opn_out
	db	 OP_PORTACCPORT
	db	2

	dw	0ffh
	dw	0e8h
	dd	opn_call
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	0e9h
	dd	opn_jmp
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	0eah
	dd	opn_jmp
	db	 OP_SEGBRANCH
	db	5

	dw	0ffh
	dw	0ebh
	dd	opn_jmp
	db	 OP_SHORTBRANCH
	db	2

	dw	0feh
	dw	0ech
	dd	opn_in
	db	 OP_ACCDX
	db	1

	dw	0feh
	dw	0eeh
	dd	opn_out
	db	 OP_DXACC
	db	1

	dw	0ffh
	dw	0f0h
	dd	opn_lock
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0f2h
	dd	opn_repnz
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0f3h
	dd	opn_repz
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0f4h
	dd	opn_hlt
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0f5h
	dd	opn_cmc
	db	 OP_CODEONLY
	db	1

	dw	038feh
	dw	0f6h
	dd	opn_test
	db	 OP_RMIMM
	db	2

	dw	038feh
	dw	010f6h
	dd	opn_not
	db	 OP_RM 
	db	2

	dw	038feh
	dw	018f6h
	dd	opn_neg
	db	 OP_RM 
	db	2

	dw	038feh
	dw	020f6h
	dd	opn_mul
	db	 OP_RM 
	db	2

	dw	038feh
	dw	028f6h
	dd	opn_imul
	db	 OP_RM 
	db	2

	dw	038feh
	dw	030f6h
	dd	opn_div
	db	 OP_RM 
	db	2

	dw	038feh
	dw	038f6h
	dd	opn_idiv
	db	 OP_RM 
	db	2

	dw	0ffh
	dw	0f8h
	dd	opn_clc
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0f9h
	dd	opn_stc
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0fah
	dd	opn_cli
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0fbh
	dd	opn_sti
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0fch
	dd	opn_cld
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0fdh
	dd	opn_std
	db	 OP_CODEONLY
	db	1

	dw	038feh
	dw	0feh
	dd	opn_inc
	db	 OP_RM 
	db	2

	dw	038feh
	dw	08feh
	dd	opn_dec
	db	 OP_RM 
	db	2

	dw	038ffh
	dw	010ffh
	dd	opn_call
	db	 OP_RM 
	db	2

	dw	038ffh
	dw	018ffh
	dd	opn_call
	db	 OP_FARRM 
	db	2

	dw	038ffh
	dw	020ffh
	dd	opn_jmp
	db	 OP_RM 
	db	2

	dw	038ffh
	dw	028ffh
	dd	opn_jmp
	db	 OP_FARRM 
	db	2

	dw	038ffh
	dw	030ffh
	dd	opn_push
	db	 OP_NOSTRICTRM
	db	2

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

base386	dw	0feh
	dw	0beh
	dd	opn_movsx
	db	 OP_MIXEDREGRM
	db	2

	dw	0feh
	dw	0b6h
	dd	opn_movzx
	db	 OP_MIXEDREGRM
	db	2

	dw	0f7h
	dw	0a0h
	dd	opn_push
	db	 OP_SEG35
	db	1

	dw	0f7h
	dw	0a1h
	dd	opn_pop
	db	 OP_SEG35
	db	1

	dw	0ffh
	dw	0b4h
	dd	opn_lfs
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	0b5h
	dd	opn_lgs
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	0b2h
	dd	opn_lss
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	06h
	dd	opn_clts
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0afh
	dd	opn_imul
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	0a4h
	dd	opn_shld
	db	 OP_REGRMSHIFT
	db	3

	dw	0ffh
	dw	0a5h
	dd	opn_shld
	db	 OP_REGRMSHIFT
	db	2

	dw	0ffh
	dw	0ach
	dd	opn_shrd
	db	 OP_REGRMSHIFT
	db	3

	dw	0ffh
	dw	0adh
	dd	opn_shrd
	db	 OP_REGRMSHIFT
	db	2

	dw	0ffh
	dw	0bch
	dd	opn_bsf
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	0bdh
	dd	opn_bsr
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	0a3h
	dd	opn_bt
	db	 OP_WORDRMREG
	db	2

	dw	0ffh
	dw	0abh
	dd	opn_bts
	db	 OP_WORDRMREG
	db	2

	dw	0ffh
	dw	0b3h
	dd	opn_btr
	db	 OP_WORDRMREG
	db	2

	dw	0ffh
	dw	0bbh
	dd	opn_btc
	db	 OP_WORDRMREG
	db	2

	dw	038ffh
	dw	020bah
	dd	opn_bt
	db	 OP_BITNUM
	db	3

	dw	038ffh
	dw	028bah
	dd	opn_bts
	db	 OP_BITNUM
	db	3

	dw	038ffh
	dw	030bah
	dd	opn_btr
	db	 OP_BITNUM
	db	3

	dw	038ffh
	dw	038bah
	dd	opn_btc
	db	 OP_BITNUM
	db	3

	dw	0ffh
	dw	0a7h
	dd	opn_ibts
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	0a6h
	dd	opn_xbts
	db	 OP_CODEONLY
	db	1

	dw	0ffh
	dw	080h
	dd	opn_jo
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	081h
	dd	opn_jno
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	082h
	dd	opn_jb
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	083h
	dd	opn_jnb
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	084h
	dd	opn_jz
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	085h
	dd	opn_jnz
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	086h
	dd	opn_jbe
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	087h
	dd	opn_ja
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	088h
	dd	opn_js
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	089h
	dd	opn_jns
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	08ah
	dd	opn_jp
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	08bh
	dd	opn_jnp
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	08ch
	dd	opn_jl
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	08dh
	dd	opn_jge
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	08eh
	dd	opn_jle
	db	 OP_BRANCH
	db	3

	dw	0ffh
	dw	08fh
	dd	opn_jg
	db	 OP_BRANCH
	db	3

	dw	038ffh
	dw	090h
	dd	opn_seto
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	091h
	dd	opn_setno
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	092h
	dd	opn_setb
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	093h
	dd	opn_setnb
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	094h
	dd	opn_setz
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	095h
	dd	opn_setnz
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	096h
	dd	opn_setbe
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	097h
	dd	opn_seta
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	098h
	dd	opn_sets
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	099h
	dd	opn_setns
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	09ah
	dd	opn_setp
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	09bh
	dd	opn_setnp
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	09ch
	dd	opn_setl
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	09dh
	dd	opn_setge
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	09eh
	dd	opn_setle
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	09fh
	dd	opn_setg
	db	 OP_NOSTRICTRM 
	db	2

	dw	0c0fdh
	dw	0c020h
	dd	opn_mov
	db	 OP_386REG
	db	2

	dw	0c0fdh
	dw	0c021h
	dd	opn_mov
	db	 OP_386REG
	db	2

	dw	0c0fdh
	dw	0c024h
	dd	opn_mov
	db	 OP_386REG
	db	2

	dw	0ffh
	dw	02h
	dd	opn_lar
	db	 OP_WORDREGRM
	db	2

	dw	0ffh
	dw	03h
	dd	opn_lsl
	db	 OP_WORDREGRM
	db	2

	dw	038ffh
	dw	01001h
	dd	opn_lgdt
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	01801h
	dd	opn_lidt
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	01000h
	dd	opn_lldt
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	03001h
	dd	opn_lmsw
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	01800h
	dd	opn_ltr
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	01h
	dd	opn_sgdt
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	0801h
	dd	opn_sidt
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	00h
	dd	opn_sldt
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	02001h
	dd	opn_smsw
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	0800h
	dd	opn_str
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	02000h
	dd	opn_verr
	db	 OP_NOSTRICTRM 
	db	2

	dw	038ffh
	dw	02800h
	dd	opn_verw
	db	 OP_NOSTRICTRM 
	db	2

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

;/* single byte commands */
floats	dw	0ffffh
	dw	0d0d9h
	dd	opn_fnop
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e0d9h
	dd	opn_fchs
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e1d9h
	dd	opn_fabs
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e4d9h
	dd	opn_ftst
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e5d9h
	dd	opn_fxam
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e8d9h
	dd	opn_fld1
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e9d9h
	dd	opn_fldl2t
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0ead9h
	dd	opn_fldl2e
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0ebd9h
	dd	opn_fldpi
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0ecd9h
	dd	opn_fldlg2
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0edd9h
	dd	opn_fldln2
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0eed9h
	dd	opn_fldz
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f0d9h
	dd	opn_f2xm1
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f1d9h
	dd	opn_fyl2x
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f2d9h
	dd	opn_fptan
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f3d9h
	dd	opn_fpatan
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f5d9h
	dd	opn_fprem1
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f4d9h
	dd	opn_fxtract
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f6d9h
	dd	opn_fdecstp
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f7d9h
	dd	opn_fincstp
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f8d9h
	dd	opn_fprem
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0f9d9h
	dd	opn_fyl2xp1
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0fad9h
	dd	opn_fsqrt
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0fbd9h
	dd	opn_fsincos
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0fcd9h
	dd	opn_frndint
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0fdd9h
	dd	opn_fscale
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0fed9h
	dd	opn_fsin
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0ffd9h
	dd	opn_fcos
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e9dah
	dd	opn_fucompp
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e0dbh
	dd	opn_feni
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e1dbh
	dd	opn_fdisi
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e2dbh
	dd	opn_fclex
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e3dbh
	dd	opn_finit
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0e4dbh
	dd	opn_fsetpm
	db	 OP_CODEONLY
	db	2

	dw	0ffffh
	dw	0d9deh
	dd	opn_fcompp
	db	 OP_CODEONLY
	db	2


;  /* Group 1, RM 3 */
	dw	0f8ffh
	dw	0c0d9h
	dd	opn_fld
	db	 OP_FLOATRM
	db	2

	dw	0f8ffh
	dw	0c8d9h
	dd	opn_fxch
	db	 OP_FLOATRM
	db	2

	dw	0f8fbh
	dw	0d8d9h
	dd	opn_fstp
	db	 OP_FLOATRM
	db	2

	dw	0c0ffh
	dw	0c0d9h
	dd	opn_esc
	db	 OP_ESC
	db	2


;  /* Group 1, RM0-2 */
	dw	038ffh
	dw	020d9h
	dd	opn_fldenv
	db	 OP_FLOATNOPTR
	db	2

	dw	038ffh
	dw	028d9h
	dd	opn_fldcw
	db	 OP_FLOATNOPTR
	db	2

	dw	038ffh
	dw	030d9h
	dd	opn_fstenv
	db	 OP_FLOATNOPTR
	db	2

	dw	038ffh
	dw	038d9h
	dd	opn_fstcw
	db	 OP_FLOATNOPTR
	db	2


;  /* Group 5, RM3 */
	dw	0f8ffh
	dw	0c0ddh
	dd	opn_ffree
	db	 OP_FLOATRM
	db	2

	dw	0f8ffh
	dw	0d0ddh
	dd	opn_fst
	db	 OP_FLOATRM
	db	2

	dw	0f8ffh
	dw	0e0ddh
	dd	opn_fucom
	db	 OP_FLOATRM
	db	2

	dw	0f8ffh
	dw	0e8ddh
	dd	opn_fucomp
	db	 OP_FLOATRM
	db	2


	dw	0c0ffh
	dw	0c0ddh
	dd	opn_esc
	db	 OP_ESC
	db	2


;  /* Group 5, RM0-2 */
	dw	038ffh
	dw	020ddh
	dd	opn_frstor
	db	 OP_FLOATNOPTR
	db	2

	dw	038ffh
	dw	030ddh
	dd	opn_fsave
	db	 OP_FLOATNOPTR
	db	2

	dw	038ffh
	dw	038ddh
	dd	opn_fstsw
	db	 OP_FLOATNOPTR
	db	2


;  /* Group 3 & 7*/
	dw	0c0fbh
	dw	0c0dbh
	dd	opn_esc
	db	 OP_ESC
	db	2

	dw	038ffh
	dw	028dbh
	dd	opn_fld
	db	 OP_SIZEFLOATRM
	db	2

	dw	038ffh
	dw	038dbh
	dd	opn_fstp
	db	 OP_SIZEFLOATRM
	db	2


;  /* Group 7 */
	dw	038ffh
	dw	020dfh
	dd	opn_fbld
	db	 OP_SIZEFLOATRM
	db	2

	dw	038ffh
	dw	028dfh
	dd	opn_fild
	db	 OP_SIZEFLOATRM
	db	2

	dw	038ffh
	dw	030dfh
	dd	opn_fbstp
	db	 OP_SIZEFLOATRM
	db	2

	dw	038ffh
	dw	038dfh
	dd	opn_fistp
	db	 OP_SIZEFLOATRM
	db	2


;  /* Math, group 0,2,4,6 special RM 3*/
	dw	0c0ffh
	dw	0c0dah
	dd	opn_esc
	db	 OP_ESC
	db	2

	dw	0f8ffh
	dw	0c0deh
	dd	opn_fadd
	db	 OP_FLOATMATH
	db	2

	dw	0f8ffh
	dw	0c8deh
	dd	opn_fmul
	db	 OP_FLOATMATH
	db	2

	dw	0f8ffh
	dw	0d0deh
	dd	opn_fcom
	db	 OP_FLOATRM
	db	2

	dw	0f8ffh
	dw	0d8deh
	dd	opn_esc
	db	 OP_ESC
	db	2

	dw	0f0ffh
	dw	0e0deh
	dd	opn_fsub
	db	 OP_FLOATMATH
	db	2

	dw	0f0ffh
	dw	0f0deh
	dd	opn_fdiv
	db	 OP_FLOATMATH
	db	2


;  /* Math, other */
	dw	038fbh
	dw	0d8h
	dd	opn_fadd
	db	 OP_FLOATMATH
	db	2

	dw	038fbh
	dw	08d8h
	dd	opn_fmul
	db	 OP_FLOATMATH
	db	2

	dw	038fbh
	dw	010d8h
	dd	opn_fcom
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	018d8h
	dd	opn_fcomp
	db	 OP_FLOATRM
	db	2

	dw	030fbh
	dw	020d8h
	dd	opn_fsub
	db	 OP_FLOATMATH
	db	2

	dw	030fbh
	dw	030d8h
	dd	opn_fdiv
	db	 OP_FLOATMATH
	db	2

	dw	038fbh
	dw	0dah
	dd	opn_fiadd
	db	 OP_FLOATMATH
	db	2

	dw	038fbh
	dw	08dah
	dd	opn_fimul
	db	 OP_FLOATMATH
	db	2

	dw	038fbh
	dw	010dah
	dd	opn_ficom
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	018dah
	dd	opn_ficomp
	db	 OP_FLOATRM
	db	2

	dw	030fbh
	dw	020dah
	dd	opn_fisub
	db	 OP_FLOATMATH
	db	2

	dw	030fbh
	dw	030dah
	dd	opn_fidiv
	db	 OP_FLOATMATH
	db	2


;  /* groups 1, 3, 5, 7 */
;  /* keep the follwing from going into error, RM3 */
	dw	0e0f9h
	dw	0c0d9h
	dd	opn_esc
	db	 OP_ESC
	db	2

	dw	038fbh
	dw	0d9h
	dd	opn_fld
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	010d9h
	dd	opn_fst
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	018d9h
	dd	opn_fstp
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	0dbh
	dd	opn_fild
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	010dbh
	dd	opn_fist
	db	 OP_FLOATRM
	db	2

	dw	038fbh
	dw	018dbh
	dd	opn_fistp
	db	 OP_FLOATRM
	db	2


;  /* Catch- all */
	dw	0f8h
	dw	0d8h
	dd	opn_esc
	db	 OP_ESC
	db	2

	dw	0
	dw	0
	dd	0
	dw	0
	dw	0

indexes dd base0, base1, base2, base3, base4, base5, base6, base7
ENDS	seg386data;

SEGMENT	seg386
PROC	FindOpcode
	mov	ebx,offset base386	; Assume it is an 0F opcode
	inc	esi			; Point to next byte
	cmp	[byte ptr es:esi-1],0fh	; Is it?
	jz	short gotable		; Yes, go parse second byte
	dec	esi			; Else point back to first byte
	mov	ebx,offset floats	; Assume floating
	sub	eax,eax			;
	mov	al,[es:esi]		; Get the opcode
	and	al,0f8h			; Apply the FLOAT mask
	cmp	al,0d8h			; Apply FLOAT compare
	jz	short gotable		; Yes, go look for opcode
	shr	al,5			; Else use upper three bits of
	mov	ebx,[indexes + eax * 4]	; opcode to select a table
gotable:
	test	[word ptr ebx],-1	; See if at end of table
	jz	short noentry		; Yes, not found
	mov	ax,[es:esi]		; Get the opcode
	and	ax,[ebx + OPCODE.MSK]	; Mask it
	cmp	ax,[ebx + OPCODE.COMPARE]; Compare with the compare value
	jz	short gotentry		; Quit if found
	add	ebx,OPCODESIZE		; Else go to next entry
	jmp	gotable			;
gotentry:
	clc				; Found, exit
	ret
noentry:
	stc				; Not found, exit
	ret
ENDP	FindOpcode
ENDS	seg386
END