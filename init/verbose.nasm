;
; verbose.nasm - some printing routines.
;

section .data

string MsgModTypes,	"elk?"
string MsgHspace,	"h  "

section .text

		; INIT_PrintModInfo - print some information about a module.
		; Input: EDI=module descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_PrintModInfo
		mpush	ebx,esi
		lea	esi,[edi+tModuleDesc.ModName]
		mServPrintStrPad esi,24
		mov	ebx,MsgModTypes
		mov	al,[edi+tModuleDesc.Type]
		xlatb
		mServPrintChar
		mServPrintChar HTAB
		mServPrintDec [edi+tModuleDesc.Size]
		mServPrintChar HTAB
		mServPrint32h [edi+tModuleDesc.CodeSect]
		mServPrintStr MsgHspace
		mServPrint32h [edi+tModuleDesc.DataSect]
		mServPrintStr MsgHspace
		mServPrint32h [edi+tModuleDesc.BSS_Sect]
		mServPrintChar 'h'
		mServPrintChar NL
		mpop	esi,ebx
		ret
endp		;---------------------------------------------------------------
