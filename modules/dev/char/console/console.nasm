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
%include "rm/ftype.ah"
%include "rm/stat.ah"
%include "rm/resmgr.ah"
%include "rm/iofunc.ah"
%include "rm/dispatch.ah"


exportdata ModuleInfo
publicproc SpkClick

externproc KB_Init, KB_ReadKey
externproc KBC_SpeakerON, KBC_SpeakerOFF
externproc VTX_Init
externproc VTX_MoveCursor, VTX_MoveCurNext, VTX_GetCurPos
externproc VTX_WrChar, VTX_WrCharTTY
externproc VTX_Scroll, VTX_ClrLine
externdata ?MaxColNum, ?MaxRowNum

library $libc
importproc _memset, _usleep, _ThreadCtl

library $librm
importproc RM_InitHandlers, RM_InitAttributes
importproc RM_AttachName, RM_HandleMsg
importproc RM_AllocDesc, RM_AllocContext
importproc RM_WaitMsg


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



section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	MODFLAGS_RESMGR)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
    field(Entry,	DD	CON_Main)
iend

TxtRegistering	DB	"Registering "
ConDevPath	DB	"%console",0
Txt~IOpriv	DB	"Unable to get I/O privileges",0
Txt~InitVideo	DB	"Video device init error",NL,0
Txt~InitKbd	DB	"Keyboard device init error",NL,0
Txt~AllocDesc	DB	"Unable to allocate descriptor",NL,0
Txt~AttachName	DB	"Unable to attach name",NL,0
Txt~WaitMsg	DB	"RM_WaitMsg error",NL,0

section .bss

?ConParmTable	RESB	tConParm_size * NUMVIRTCONS
?BeepTone	RESW	1
?ConnectFuncs	RESB	tResMgrConnectFunctions_size
?IOfuncs	RESB	tResMgrIOfunctions_size
?Attr		RESB	tIOfuncAttr_size

section .text

		; CON_Main - initialization and main loop.
proc CON_Main
		arg	argc, argv
		locauto	rmattr, tResMgrAttr_size
		locals	dpp, id
		prologue

		mServPrintStr TxtRegistering

		mov	byte [?ConParmTable+tConParm.VidParms+tConVidParm.PrintAttr],7

		; Get I/O privileges
		Ccall	_ThreadCtl, TCTL_IO, 0
		test	eax,eax
		js	near .ErrIOpriv

		; Initialize video device and keyboard
		call	VTX_Init
		jc	near .ErrVidInit
		call	KB_Init
		jc	near .ErrKbdInit

		; Default PC speaker beep tone
		mov	word [?BeepTone],1200

		; Allocate the descriptor
		call	RM_AllocDesc
		jc	near .Err1
		mov	[%$dpp],eax

		; Initialize resource manager attributes
		lea	edi,[%$rmattr]
		Ccall	_memset, edi, 0, tResMgrAttr_size
		mov	dword [edi+tResMgrAttr.NpartsMax],1
		mov	dword [edi+tResMgrAttr.MsgMaxSize],2048

		; Initialize functions for handling messages
		mov	ecx,RESMGR_CONNECT_NFUNCS + (RESMGR_IO_NFUNCS << 16)
		mov	ebx,?ConnectFuncs
		mov	edx,?IOfuncs
		call	RM_InitHandlers

		; Initialize device attributes
		mov	ebx,?Attr
		mov	eax,ST_MODE_IFNAM | 1B6h
		call	RM_InitAttributes

		; Attach device name
		mov	eax,[%$dpp]
		mov	esi,ConDevPath
		mov	ecx,FTYPE_ANY
		mov	ebx,?ConnectFuncs
		mov	edx,?IOfuncs
		push	?Attr
		call	RM_AttachName
		jc	.Err2
		mov	edx,eax

		; Allocate a context structure
		mov	eax,[%$dpp]
		call	RM_AllocContext
		mov	ebx,eax

		; Start the message processing loop
.Loop:		call	RM_WaitMsg
		jc	.Err3
		mov	ebx,eax
		call	RM_HandleMsg
		jmp	.Loop

.Exit:		epilogue
		ret

.ErrIOpriv:	mServPrintStr Txt~IOpriv
		jmp	.Exit
.ErrVidInit:	mServPrintStr Txt~InitVideo
		jmp	.Exit
.ErrKbdInit:	mServPrintStr Txt~InitKbd
		jmp	.Exit
.Err1:		mServPrintStr Txt~AllocDesc
		jmp	.Exit
.Err2:		mServPrintStr Txt~AttachName
		jmp	.Exit
.Err3:		mServPrintStr Txt~WaitMsg
		jmp	.Exit
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
