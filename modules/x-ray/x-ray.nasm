;*******************************************************************************
; x-ray.nasm - a simple system debugging tool.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module $x-ray

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "serventry.ah"
%include "asciictl.ah"

exportdata ModuleInfo

library $libc
importproc _strncmp
importproc _MsgSend

library monitor.cons
extern ReadString, PrintWordHex

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
    field(Entry,	DD	XR_Main)
iend

TxtBanner	DB	NL,"x-ray - RadiOS system debugging tool",NL
		DB	"Copyright (c) 2002 RET & COM Research.",NL,0

TxtHelp		DB	NL,"Commands:",NL
		DB     "S		- call monitor (g to go back)",NL
		DB     "smsg num	- send a message to task manager",NL
		DB     "stat		- view scheduler statistics",NL
		DB     "ts		- view thread statistics",NL
		DB     "allocmem size	- allocate <size> bytes block",NL
		DB     "freemem addr	- free memory block",NL
		DB     "memstat		- print memory allocation info",NL
		DB     "reboot		- reboot machine",NL,0
		
TxtDbgPrompt	DB	NL,"x-ray> ",0
TxtErr		DB	NL,NL,7,"ERROR ",0

CommandTable	DB	1,"?"
		DD	XR_Help
		DB	4,"help"
		DD	XR_Help
		DB	1,"S"
		DD	XR_CallMonitor
		DB	4,"smsg"
		DD	XR_SendMsg
;		DB	8,"allocmem"
;		DD	MM_DebugAllocMem
;		DB	7,"freemem"
;		DD	MM_DebugFreeMem
;		DB	7,"memstat"
;		DD	MM_PrintStat
;		DB	8,"freemcbs"
;		DD	MM_DebugFreeMCBs

;		DB	4,"stat"
;		DD	MT_PrintSchedStat
;		DB	2,"ts"
;		DD	MT_DumpReadyThreads
;		DB	6,"reboot"
;		DD	XR_Reboot
		DB	0


; --- Variables ---

section .bss

SBuffer		RESB	80


; --- Code ---

section .text

		; XR_DispatchCmd - dispatch entered command.
		; Input: ESI=address of command line.
		; Output: none.
proc XR_DispatchCmd
		push	edi
		xor	ecx,ecx
		mov	edi,CommandTable
		
.Loop:		mov	cl,[edi]			; Command length
		or	cl,cl
		jz	short .Done
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
;jmp $
		mServPrintStr TxtBanner
.Loop:		mServPrintStr TxtDbgPrompt
		mov	esi,SBuffer
		mov	cl,48
		call	ReadString
		and	ecx,0FFh
		mov	byte [esi+ecx],0

		call	XR_DispatchCmd
		jmp	.Loop
endp		;---------------------------------------------------------------


		; XR_Help - print a short help message.
proc XR_Help
		mServPrintStr TxtHelp
		ret
endp		;---------------------------------------------------------------


		; XR_CallMonitor - just int3.
proc XR_CallMonitor
		int3
		ret
endp		;---------------------------------------------------------------


		; XR_SendMsg - send a message to task manager.
proc XR_SendMsg
		locauto msgbuf, 256
		prologue
		mpush	ecx,esi

		lea	eax,[%$msgbuf]
		Ccall	_MsgSend, SYSMGR_COID, eax, 256, eax, 256

		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; XR_ErrorHandler - error handler.
		; Input: AX=error code.
		; Output: none.
proc XR_ErrorHandler
		mServPrintStr TxtErr
		call	PrintWordHex
		xor	eax,eax
.Exit:		ret
endp		;---------------------------------------------------------------
