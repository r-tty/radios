;-------------------------------------------------------------------------------
;  _test_.asm - testing and debugging routines.
;-------------------------------------------------------------------------------

include "diskbuf.ah"
include "commonfs.ah"

		public TEST_CreateRDimage
		public TEST_ExamineFS

segment KDATA
msg_Debugging	DB NL,"DEBUGGING: ",0
msg_FScreated	DB "File system created on %ramdisk",NL,0
msg_CfgCreated	DB "Config file created",NL,0
msg_HelloSaved	DB "`Hello, world!' created",NL,0
msg_DbgPrompt	DB NL,"DEBUGFS>",0
msg_Err		DB NL,NL,7,"ERROR ",0
msg_SerHlp	DB NL,NL,"Press '.' to exit, '?' to get stat",NL,0
msg_MemSt	DB NL,NL,"MCB",9,9,"Addr",9,9,"Len",9,9,"Next MCB",9,"Prev MCB",NL,0
msg_FreeMem	DB NL,"Physical memory free (KB): ",0

cmdQuit		DB "q"
cmdNewTxtFile	DB "cf"
cmdRmFile	DB "rm"
cmdLs		DB "ls"
cmdView		DB "vw"
cmdRm		DB "rm"
cmdMv		DB "mv"
cmdMon		DB "S"
cmdCM		DB "CM"
cmdCL		DB "CL"
cmdMd		DB "md"
cmdCd		DB "cd"
cmdRd		DB "rd"
cmdFlushBuffers	DB "flush"
cmdSerial	DB "testserial"
cmdProbe	DB "probe"
cmdExec		DB "exec"
cmdAllocMem	DB "allocmem"
cmdFreeMem	DB "freemem"
cmdMemStat	DB "memstat"
cmdFreeMCBs	DB "freemcbs",0
cmdGetISS	DB "getiss"

SBuffer		DB 80 dup (?)

CfgName		DB "radios.config",0
cfgf_lb		=	$
ConfigFile	DB ";-----------------------------------------------------",NL
		DB "; radios.config - RadiOS configuration file",NL
		DB ";-----------------------------------------------------",NL,NL
		DB "Driver=cm6329.drv",NL
		DB ";Driver=ess1868.drv",NL
		DB NL
		DB "MaxProcesses=8",NL
		DB 0
SizeOfCfgFile	=	$-cfgf_lb

HelloName	DB "hello",0
hellof_lbl	=	$
HelloFile  	DB 82,68,79,70,70,50,189,0,0,0,119,0,0,0,2,10
		DB 3,0,63,75,69,82,78,69,76,0,2,7,4,0,69,120
		DB 105,116,0,2,15,5,0,63,75,69,82,78,69,76,46,77
		DB 73,83,67,0,2,11,6,0,87,114,83,116,114,105,110,103
		DB 0,3,10,0,0,0,0,0,109,97,105,110,0,1,8,0
		DB 1,0,0,0,4,1,0,1,8,0,6,0,0,0,4,6
		DB 0,6,8,0,10,0,0,0,2,6,0,1,8,0,15,0
		DB 0,0,4,4,0,6,8,0,19,0,0,0,2,4,0,5
		DB 4,128,0,0,0,1,0,0,0,0,0,21,0,0,0,190
		DB 0,0,0,0,154,0,0,0,0,0,0,49,192,154,0,0
		DB 0,0,0,0,2,0,1,0,0,0,15,0,0,0,72,101
		DB 108,108,111,44,32,87,111,114,108,100,33,10,0,0,0,0
		DB 0,0,0,0,0,0,0
SizeOfHello	= $-hellof_lbl
ends

macro mPrintMsg What
 mWrString msg_Debugging
 mWrString What
endm

proc TEST_CreateRDimage near

		; Link %ramdisk with %rfs at F:
		mov	esi,[DrvId_RFS]
		mov	edi,[DrvId_RD]
		mov	dl,5
		mov	dh,flFSL_NoInitFS
		call	CFS_LinkFS
		jc	@@Err

		; Make filesystem on %ramdisk
		mov	dl,5			; "F:"
		xor	esi,esi
		call	CFS_MakeFS
		jc	@@Err
		call	CFS_SetCurrentLP
		mPrintMsg msg_FScreated

		; Create config file
		mov	esi,offset CfgName
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short @@WrConf
		call	TEST_ErrorHandler
		jmp	@@Err

		; Write config file
@@WrConf:	mov	esi,offset ConfigFile
		mov	ecx,SizeOfCfgFile
		xor	eax,eax
		call	CFS_Write
		jnc	short @@CloseCfg
		call	TEST_ErrorHandler
		jmp	short @@Err

		; Close config file
@@CloseCfg:	xor	eax,eax
		call	CFS_Close
		jc	short @@Err

		; Create 'Hello, world!'
		mov	esi,offset HelloName
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jc	short @@Err

		; Write 'Hello, world!'
		mov	esi,offset HelloFile
		mov	ecx,SizeOfHello
		xor	eax,eax
		call	CFS_Write
		jnc	short @@CloseHello
		call	TEST_ErrorHandler
		jmp	short @@Err

		; Close file
@@CloseHello:	xor	eax,eax
		call	CFS_Close
		jc	short @@Err


		; Unlink filesystem from %ramdisk
		mov	dl,5
		call	CFS_UnlinkFS
		jc	short @@Err

		mPrintMsg msg_CfgCreated
		ret

@@Err:		int 3
		ret
endp		;---------------------------------------------------------------


proc TEST_ExamineFS near
@@Loop:		mWrString msg_DbgPrompt
		mov	esi,offset SBuffer
		mov	cl,48
		call	ReadString
		and	ecx,0FFh
		mov	[byte esi+ecx],0

		mov	cl,size cmdQuit
		mov	edi,offset cmdQuit
		call	StrLComp
		jz	@@Exit

		mov	cl,size cmdNewTxtFile
		mov	edi,offset cmdNewTxtFile
		call	StrLComp
		push	offset @@Loop
		jz	TEST_CreateTextFile
		add	esp,4

		mov	cl,size cmdView
		mov	edi,offset cmdView
		call	StrLComp
		push	offset @@Loop
		jz	TEST_ViewFile
		add	esp,4

		mov	cl,size cmdRm
		mov	edi,offset cmdRm
		call	StrLComp
		push	offset @@Loop
		jz	TEST_RemoveFile
		add	esp,4

		mov	cl,size cmdMv
		mov	edi,offset cmdMv
		call	StrLComp
		push	offset @@Loop
		jz	TEST_MoveFile
		add	esp,4

		mov	cl,size cmdLs
		mov	edi,offset cmdLs
		call	StrLComp
		push	offset @@Loop
		jz	TEST_Ls
		add	esp,4

		mov	cl,size cmdMd
		mov	edi,offset cmdMd
		call	StrLComp
		push	offset @@Loop
		jz	TEST_MkDir
		add	esp,4

		mov	cl,size cmdCd
		mov	edi,offset cmdCd
		call	StrLComp
		push	offset @@Loop
		jz	TEST_ChDir
		add	esp,4

		mov	cl,size cmdRd
		mov	edi,offset cmdRd
		call	StrLComp
		push	offset @@Loop
		jz	TEST_RmDir
		add	esp,4

		mov	cl,size cmdFlushBuffers
		mov	edi,offset cmdFlushBuffers
		call	StrLComp
		push	offset @@Loop
		jz	BUF_FlushAll
		add	esp,4

		mov	cl,size cmdCM
		mov	edi,offset cmdCM
		call	StrLComp
		push	offset @@Loop
		jz	TEST_CreateManyFiles
		add	esp,4

		mov	cl,size cmdCL
		mov	edi,offset cmdCL
		call	StrLComp
		push	offset @@Loop
		jz	TEST_CreateLargeFile
		add	esp,4

		mov	cl,size cmdSerial
		mov	edi,offset cmdSerial
		call	StrLComp
		push	offset @@Loop
		jz	TEST_Serial
		add	esp,4

		mov	cl,size cmdProbe
		mov	edi,offset cmdProbe
		call	StrLComp
		push	offset @@Loop
		jz	TEST_Probe
		add	esp,4

		mov	cl,size cmdAllocMem
		mov	edi,offset cmdAllocMem
		call	StrLComp
		push	offset @@Loop
		jz	TEST_AllocMem
		add	esp,4

		mov	cl,size cmdFreeMem
		mov	edi,offset cmdFreeMem
		call	StrLComp
		push	offset @@Loop
		jz	TEST_FreeMem
		add	esp,4

		mov	cl,size cmdMemStat
		mov	edi,offset cmdMemStat
		call	StrLComp
		push	offset @@Loop
		jz	TEST_MemStat
		add	esp,4

		mov	cl,size cmdFreeMCBs
		mov	edi,offset cmdFreeMCBs
		call	StrLComp
		push	offset @@Loop
		jz	TEST_FreeMCBs
		add	esp,4

		mov	cl,size cmdGetISS
		mov	edi,offset cmdGetISS
		call	StrLComp
		push	offset @@Loop
		jz	TEST_GetISS
		add	esp,4

		mov	cl,size cmdMon
		mov	edi,offset cmdMon
		call	StrLComp
		jnz	@@NotMon
		int	3
		jmp	@@Loop

@@NotMon:

		jmp	@@Loop

@@Exit:		ret
endp		;---------------------------------------------------------------


proc TEST_CreateTextFile near
@@handle	EQU	ebp-4
@@size		EQU	ebp-8
@@buffer	EQU	ebp-8-520

		enter	528,0
		push	ecx esi
		add	esi,ecx
		inc	esi

		; Open file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short @@Begin
		call	TEST_ErrorHandler
		jmp	short @@Exit

@@Begin:	mov	[@@handle],ebx

		; Read file from console
		lea	esi,[@@buffer]
		mov	[dword @@size],0
@@Loop:		mWrChar NL
		mov	cl,77
		call	ReadString
		or	cl,cl
		jz	@@EmptyLn
		cmp	[byte esi],'`'
		je	short @@EndInput
@@EmptyLn:	and	ecx,0FFh
		add	esi,ecx
		mov	[byte esi],NL
		inc	esi
		add	[@@size],ecx
		inc	[dword @@size]
		jmp	@@Loop

@@EndInput:

		; Write to file
		lea	esi,[@@buffer]
		mov	ebx,[@@handle]
		mov	ecx,[@@size]
		xor	eax,eax
		call	CFS_Write
		jnc	short @@Close
		call	TEST_ErrorHandler

		; Close file
@@Close:	xor	eax,eax
		call	CFS_Close
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		leave
		ret
endp		;---------------------------------------------------------------


proc TEST_ViewFile near
@@handle	EQU	ebp-4
@@buffer	EQU	ebp-516

		enter 516,0
		push	ecx esi
		add	esi,ecx
		inc	esi

		mWrChar NL
		mWrChar NL

		xor	edx,edx
		xor	eax,eax
		call	CFS_Open
		jnc	short @@Loop
		call	TEST_ErrorHandler
		jmp	short @@Exit

@@Loop:		lea	esi,[@@buffer]
		mov	ecx,512
		xor	eax,eax
		call	CFS_Read
		jc	short @@Exit
		or	eax,eax
		jz	short @@OK			; Nothing to view
		mov	ecx,eax

		push	ecx
@@Print:	lodsb
		mCallDriver [DrvId_Con],DRVF_Write
		dec	ecx
		jz	short @@EndPrint
		jmp	@@Print
@@EndPrint:	pop	ecx

		cmp	ecx,512
		jb	short @@OK
		jmp	@@Loop

@@OK:           xor	ax,ax
		call	CFS_Close
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		leave
		ret
endp		;---------------------------------------------------------------


proc TEST_RemoveFile near
		push	ecx esi
		add	esi,ecx
		inc	esi
		xor	eax,eax
		call	CFS_RemoveFile
		jnc	short @@Exit
		call	TEST_ErrorHandler
@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_MoveFile near
		push	ecx esi
		add	esi,ecx
		inc	esi				; ESI=old name
		mov	edi,esi
		mov	al, ' '
		call	StrScan
		or	edi,edi
		jz	short @@Exit
		xor	al,al
		stosb					; EDI=new name

		xor	eax,eax
		call	CFS_MoveFile
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_Ls near
		push	ecx esi
	extrn rfs_ls:near
	call rfs_ls

		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_MkDir near
		push	ecx esi

		add	esi,ecx
		inc	esi

 		xor	eax,eax
		call	CFS_CreateDir
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_ChDir near
		push	ecx esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	CFS_ChangeDir
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_RmDir near
		push	ecx esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	CFS_RemoveDir
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_CreateManyFiles
@@count		EQU	ebp-4
@@buf		EQU	ebp-16

		enter	16,0
		push	ecx esi

		mov	[dword @@count],0
@@Loop:		lea	esi,[@@buf]
		mov	eax,[@@count]
		call	K_DecD2Str

		; Create file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short @@Close
		call	TEST_ErrorHandler
		jmp	short @@Exit

		; Close file
@@Close:	xor	eax,eax
		call	CFS_Close
		jnc	short @@Cont
		call	TEST_ErrorHandler
		jmp	short @@Exit

@@Cont:		inc	[dword @@count]
		cmp	[dword @@count],31
		je	short @@Exit
		jmp	@@Loop


@@Exit:		pop	esi ecx
		leave
		ret
endp		;---------------------------------------------------------------


proc TEST_CreateLargeFile
		push	ecx esi
		add	esi,ecx
		inc	esi

		; Open file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short @@Begin
		call	TEST_ErrorHandler
		jmp	short @@Exit

		; Write to file
@@Begin:	mov	esi,0B8000h
		mov	ecx,211931
		xor	eax,eax
		call	CFS_Write
		jnc	short @@Close
		call	TEST_ErrorHandler

		; Close file
@@Close:	xor	eax,eax
		call	CFS_Close
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx

		ret
endp		;---------------------------------------------------------------


		; TEST_Serial - serial driver test.
proc TEST_Serial near
		push	ecx esi

		add	esi,ecx
		inc	esi

		call	DRV_FindName
		jnc	short @@Start
		call	TEST_ErrorHandler
		jmp	@@Exit

@@Start:	test	eax,00FF0000h
		jz	@@Exit
		mov	edi,eax
		mWrString msg_SerHlp

		mCallDriver edi,DRVF_Open
		jnc	short @@TTYmode
		call	TEST_ErrorHandler
		jmp	@@Exit

@@TTYmode:	mCallDriverCtrl edi,DRVCTL_SER_GetRXbufStat
		jc	@@Close
		or	dx,dx
		jz	short @@CheckKey
		mCallDriver edi,DRVF_Read
		mCallDriver [DrvId_Con],DRVF_Write
		jmp	@@TTYmode

@@CheckKey:	mCallDriverCtrl DRVID_Keyboard,DRVCTL_KB_CheckKeyPress
		jz	@@TTYmode
		mCallDriver [DrvId_Con],DRVF_Read
		cmp	al,'.'
		je	short @@Close
		cmp	al,'?'
		je	short @@PrintStat
		mCallDriver edi,DRVF_Write
		jnc	@@TTYmode
		call	TEST_ErrorHandler
		jmp	short @@Close

@@PrintStat:	mCallDriverCtrl edi,DRVCTL_SER_GetUARTmode
		jc	short @@Close
		mWrChar NL
		mov	eax,ecx
		call	PrintDwordDec
		mWrChar ','
		mov	al,bl
		call	PrintByteHex
		mWrChar ','
		mov	al,bh
		call	PrintByteHex
		mWrChar NL
		jmp	@@TTYmode

@@Close:	mCallDriver edi,DRVF_Close
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_Probe - misc probing calls.
proc TEST_Probe near
		push	ecx esi

		add	esi,ecx
		inc	esi

		call	TMR_CountCPUspeed
		mWrChar NL
		mov	eax,ecx
		call	PrintDwordDec

		cli					; 10 sec test
		mov	ecx,10000
		call	K_LDelayMs
		sti

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_Exec - load and run executable module.
proc TEST_Exec near
		push	ecx esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	MOD_Load
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_AllocMem - allocate memory block.
proc TEST_AllocMem near
		push	ecx esi

		add	esi,ecx
		inc	esi

		call	ValDwordHex
		jc	short @@Exit
		mov	ecx,eax
		xor	eax,eax
		xor	dl,dl
		call	MM_AllocBlock
		jnc	short @@PrintAddr
		call	TEST_ErrorHandler
		jmp	short @@Exit

@@PrintAddr:	mWrChar NL
		mov	eax,ebx
		call	PrintDwordHex

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_FreeMem - free memory block.
proc TEST_FreeMem near
		push	ecx esi

		add	esi,ecx
		inc	esi

		call	ValDwordHex
		jc	short @@Exit
		mov	ebx,eax
		xor	eax,eax
		xor	dl,dl
		call	MM_FreeBlock
		jnc	short @@Exit
		call	TEST_ErrorHandler

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_MemStat - print process memory state.
proc TEST_MemStat near
		push	ecx esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	@@Exit

		call	K_GetProcDescAddr
		jc	@@Exit
		mov	edi,ebx
		mov	ebx,[ebx+tProcDesc.FirstMCB]

		mov	eax,cr3
		push	eax
		mov	eax,[edi+tProcDesc.PageDir]
		mov	cr3,eax

		or	ebx,ebx
		jz	@@PrintTotal
		mWrString msg_MemSt

@@Loop:		or	ebx,ebx
		jz	@@PrintTotal
		mov	eax,ebx
		call	PrintDwordHex
		mWrChar 9
		mov	eax,[ebx+tMCB.Addr]
		call	PrintDwordHex
		mWrChar 9
		mov	eax,[ebx+tMCB.Len]
		call	PrintDwordHex
		mWrChar 9
		mov	eax,[ebx+tMCB.Next]
		call	PrintDwordHex
		mWrChar 9
		mov	eax,[ebx+tMCB.Prev]
		call	PrintDwordHex
		mov	ebx,[ebx+tMCB.Next]
		mWrChar NL
		jmp	@@Loop

@@PrintTotal:	mWrString msg_FreeMem
		call	PG_GetNumFreePages
		mov	eax,ecx
		shl	eax,2
		call	PrintDwordDec
		mWrChar NL

		pop	eax
		mov	cr3,eax

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_FreeMCBs - free process MCBs.
proc TEST_FreeMCBs near

		push	ecx esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	short @@Exit
		mov	edx,eax

		call	K_GetProcDescAddr
		jc	short @@Exit
		mov	esi,ebx
		mov	ebx,[ebx+tProcDesc.FirstMCB]

		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		mov	eax,edx
		call	MM_FreeMCBarea
		jnc	short @@RestorePD
		call	TEST_ErrorHandler

@@RestorePD:	pop	eax
		mov	cr3,eax

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_GetISS - get and print driver initialization status
		;		string.
proc TEST_GetISS near
		push	ecx esi

		add	esi,ecx
		inc	esi

		call	DRV_FindName
		jnc	short @@GotDID
		call	TEST_ErrorHandler
		jmp	short @@Exit

@@GotDID:	mCallDriverCtrl eax,DRVCTL_GetInitStatStr
		jnc	short @@Print
                call	TEST_ErrorHandler
		jmp	short @@Exit

@@Print:	mWrChar NL
		mCallDriverCtrl [DrvId_Con],DRVCTL_CON_WrString

@@Exit:		pop	esi ecx
		ret
endp		;---------------------------------------------------------------


		; Error handler.
proc TEST_ErrorHandler near
		mWrString msg_Err
		call	PrintWordHex
		cmp	ax,ERR_FS_DiskFull			; Disk full?
		jne	short @@Exit
		xor	eax,eax
		call	CFS_Truncate
@@Exit:		ret
endp		;---------------------------------------------------------------
