;-------------------------------------------------------------------------------
; i387.nasm - library of FPU math functions.
; Based on FreeBSD msun/i387 code, (c) 1993,94 Winning Strategies, Inc.
;-------------------------------------------------------------------------------

module libm.i387

exportproc _atan, _tan
exportproc _ceil
exportproc _copysign
exportproc _cos, _sin
exportproc _finite
exportproc _floor
exportproc _ilogb
exportproc _log1p, _logb
exportproc _rint
publicproc _scalbn, _significand


section .text

		; acos = atan (sqrt(1 - x^2) / x)
proc __ieee754_acos
		fld	qword [esp+4]		; x
		fst	st1
		fmul	st0			; x^2
		fld1				
		fsubp	st0			; 1 - x^2
		fsqrt				; sqrt (1 - x^2)
		fxch	st1
		fpatan
		ret
endp		;---------------------------------------------------------------


		; asin = atan (x / sqrt(1 - x^2))
proc __ieee754_asin
		fld	qword [esp+4]		; x
		fst	st1
		fmul	st0			; x^2
		fld1
		fsubp	st0			; 1 - x^2
		fsqrt				; sqrt (1 - x^2)
		fpatan
		ret
endp		;---------------------------------------------------------------


proc __ieee754_atan2
		fld	qword [esp+4]
		fld	qword [esp+12]
		fpatan
		ret
endp		;---------------------------------------------------------------


		; e^x = 2^(x * log2(e))
proc __ieee754_exp
		fld	qword [esp+4]
		fldl2e
		fmulp	st0			; x * log2(e)
		fst	st1
		frndint				; int(x * log2(e))
		fst	st2
		fsubrp	st0			; fract(x * log2(e))
		f2xm1				; 2^(fract(x * log2(e))) - 1
		fld1
		faddp	st0			; 2^(fract(x * log2(e)))
		fscale				; e^x
		fstp	st1
		ret
endp		;---------------------------------------------------------------


proc __ieee754_fmod
		fld	qword [esp+12]
		fld	qword [esp+4]
.1:		fprem
		fstsw	ax
		sahf
		jp	.1
		fstp	st1
		ret
endp		;---------------------------------------------------------------


proc __ieee754_log
		fldln2
		fld	qword [esp+4]
		fyl2x
		ret
endp		;---------------------------------------------------------------


proc __ieee754_log10
		fldlg2
		fld	qword [esp+4]
		fyl2x
		ret
endp		;---------------------------------------------------------------


proc __ieee754_remainder
		fld	qword [esp+12]
		fld	qword [esp+4]
.1:		fprem1
		fstsw	ax
		sahf
		jp	.1
		fstp	st1
		ret
endp		;---------------------------------------------------------------


proc __ieee754_scalb
		fld	qword [esp+12]
		fld	qword [esp+4]
		fscale
		fstp	st1
		ret
endp		;---------------------------------------------------------------


proc __ieee754_sqrt
		fld	qword [esp+4]
		fsqrt
		ret
endp		;---------------------------------------------------------------


proc _atan
		fld	qword [esp+4]
		fld1
		fpatan
		ret
endp		;---------------------------------------------------------------


proc _ceil
		prologue 8

		fstcw	[ebp-4]			; store fpu control word
		mov	dx,[ebp-4]
		or	dx,800h			; round towards +oo
		and	dx,0FBFFh
		mov	[ebp-8],dx
		fldcw	[ebp-8]			; load modfied control word

		fld	qword [ebp+8]		; round
		frndint

		fldcw	[ebp-4]			; restore original control word

		epilogue
		ret
endp		;---------------------------------------------------------------


proc _copysign
		mov	edx,[esp+16]
		and	edx,80000000h
		mov	eax,[esp+8]
		and	eax,7FFFFFFFh
		or	eax,edx
		mov	[esp+8],eax
		fld	qword [esp+4]
		ret
endp		;---------------------------------------------------------------


proc _cos
		fld	qword [esp+4]
		fcos
		fnstsw	ax
		and	ax,400h
		jnz	.1
		ret	
.1:		fldpi
		fadd	st0
		fxch	st1
.2:		fprem1
		fnstsw	ax
		and	ax,400h
		jnz	.2
		fstp	st1
		fcos
		ret
endp		;---------------------------------------------------------------


proc _finite
		mov	eax,[esp+8]
		and	eax,7FF00000h
		cmp	eax,7FF00000h
		setne	al
		and	eax,0FFh
		ret
endp		;---------------------------------------------------------------


proc _floor
		prologue 8

		fstcw	[ebp-4]			; store fpu control word
		mov	dx,[ebp-4]
		or	dx,400h			; round towards -oo
		and	dx,0F7FFh
		mov	[ebp-8],dx
		fldcw	[ebp-8]			; load modfied control word

		fld	qword [ebp+8]		; round
		frndint

		fldcw	[ebp-4]			; restore original control word

		epilogue
		ret
endp		;---------------------------------------------------------------


proc _ilogb
		prologue 4

		fld	qword [ebp+8]
		fxtract
		fstp	st0

		fistp	dword [ebp-4]
		mov	eax,[ebp-4]

		epilogue
		ret
endp		;---------------------------------------------------------------


		; The fyl2xp1 instruction has such a limited range:
		;	-(1 - (sqrt(2) / 2)) <= x <= sqrt(2) - 1
		; it's not worth trying to use it.  
		;
		; Also, I'm not sure fyl2xp1's extra precision will
		; matter once the result is converted from extended
		; real (80 bits) back to double real (64 bits).
proc _log1p
		fldln2
		fld	qword [esp+4]
		fld1
		faddp	st0
		fyl2x
		ret
endp		;---------------------------------------------------------------


proc _logb
		fld	qword [esp+4]
		fxtract
		fstp	st0
		ret
endp		;---------------------------------------------------------------


proc _rint
		fld	qword [esp+4]
		frndint
		ret
endp		;---------------------------------------------------------------


proc _scalbn
		fild	qword [esp+12]
		fld	qword [esp+4]
		fscale
		fstp	st1
		ret
endp		;---------------------------------------------------------------


proc _significand
		fld	qword [esp+4]
		fxtract
		fstp	st1
		ret
endp		;---------------------------------------------------------------


proc _sin
		fld	qword [esp+4]
		fsin
		fnstsw	ax
		and	ax,400h
		jnz	.1
		ret
.1:		fldpi
		fadd	st0
		fxch	st1
.2:		fprem1
		fnstsw	ax
		and	ax,400h
		jnz	.2
		fstp	st1
		fsin
		ret
endp		;---------------------------------------------------------------


proc _tan
		fld	qword [esp+4]
		fptan
		fnstsw	ax
		and	ax,400h
		jnz	.1
		fstp	st0
		ret
.1:		fldpi
		fadd	st0
		fxch	st1
.2:		fprem1
		fstsw	ax
		and	ax,400h
		jnz	.2
		fstp	st1
		fptan
		fstp	st0
		ret
endp		;---------------------------------------------------------------
