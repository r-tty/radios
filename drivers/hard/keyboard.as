;*******************************************************************************
;  keyboard.as - AT MFII keyboard driver.
;  Copyright (c) 1999 RET & COM research.
;*******************************************************************************

module keyboard

%define extcall near

%include "driver.ah"
%include "sys.ah"
%include "hw/ports.ah"
%include "errors.ah"
%include "asciictl.ah"
%include "keydefs.ah"
%include "signal.ah"


; --- Exports ---

global DrvKeyboard


; --- Imports ---

library kernel.misc
extern K_LDelay:extcall
extern StrCopy:extcall, StrAppend:extcall
extern K_HexW2Str:extcall

library kernel.ipc
extern K_HandleEvent:extcall

library kernel.onboard
extern KBC_ClrOutBuf:near, KBC_SendKBCmd:near, KBC_ReadKBPort:near
extern SPK_Tick:near


; --- Definitions ---

; Keyboard commands
%define	KB_CmdReset		0FFh
%define	KB_CmdResend		0FEh
%define	KB_CmdSetDefault	0F6h
%define	KB_CmdDfltDisable	0F5h
%define	KB_CmdEnable		0F4h
%define	KB_CmdSetRateDelay	0F3h
%define	KB_CmdReadID		0F2h
%define	KB_CmdEcho		0EEh
%define	KB_CmdIndCtrl		0EDh
%define	KB_CmdScanDisable	0ADh
%define	KB_CmdScanEnable	0AEh

; Keyboard answers
%define	KB_AnsBufErr		0FFh
%define	KB_AnsResend		0FEh
%define	KB_AnsDiagFail		0FDh
%define	KB_AnsACK		0FAh
%define	KB_AnsKeyUp		0F0h
%define	KB_AnsEcho		0EEh

; Keyboard answer flags (KB_AnswFlags)
%define	KB_FlagACK		1
%define	KB_FlagResend		2
%define	KB_FlagTestOK		4
%define	KB_FlagDiagFail		8
%define	KB_FlagEcho		16
%define	KB_FlagBufErr		128

; Pressed key flags
%define	KB_Prs_LShift		1
%define	KB_Prs_LCtrl		2
%define	KB_Prs_LAlt		4
%define	KB_Prs_RShift		8
%define	KB_Prs_RCtrl		16
%define	KB_Prs_RAlt		32
%define	KB_Prs_CapsLock		64
%define	KB_Prs_NumLock		128
%define	KB_Prs_ScrollLock	256
%define	KB_Prs_Shift		8192
%define	KB_Prs_Ctrl		16384
%define	KB_Prs_Alt		32768

; On/off switches
%define	KB_swScrollLock		1
%define	KB_swNumLock		2
%define	KB_swCapsLock		4
%define	KB_swInsert		128

; Miscellaneous flags
%define	KB_flPrefE0		1
%define	KB_flPrefE1		2
%define	KB_flBinaryMode		64
%define	KB_flNoAnalyse		128

; Buffer length (in words)
%define	KB_BufSize		16


; --- Data ---

section .data

; Keyboard driver information structure
DrvKeyboard	DB	"%keyboard"
		TIMES	16-$+DrvKeyboard DB 0
		DD	DrvKeyboardET
		DW	DRVFL_Char

; Keyboard driver entry points table
DrvKeyboardET	DD	KB_Init
		DD	KB_HandleEv
		DD	KB_EnableScan
		DD	KB_DisableScan
		DD	KB_ReadKey
		DD	NULL
		DD	NULL
		DD	KB_Control

; Control functions
KB_Control	DD	KB_GetInitStatStr
		DD	KB_GetParameters
		DD	KB_SetParameters
		DD	KB_GetKeyNoWait
		DD	NULL
		DD	KB_ClearBuf
		DD	NULL
		DD	NULL
		DD	KB_KeyPressed

; Initialization status string
KBInfoStr	DB 9,": AT extended (MFII), internal ID=    h",0

; Keyboard layout tables
KBLayoutNorm	DB ASC_NUL,ASC_ESC,"1234567890-=",ASC_BS,ASC_HT
		DB "qwertyuiop[]",ASC_CR,0,"asdfghjkl;'`",0
		DB "\zxcvbnm,./",0,'*',0," ",0
		DB 0,0,0,0,0,0,0,0,0,0,0,0,'789-456+1230.'

KBLayoutShift	DB ASC_NUL,ASC_ESC,"!@#$%^&*()_+",ASC_BS,ASC_HT
		DB "QWERTYUIOP{}",ASC_CR,0,'ASDFGHJKL:"~',0
		DB "|ZXCVBNM<>?",0,'*',0," ",0
		DB 0,0,0,0,0,0,0,0,0,0,0,0,'789-456+1230.'

KBLayoutCtrl	DB ASC_NUL,ASC_ESC,0,0,0,0,0,1Eh,0,0,0,0
		DB 4Eh,55h,07Fh,0
		DB 11h,17h,5,12h,14h,19h,15h,9,0Fh,10h,1Bh,1Dh,0Ah,0
		DB 1,13h,4,6,7,8,0Ah,8,0Ch,0,0,0,0
		DB 1Ch,1Ah,18h,3,16h,2,0Eh,0Dh,0,0,0,0,0,0," ",0



; --- Variables ---

section .bss

KB_LastKCode	RESB	1			; Last keyboard code
KB_AnswFlags	RESB	1			; Keyboard answers flags
KB_PrsFlags	RESW	1			; Keypressing flags
KB_SwStatus	RESB	1			; Switches status
KB_MiscFlags	RESB	1			; Miscellaneous flags

KB_InternalID	RESW	1			; Keyboard ID

KB_Buffer	RESW	KB_BufSize		; Keyboard FIFO buffer
KB_BufHead	RESB	1			; Buffer head pointer
KB_BufTail	RESB	1			; Buffer tail pointer


; --- Procedures ---

section .text

		; KB_Init - reset and initialize keyboard.
		; Input: none.
		; Output: CF=0 - OK, AX=keyboard internal ID;
		;	  CF=1 - error, AX=error code.
proc KB_Init
		mpush	ecx,edx
		call	KBC_ClrOutBuf

		cli
		call	KBC_ClrOutBuf
		and	byte [KB_AnswFlags],~KB_FlagEcho
		mov	al,KB_CmdEcho
		clc
		call	KBC_SendKBCmd			; Send "Echo" command
		jc	near .Exit
		mov	ecx,1000h
		call	K_LDelay
		sti

		mov	edx,20
.Ping:		mov	ecx,1000h			; Wait for echo ping
		call	K_LDelay
		test	byte [KB_AnswFlags],KB_FlagEcho
		jnz	short .EchoOK
		dec	edx
		jnz	.Ping
		jmp	.Err

.EchoOK: 	cli
		call	KBC_ClrOutBuf
		mov	word [KB_InternalID],0
		or	byte [KB_MiscFlags],KB_flNoAnalyse
		mov	al,KB_CmdReadID			; Get KB ID
		clc
		call	KBC_SendKBCmd
		jc	short .Exit
		and	byte [KB_AnswFlags],~KB_FlagACK
		sti

		mov	edx,100				; Wait for ID
.WaitID:	test	byte [KB_AnswFlags],KB_FlagACK
		jnz	short .ReadID
		mov	ecx,100
		call	K_LDelay
		dec	edx
		jnz	.WaitID
		jmp	short .Err

.ReadID:	call	KB_ReadKey
		mov	byte [KB_InternalID],al
		call	KB_ReadKey
		mov	byte [KB_InternalID+1],al

.IDOK:		clc

.Exit:		sti
		pushfd
		and	byte [KB_MiscFlags],~KB_flNoAnalyse
		call	KBC_ClrOutBuf
		popfd
		mpop	edx,ecx
		ret

.Err:		mov	ax,ERR_KB_DetFail
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; KB_HandleEv - handle keyboard events.
		; Input: EAX=event code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KB_HandleEv
		cmp	eax,(EV_IRQ << 16)+1
		jne	.Err
		push	eax
		call	KBC_ReadKBPort
		mov	byte [KB_LastKCode],al

		cmp	al,KB_AnsBufErr
		je	short .BErr
		cmp	al,KB_AnsDiagFail
		je	short .DFail
		cmp	al,KB_AnsResend
		je	short .Rsnd
		cmp	al,KB_AnsEcho
		je	short .Echo
		cmp	al,KB_AnsACK
		je	short .ACK

		call	KB_AnalyseKCode
		test	byte [KB_MiscFlags],KB_flNoAnalyse
		jnz	short .InBuf
		or	ax,ax
		jz	short .Done
.InBuf:		call	KB_PutInBuf
		jmp	short .Done

.BErr:		or	byte [KB_AnswFlags],KB_FlagBufErr
		jmp	short .Done
.DFail:		or	byte [KB_AnswFlags],KB_FlagDiagFail
		jmp	short .Done
.Rsnd:		or	byte [KB_AnswFlags],KB_FlagResend
		jmp	short .Done
.Echo:		or	byte [KB_AnswFlags],KB_FlagEcho
		jmp	short .Done
.ACK:		or	byte [KB_AnswFlags],KB_FlagACK
.Done:		pop	eax
		clc
		ret
.Err:		mov	ax,ERR_UnknEv
		stc
		ret
endp		;---------------------------------------------------------------


		; KB_EnableScan - send command "enable scanning" to keyboard.
		; Input: none.
		; Output: none.
proc KB_EnableScan
		mov	al,KB_CmdScanEnable
		clc
		call	KBC_SendKBCmd
		ret
endp		;---------------------------------------------------------------


		; KB_DisableScan - send command "disable scanning" to keyboard.
		; Input: none.
		; Output: none.
proc KB_DisableScan
		mov	al,KB_CmdScanDisable
		clc
		call	KBC_SendKBCmd
		ret
endp		;---------------------------------------------------------------


		; KB_ReadKey - wait until a key will be pressed and read it.
		; Input: none.
		; Output: AX=pressed key code.
proc KB_ReadKey
.Loop:		call	KB_GetKeyNoWait
		jz	.Loop
		ret
endp		;---------------------------------------------------------------


		; KB_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc KB_GetInitStatStr
		mpush	esi,edi
		push	esi
		mov	ax,[KB_InternalID]
		mov	edi,KBInfoStr
		lea	esi,[edi+35]			; Convert ID
		call	K_HexW2Str			; into string
		mov	word [esi],'h'
		pop	edi
		mov	esi,DrvKeyboard
		call	StrCopy
		mov	esi,KBInfoStr
		call	StrAppend
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; KB_GetParameters - get keyboard parameters.
		; Input: none.
		; Output:
proc KB_GetParameters
		ret
endp		;---------------------------------------------------------------


		; KB_SetParameters - set keyboard parameters.
		; Input:
		; Output: none.
proc KB_SetParameters
		ret
endp		;---------------------------------------------------------------


		; KB_GetKeyNoWait - read key without waiting.
		; Input: none.
		; Output: ZF=0 - key not pressed,
		;	  ZF=1 - key pressed, AX=key code.
proc KB_GetKeyNoWait
		call	KB_KeyPressed
		jz	short .Exit
		mpush	ebx,edx
		xor	ebx,ebx
		mov	bl,[KB_BufHead]
		mov	edx,offset KB_Buffer
		mov	ax,[edx+ebx*2]
		inc	bl
		cmp	bl,KB_BufSize
		jb	.Store
		xor	bl,bl
.Store:		mov	[KB_BufHead],bl
		inc	bl					; Set ZF=0
		mpop	edx,ebx
.Exit:		ret
endp		;---------------------------------------------------------------


		; KB_ClearBuf - clear keyboard buffer.
		; Input: none.
		; Output: none.
proc KB_ClearBuf
		mov	byte [KB_BufHead],0
		mov	byte [KB_BufTail],0
		ret
endp		;---------------------------------------------------------------


		; KB_KeyPressed - check the keyboard buffer on pressed key.
		; Input: none.
		; Output: ZF=0 - key pressed,
		;	  ZF=1 - key not pressed.
proc KB_KeyPressed
		push	eax
		mov	al,[KB_BufHead]
		cmp	al,[KB_BufTail]
		pop	eax
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; KB_AnalyseKCode - convert keyboard codes into ASCII and
		;		    BIOS-compatible scan-codes.
		; Input: AL=keyboard code.
		; Output: AL=ASCII code or 0,
		;	  AH=scan code,
		;	  EDX=control keys status.
proc KB_AnalyseKCode
		mpush	ebx,edx

		xor	ah,ah
		test	byte [KB_MiscFlags],KB_flNoAnalyse
		jnz	near .Valid
		test	byte [KB_MiscFlags],KB_flPrefE0
		jnz	near .LastE0
		test	byte [KB_MiscFlags],KB_flPrefE1
		jnz	near .LastE1

		cmp	al,0E0h
		je	near .NowE0
		cmp	al,0E1h
		je	near .NowE1
		cmp	al,KB_LShift
		je	near .NowLShift
		cmp	al,KB_RShift
		je	near .NowRShift
		cmp	al,KB_Ctrl
		je	near .NowLCtrl
		cmp	al,KB_Alt
		je	near .NowLAlt
		cmp	al,KB_CapsLock
		je	near .NowCapsLock
		cmp	al,KB_NumLock
		je	near .NowNumLock
		cmp	al,KB_ScrollLock
		je	near .NowScrLock

		test	al,80h
		jnz	near .Release

.Common:	test	word [KB_PrsFlags],KB_Prs_Shift
		jnz	short .xLatShift
		test	word [KB_PrsFlags],KB_Prs_Ctrl
		jnz	short .xLatCtrl

		mov	ebx,offset KBLayoutNorm
		xlatb
		or	al,al
		jz	near .Exit
		jmp	.Valid

.xLatShift:	mov	ebx,offset KBLayoutShift
		xlatb
		or	al,al
		jz	near .Exit
		jmp	.Valid

.xLatCtrl:	test	word [KB_PrsFlags],KB_Prs_Alt
		jnz	short .QCtrlAltDel
		mov	ebx,KBLayoutCtrl
		xlatb
		or	al,al
		jz	near .Exit
		jmp	.Valid


.QCtrlAltDel:	cmp	al,KB_KeypadDel
		jne	near .Exit
		mov	eax,(EV_SIGNAL << 16)+SIG_CTRLALTDEL
		xor	edx,edx				; PID=0 (kernel)
		call	K_HandleEvent
		jmp	.Exit

.Release:	cmp	al,KB_LShift+80h
		je	near .RelLShift
		cmp	al,KB_RShift+80h
		je	near .RelRShift
		cmp	al,KB_Ctrl+80h
		je	near .RelLCtrl
		cmp	al,KB_Alt+80h
		je	near .RelLAlt
		cmp	al,KB_NumLock+80h
		je	near .RelNumLock
		cmp	al,KB_CapsLock+80h
		je	near .RelCapsLock
		cmp	al,KB_ScrollLock+80h
		je	near .RelScrLock
		jmp	.Exit


.LastE0:	and	byte [KB_MiscFlags],~KB_flPrefE0
		cmp	al,KB_Ctrl
		je	near .NowRCtrl
		cmp	al,KB_Alt
		je	near .NowRAlt
		cmp	al,KB_Ctrl+80h
		je	near .RelRCtrl
		cmp	al,KB_Alt+80h
		je	near .RelRAlt
		cmp	al,KB_KeypadEnter
		je	near .Common
		cmp	al,KB_KeypadSlash
		je	near .Common
		cmp	al,KB_KeypadDel
		jne	short .NoDel
		test	word [KB_PrsFlags],KB_Prs_Ctrl+KB_Prs_Alt
		jnz	near .QCtrlAltDel
.ExtASCII:	mov	ah,al
		xor	al,al
		jmp	.Valid

.NoDel:
		jmp	.Exit

.LastE1:	and	byte [KB_MiscFlags],~KB_flPrefE1
		jmp	.Exit

.NowE0:		or	byte [KB_MiscFlags],KB_flPrefE0
		jmp	.Exit
.NowE1:		or	byte [KB_MiscFlags],KB_flPrefE1
		jmp	.Exit


.NowLShift:	or	word [KB_PrsFlags],KB_Prs_LShift+KB_Prs_Shift
		jmp	.Exit
.NowLCtrl:	or	word [KB_PrsFlags],KB_Prs_LCtrl+KB_Prs_Ctrl
		jmp	.Exit
.NowLAlt:	or	word [KB_PrsFlags],KB_Prs_LAlt+KB_Prs_Alt
		jmp	.Exit
.NowRShift:	or	word [KB_PrsFlags],KB_Prs_RShift+KB_Prs_Shift
		jmp	.Exit
.NowRCtrl:	or	word [KB_PrsFlags],KB_Prs_RCtrl+KB_Prs_Ctrl
		jmp	.Exit
.NowRAlt:	or	word [KB_PrsFlags],KB_Prs_RAlt+KB_Prs_Alt
		jmp	.Exit

.RelLShift:	and	word[KB_PrsFlags],~KB_Prs_LShift
		jmp	short .RelShift
.RelLCtrl:	and	word [KB_PrsFlags],~KB_Prs_LCtrl
		jmp	short .RelCtrl
.RelLAlt:	and	word [KB_PrsFlags],~KB_Prs_LAlt
		jmp	short .RelAlt
.RelRShift:	and	word [KB_PrsFlags],~KB_Prs_RShift
		jmp	short .RelShift
.RelRCtrl:	and	word [KB_PrsFlags],~KB_Prs_RCtrl
		jmp	short .RelCtrl
.RelRAlt:	and	word [KB_PrsFlags],~KB_Prs_RAlt
		jmp	short .RelAlt

.RelShift:	test	word [KB_PrsFlags],KB_Prs_LShift+KB_Prs_RShift
		jnz	near .Exit
		and	word [KB_PrsFlags],~KB_Prs_Shift
		jmp	.Exit
.RelCtrl:	test	word [KB_PrsFlags],KB_Prs_LCtrl+KB_Prs_RCtrl
		jnz	near .Exit
		and	word [KB_PrsFlags],~KB_Prs_Ctrl
		jmp	.Exit
.RelAlt:	test	word [KB_PrsFlags],KB_Prs_LAlt+KB_Prs_RAlt
		jnz	near .Exit
		and	word [KB_PrsFlags],~KB_Prs_Alt
		jmp	.Exit

.NowCapsLock:	test	word [KB_PrsFlags],KB_Prs_CapsLock
		jnz	near .Exit
		or	word [KB_PrsFlags],KB_Prs_CapsLock
		test	byte [KB_SwStatus],KB_swCapsLock
		jz	.CapsON
		and	byte [KB_SwStatus],~KB_swCapsLock
		jmp	.SetInd
.CapsON:	or	byte [KB_SwStatus],KB_swCapsLock
		jmp	.SetInd

.NowNumLock:	test	word [KB_PrsFlags],KB_Prs_NumLock
		jnz	near .Exit
		or	word [KB_PrsFlags],KB_Prs_NumLock
		test	byte [KB_SwStatus],KB_swNumLock
		jz	.NumON
		and	byte [KB_SwStatus],~KB_swNumLock
		jmp	short .SetInd
.NumON:		or	byte [KB_SwStatus],KB_swNumLock
		jmp	short .SetInd

.NowScrLock:	test	word [KB_PrsFlags],KB_Prs_ScrollLock
		jnz	near .Exit
		or	word [KB_PrsFlags],KB_Prs_ScrollLock
		test	byte [KB_SwStatus],KB_swScrollLock
		jz	.ScrollON
		and	byte [KB_SwStatus],~KB_swScrollLock
		jmp	short .SetInd
.ScrollON:	or	byte [KB_SwStatus],KB_swScrollLock
		jmp	short .SetInd

.SetInd:	call	KB_SetIndicators
		jmp	short .Exit

.RelCapsLock:	and	word [KB_PrsFlags],~KB_Prs_CapsLock
		jmp	short .Exit
.RelNumLock:	and	word [KB_PrsFlags],~KB_Prs_NumLock
		jmp	short .Exit
.RelScrLock:	and	word [KB_PrsFlags],~KB_Prs_ScrollLock
		jmp	short .Exit

.Exit:		xor	ax,ax
.Valid:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; KB_PutInBuf - put a key code into the keyboard buffer.
		; Input: AX=key code.
		; Output: CF=0 - OK,
		;	  CF=1 - buffer overflow.
		; Note: beep if buffer overflow.
proc KB_PutInBuf
		mpush	ebx,edx
		xor	ebx,ebx
		mov	bl,[KB_BufTail]
		inc	bl
		cmp	bl,KB_BufSize
		jb	short .Check
		xor	bl,bl
.Check:		cmp	bl,[KB_BufHead]
		je	.Overflow
		push	ebx
		mov	edx,KB_Buffer
		mov	bl,[KB_BufTail]
		mov	[edx+ebx*2],ax
		pop	ebx
		mov	[KB_BufTail],bl
		clc
		jmp	short .Exit

.Overflow:	call	SPK_Tick
		stc

.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; KB_SetIndicators - keyboard indicators control.
		; Input: none.
		; Output: none.
		; Note: sets keyboard indicators status appropriate to
		;	KB_SwStatus variable.
proc KB_SetIndicators
		push	eax
		mov	al,KB_CmdIndCtrl
		mov	ah,[KB_SwStatus]
		and	ah,7
		stc
		call	KBC_SendKBCmd
		pop	eax
		ret
endp		;---------------------------------------------------------------

