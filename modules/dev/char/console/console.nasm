;*******************************************************************************
; console.nasm - RadiOS console server.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module $console

%include "sys.ah"
%include "errors.ah"
%include "asciictl.ah"
%include "module.ah"
%include "serventry.ah"
%include "rm/iofunc.ah"

; --- Exports ---

exportdata ModuleInfo

publicproc SpkClick

; --- Imports ---
library $libc
importproc _usleep

library cons.vtx
extern VTX_Init
extern VTX_MoveCursor, VTX_MoveCurNext, VTX_GetCurPos
extern VTX_WrChar, VTX_WrCharTTY
extern VTX_Scroll, VTX_ClrLine
extern ?MaxColNum, ?MaxRowNum

library cons.keyboard
extern KB_Init, KB_ReadKey

library cons.kbc
extern KBC_SpeakerON, KBC_SpeakerOFF


; --- Definitions ---

%define	NUMVIRTCONS	8			; Number of virtual consoles

; Video parameters structure
struc tConVidParm
.VidMode	RESB	1			; Video mode
.CursorShape	RESB	1			; Cursor shape
.CursorPos	RESW	1			; Cursor position
.FontPtr	RESD	1			; Font table pointer
.PrintAttr	RESB	1			; Screen attributes
.Reserved	RESB	3
endstruc

; Keyboard parameters structure
struc tConKbdParm
.Mode		RESB	1			; Mode flags
.RateDelay	RESB	1			; Keyboard rate and delay
.Switches	RESB	1			; Switches status
.Reserved	RESB	1
.Layout		RESD	1			; Keyboard layout pointer
endstruc

struc tConParm
.KbdParms	RESB	tConKbdParm_size
.VidParms	RESB	tConVidParm_size
endstruc



; --- Data ---

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
    field(Entry,	DD	CON_Main)
iend

; --- Variables ---

section .bss

?ConParmTable	RESB	tConParm_size * NUMVIRTCONS
?BeepTone	RESW	1


; --- Code ---

section .text

		; CON_Main - main loop.
proc CON_Main
		mpush	edx,esi
		mov	byte [?ConParmTable+tConParm.VidParms+tConVidParm.PrintAttr],7

		; Initialize video device and keyboard
		xor	dl,dl
		call	VTX_Init
		jc	.Exit
		call	KB_Init
		jc	.Exit

		; Default PC speaker beep tone
		mov	word [?BeepTone],1200

		jmp	$

		xor	eax,eax
.Exit:		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------



		; CON_Open - "open" console.
		; Input: EDX (high word) = console number (0 for system).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_Open
		ret
endp		;---------------------------------------------------------------


		; CON_Close - "close" console.
		; Input: EDX (high word) = console number.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CON_Close
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; CON_HandleCTRL - handle ASCII control characters.
		; Input: AL=character code.
		; Output: CF=0 - not CTRL code,
		;	  CF=1 - CTRL code (has been handled).
proc CON_HandleCTRL
		mpush	ebx,edx
		cmp	al,ASC_BEL
		je	short .BEL
		cmp	al,ASC_BS
		je	short .BS
		cmp	al,ASC_HT
		je	near .HT
		cmp	al,ASC_VT
		je	near .HT
		cmp	al,ASC_LF
		je	near .LF
		cmp	al,ASC_CR
		je	near .CR
		clc
		jmp	.Exit

.BEL:		call	SpkBell
		jmp	.Done

.BS:		call	VTX_GetCurPos
		or	dl,dl
		jz      short .BS_Up
		dec	dl
		call	VTX_MoveCursor
		jmp	.BS_Delete
.BS_Up:		or	dh,dh
		jz	near .Done
		dec	dh
		mov	dl,[?MaxColNum]
		call	VTX_MoveCursor
.BS_Delete:	push	eax
		mov	al,' '
		call	VTX_WrChar
		pop	eax
		jmp	.Done

.HT:		call	VTX_GetCurPos
		shr	dl,3
		inc	dl
		shl	dl,3
		cmp	dl,[?MaxColNum]
		jbe	.HT_Next
		mov	dl,[?MaxColNum]
		call	VTX_MoveCursor
		call	VTX_MoveCurNext
		jmp	.Done
.HT_Next:	call	VTX_MoveCursor
		jmp	.Done

.VT:		call	VTX_GetCurPos
		jmp	short .Done

.LF:		call	VTX_GetCurPos
		cmp	dh,[?MaxRowNum]
		jae	.LF_Scroll
		inc	dh
		call	VTX_MoveCursor
		jmp	short .Done

.LF_Scroll:	mov	dl,1
		call	VTX_Scroll
		push	eax
		xor	al,al
		mov	ebx,?ConParmTable
		mov	ah,[ebx+tConParm.VidParms+tConVidParm.PrintAttr]
		stc
		call	VTX_ClrLine
		pop	eax
		jmp	short .Done

.CR:		call	VTX_GetCurPos
		xor	dl,dl
		call	VTX_MoveCursor

.Done:		stc
.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; CON_Read - read one character from input device.
		; Input: none.
		; Output: AL=read character ASCII code,
		;	  AH=key scan code.
proc CON_Read
		call	KB_ReadKey
		ret
endp		;---------------------------------------------------------------


		; CON_Write - write character with CTRL handling.
		; Input: EDX (high word) = minor (console) number,
		;	 AL=character code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_Write
		call	CON_HandleCTRL
		jnc	short .NoCtrl
		cmp	al,ASC_LF
		jne	short .OK
		push	eax
		mov	al,ASC_CR
		call	CON_HandleCTRL
		pop	eax
		jmp	short .OK
.NoCtrl:	call	VTX_WrCharTTY
.OK:		clc
		ret
endp		;---------------------------------------------------------------


		; CON_WrString - write null-terminated string.
		; Input: ESI=pointer to ASCIIZ-string.
		; Output: none.
proc CON_WrString
		mpush	eax,esi
.Loop:		mov	al,[esi]
		or	al,al
		jz	short .Exit
		call	CON_Write
                inc	esi
		jmp	.Loop
.Exit:		mpop	esi,eax
		ret
endp		;---------------------------------------------------------------


		; SpkSound - make sound signal on PC-speaker.
		; Input: ECX - sound duration (in milliseconds).
proc SpkSound
		push	eax
		call	KBC_SpeakerOFF
		mov	eax,1000
		mul	ecx
		Ccall	_usleep, eax
		call	KBC_SpeakerOFF
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SpkBell - ring a "bell" (ASCII 7).
proc SpkBell
		push	ecx
		mov	ecx,350
		call	SpkSound
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; SpkClick - make a click-like sound.
proc SpkClick
		mpush	eax,ecx
	;	mChip_SpkSetFreq 300
		xor	ecx,ecx
		inc	cl
		call	SpkSound
		movzx	eax,word [?BeepTone]
	;	mChip_SpkSetFreq 
		mpop	ecx,eax
		ret
endp		;---------------------------------------------------------------
