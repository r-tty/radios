;-------------------------------------------------------------------------------
; tm_main.nasm - main loop: receive messages and handle them.
;-------------------------------------------------------------------------------

module tm.main

%include "sys.ah"
%include "msg.ah"
%include "errors.ah"
%include "parameters.ah"
%include "module.ah"
%include "serventry.ah"
%include "tm/process.ah"
%include "tm/sysmsg.ah"

publicproc TM_Main, TM_SetMsgHandler, TM_GetMsgHandler, TM_SetMHfromTable

externproc TM_InitMemman, TM_InitModules, TM_InitPathman
externproc TM_RegisterBinFmt, TM_IterateModList
externproc TM_NewProcess, TM_CopyConnections
externproc MapArea, MM_AllocPagesAt, CopyFromAct, PoolInit
externdata ProcMsgHandlers
externdata ?BootModsArr, ?ProcListPtr, ?ConnPool
externdata BinFmtRDOFF

library $libc
importproc _ChannelCreate, _ConnectAttach
importproc _MsgReceive, _MsgReply, _MsgError, _MsgRead
importproc _ThreadCreate

section .data

SysMsgHandlers:
mMHTabEnt MH_SysConf, SYS_CONF
mMHTabEnt MH_SysCmd, SYS_CMD
mMHTabEnt MH_SysLog, SYS_LOG
mMHTabEnt 0

TxtTaskmanInit	DB	"Task manager initialization:",10,0
Txt~CreateChan	DB	"Unable to create channel",0
TxtFatalErr	DB	"Fatal error (code ",0
TxtHalt		DB	", halting", 0
TxtRebooting	DB	10,"About to reboot.. OK?",0
TxtBadMsgLen	DB	10,"Invalid message length ",0
TxtMissingMH	DB	10,"Missing message handler for message: type=",0
TxtBadMsg	DB	10,"taskman got invalid message: type=",0
TxtSubtype	DB	"h, subtype=",0
TxtGotPulse	DB	10,"taskman got pulse: code=",0
TxtPulseVal	DB	", value=",0


section .bss

?SpareChannel	RESD	1
?MsgHandlers	RESD	SYSMSG_MAX+1


section .text

		; TM_Main - user-mode initialization and the main loop.
proc TM_Main
		locauto	msgbuf, tPulse_size
		locauto	minfo, tMsgInfo_size
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

		; Initialize path management
		call	TM_InitPathman
		jc	near .Fatal

		; Install our message handlers
		mov	esi,SysMsgHandlers
		call	TM_SetMHfromTable

		; Install procmgr message handlers as well
		mov	esi,ProcMsgHandlers
		call	TM_SetMHfromTable

		; Our channel must have chid==1, so create a spare one
		Ccall	_ChannelCreate, 0
		test	eax,eax
		js	near .Fatal
		mov	[?SpareChannel],eax		; just in case

		; Create the IPC channel that we will use for communications
		Ccall	_ChannelCreate, 0
		test	eax,eax
		js	near .Fatal
		
		; Initialize connection pool
		mov	ebx,?ConnPool
		xor	ecx,ecx
		mov	cl,tConnDesc_size
		mov	dl,POOLFL_HIMEM
		call	PoolInit

		; Create a connection to our channel. It will be inherited
		; by all child processes.
		Ccall	_ConnectAttach, 0, SYSMGR_PID, SYSMGR_CHID, SYSMGR_COID, 0
		test	eax,eax
		js	near .Fatal

		; Create boot processes. They will start running immediately!
		mov	edx,CreateBootProc
		call	TM_IterateModList
		jc	near .Fatal

		; Main loop: wait for a message and process it.
.MsgLoop:	lea	edi,[%$msgbuf]
		lea	esi,[%$minfo]
		Ccall	_MsgReceive, SYSMGR_CHID, edi, tPulse_size, esi
		mov	ebx,eax
		test	eax,eax
		js	near .Fatal
		jnz	.GotMsg
		call	TM_PulseHandler
		jmp	.MsgLoop

		; Check if a message size and type is valid
.GotMsg:	mov	ecx,[esi+tMsgInfo.MsgLen]
		cmp	ecx,4
		jb	.InvLen
		xor	eax,eax
		mov	ax,[edi]
		cmp	ax,SYSMSG_BASE
		jb	.InvMsg
		cmp	ax,SYSMSG_MAX
		ja	.InvMsg

		; If there is no handler for this message - send an error
		mov	edx,[?MsgHandlers+eax*4]
		or	edx,edx
		jz	.MissingMH
		call	edx
		jmp	.MsgLoop

.MissingMH:	mServPrintStr TxtMissingMH
		jmp	.PrintMsgType
.InvMsg:	mServPrintStr TxtBadMsg
.PrintMsgType:	mServPrint16h
		mServPrintStr TxtSubtype
		mServPrint16h [edi+2]
		mServPrintChar 'h'
		mServPrintChar 10
		jmp	.ReplyErr

.InvLen:	mServPrintStr TxtBadMsgLen
		mServPrintDec ecx
		mServPrintChar 10

.ReplyErr:	Ccall	_MsgError, ebx, -ENOMSG
		jmp	.MsgLoop

.Fatal:		mServPrintStr TxtFatalErr
		mServPrint16h
		mServPrintChar ')'
		mServPrintStr TxtHalt
		jmp	$
		epilogue
endp		;---------------------------------------------------------------


		; Iterator - create a boot process from module image.
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

		; Copy connection descriptors
		mpush	ebx,esi
		mov	edi,esi
		mov	esi,[?ProcListPtr]
		call	TM_CopyConnections
		mpop	esi,ebx
		jc	.Exit

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

.Proceed:	mpush	ebx,edx,esi

		; Actually, only the code section can be shared
		mov	edx,[esi+tProcDesc.PageDir]
		mov	al,PG_PRESENT | PG_USERMODE
		mov	ah,PG_PRESENT | PG_USERMODE | PG_WRITABLE
		mov	esi,[ebx+tModule.CodeStart]
		mov	edi,[ebx+tModule.VirtAddr]
		add	edi,USERAREASTART
		mov	ecx,[ebx+tModule.CodeLen]
		call	MapArea
		jc	.Exit

		; Allocate memory for data and BSS
		mov	eax,[ebx+tModule.DataStart]
		sub	eax,esi
		add	edi,eax
		mov	ecx,[ebx+tModule.DataLen]
		add	ecx,[ebx+tModule.BSSlen]
		jecxz	.Exit
		push	ecx
		add	ecx,PAGESIZE-1
		shr	ecx,PAGESHIFT
		mov	al,PG_USERMODE | PG_WRITABLE
		push	ebx
		mov	ebx,edi
		call	MM_AllocPagesAt
		pop	ebx
		pop	ecx
		jc	.Exit

		; Copy the data and BSS (so BSS will be zeroed)
		mov	esi,[ebx+tModule.DataStart]
		sub	edi,USERAREASTART
		call	CopyFromAct

.Exit:		mpop	esi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; Install a system message handler.
		; Input: AX=message type,
		;	 EBX=handler address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc TM_SetMsgHandler
		cmp	ax,SYSMSG_MAX
		cmc
		jbe	.Exit
		and	eax,0FFFFh
		mov	[?MsgHandlers+eax*4],ebx
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Get the address of a system message handler.
		; Input: AX=message type,
		;	 EBX=handler address.
		; Output: CF=0 - OK, EBX=handler address;
		;	  CF=1 - error.
proc TM_GetMsgHandler
		cmp	ax,SYSMSG_MAX
		cmc
		jbe	.Exit
		and	eax,0FFFFh
		mov	ebx,[?MsgHandlers+eax*4]
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; Set up system message handlers from a table.
		; Input: ESI=table address (terminated with NULL).
		; Output: none.
		; Note: table entry consists of a handler address (dword)
		;	and message type (word)
proc TM_SetMHfromTable
.Loop:		mov	ebx,[esi]
		or	ebx,ebx
		jz	.Exit
		mov	ax,[esi+4]
		call	TM_SetMsgHandler
		add	esi,byte 6
		jmp	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; Pulse handler.
		; Input: EDI=pulse address.
		; Output: none.
proc TM_PulseHandler
		mServPrintStr TxtGotPulse
		movzx	eax,byte [edi+tPulse.Code]
		mServPrintDec
		mServPrintStr TxtPulseVal
		mServPrintDec [edi+tPulse.SigValue]
		mServPrintChar 10
		ret
endp		;---------------------------------------------------------------


		; SYS_CONF message handler.
		; Input: EBX=rcvid.
proc MH_SysConf
		locauto msgbuf, tMsg_SysConf_size
		prologue

		lea	edi,[%$msgbuf]
		Ccall	_MsgRead, ebx, edi, tSysConfRequest_size, 0
		test	eax,eax
		clc
		js	.Exit
		cmp	eax,tSysConfRequest_size
		jb	.Exit

		Ccall	_MsgReply, ebx, 0, edi, tSysConfReply_size

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; SYS_CMD message handler.
		; Input: EBX=rcvid.
proc MH_SysCmd
		locauto msgbuf, tMsg_SysCmd_size
		prologue

		lea	edi,[%$msgbuf]
		Ccall	_MsgRead, ebx, edi, tMsg_SysCmd_size, 0
		test	eax,eax
		clc
		js	.Exit
		cmp	eax,tMsg_SysCmd_size
		jb	.Exit

		cmp	word [edi+tMsg_SysCmd.Cmd],SYS_CMD_REBOOT
		jne	.Error

		mServPrintStr TxtRebooting
		mServReadKey
		cmp	al,'y'
		jne	.Error
		call	EXITGATE:0

.Error:		Ccall	_MsgError, ebx, dword -EINVAL

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; SYS_LOG message handler.
		; Input: EBX=rcvid.
proc MH_SysLog
		ret
endp		;---------------------------------------------------------------
