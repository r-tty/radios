;*******************************************************************************
; tester.nasm - a simple system debugging tool.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module $tester

%include "rmk.ah"
%include "errors.ah"
%include "module.ah"
%include "locstor.ah"
%include "asciictl.ah"
%include "tm/sysmsg.ah"

exportdata ModuleInfo

library $libc
importproc _exit
importproc _strncmp, _strlen
importproc _MsgSend, _MsgSendv, _MsgSendPulse
importproc _ClockTime
importproc _AllocPages, _FreePages
importproc _getch, _putch, _printf

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
    field(Entry,	DD	TST_Main)
iend

TxtHelp		DB	NL,"Commands:",NL
		DB     "pulse		- send a pulse to task manager",NL
		DB     "sendiov		- send an IOV to task manager",NL
		DB     "schedstat	- view scheduler statistics",NL
		DB     "ts		- view thread statistics",NL
		DB     "tls		- print current TLS information",NL
		DB     "modstat		- print module information",NL
		DB     "allocpgs X	- allocate X memory pages",NL
		DB     "freemem addr	- free memory block",NL
		DB     "memstat		- print memory allocation info",NL
		DB     "ls		- list files in current directory",NL
		DB     "cd newdir	- change current directory to newdir",NL
		DB     "cat file	- type the contents of file",NL
		DB     "reboot		- reboot machine",NL,0
		
TxtDbgPrompt	DB	NL,"tester> ",0
TxtErr		DB	NL,"Function returned an error %Xh",0
TxtGotReply	DB	"tester got reply: ",0
TxtNeg		DB	" (-%d)",0
TxtTLSinfo	DB	NL,"My TID is %d, and PID is %d",NL,0
TxtBlockAddr	DB	NL,"Block address: %Xh",NL,0
TxtFoobar	DB	"foobarbazqux"
TxtFmtDec	DB	"%d",0
TxtFmtHex	DB	"%Xh",0

CommandTable:
mDispTabEnt "?",	TST_Help
mDispTabEnt "help",	TST_Help
mDispTabEnt "*",	TST_Breakpoint
mDispTabEnt "smsg",	TST_SendMsg
mDispTabEnt "pulse",	TST_SendPulse
mDispTabEnt "sendiov",	TST_SendIOV
mDispTabEnt "tls",	TST_PrintTLS
mDispTabEnt "rt",	TST_Time
mDispTabEnt "reboot",	TST_Reboot
mDispTabEnt "allocpgs",	TST_AllocPages
mDispTabEnt "freepgs",	TST_FreePages
mDispTabEnt "ls",	TST_ListFiles
mDispTabEnt "cd",	TST_ChangeDir
mDispTabEnt "cat",	TST_TypeFile


section .bss

?InpBuffer	RESB	80


section .text

		; char *ReadString(char *s, int size, int fd);
proc ReadString
		arg	str, size, stream
		prologue
		
		mov	ecx,[%$size]
		sub	esp,ecx			; Allocate local buffer

		mpush	esi,edi
		mov	esi,[%$str]
		mov	edi,ebp
		sub	edi,ecx
		push	edi			; EDI=local buffer address
		push	ecx
		cld
		rep	movsb
		pop	ecx
		pop	edi
		mov	esi,edi			; ESI=EDI=local buffer address

.ReadKey:	Ccall	_getch
		or	al,al
		jz	.FuncKey
		cmp	al,ASC_BS
		je	.BS
		cmp	al,ASC_CR
		je	.Done
		cmp	al,' '			; Another ASCII CTRL?
		jb	.ReadKey		; Yes, ignore it.
		cmp	edi,ebp			; Buffer full?
		je	.ReadKey		; Yes, ignore it.
		mov	[edi],al		; Store read character
		inc	edi
		Ccall	_putch
		jmp	.ReadKey

.FuncKey:	jmp	.ReadKey

.BS:		cmp	edi,esi
		je	.ReadKey
		dec	edi
		Ccall	_putch
		jmp	.ReadKey

.Done:		mov	ecx,edi
		sub	ecx,esi
		mov	edi,[esp+4]		; EDI=target buffer address
		push	ecx			; ECX=number of read characters
		cld
		rep	movsb
		mov	byte [edi],0
		pop	ecx

		mov	eax,[%$str]
		mpop	edi,esi
		epilogue
		ret
endp		;---------------------------------------------------------------


		; void PrintString(const char *str);
proc PrintString
		xchg	esi,[esp+4]
		cld
.Loop:		lodsb
		or	al,al
		jz	.Done
		Ccall	_putch
		jmp	.Loop
.Done:		xchg	esi,[esp+4]
		ret
endp		;---------------------------------------------------------------


		; TST_DispatchCmd - run a command.
		; Input: ESI=address of command line.
		; Output: none.
proc TST_DispatchCmd
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


		; TST_Main - start entry point.
		; Input: none.
		; Output: never.
proc TST_Main
		; Read a line from standard input and process command
.Loop:		Ccall	PrintString, TxtDbgPrompt

		mov	esi,?InpBuffer
		Ccall	ReadString, esi, 48, 0
		test	eax,eax
		jz	.Loop
		Ccall	_strlen, eax
		mov	byte [esi+eax],0
		mov	ecx,eax

		call	TST_DispatchCmd
		jmp	.Loop
endp		;---------------------------------------------------------------


		; TST_Help - print a short help message.
proc TST_Help
		Ccall	PrintString, TxtHelp
		ret
endp		;---------------------------------------------------------------


		; TST_Breakpoint - just int3.
proc TST_Breakpoint
		int3
		ret
endp		;---------------------------------------------------------------


		; TST_SendMsg - send a message to task manager.
proc TST_SendMsg
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
		Ccall	PrintString, TxtGotReply
		Ccall	PrintString, edi

.Exit:		mpop	esi,ecx
		epilogue
		ret

.Err:		call	TST_ErrorHandler
		jmp	.Exit
endp		;---------------------------------------------------------------


		; TST_SendPulse - send a pulse to task manager.
proc TST_SendPulse
		mpush	ecx,esi

		Ccall	_MsgSendPulse, SYSMGR_COID, 0, 23, 15300
		test	eax,eax
		jz	.Exit
		call	TST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; Send a 4-part IOV to task manager.
proc TST_SendIOV
		locauto	iov, 4*tIOV_size
		prologue
		mpush	ecx,esi

		xor	eax,eax
		mov	al,3
		mov	dword [%$iov+tIOV.Base],TxtFoobar
		mov	[%$iov+tIOV.Len],eax
		mov	dword [%$iov+8+tIOV.Base],TxtFoobar+3
		mov	[%$iov+8+tIOV.Len],eax
		mov	dword [%$iov+16+tIOV.Base],TxtFoobar+6
		mov	[%$iov+16+tIOV.Len],eax
		mov	dword [%$iov+24+tIOV.Base],TxtFoobar+9
		mov	[%$iov+24+tIOV.Len],eax

		lea	ebx,[%$iov]
		Ccall	_MsgSendv, SYSMGR_COID, ebx, 4, ebx, 4
		test	eax,eax
		jz	.Exit
		call	TST_ErrorHandler

.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; Print information from TLS
proc TST_PrintTLS
		mpush	esi,ecx
		tlsptr(ebx)
		Ccall	_printf, TxtTLSinfo, dword [ebx+tTLS.TID], dword [ebx+tTLS.PID]
		mpop	ecx,esi
		ret
endp		;---------------------------------------------------------------


		; Print current time.
proc TST_Time
		locauto	tbuf, Qword_size
		prologue
		lea	edi,[%$tbuf]
		Ccall	_ClockTime, 0, 0, edi
		test	eax,eax
		js	.Exit

		Ccall	_putch, byte NL
		Ccall	_printf, TxtFmtDec, dword [edi]

.Exit		epilogue
		ret
endp		;---------------------------------------------------------------


		; Reboot the system.
proc TST_Reboot
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
proc TST_AllocPages
		mov	ecx,8192
		Ccall	_AllocPages, ecx
		test	eax,eax
		js	TST_ErrorHandler
		Ccall	_printf, TxtBlockAddr, eax
		ret
endp		;---------------------------------------------------------------


		; Free memory pages
proc TST_FreePages
		ret
endp		;---------------------------------------------------------------


		; List the files in current directory
proc TST_ListFiles
		ret
endp		;---------------------------------------------------------------


		; Change the current directory
proc TST_ChangeDir
		ret
endp		;---------------------------------------------------------------


		; Type the contents of file
proc TST_TypeFile
		ret
endp		;---------------------------------------------------------------


		; TST_ErrorHandler - error handler.
		; Input: AX=error code.
		; Output: none.
proc TST_ErrorHandler
		push	ecx
		mov	ecx,eax
		Ccall	_printf, TxtErr, eax
		test	ecx,ecx
		jns	.Done
		neg	ecx
		Ccall	_printf, TxtNeg, ecx
.Done:		Ccall	_putch, byte NL
		pop	ecx
		ret
endp		;---------------------------------------------------------------
