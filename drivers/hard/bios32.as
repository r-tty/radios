;*******************************************************************************
;  bios32.asm - BIOS 32-bit services support driver.
;  Copyright (c) 1999 RET & COM research.
;*******************************************************************************

module bios32

%define extcall near

%include "sys.ah"
%include "errors.ah"


; --- Exports ---

global DrvBIOS32


; --- Imports ---

library kernel.misc
extern StrCopy:extcall, StrEnd:extcall
extern K_HexD2Str:extcall


; --- Definitions ---

; BIOS32 directory structure
struc tB32dir
.Signature	RESD	1			; Signature ("_32_")
.Entry		RESD	1			; 32 bit physical address
.Revision	RESB	1			; Revision level, 0
.Len		RESB	1			; Length in paragraphs should be 01
.CheckSum	RESB	1			; All bytes must add up to zero
.Reserved	RESB	5			; Must be zero
endstruc

; --- Data ---

section .data

; BIOS32 driver main structure
DrvBIOS32	DB	"%BIOS32"
		TIMES	16-$+DrvBIOS32 DB 0
		DD	BIOS32ET
		DW	0

; Driver entry points table
BIOS32ET	DD	B32_Init
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	B32_Control

B32_Control	DD	B32_GetInitStatStr
		DD	B32_GetParameters

; Init status string
B32str_NotDet	DB " not detected or init error",0
B32str_Entry	DB " entry at ",0


; --- Variables ---

section .bss

B32_DirStruct	RESD	1
B32_Entry	RESD	1


; --- Procedures ---

section .text

		; B32_Init - search and initialize BIOS32.
		; Input: ESI=buffer for init status string.
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

		call	B32_GetInitStatStr

.Found:		clc
.Exit:		mpop	edi,ecx
		ret

.Err1:		mov	ax,ERR_BIOS32_NotFound
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; B32_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer address.
		; Output: none.
proc B32_GetInitStatStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,DrvBIOS32
		call	StrCopy
		call	StrEnd
		mov	ax,"	:"
		stosw
		cmp	dword [B32_DirStruct],0
		je	short .NotFound

		mov	esi,B32str_Entry
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	eax,[B32_Entry]
		call	K_HexD2Str
		mov	word [esi],'h'
		jmp	short .Exit

.NotFound:	mov	esi,B32str_NotDet
		call	StrCopy

.Exit:		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; B32_GetParameters - get driver parameters.
		; Input:
		; Output:
proc B32_GetParameters
		ret
endp		;---------------------------------------------------------------

