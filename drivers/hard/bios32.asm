;*******************************************************************************
;  bios32.asm - BIOS 32-bit services support driver.
;  Copyright (c) 1999 RET & COM research.
;*******************************************************************************


; --- Definitions ---

; BIOS32 directory structure
struc tB32dir
 Signature	DD	?			; Signature ("_32_")
 Entry		DD	?			; 32 bit physical address
 Revision	DB	?			; Revision level, 0
 Len		DB	?			; Length in paragraphs should be 01
 CheckSum	DB	?			; All bytes must add up to zero
 Reserved	DB	5 dup (?)		; Must be zero
ends

; --- Data ---
segment KDATA
; BIOS32 driver main structure
DrvBIOS32	tDriver <"%BIOS32         ",offset BIOS32ET,0>

; Driver entry points table
BIOS32ET	tDrvEntries < B32_Init,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      NULL,\
			      B32_Control >

B32_Control	DD	B32_GetInitStatStr
		DD	B32_GetParameters

; Init status string
B32str_NotDet	DB " not detected or init error",0
B32str_Entry	DB " entry at ",0
ends


; --- Variables ---
segment KVARS
B32_DirStruct	DD	0
B32_Entry	DD	0
ends


; --- Procedures ---
segment KCODE
		; B32_Init - search and initialise BIOS32.
		; Input: ESI=buffer for init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc B32_Init near
		push	ecx edx edi
		mov	edi,0E0000h
		mov	eax,"_23_"
		mov	ecx,8000h
		cld
		repne	scasd
		jnz	short @@Err1

		sub	edi,4
		mov	[B32_DirStruct],edi
		mov	eax,[edi+tB32dir.Entry]
		mov	[B32_Entry],eax

		xor	edx,edx
		call	B32_GetInitStatStr

@@Found:	clc
@@Exit:		pop	edi edx ecx
		ret

@@Err1:		mov	ax,ERR_BIOS32_NotFound
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; B32_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer ofr string.
		; Output: none.
proc B32_GetInitStatStr near
		push	esi edi
		mov	edi,esi
		mov	esi,offset DrvBIOS32.DrvName
		call	StrCopy
		call	StrEnd
		mov	ax,":	"
		stosw
		cmp	[B32_DirStruct],0
		je	short @@NotFound

		mov	esi,offset B32str_Entry
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	eax,[B32_Entry]
		call	K_HexD2Str
		mov	[word esi],'h'
		jmp	short @@Exit

@@NotFound:	mov	esi,offset B32str_NotDet
		call	StrCopy

@@Exit:		pop	edi esi
		ret
endp		;---------------------------------------------------------------


		; B32_GetParameters - get driver parameters.
		; Input:
		; Output:
proc B32_GetParameters near
		ret
endp		;---------------------------------------------------------------

ends
