;*******************************************************************************
; x-ray.nasm - a simple system debugging tool.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module $x-ray

%include "rmk.ah"
%include "errors.ah"
%include "module.ah"
%include "locstor.ah"
%include "serventry.ah"
%include "asciictl.ah"
%include "tm/sysmsg.ah"

exportdata ModuleInfo

library $libc
importproc _fgets, _exit
importproc _strncmp, _strlen
importproc _MsgSend, _MsgSendPulse
importproc _ClockTime
importproc _AllocPages, _FreePages

; Macro for declaring a dispatch table entry
; Parameters:	%1 - command string,
;		%2 - handler address.
%macro mDispTabEnt 2
%strlen cmdlen %1
	DB	cmdlen,%1
	DD	%2
%endmacro

section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	0)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
    field(Entry,	DD	XR_Main)
iend

TxtBanner	DB	NL,"x-ray - RadiOS system debugging tool",NL
		DB	"Copyright (c) 2003 RET & COM Research.",NL,0

TxtHelp		DB	NL,"Commands:",NL
		DB     "pulse		- send a pulse to task manager",NL
		DB     "schedstat	- view scheduler statistics",NL
		DB     "ts		- view thread statistics",NL
		DB     "tls		- print current TLS information",NL
		DB     "modstat		- print module information",NL
		DB     "allocpgs X	- allocate X memory pages",NL
		DB     "freemem addr	- free memory block",NL
		DB     "memstat		- print memory allocation info",NL
		DB     "reboot		- reboot machine",NL,0
		
TxtDbgPrompt	DB	NL,"x-ray> ",0
TxtErr		DB	NL,"Function returned an error ",0
TxtGotReply	DB	"x-ray got reply: ",0
TxtOpenPar	DB	" (-",0
TxtTID		DB	NL,"My TID is ",0
TxtPID		DB	", and PID is ",0
TxtBlockAddr	DB	NL,"Block address: ",0

CommandTable:
mDispTabEnt "?",	XR_Help
mDispTabEnt "help",	XR_Help
mDispTabEnt "*",	XR_Breakpoint
mDispTabEnt "smsg",	XR_SendMsg
mDispTabEnt "pulse",	XR_SendPulse
mDispTabEnt "tls",	XR_PrintTLS
mDispTabEnt "rt",	XR_Time
mDispTabEnt "reboot",	XR_Reboot
mDispTabEnt "allocpgs",	XR_AllocPages
mDispTabEnt "freepgs",	XR_FreePages
;mDispTabEnt "memstat",	MM_PrintStat
;mDispTabEnt "freemcbs",MM_DebugFreeMCBs
;mDispTabEnt "schedstat", MT_PrintSchedStat
;mDispTabEnt "ts",	MT_DumpReadyThreads


section .bss

?InpBuffer	RESB	80


section .text

		; XR_DispatchCmd - run a command.
		; Input: ESI=address of command line.
		; Output: none.
proc XR_DispatchCmd
		push	edi
		xor	ecx,ecx
		mov	edi,CommandTable
		
.Loop:		mov	cl,[edi]			; Command length
		or	cl,cl
		jz	.Done
		inc	edi
		Ccall	_strncmp, esi, edi, ecx
		or	eax,eax
		jz	.GotCmd
		lea	edi,[edi+ecx+4]
		jmp	.Loop
		
.GotCmd:	mov	ebx,[edi+ecx]			; Valid address?
		lea	edi,[edi+ecx+4]
		or	ebx,ebx
		jz	.Loop
		call	ebx				; Call procedure
.Done:		pop	edi
		ret
endp		;---------------------------------------------------------------


		; XR_Main - start entry point.
		; Input: none.
		; Output: never.
proc XR_Main
		mServPrintStr TxtBanner

		; Read a line from standard input and process command
.Loop:		mServPrintStr TxtDbgPrompt

		mov	esi,?InpBuffer
		Ccall	_fgets, esi, 48, 0
		test	eax,eax
		jz	.Loop
		Ccall	_strlen, eax
		mov	byte [esi+eax],0
		mov	ecx,eax

		call	XR_DispatchCmd
		jmp	.Loop
		
endp		;---------------------------------------------------------------


		; XR_Help - print a short help message.
proc XR_Help
		mServPrintStr TxtHelp
		ret
endp		;---------------------------------------------------------------


		; XR_Breakpoint - just int3.
proc XR_Breakpoint
		int3
		ret
endp		;---------------------------------------------------------------


		; XR_SendMsg - send a message to task manager.
proc XR_SendMsg
		locauto msgbuf, 256
		prologue
		mpush	ecx,esi

		lea	edi,[%$msgbuf]
		Ccall	_strlen, esi
		sub	eax,ecx
		add	esi,ecx
		inc	esi
		Ccall	_MsgSend, SYSMGR_COID, esi, eax, edi, 20
		test	eax,eax
		js	.Err
		mServPrintStr TxtGotReply
		mServPrintStr edi

.Exit:		mpop	esi,ecx
		epilogue
		ret

.Err:		call	XR_ErrorHandler
		jmp	.Exit
endp		;---------------------------------------------------------------


		; XR_SendPulse - send a pulse to task manager.
proc XR_SendPulse
		mpush	ecx,esi

		Ccall	_MsgSendPulse, SYSMGR_COID, 0, 23, 15300
		test	eax,eax
		jz	.Exit
		call	XR_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; Print information from TLS
proc XR_PrintTLS
		mpush	esi,ecx
		tlsptr(ebx)
		mServPrintStr TxtTID
		mServPrintDec [ebx+tTLS.TID]
		mServPrintStr TxtPID
		mServPrintDec [ebx+tTLS.PID]
		mServPrintChar NL
		mpop	ecx,esi
		ret
endp		;---------------------------------------------------------------


		; Print current time.
proc XR_Time
		locauto	tbuf, Qword_size
		prologue
		lea	edi,[%$tbuf]
		Ccall	_ClockTime, 0, 0, edi
		test	eax,eax
		js	.Exit

		mServPrintChar NL
		mServPrintDec [edi]

.Exit		epilogue
		ret
endp		;---------------------------------------------------------------


		; Reboot the system.
proc XR_Reboot
		locauto msgbuf, tMsg_SysCmd_size
		prologue

		lea	edi,[%$msgbuf]
		mov	word [edi+tMsg_SysCmd.Type],SYS_CMD
		mov	word [edi+tMsg_SysCmd.Cmd],SYS_CMD_REBOOT
		Ccall	_MsgSend, SYSMGR_COID, edi, tMsg_SysCmd_size, edi, 0

		epilogue
		ret
endp		;---------------------------------------------------------------


		; Allocate memory pages
proc XR_AllocPages
		mov	ecx,8192
		Ccall	_AllocPages, ecx
		test	eax,eax
		js	XR_ErrorHandler
		mServPrintStr TxtBlockAddr
		mServPrint32h
		mServPrintChar NL
		ret
endp		;---------------------------------------------------------------


		; Free memory pages
proc XR_FreePages
		ret
endp		;---------------------------------------------------------------


		; XR_ErrorHandler - error handler.
		; Input: AX=error code.
		; Output: none.
proc XR_ErrorHandler
		mServPrintStr TxtErr
		mServPrint32h
		push	eax
		mServPrintChar 'h'
		pop	eax
		test	eax,eax
		jns	.Done
		neg	eax
		mServPrintStr TxtOpenPar
		mServPrintDec
		mServPrintChar ')'
.Done:		mServPrintChar NL
		ret
endp		;---------------------------------------------------------------
