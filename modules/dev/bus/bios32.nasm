;-------------------------------------------------------------------------------
; bios32.nasm - routines for accessing BIOS 32-bit entry point.
;-------------------------------------------------------------------------------

module bios32

%include "sys.ah"
%include "errors.ah"

; BIOS32 directory structure
struc tB32dir
.Signature	RESD	1			; Signature ("_32_")
.Entry		RESD	1			; 32 bit physical address
.Revision	RESB	1			; Revision level, 0
.Len		RESB	1			; Length in paragraphs should be 01
.CheckSum	RESB	1			; All bytes must add up to zero
.Reserved	RESB	5			; Must be zero
endstruc

section .bss

B32_DirStruct	RESD	1
B32_Entry	RESD	1


section .text

		; B32_Init - search and initialize BIOS32.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc B32_Init
		mpush	ecx,edi
		mov	edi,0E0000h
		mov	eax,"_32_"
		mov	ecx,8000h
		cld
		repne	scasd
		jnz	.Err1

		sub	edi,byte 4
		mov	[B32_DirStruct],edi
		mov	eax,[edi+tB32dir.Entry]
		mov	[B32_Entry],eax
		clc
		
.Exit:		mpop	edi,ecx
		ret

.Err1:		mov	ax,ERR_BIOS32_NotFound
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------
