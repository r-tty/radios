;*******************************************************************************
;  rkdt.as - RadiOS Kernel Debugging Tool.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

module rkdt

%include "sys.ah"
%include "errors.ah"
%include "process.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "asciictl.ah"
%include "commonfs.ah"
%include "memman.ah"

global RKDT_CreateRDimage, TEST_ExamineFS

library kernel
extern DrvId_Con, DrvId_RD, DrvId_RFS

library kernel.driver
extern DRV_CallDriver, DRV_FindName

library kernel.paging
extern PG_GetNumFreePages

library kernel.mm
extern MM_AllocBlock, MM_FreeBlock
extern MM_FreeMCBarea

library kernel.mt
extern MT_Exec, K_GetProcDescAddr

library kernel.fs
extern CFS_MakeFS, CFS_LinkFS, CFS_UnlinkFS
extern CFS_SetCurrentLP
extern CFS_Open, CFS_Close, CFS_Read, CFS_Write
extern CFS_CreateFile, CFS_RemoveFile
extern CFS_MoveFile, CFS_Truncate
extern CFS_ChangeDir, CFS_CreateDir, CFS_RemoveDir
extern BUF_FlushAll

library kernel.misc
extern StrLComp, StrScan
extern PrintDwordDec, PrintByteHex, PrintWordHex, PrintDwordHex
extern ReadString
extern K_DecD2Str
extern ValDwordDec, ValDwordHex
extern K_LDelayMs

library onboard.timer
extern TMR_CountCPUspeed


section .data

msg_Banner	DB NL,NL,"RadiOS Kernel Debugging Tool, version 1.0",NL
		DB "Copyright (c) 1999 RET & COM Research.",NL,0
msg_Debugging	DB NL,"DEBUGGING: ",0
msg_FScreated	DB "File system created on %ramdisk",NL,0
msg_CfgCreated	DB "Config file created",NL,0
msg_DbgPrompt	DB NL,"RKDT>",0
msg_Err		DB NL,NL,7,"ERROR ",0
msg_SerHlp	DB NL,NL,"Press Ctrl-Z to exit, Ctrl-V to get stat",NL,0
msg_MemSt	DB NL,NL,"MCB",9,9,"Addr",9,9,"Len",9,9,"Next MCB",9,"Prev MCB",NL,0
msg_FreeMem	DB NL,"Physical memory free (KB): ",0

cmdQuit		DB "q"
cmdMon		DB "S"
cmdNewTxtFile	DB "cf"
cmdRmFile	DB "rm"
cmdLs		DB "ls"
cmdView		DB "vw"
cmdRm		DB "rm"
cmdMv		DB "mv"
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
cmdFreeMCBs	DB "freemcbs"
cmdGrabFile	DB "grabfile"
cmdGetISS	DB "getiss"

CfgName		DB "radios.config",0
ConfigFile	DB ";-----------------------------------------------------",NL
		DB "; radios.config - RadiOS configuration file",NL
		DB ";-----------------------------------------------------",NL,NL
		DB "Driver=cm6329.drv",NL
		DB ";Driver=ess1868.drv",NL
		DB NL
		DB "MaxProcesses=8",NL
		DB 0
SizeOfCfgFile	EQU	$-ConfigFile
ends

%macro mPrintMsg 1
 mWrString msg_Debugging
 mWrString %1
%endmacro

section .bss

SBuffer		RESB	80



section .text

proc RKDT_CreateRDimage

		; Link %ramdisk with %rfs at F:
		mov	esi,[DrvId_RFS]
		mov	edi,[DrvId_RD]
		mov	dl,5
		mov	dh,flFSL_NoInitFS
		call	CFS_LinkFS
		jc	near .Err

		; Make filesystem on %ramdisk
		mov	dl,5			; "F:"
		xor	esi,esi
		call	CFS_MakeFS
		jc	near .Err
		call	CFS_SetCurrentLP

		; Unlink filesystem from %ramdisk
		mov	dl,5
		call	CFS_UnlinkFS
		jc	near .Err
		mPrintMsg msg_FScreated

		; Link filesystem again
		mov	esi,[DrvId_RFS]
		mov	edi,[DrvId_RD]
		mov	dx,5
		call	CFS_LinkFS
		jc	near .Err

		; Create config file
		mov	esi,CfgName
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .WrConf
		call	TEST_ErrorHandler
		jmp	.Err

		; Write config file
.WrConf:	mov	esi,ConfigFile
		mov	ecx,SizeOfCfgFile
		xor	eax,eax
		call	CFS_Write
		jnc	short .CloseCfg
		call	TEST_ErrorHandler
		jmp	short .Err

		; Close config file
.CloseCfg:	xor	eax,eax
		call	CFS_Close
		jc	short .Err

		; Unlink filesystem from %ramdisk
		mov	dl,5
		call	CFS_UnlinkFS
		jc	short .Err

		mPrintMsg msg_CfgCreated
		ret

.Err:		int3
		ret
endp		;---------------------------------------------------------------


proc TEST_ExamineFS
		mWrString msg_Banner
.Loop:		mWrString msg_DbgPrompt
		mov	esi,offset SBuffer
		mov	cl,48
		call	ReadString
		and	ecx,0FFh
		mov	byte [esi+ecx],0

		mov	cl,1
		mov	edi,cmdQuit
		call	StrLComp
		jz	near .Exit

		mov	edi,cmdMon
		call	StrLComp
		jnz	.NotMon
		int3
		jmp	.Loop

.NotMon:	mov	cl,2
		mov	edi,cmdNewTxtFile
		call	StrLComp
		push	dword .Loop
		jz	near TEST_CreateTextFile
		add	esp,4

		mov	edi,cmdView
		call	StrLComp
		push	dword .Loop
		jz	near TEST_ViewFile
		add	esp,4

		mov	edi,cmdRm
		call	StrLComp
		push	dword .Loop
		jz	near TEST_RemoveFile
		add	esp,4

		mov	edi,cmdMv
		call	StrLComp
		push	dword .Loop
		jz	near TEST_MoveFile
		add	esp,4

		mov	edi,cmdLs
		call	StrLComp
		push	dword .Loop
		jz	near TEST_Ls
		add	esp,4

		mov	edi,cmdMd
		call	StrLComp
		push	dword .Loop
		jz	near TEST_MkDir
		add	esp,4

		mov	edi,cmdCd
		call	StrLComp
		push	dword .Loop
		jz	near TEST_ChDir
		add	esp,4

		mov	edi,cmdRd
		call	StrLComp
		push	dword .Loop
		jz	near TEST_RmDir
		add	esp,4

		mov	edi,cmdCM
		call	StrLComp
		push	dword .Loop
		jz	near TEST_CreateManyFiles
		add	esp,4

		mov	edi,cmdCL
		call	StrLComp
		push	dword .Loop
		jz	near TEST_CreateLargeFile
		add	esp,4


		mov	cl,5
		mov	edi,cmdFlushBuffers
		call	StrLComp
		jnz	.NotFlush
		call	BUF_FlushAll
		jmp	.Loop

.NotFlush:	mov	edi,cmdProbe
		call	StrLComp
		push	dword .Loop
		jz	near TEST_Probe
		add	esp,byte 4

		mov	cl,8
		mov	edi,cmdGrabFile
		call	StrLComp
		push	dword .Loop
		jz	near TEST_GrabFile
		add	esp,byte 4

		mov	edi,cmdFreeMCBs
		call	StrLComp
		push	dword .Loop
		jz	near TEST_FreeMCBs
		add	esp,byte 4

		mov	edi,cmdAllocMem
		call	StrLComp
		push	dword .Loop
		jz	near TEST_AllocMem
		add	esp,byte 4

		mov	cl,7
		mov	edi,cmdFreeMem
		call	StrLComp
		push	dword .Loop
		jz	near TEST_FreeMem
		add	esp,byte 4

		mov	edi,cmdMemStat
		call	StrLComp
		push	dword .Loop
		jz	near TEST_MemStat
		add	esp,byte 4

		mov	cl,10
		mov	edi,cmdSerial
		call	StrLComp
		push	dword .Loop
		jz	near TEST_Serial
		add	esp,byte 4

		mov	cl,6
		mov	edi,cmdGetISS
		call	StrLComp
		push	dword .Loop
		jz	near TEST_GetISS
		add	esp,byte 4

		mov	cl,4
		mov	edi,offset cmdExec
		call	StrLComp
		push	dword .Loop
		jz	near TEST_Exec
		add	esp,byte 4

		jmp	.Loop

.Exit:		ret
endp		;---------------------------------------------------------------


proc TEST_CreateTextFile
%define	.handle		ebp-4
%define	.size		ebp-8
%define	.buffer		ebp-8-520

		prologue 528
		mpush	ecx,esi
		add	esi,ecx
		inc	esi

		; Open file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Begin
		call	TEST_ErrorHandler
		jmp	short .Exit

.Begin:		mov	[.handle],ebx

		; Read file from console
		lea	esi,[.buffer]
		mov	dword [.size],0
.Loop:		mWrChar NL
		mov	cl,77
		call	ReadString
		or	cl,cl
		jz	.EmptyLn
		cmp	byte [esi],'`'
		je	short .EndInput
.EmptyLn:	and	ecx,0FFh
		add	esi,ecx
		mov	byte [esi],NL
		inc	esi
		add	[.size],ecx
		inc	dword [.size]
		jmp	.Loop

.EndInput:

		; Write to file
		lea	esi,[.buffer]
		mov	ebx,[.handle]
		mov	ecx,[.size]
		xor	eax,eax
		call	CFS_Write
		jnc	short .Close
		call	TEST_ErrorHandler

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc TEST_ViewFile
%define	.handle	ebp-4
%define	.buffer	ebp-516

		prologue 516
		mpush	ecx,esi
		add	esi,ecx
		inc	esi

		mWrChar NL
		mWrChar NL

		xor	edx,edx
		xor	eax,eax
		call	CFS_Open
		jnc	short .Loop
		call	TEST_ErrorHandler
		jmp	short .Exit

.Loop:		lea	esi,[.buffer]
		mov	ecx,512
		xor	eax,eax
		call	CFS_Read
		jc	short .Exit
		or	eax,eax
		jz	short .OK			; Nothing to view
		mov	ecx,eax

		push	ecx
.Print:		lodsb
		mCallDriver dword [DrvId_Con], byte DRVF_Write
		dec	ecx
		jz	short .EndPrint
		jmp	.Print
.EndPrint:	pop	ecx

		cmp	ecx,512
		jb	short .OK
		jmp	.Loop

.OK:		xor	ax,ax
		call	CFS_Close
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc TEST_RemoveFile
		mpush	ecx,esi
		add	esi,ecx
		inc	esi
		xor	eax,eax
		call	CFS_RemoveFile
		jnc	short .Exit
		call	TEST_ErrorHandler
.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_MoveFile
		mpush	ecx,esi
		add	esi,ecx
		inc	esi				; ESI=old name
		mov	edi,esi
		mov	al, ' '
		call	StrScan
		or	edi,edi
		jz	short .Exit
		xor	al,al
		stosb					; EDI=new name

		xor	eax,eax
		call	CFS_MoveFile
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_Ls
		mpush	ecx,esi
	extern rfs_ls
	call rfs_ls

		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_MkDir
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

 		xor	eax,eax
		call	CFS_CreateDir
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_ChDir
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	CFS_ChangeDir
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_RmDir
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	CFS_RemoveDir
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_CreateManyFiles
%define	.count		ebp-4
%define	.buf		ebp-16

		prologue 16
		mpush	ecx,esi

		mov	dword [.count],0
.Loop:		lea	esi,[.buf]
		mov	eax,[.count]
		call	K_DecD2Str

		; Create file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Close
		call	TEST_ErrorHandler
		jmp	short .Exit

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Cont
		call	TEST_ErrorHandler
		jmp	short .Exit

.Cont:		inc	dword [.count]
		cmp	dword [.count],31
		je	short .Exit
		jmp	.Loop


.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc TEST_CreateLargeFile
		mpush	ecx,esi
		add	esi,ecx
		inc	esi

		; Open file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Begin
		call	TEST_ErrorHandler
		jmp	short .Exit

		; Write to file
.Begin:		mov	esi,0B8000h
		mov	ecx,211931
		xor	eax,eax
		call	CFS_Write
		jnc	short .Close
		call	TEST_ErrorHandler

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_GrabFile - grab file from 90002h.
		; Note: file length (<64K) is at 90000h.
proc TEST_GrabFile
		mpush	ecx,esi
		or	ecx,ecx
		jz	short .Exit
		add	esi,ecx
		inc	esi

		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Write
		call	TEST_ErrorHandler
		jmp	short .Exit

		; Write file
.Write:		mov	esi,90002h
		movzx	ecx,word [90000h]
		xor	eax,eax
		call	CFS_Write
		jnc	short .Close
		call	TEST_ErrorHandler
		jmp	short .Exit

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_Serial - serial driver test.
proc TEST_Serial
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	DRV_FindName
		jnc	short .Start
		call	TEST_ErrorHandler
		jmp	.Exit

.Start:		test	eax,00FF0000h
		jz	near .Exit
		mov	edi,eax
		mWrString msg_SerHlp

		mCallDriver edi, byte DRVF_Open
		jnc	short .TTYmode
		call	TEST_ErrorHandler
		jmp	.Exit

.TTYmode:	mCallDriverCtrl edi,DRVCTL_SER_GetRXbufStat
		jc	near .Close
		or	dx,dx
		jz	short .CheckKey
		mCallDriver edi, byte DRVF_Read
		mCallDriver dword [DrvId_Con], byte DRVF_Write
		jmp	.TTYmode

.CheckKey:	mCallDriverCtrl byte DRVID_Keyboard,DRVCTL_KB_CheckKeyPress
		jz	.TTYmode
		mCallDriver dword [DrvId_Con], byte DRVF_Read
		cmp	al,ASC_SUB
		je	near .Close
		cmp	al,ASC_SYN
		je	short .PrintStat
		mCallDriver edi, byte DRVF_Write
		jnc	.TTYmode
		call	TEST_ErrorHandler
		jmp	short .Close

.PrintStat:	mCallDriverCtrl edi,DRVCTL_SER_GetUARTmode
		jc	short .Close
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
		jmp	.TTYmode

.Close:		mCallDriver edi, byte DRVF_Close
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_Probe - misc probing calls.
proc TEST_Probe
		mpush	ecx,esi

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

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_Exec - execute a program.
proc TEST_Exec
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		xor	edx,edx				; Sync exec
		call	MT_Exec
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_AllocMem - allocate memory block.
proc TEST_AllocMem
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	ValDwordHex
		jc	short .Exit
		mov	ecx,eax
		xor	eax,eax
		xor	dl,dl
		call	MM_AllocBlock
		jnc	short .PrintAddr
		call	TEST_ErrorHandler
		jmp	short .Exit

.PrintAddr:	mWrChar NL
		mov	eax,ebx
		call	PrintDwordHex

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_FreeMem - free memory block.
proc TEST_FreeMem
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	ValDwordHex
		jc	short .Exit
		mov	ebx,eax
		xor	eax,eax
		xor	dl,dl
		xor	edi,edi
		call	MM_FreeBlock
		jnc	short .Exit
		call	TEST_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_MemStat - print process memory state.
proc TEST_MemStat
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	near .Exit

		call	K_GetProcDescAddr
		jc	near .Exit
		mov	edi,ebx
		mov	ebx,[ebx+tProcDesc.FirstMCB]

		mov	eax,cr3
		push	eax
		mov	eax,[edi+tProcDesc.PageDir]
		mov	cr3,eax

		or	ebx,ebx
		jz	near .PrintTotal
		mWrString msg_MemSt

.Loop:		or	ebx,ebx
		jz	near .PrintTotal
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
		jmp	.Loop

.PrintTotal:	mWrString msg_FreeMem
		call	PG_GetNumFreePages
		mov	eax,ecx
		shl	eax,2
		call	PrintDwordDec
		mWrChar NL

		pop	eax
		mov	cr3,eax

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_FreeMCBs - free process MCBs.
proc TEST_FreeMCBs
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call    ValDwordDec
		jc	short .Exit
		or	eax,eax
		jz	short .Exit
		mov	edx,eax

		call	K_GetProcDescAddr
		jc	short .Exit
		mov	esi,ebx

		mov	eax,cr3
		push	eax
		mov	eax,[esi+tProcDesc.PageDir]
		mov	cr3,eax

		mov	eax,edx
		call	MM_FreeMCBarea
		jnc	short .RestorePD
		call	TEST_ErrorHandler

.RestorePD:	pop	eax
		mov	cr3,eax

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_GetISS - get and print driver initialization status
		;		string.
proc TEST_GetISS
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	DRV_FindName
		jnc	short .GotDID
		call	TEST_ErrorHandler
		jmp	short .Exit

.GotDID:	mCallDriverCtrl eax,DRVCTL_GetInitStatStr
		jnc	short .Print
                call	TEST_ErrorHandler
		jmp	short .Exit

.Print:		mWrChar NL
		mCallDriverCtrl dword [DrvId_Con],DRVCTL_CON_WrString

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; Error handler.
proc TEST_ErrorHandler
		mWrString msg_Err
		call	PrintWordHex
		cmp	ax,ERR_FS_DiskFull			; Disk full?
		jne	short .Exit
		xor	eax,eax
		call	CFS_Truncate
.Exit:		ret
endp		;---------------------------------------------------------------
