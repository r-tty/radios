;*******************************************************************************
; keyboard.nasm - AT keyboard driver.
; Copyright (c) 1999, 2002 RET & COM Research.
;*******************************************************************************

module cons.kbd

%include "rmk.ah"
%include "errors.ah"
%include "asciictl.ah"
%include "tm/sysmsg.ah"
%include "hw/ports.ah"
%include "hw/kbc.ah"
%include "hw/kbdcodes.ah"


publicproc KB_Init, KB_ReadKey

externproc SpkClick
externproc KBC_SendKBCmd, KBC_ReadKBPort, KBC_ClrOutBuf

library $libc
importproc _ThreadCreate, _ThreadCtl
importproc _InterruptAttach, _InterruptWait
importproc _MsgSend
importproc _usleep

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
%define	KB_Prs_RCtrl		10h
%define	KB_Prs_RAlt		20h
%define	KB_Prs_CapsLock		40h
%define	KB_Prs_NumLock		80h
%define	KB_Prs_ScrollLock	100h
%define	KB_Prs_Shift		2000h
%define	KB_Prs_Ctrl		4000h
%define	KB_Prs_Alt		8000h

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

; Default keyboard layout
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

?LastKCode	RESB	1			; Last keyboard code
?AnswFlags	RESB	1			; Keyboard answers flags
?PrsFlags	RESW	1			; Keypressing flags
?SwStatus	RESB	1			; Switches status
?MiscFlags	RESB	1			; Miscellaneous flags

?InternalID	RESW	1			; Keyboard ID

?Buffer		RESW	KB_BufSize		; Keyboard FIFO buffer
?BufHead	RESB	1			; Buffer head pointer
?BufTail	RESB	1			; Buffer tail pointer

?CurrVirtCon	RESB	1			; Current virtual console

?IntThrStack	RESB	1024

section .text

		; Create the interrupt handling thread for keyboard.
proc KB_Init
		Ccall	_ThreadCreate, 0, KB_InterruptThread, 0, 0
		test	eax,eax
		js	.Err
		ret

.Err:		stc
		ret
endp		;---------------------------------------------------------------


		; Reset and initialize keyboard.
		; Input: none.
		; Output: EAX >= 0 - OK (AX=keyboard internal ID);
		;	  EAX < 0 - error.
proc KB_DetectDev
		mpush	ecx,edx
		call	KBC_ClrOutBuf

		cli
		call	KBC_ClrOutBuf
		and	byte [?AnswFlags],~KB_FlagEcho
		mov	al,KB_CmdEcho
		clc
		call	KBC_SendKBCmd			; Send "Echo" command
		jc	near .Exit
		Ccall	_usleep, dword 1000*1000h
		sti

		mov	edx,20
.Ping:		Ccall	_usleep, dword 1000*1000h	; Wait for echo ping
		test	byte [?AnswFlags],KB_FlagEcho
		jnz	.EchoOK
		dec	edx
		jnz	.Ping
		jmp	.Err

.EchoOK: 	cli
		call	KBC_ClrOutBuf
		mov	word [?InternalID],0
		or	byte [?MiscFlags],KB_flNoAnalyse
		mov	al,KB_CmdReadID			; Get KB ID
		clc
		call	KBC_SendKBCmd
		jc	.Exit
		and	byte [?AnswFlags],~KB_FlagACK
		sti

		mov	edx,100				; Wait for ID
.WaitID:	test	byte [?AnswFlags],KB_FlagACK
		jnz	.ReadID
		Ccall	_usleep, dword 100*100
		dec	edx
		jnz	.WaitID
		jmp	.Err

.ReadID:	call	KB_ReadKeyNoSched
		mov	byte [?InternalID],al
		call	KB_ReadKeyNoSched
		mov	byte [?InternalID+1],al

.IDOK:		clc

.Exit:		and	byte [?MiscFlags],~KB_flNoAnalyse
		call	KBC_ClrOutBuf
		mpop	edx,ecx
		ret

.Err:		xor	eax,eax
		dec	eax
		jmp	.Exit
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
.WaitLoop:	call	KB_GetKeyNoWait
		jz	.WaitLoop
		ret
endp		;---------------------------------------------------------------


		; KB_GetKeyNoWait - read key without waiting.
		; Input: none.
		; Output: ZF=1 - key not pressed,
		;	  ZF=0 - key pressed, AX=key code.
proc KB_GetKeyNoWait
		call	KB_KeyPressed
		jz	.Exit
		mpush	ebx,edx
		xor	ebx,ebx
		mov	bl,[?BufHead]
		mov	edx,?Buffer
		mov	ax,[edx+ebx*2]
		inc	bl
		cmp	bl,KB_BufSize
		jb	.Store
		xor	bl,bl
.Store:		mov	[?BufHead],bl
		inc	bl					; Set ZF=0
		mpop	edx,ebx
.Exit:		ret
endp		;---------------------------------------------------------------


		; KB_ClearBuf - clear keyboard buffer.
		; Input: none.
		; Output: none.
proc KB_ClearBuf
		mov	byte [?BufHead],0
		mov	byte [?BufTail],0
		ret
endp		;---------------------------------------------------------------


		; KB_KeyPressed - check the keyboard buffer on pressed key.
		; Input: none.
		; Output: ZF=0 - key pressed,
		;	  ZF=1 - key not pressed.
proc KB_KeyPressed
		push	eax
		mov	al,[?BufHead]
		cmp	al,[?BufTail]
		pop	eax
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; KB_ReadKeyNoSched - loop until key be pressed.
		; Input: none.
		; Output: AX=keycode.
proc KB_ReadKeyNoSched
.Loop:		call	KB_GetKeyNoWait
		jz	.Loop
		ret
endp		;---------------------------------------------------------------


		; KB_AnalyseKCode - convert keyboard codes into ASCII and
		;		    BIOS-compatible scan-codes.
		; Input: AL=keyboard code.
		; Output: AL=ASCII code or 0,
		;	  AH=scan code,
		;	  EDX=control keys status.
proc KB_AnalyseKCode
		mpush	ebx,edx

		xor	ah,ah
		test	byte [?MiscFlags],KB_flNoAnalyse
		jnz	near .Valid
		test	byte [?MiscFlags],KB_flPrefE0
		jnz	near .LastE0
		test	byte [?MiscFlags],KB_flPrefE1
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

.Common:	test	word [?PrsFlags],KB_Prs_Shift
		jnz	.xLatShift
		test	word [?PrsFlags],KB_Prs_Ctrl
		jnz	.xLatCtrl

		mov	ebx,KBLayoutNorm
		xlatb
		or	al,al
		jz	near .Exit
		jmp	.Valid

.xLatShift:	mov	ebx,KBLayoutShift
		xlatb
		or	al,al
		jz	near .Exit
		jmp	.Valid

.xLatCtrl:	test	word [?PrsFlags],KB_Prs_Alt
		jnz	.QCtrlAltDel
		mov	ebx,KBLayoutCtrl
		xlatb
		or	al,al
		jz	near .Exit
		jmp	.Valid


.QCtrlAltDel:	cmp	al,KB_KeypadDel
		jne	near .Exit
		call	KB_NotifyReboot
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


.LastE0:	and	byte [?MiscFlags],~KB_flPrefE0
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
		cmp	al,KB_EA_Left
		je	.QChVirtCon
		cmp	al,KB_EA_Right
		je	.QChVirtCon
		cmp	al,KB_KeypadDel
		jne	.NoDel
		test	word [?PrsFlags],KB_Prs_Ctrl+KB_Prs_Alt
		jnz	near .QCtrlAltDel
.ExtASCII:	mov	ah,al
		xor	al,al
		jmp	.Valid

.NoDel:
		jmp	.Exit
		
.QChVirtCon:	test	word [?PrsFlags],KB_Prs_LAlt
		jz	near .Exit
		mov	ah,[?CurrVirtCon]
		cmp	al,KB_EA_Left
		je	.DecVirtCon
		inc	ah
		cmp	ah,8
		jb	.SetVirtCon
		xor	ah,ah
.SetVirtCon:	mov	[?CurrVirtCon],ah
		jmp	.Exit
		
.DecVirtCon:	dec	ah
		jge	.SetVirtCon
		mov	ah,7
		jmp	.SetVirtCon

.LastE1:	and	byte [?MiscFlags],~KB_flPrefE1
		jmp	.Exit

.NowE0:		or	byte [?MiscFlags],KB_flPrefE0
		jmp	.Exit
.NowE1:		or	byte [?MiscFlags],KB_flPrefE1
		jmp	.Exit


.NowLShift:	or	word [?PrsFlags],KB_Prs_LShift+KB_Prs_Shift
		jmp	.Exit
.NowLCtrl:	or	word [?PrsFlags],KB_Prs_LCtrl+KB_Prs_Ctrl
		jmp	.Exit
.NowLAlt:	or	word [?PrsFlags],KB_Prs_LAlt+KB_Prs_Alt
		jmp	.Exit
.NowRShift:	or	word [?PrsFlags],KB_Prs_RShift+KB_Prs_Shift
		jmp	.Exit
.NowRCtrl:	or	word [?PrsFlags],KB_Prs_RCtrl+KB_Prs_Ctrl
		jmp	.Exit
.NowRAlt:	or	word [?PrsFlags],KB_Prs_RAlt+KB_Prs_Alt
		jmp	.Exit

.RelLShift:	and	word[?PrsFlags],~KB_Prs_LShift
		jmp	.RelShift
.RelLCtrl:	and	word [?PrsFlags],~KB_Prs_LCtrl
		jmp	.RelCtrl
.RelLAlt:	and	word [?PrsFlags],~KB_Prs_LAlt
		jmp	.RelAlt
.RelRShift:	and	word [?PrsFlags],~KB_Prs_RShift
		jmp	.RelShift
.RelRCtrl:	and	word [?PrsFlags],~KB_Prs_RCtrl
		jmp	.RelCtrl
.RelRAlt:	and	word [?PrsFlags],~KB_Prs_RAlt
		jmp	.RelAlt

.RelShift:	test	word [?PrsFlags],KB_Prs_LShift+KB_Prs_RShift
		jnz	near .Exit
		and	word [?PrsFlags],~KB_Prs_Shift
		jmp	.Exit
.RelCtrl:	test	word [?PrsFlags],KB_Prs_LCtrl+KB_Prs_RCtrl
		jnz	near .Exit
		and	word [?PrsFlags],~KB_Prs_Ctrl
		jmp	.Exit
.RelAlt:	test	word [?PrsFlags],KB_Prs_LAlt+KB_Prs_RAlt
		jnz	near .Exit
		and	word [?PrsFlags],~KB_Prs_Alt
		jmp	.Exit

.NowCapsLock:	test	word [?PrsFlags],KB_Prs_CapsLock
		jnz	near .Exit
		or	word [?PrsFlags],KB_Prs_CapsLock
		test	byte [?SwStatus],KB_swCapsLock
		jz	.CapsON
		and	byte [?SwStatus],~KB_swCapsLock
		jmp	.SetInd
.CapsON:	or	byte [?SwStatus],KB_swCapsLock
		jmp	.SetInd

.NowNumLock:	test	word [?PrsFlags],KB_Prs_NumLock
		jnz	near .Exit
		or	word [?PrsFlags],KB_Prs_NumLock
		test	byte [?SwStatus],KB_swNumLock
		jz	.NumON
		and	byte [?SwStatus],~KB_swNumLock
		jmp	.SetInd
.NumON:		or	byte [?SwStatus],KB_swNumLock
		jmp	.SetInd

.NowScrLock:	test	word [?PrsFlags],KB_Prs_ScrollLock
		jnz	near .Exit
		or	word [?PrsFlags],KB_Prs_ScrollLock
		test	byte [?SwStatus],KB_swScrollLock
		jz	.ScrollON
		and	byte [?SwStatus],~KB_swScrollLock
		jmp	.SetInd
.ScrollON:	or	byte [?SwStatus],KB_swScrollLock
		jmp	.SetInd

.SetInd:	call	KB_SetIndicators
		jmp	.Exit

.RelCapsLock:	and	word [?PrsFlags],~KB_Prs_CapsLock
		jmp	.Exit
.RelNumLock:	and	word [?PrsFlags],~KB_Prs_NumLock
		jmp	.Exit
.RelScrLock:	and	word [?PrsFlags],~KB_Prs_ScrollLock
		jmp	.Exit

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
		mov	bl,[?BufTail]
		inc	bl
		cmp	bl,KB_BufSize
		jb	.Check
		xor	bl,bl
.Check:		cmp	bl,[?BufHead]
		je	.Overflow
		push	ebx
		mov	edx,?Buffer
		mov	bl,[?BufTail]
		mov	[edx+ebx*2],ax
		pop	ebx
		mov	[?BufTail],bl
		clc
		jmp	.Exit

.Overflow:	call	SpkClick
		stc

.Exit:		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


		; KB_SetIndicators - keyboard indicators control.
		; Input: none.
		; Output: none.
		; Note: sets keyboard indicators status appropriate to
		;	?SwStatus variable.
proc KB_SetIndicators
		push	eax
		mov	al,KB_CmdIndCtrl
		mov	ah,[?SwStatus]
		and	ah,7
		stc
		call	KBC_SendKBCmd
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; KB_InterruptThread - thread for handling interrupts.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KB_InterruptThread
		locauto	ev, tSigEvent_size
		prologue

		; Get I/O privilege
		Ccall	_ThreadCtl, TCTL_IO, 0
		test	eax,eax
		stc
		jns	.Attach
		ret

		; Attach an interrupt event
.Attach:	lea	eax,[%$ev]
		Ccall	_InterruptAttach, 1, 0, eax, tSigEvent_size, 0
		test	eax,eax
		stc
		jns	.WaitLoop

		; Infinite loop: wait for an interrupt and handle it
.WaitLoop:	Ccall	_InterruptWait, 0, 0
		call	KBC_ReadKBPort
		mov	byte [?LastKCode],al
		cmp	al,KB_AnsBufErr
		je	.BErr
		cmp	al,KB_AnsDiagFail
		je	.DFail
		cmp	al,KB_AnsResend
		je	.Rsnd
		cmp	al,KB_AnsEcho
		je	.Echo
		cmp	al,KB_AnsACK
		je	.ACK

		call	KB_AnalyseKCode
		test	byte [?MiscFlags],KB_flNoAnalyse
		jnz	.InBuf
		or	ax,ax
		jz	.WaitLoop
		
		; Put a key in the buffer
.InBuf:		call	KB_PutInBuf
		jmp	.WaitLoop

.BErr:		or	byte [?AnswFlags],KB_FlagBufErr
		jmp	.WaitLoop
.DFail:		or	byte [?AnswFlags],KB_FlagDiagFail
		jmp	.WaitLoop
.Rsnd:		or	byte [?AnswFlags],KB_FlagResend
		jmp	.WaitLoop
.Echo:		or	byte [?AnswFlags],KB_FlagEcho
		jmp	.WaitLoop
.ACK:		or	byte [?AnswFlags],KB_FlagACK
		jmp	.WaitLoop
		epilogue
endp		;---------------------------------------------------------------


		; KB_NotifyReboot - send a SYS_CMD_REBOOT to task manager.
		; Input: none.
		; Output: none.
proc KB_NotifyReboot
		locauto msgbuf, tMsg_SysCmd_size
		prologue

		lea	edi,[%$msgbuf]
		mov	word [edi+tMsg_SysCmd.Type],SYS_CMD
		mov	word [edi+tMsg_SysCmd.Cmd],SYS_CMD_REBOOT
		Ccall	_MsgSend, SYSMGR_COID, edi, tMsg_SysCmd_size, edi, 0

		epilogue
		ret
endp		;---------------------------------------------------------------
