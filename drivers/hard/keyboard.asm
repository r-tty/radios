;*******************************************************************************
;  keyboard.asm - AT MFII keyboard driver.
;  Copyright (c) 1998 RET & COM research.
;*******************************************************************************

include "asciictl.ah"
include "keydefs.ah"
include "signal.ah"


; --- Definitions ---

; Keyboard commands
KB_CmdReset		EQU	0FFh
KB_CmdResend		EQU	0FEh
KB_CmdSetDefault	EQU	0F6h
KB_CmdDfltDisable	EQU	0F5h
KB_CmdEnable		EQU	0F4h
KB_CmdSetRateDelay	EQU	0F3h
KB_CmdReadID		EQU	0F2h
KB_CmdEcho		EQU	0EEh
KB_CmdIndCtrl		EQU	0EDh
KB_CmdScanDisable	EQU	0ADh
KB_CmdScanEnable	EQU	0AEh

; Keyboard answers
KB_AnsBufErr		EQU	0FFh
KB_AnsResend		EQU	0FEh
KB_AnsDiagFail		EQU	0FDh
KB_AnsACK		EQU	0FAh
KB_AnsKeyUp		EQU	0F0h
KB_AnsEcho		EQU	0EEh

; Keyboard answer flags (KB_AnswFlags)
KB_FlagACK		EQU	1
KB_FlagResend		EQU	2
KB_FlagTestOK		EQU	4
KB_FlagDiagFail		EQU	8
KB_FlagEcho		EQU	16
KB_FlagBufErr		EQU	128

; Pressed key flags
KB_Prs_LShift		EQU	1
KB_Prs_LCtrl		EQU	2
KB_Prs_LAlt		EQU	4
KB_Prs_RShift		EQU	8
KB_Prs_RCtrl		EQU	16
KB_Prs_RAlt		EQU	32
KB_Prs_CapsLock		EQU	64
KB_Prs_NumLock		EQU	128
KB_Prs_ScrollLock	EQU	256
KB_Prs_Shift		EQU	8192
KB_Prs_Ctrl		EQU	16384
KB_Prs_Alt		EQU	32768

; On/off switches
KB_swScrollLock		EQU	1
KB_swNumLock		EQU	2
KB_swCapsLock		EQU	4
KB_swInsert		EQU	128

; Miscellaneous flags
KB_flPrefE0		EQU	1
KB_flPrefE1		EQU	2
KB_flBinaryMode		EQU	64
KB_flNoAnalyse		EQU	128

; Buffer length (in words)
KB_BufSize		EQU	16


; --- Data ---

segment KDATA
; Keyboard driver information structure
DrvKeyboard	tDriver <"%keyboard       ",offset DrvKeyboardET,DRVFL_Char>

; Keyboard driver entry points table
DrvKeyboardET	tDrvEntries < KB_Init,\
			      KB_HandleEv,\
			      KB_EnableScan,\
			      KB_DisableScan,\
			      KB_ReadKey,\
			      NULL,\
			      NULL,\
			      KB_Control >

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

; Driver information string
KBInfoStr		DB 9,": AT extended (MFII), internal ID=    h",0

; Keyboard layout tables
KBLayoutNorm		DB ASC_NUL,ASC_ESC,"1234567890-=",ASC_BS,ASC_HT
			DB "qwertyuiop[]",ASC_CR,0,"asdfghjkl;'`",0
			DB "\zxcvbnm,./",0,'*',0," ",0
			DB 0,0,0,0,0,0,0,0,0,0,0,0,'789-456+1230.'
			
KBLayoutShift		DB ASC_NUL,ASC_ESC,"!@#$%^&*()_+",ASC_BS,ASC_HT
			DB "QWERTYUIOP{}",ASC_CR,0,'ASDFGHJKL:"~',0
			DB "|ZXCVBNM<>?",0,'*',0," ",0
			DB 0,0,0,0,0,0,0,0,0,0,0,0,'789-456+1230.'

KBLayoutCtrl		DB ASC_NUL,ASC_ESC,0,0,0,0,0,1Eh,0,0,0,0
			DB 4Eh,55h,07Fh,0
			DB 11h,17h,5,12h,14h,19h,15h,9,0Fh,10h,1Bh,1Dh,0Ah,0
			DB 1,13h,4,6,7,8,0Ah,8,0Ch,0,0,0,0
			DB 1Ch,1Ah,18h,3,16h,2,0Eh,0Dh,0,0,0,0,0,0," ",0
ends


; --- Keyboard variables ---
segment KVARS
KB_LastKCode		DB	0		; Last keyboard code
KB_AnswFlags		DB	0		; Keyboard answers flags
KB_PrsFlags		DW	0		; Keypressing flags
KB_SwStatus		DB	0		; Switches status
KB_MiscFlags		DB	0		; Miscellaneous flags

KB_InternalID		DW	0		; Keyboard ID

KB_Buffer		DW KB_BufSize dup (0)	; Keyboard FIFO buffer
KB_BufHead		DB	0		; Buffer head pointer
KB_BufTail		DB	0		; Buffer tail pointer
ends

; --- Procedures ---

		; KB_Init - reset and initialize keyboard.
		; Input: ESI=buffer for init status string.
		; Output: CF=0 - OK, AX=keyboard internal ID;
		;	  CF=1 - error, AX=error code.
proc KB_Init near
		push	ecx edx
		call	KBC_ClrOutBuf

		cli
		call	KBC_ClrOutBuf
		and	[KB_AnswFlags],not KB_FlagEcho
		mov	al,KB_CmdEcho
		clc
		call	KBC_SendKBCmd			; Send "Echo" command
		jc	@@Exit
		mov	ecx,1000h
		call	K_LDelay
		sti

		mov	edx,20
@@Ping:		mov	ecx,1000h			; Wait for echo ping
		call	K_LDelay
		test	[KB_AnswFlags],KB_FlagEcho
		jnz	short @@EchoOK
		dec	edx
		jnz	@@Ping
		jmp	@@Err

@@EchoOK: 	cli
		call	KBC_ClrOutBuf
		mov	[KB_InternalID],0
		or	[KB_MiscFlags],KB_flNoAnalyse
		mov	al,KB_CmdReadID			; Get KB ID
		clc
		call	KBC_SendKBCmd
		jc	short @@Exit
		and	[KB_AnswFlags],not KB_FlagACK
		sti

		mov	edx,100				; Wait for ID
@@WaitID:	test	[KB_AnswFlags],KB_FlagACK
		jnz	short @@ReadID
		mov	ecx,100
		call	K_LDelay
		dec	edx
		jnz	@@WaitID
		jmp	short @@Err

@@ReadID:	call	KB_ReadKey
		mov	[byte low KB_InternalID],al
		call	KB_ReadKey
		mov	[byte high KB_InternalID],al

@@IDOK:		call	KB_GetInitStatStr
		clc

@@Exit:		sti
		pushfd
		and	[KB_MiscFlags],not KB_flNoAnalyse
		call	KBC_ClrOutBuf
		popfd
		pop	edx ecx
		ret

@@Err:		mov	ax,ERR_KB_DetFail
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; KB_HandleEv - handle keyboard events.
		; Input: EAX=event code.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc KB_HandleEv near
		cmp	eax,EV_IRQ+1
		jne	@@Err
		push	eax
		call	KBC_ReadKBPort
		mov	[KB_LastKCode],al

		cmp	al,KB_AnsBufErr
		je	short @@BErr
		cmp	al,KB_AnsDiagFail
		je	short @@DFail
		cmp	al,KB_AnsResend
		je	short @@Rsnd
		cmp	al,KB_AnsEcho
		je	short @@Echo
		cmp	al,KB_AnsACK
		je	short @@ACK

		call	KB_AnalyseKCode
		test	[KB_MiscFlags],KB_flNoAnalyse
		jnz	short @@InBuf
		or	ax,ax
		jz	short @@Done
@@InBuf:	call	KB_PutInBuf
		jmp	short @@Done

@@BErr:		or	[KB_AnswFlags],KB_FlagBufErr
		jmp	short @@Done
@@DFail:	or	[KB_AnswFlags],KB_FlagDiagFail
		jmp	short @@Done
@@Rsnd:		or	[KB_AnswFlags],KB_FlagResend
		jmp	short @@Done
@@Echo:		or	[KB_AnswFlags],KB_FlagEcho
		jmp	short @@Done
@@ACK:		or	[KB_AnswFlags],KB_FlagACK
@@Done:		pop	eax
		clc
		ret
@@Err:		mov	ax,ERR_UnknEv
		stc
		ret
endp		;---------------------------------------------------------------


		; KB_EnableScan - send command "enable scanning" to keyboard.
		; Input: none.
		; Output: none.
proc KB_EnableScan near
		mov	al,KB_CmdScanEnable
		clc
		call	KBC_SendKBCmd
		ret
endp		;---------------------------------------------------------------


		; KB_DisableScan - send command "disable scanning" to keyboard.
		; Input: none.
		; Output: none.
proc KB_DisableScan near
		mov	al,KB_CmdScanDisable
		clc
		call	KBC_SendKBCmd
		ret
endp		;---------------------------------------------------------------


		; KB_ReadKey - wait until a key will be pressed and read it.
		; Input: none.
		; Output: AX=pressed key code.
proc KB_ReadKey near
@@Loop:		call	KB_GetKeyNoWait
		jz	@@Loop
		ret
endp		;---------------------------------------------------------------


		; KB_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc KB_GetInitStatStr near
		push	esi edi
		push	esi
		mov	ax,[KB_InternalID]
		mov	edi,offset KBInfoStr
		lea	esi,[edi+35]			; Convert ID
		call	K_HexW2Str			; into string
		mov	[word esi],'h'
		pop	edi
		mov	esi,offset DrvKeyboard.DrvName
		call	StrCopy
		mov	esi,offset KBInfoStr
		call	StrAppend
		pop	edi esi
		ret
endp		;---------------------------------------------------------------


		; KB_GetParameters - get keyboard parameters.
		; Input: none.
		; Output:
proc KB_GetParameters near
		ret
endp		;---------------------------------------------------------------


		; KB_SetParameters - set keyboard parameters.
		; Input:
		; Output: none.
proc KB_SetParameters near
		ret
endp		;---------------------------------------------------------------


		; KB_GetKeyNoWait - read key without waiting.
		; Input: none.
		; Output: ZF=0 - key not pressed,
		;	  ZF=1 - key pressed, AX=key code.
proc KB_GetKeyNoWait near
		call	KB_KeyPressed
		jz	short @@Exit
		push	ebx edx
		xor	ebx,ebx
		mov	bl,[KB_BufHead]
		mov	edx,offset KB_Buffer
		mov	ax,[edx+ebx*2]
		inc	bl
		cmp	bl,KB_BufSize
		jb	@@Store
		xor	bl,bl
@@Store:	mov	[KB_BufHead],bl
		inc	bl					; Set ZF=0
		pop	edx ebx
@@Exit:		ret
endp		;---------------------------------------------------------------


		; KB_ClearBuf - clear keyboard buffer.
		; Input: none.
		; Output: none.
proc KB_ClearBuf near
		mov	[KB_BufHead],0
		mov	[KB_BufTail],0
		ret
endp		;---------------------------------------------------------------


		; KB_KeyPressed - check the keyboard buffer on pressed key.
		; Input: none.
		; Output: ZF=0 - key pressed,
		;	  ZF=1 - key not pressed.
proc KB_KeyPressed near
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
proc KB_AnalyseKCode near
		push	ebx edx

		xor	ah,ah
		test	[KB_MiscFlags],KB_flNoAnalyse
		jnz	@@Valid
		test	[KB_MiscFlags],KB_flPrefE0
		jnz	@@LastE0
		test	[KB_MiscFlags],KB_flPrefE1
		jnz	@@LastE1

		cmp	al,0E0h
		je	@@NowE0
		cmp	al,0E1h
		je	@@NowE1
		cmp	al,KB_LShift
		je	@@NowLShift
		cmp	al,KB_RShift
		je	@@NowRShift
		cmp	al,KB_Ctrl
		je	@@NowLCtrl
		cmp	al,KB_Alt
		je	@@NowLAlt
		cmp	al,KB_CapsLock
		je	@@NowCapsLock
		cmp	al,KB_NumLock
		je	@@NowNumLock
		cmp	al,KB_ScrollLock
		je	@@NowScrLock

		test	al,80h
		jnz	short @@Release

@@Common:	test	[KB_PrsFlags],KB_Prs_Shift
		jnz	short @@xLatShift
		test	[KB_PrsFlags],KB_Prs_Ctrl
		jnz	short @@xLatCtrl

		mov	ebx,offset KBLayoutNorm
		xlatb
		or	al,al
		jz	@@Exit
		jmp	@@Valid

@@xLatShift:	mov	ebx,offset KBLayoutShift
		xlatb
		or	al,al
		jz	@@Exit
		jmp	@@Valid

@@xLatCtrl:	test	[KB_PrsFlags],KB_Prs_Alt
		jnz	short @@QCtrlAltDel
		mov	ebx,offset KBLayoutCtrl
		xlatb
		or	al,al
		jz	@@Exit
		jmp	@@Valid


@@QCtrlAltDel:	cmp	al,KB_KeypadDel
		jnz	@@Exit
		mov	eax,EV_SIGNAL+SIG_CTRLALTDEL
		xor	edx,edx				; PID=0 (kernel)
		call	K_SendMessage
		jmp	@@Exit

@@Release:	cmp	al,KB_LShift+80h
		je	@@RelLShift
		cmp	al,KB_RShift+80h
		je	@@RelRShift
		cmp	al,KB_Ctrl+80h
		je	@@RelLCtrl
		cmp	al,KB_Alt+80h
		je	@@RelLAlt
		cmp	al,KB_NumLock+80h
		je	@@RelNumLock
		cmp	al,KB_CapsLock+80h
		je	@@RelCapsLock
		cmp	al,KB_ScrollLock+80h
		je	@@RelScrLock
		jmp	@@Exit


@@LastE0:	and	[KB_MiscFlags],not KB_flPrefE0
		cmp	al,KB_Ctrl
		je	@@NowRCtrl
		cmp	al,KB_Alt
		je	@@NowRAlt
		cmp	al,KB_Ctrl+80h
		je	@@RelRCtrl
		cmp	al,KB_Alt+80h
		je	@@RelRAlt
		cmp	al,KB_KeypadEnter
		je	@@Common
		cmp	al,KB_KeypadSlash
		je	@@Common
		cmp	al,KB_KeypadDel
		jne	short @@NoDel
		test	[KB_PrsFlags],KB_Prs_Ctrl+KB_Prs_Alt
		jnz	@@QCtrlAltDel
@@ExtASCII:	mov	ah,al
		xor	al,al
		jmp	@@Valid

@@NoDel:
		jmp	@@Exit

@@LastE1:	and	[KB_MiscFlags],not KB_flPrefE1
		jmp	@@Exit

@@NowE0:	or	[KB_MiscFlags],KB_flPrefE0
		jmp	@@Exit
@@NowE1:        or	[KB_MiscFlags],KB_flPrefE1
		jmp	@@Exit


@@NowLShift:	or	[KB_PrsFlags],KB_Prs_LShift+KB_Prs_Shift
		jmp	@@Exit
@@NowLCtrl:	or	[KB_PrsFlags],KB_Prs_LCtrl+KB_Prs_Ctrl
		jmp	@@Exit
@@NowLAlt:	or	[KB_PrsFlags],KB_Prs_LAlt+KB_Prs_Alt
		jmp	@@Exit
@@NowRShift:	or	[KB_PrsFlags],KB_Prs_RShift+KB_Prs_Shift
		jmp	@@Exit
@@NowRCtrl:	or	[KB_PrsFlags],KB_Prs_RCtrl+KB_Prs_Ctrl
		jmp	@@Exit
@@NowRAlt:	or	[KB_PrsFlags],KB_Prs_RAlt+KB_Prs_Alt
		jmp	@@Exit

@@RelLShift:	and	[KB_PrsFlags],not KB_Prs_LShift
		jmp	short @@RelShift
@@RelLCtrl:	and	[KB_PrsFlags],not KB_Prs_LCtrl
		jmp	short @@RelCtrl
@@RelLAlt:	and	[KB_PrsFlags],not KB_Prs_LAlt
		jmp	short @@RelAlt
@@RelRShift:	and	[KB_PrsFlags],not KB_Prs_RShift
		jmp	short @@RelShift
@@RelRCtrl:	and	[KB_PrsFlags],not KB_Prs_RCtrl
		jmp	short @@RelCtrl
@@RelRAlt:	and	[KB_PrsFlags],not KB_Prs_RAlt
		jmp	short @@RelAlt

@@RelShift:	test	[KB_PrsFlags],KB_Prs_LShift+KB_Prs_RShift
		jnz	@@Exit
		and	[KB_PrsFlags],not KB_Prs_Shift
		jmp	@@Exit
@@RelCtrl:	test	[KB_PrsFlags],KB_Prs_LCtrl+KB_Prs_RCtrl
		jnz	@@Exit
		and	[KB_PrsFlags],not KB_Prs_Ctrl
		jmp	@@Exit
@@RelAlt:	test	[KB_PrsFlags],KB_Prs_LAlt+KB_Prs_RAlt
		jnz	@@Exit
		and	[KB_PrsFlags],not KB_Prs_Alt
		jmp	@@Exit

@@NowCapsLock:	test	[KB_PrsFlags],KB_Prs_CapsLock
		jnz	@@Exit
		or	[KB_PrsFlags],KB_Prs_CapsLock
		test	[KB_SwStatus],KB_swCapsLock
		jz	@@CapsON
		and	[KB_SwStatus],not KB_swCapsLock
		jmp	short @@SetInd
@@CapsON:	or	[KB_SwStatus],KB_swCapsLock
		jmp	short @@SetInd

@@NowNumLock:   test	[KB_PrsFlags],KB_Prs_NumLock
		jnz	@@Exit
		or	[KB_PrsFlags],KB_Prs_NumLock
		test	[KB_SwStatus],KB_swNumLock
		jz	@@NumON
		and	[KB_SwStatus],not KB_swNumLock
		jmp	short @@SetInd
@@NumON:	or	[KB_SwStatus],KB_swNumLock
		jmp	short @@SetInd

@@NowScrLock:   test	[KB_PrsFlags],KB_Prs_ScrollLock
		jnz	@@Exit
		or	[KB_PrsFlags],KB_Prs_ScrollLock
		test	[KB_SwStatus],KB_swScrollLock
		jz	@@ScrollON
		and	[KB_SwStatus],not KB_swScrollLock
		jmp	short @@SetInd
@@ScrollON:	or	[KB_SwStatus],KB_swScrollLock
		jmp	short @@SetInd

@@SetInd:	call	KB_SetIndicators
		jmp	short @@Exit

@@RelCapsLock:	and	[KB_PrsFlags],not KB_Prs_CapsLock
		jmp	short @@Exit
@@RelNumLock:   and	[KB_PrsFlags],not KB_Prs_NumLock
		jmp	short @@Exit
@@RelScrLock:   and	[KB_PrsFlags],not KB_Prs_ScrollLock
		jmp	short @@Exit

@@Exit:		xor	ax,ax
@@Valid:	pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; KB_PutInBuf - put a key code into the keyboard buffer.
		; Input: AX=key code.
		; Output: CF=0 - OK,
		;	  CF=1 - buffer overflow.
		; Note: beep if buffer overflow.
proc KB_PutInBuf near
		push	ebx
		push	edx
		xor	ebx,ebx
		mov	bl,[KB_BufTail]
		inc	bl
		cmp	bl,KB_BufSize
		jb	short @@Check
		xor	bl,bl
@@Check:	cmp	bl,[KB_BufHead]
		je	short @@Overflow
		push	ebx
		mov	edx,offset KB_Buffer
		mov	bl,[KB_BufTail]
		mov	[edx+ebx*2],ax
		pop	ebx
		mov	[KB_BufTail],bl
		clc
		jmp	short @@Exit

@@Overflow:	call	SPK_Tick
		stc

@@Exit:		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; KB_SetIndicators - keyboard indicators control.
		; Input: none.
		; Output: none.
		; Note: sets keyboard indicators status appropriate to
		;	KB_SwStatus variable.
proc KB_SetIndicators near
		push	eax
		mov	al,KB_CmdIndCtrl
		mov	ah,[KB_SwStatus]
		and	ah,7
		stc
		call	KBC_SendKBCmd
		pop	eax
		ret
endp		;---------------------------------------------------------------
