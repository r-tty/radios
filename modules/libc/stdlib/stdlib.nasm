
module libc.stdlib

%include "lib/stdlib.ah"

exportproc _ldiv

publicproc libc_init_stdlib

FixNeg		EQU	-1 / 2

section .text

		; ldiv_t ldiv(long numer, long denom);
proc _ldiv
		arg	_plh, numer, denom
		locauto	val, tLdiv_size
		prologue
		mpush	ecx,esi,edi
		mov	edi,[%$numer]
		mov	esi,[%$denom]
		mov	eax,edi
		mov	ecx,esi
		cdq
		idiv	ecx
		mov	[%$val+tLdiv.Quot],eax
		imul	esi,[%$val+tLdiv.Quot]
		sub	edi,esi
		mov	[%$val+tLdiv.Rem],edi
		mov	edi,FixNeg
		or	edi,edi
		jge	.NoFix
		mov	edi,[%$val+tLdiv.Quot]
		or	edi,edi
		jge	.NoFix
		mov	edi,[%$val+tLdiv.Rem]
		or	edi,edi
		je	.NoFix
		inc	dword [%$val+tLdiv.Quot]
		mov	edi,[%$denom]
		sub	[%$val+tLdiv.Rem],edi
		
.NoFix:		mov	edi,[%$_plh]
		lea	esi,[%$val]
		mov	ecx,8
		cld
		rep	movsb

		epilogue
		ret
endp		;---------------------------------------------------------------


		; Initialization
proc libc_init_stdlib
		ret
endp		;---------------------------------------------------------------
