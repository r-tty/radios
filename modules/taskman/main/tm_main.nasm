;-------------------------------------------------------------------------------
; tm_main.nasm - main loop: receive messages and handle them.
;-------------------------------------------------------------------------------

module tm.main

%include "sys.ah"
%include "parameters.ah"
%include "module.ah"
%include "serventry.ah"
%include "tm/process.ah"
%include "rm/iomsg.ah"

publicproc TM_Main

externproc TM_InitMemman, TM_InitModules, TM_InitPathman
externproc TM_RegisterBinFmt, TM_IterateModList
externproc TM_NewProcess
externproc MapArea
externdata ?BootModsArr, ?ProcListPtr
externdata BinFmtRDOFF

library $libc
importproc _ChannelCreate, _ConnectAttach
importproc _MsgReceive, _MsgReply
importproc _ThreadCreate


section .data

TxtTaskmanInit	DB	"Task manager initialization:",10,0
Txt~CreateChan	DB	"Unable to create channel",0
Txt~CreateConn	DB	"Unable to create connection",0
TxtFatalErr	DB	"Fatal error (code ",0
TxtHalt		DB	" - task manager is halted", 0
TxtGotMsg	DB	"got a message",10,0


section .bss

?SpareChannel	RESD	1


section .text

		; TM_Main - user-mode initialization and the main loop.
proc TM_Main
		locauto	msgbuf, 256
		prologue

		mServPrintStr TxtTaskmanInit

		; Initialize memory management
		mov	eax,MAXMCBS
		call	TM_InitMemman
		jc	near .Fatal

		; Initialize modules
		mov	eax,MAXMODULES
		mov	esi,[?BootModsArr]
		call	TM_InitModules
		jc	near .Fatal

		; Map shared libraries for ourselves, we'll need them
		mov	esi,[?ProcListPtr]
		mov	edx,MapShLib
		call	TM_IterateModList
		jc	near .Fatal

		; Register RDOFF binary format driver
		mov	edx,BinFmtRDOFF
		call	TM_RegisterBinFmt
		jc	near .Fatal

		; Initialize path managemenyt
		call	TM_InitPathman
		jc	near .Fatal

		; Prepare boot processes
		mov	edx,CreateBootProc
		call	TM_IterateModList
		jc	near .Fatal

		; Our channel must have chid==1, so create a spare one
		Ccall	_ChannelCreate, 0
		test	eax,eax
		js	.Fatal
		mov	[?SpareChannel],eax		; just in case

		; Create the IPC channel that we will use for communications
		Ccall	_ChannelCreate, 0
		test	eax,eax
		js	.Crit1
		Ccall	_ConnectAttach, 0, 0, eax, SYSMGR_COID, 0
		test	eax,eax
		js	.Crit2

		; Main loop: wait for a message and process it.
.MsgLoop:	lea	eax,[%$msgbuf]
		Ccall	_MsgReceive, byte SYSMGR_CHID, eax, 256, 0
		mServPrintStr TxtGotMsg
		jmp	.MsgLoop

.Panic:		mServPrintStr
		mServPrintStr TxtHalt
		jmp	$
.Crit1:		mov	esi,Txt~CreateChan
		jmp	.Panic
.Crit2:		mov	esi,Txt~CreateConn
		jmp	.Panic
.Fatal:		push	eax
		mServPrintStr TxtFatalErr
		pop	eax
		mServPrint16h
		mServPrintChar ')'
		mServPrintStr TxtHalt
		jmp	$
		epilogue
endp		;---------------------------------------------------------------


		; Create a boot process (iterator).
		; Input: EBX=address of boot module descriptor.
		; Output: CF=0 - OK, ESI=address of PCB;
		;	  CF=1 - error, AX=error code.
proc CreateBootProc
		locals	pcb
		prologue
		mpush	ebx,ecx,edx,edi

		; If a module is not executable - nothing to do.
		cmp	byte [ebx+tModule.Type],MODTYPE_EXECUTABLE
		clc
		jne	.Exit
		
		; Create process
		mov	esi,[?ProcListPtr]
		call	TM_NewProcess
		jc	.Exit
		mov	[%$pcb],esi

		; Map its address space
		mov	ecx,[ebx+tModule.Size]
		mov	edx,[esi+tProcDesc.PageDir]
		mov	al,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		mov	ah,al
		mov	esi,[ebx+tModule.CodeStart]
		mov	edi,[ebx+tModule.VirtAddr]
		add	edi,USERAREASTART
		call	MapArea
		jc	.Exit

		; Map shared libraries
		mov	esi,[%$pcb]
		mov	edx,MapShLib
		call	TM_IterateModList

		; Create first thread
		Ccall	_ThreadCreate, dword [esi+tProcDesc.PID], \
			dword [ebx+tModule.Entry], 0, 0
		or	eax,eax
		jns	.Exit
		stc

.Exit:		mpop	edi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; Iterator - map a shared library for a boot module.
		; Input: ESI=process descriptor address,
		;	 EBX=address of module descriptor being iterated.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MapShLib
		cmp	byte [ebx+tModule.Type],MODTYPE_LIBRARY
		je	.Proceed
		clc
		ret

.Proceed:	mpush	edx,esi
		mov	edx,[esi+tProcDesc.PageDir]
		mov	al,PG_PRESENT | PG_USERMODE
		mov	ah,al
		mov	esi,[ebx+tModule.CodeStart]
		mov	edi,[ebx+tModule.VirtAddr]
		add	edi,USERAREASTART
		mov	ecx,[ebx+tModule.Size]
		call	MapArea
		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------
