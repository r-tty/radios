;*******************************************************************************
;  rkdt.as - RadiOS Kernel Debugging Tool.
;  Copyright (c) 1999,2000 RET & COM Research.
;*******************************************************************************

module rkdt

%include "sys.ah"
%include "errors.ah"
%include "sema.ah"
%include "pool.ah"
%include "process.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "kconio.ah"
%include "asciictl.ah"
%include "commonfs.ah"
%include "memman.ah"

global RKDT_CreateRDimage, RKDT_ErrorHandler, RKDT_Main

library kernel
extern DrvId_RD, DrvId_RFS

library kernel.driver
extern DRV_CallDriver, DRV_FindName

library kernel.paging
extern PG_GetNumFreePages

library kernel.mm
extern MM_AllocBlock:near, MM_FreeBlock:near
extern MM_FreeMCBarea:near
extern MM_DebugAllocMem:near, MM_DebugFreeMem:near
extern MM_PrintStat:near, MM_DebugFreeMCBs:near

library kernel.mt
extern ?ProcListPtr
extern MT_DumpReadyThreads:near, MT_PrintSchedStat:near

library kernel.misc
extern StrLComp:near, StrScan:near
extern K_LDelayMs:near

library kernel.kconio
extern PrintChar:near, PrintString:near
extern PrintDwordDec, PrintByteHex, PrintWordHex, PrintDwordHex
extern ReadString
extern DecD2Str
extern ValDwordDec, ValDwordHex

library init
extern SysReboot

library hw.onboard
extern TMR_CountCPUspeed

library hw.serport
extern SER_DumbTTY


; --- Macros ---

%macro mPrintMsg 1
 mPrintString msg_Debugging
 mPrintString %1
%endmacro


; --- Data ---

section .data

msg_Banner	DB NL,NL,"RadiOS Kernel Debugging Tool, version 1.1",NL
		DB "Copyright (c) 1999,2000 RET & COM Research.",NL,0
		
msg_Help	DB NL,"Commands:",NL
		DB "S      - call monitor (g to go back)",NL
		DB "stat   - view scheduler statistics",NL
		DB "ts     - view thread statistics",NL
		DB "reboot - reboot machine",NL
		DB "help   - get this message",NL,0
		
msg_DbgPrompt	DB NL,"RKDT>",0
msg_Err		DB NL,NL,7,"ERROR ",0
msg_Debugging	DB NL,"DEBUGGING: ",0
msg_Rebooting	DB NL,"...rebooting...",0

cmdQuestion	DB 1,"?"				; Must be first
		DD	RKDT_Help
cmdHelp		DB 4,"help"
		DD	RKDT_Help
cmdMon		DB 1,"S"
		DD	RKDT_CallMonitor
cmdNewTxtFile	DB 2,"cf"
		DD	0
cmdRmFile	DB 2,"rm"
		DD	0
cmdLs		DB 2,"ls"
		DD	0
cmdView		DB 2,"vw"
		DD	0
cmdRm		DB 2,"rm"
		DD	0
cmdMv		DB 2,"mv"
		DD	0
cmdCM		DB 2,"CM"
		DD	0
cmdCL		DB 2,"CL"
		DD	0
cmdMd		DB 2,"md"
		DD	0
cmdCd		DB 2,"cd"
		DD	0
cmdRd		DB 2,"rd"
		DD	0

cmdFlushBuffers	DB 5,"flush"
		DD	0
cmdSerial	DB 10,"testserial"
		DD	SER_DumbTTY
cmdProbe	DB 5,"probe"
		DD	0
cmdExec		DB 4,"exec"
		DD	0
cmdAllocMem	DB 8,"allocmem"
		DD	MM_DebugAllocMem
cmdFreeMem	DB 7,"freemem"
		DD	MM_DebugFreeMem
cmdMemStat	DB 7,"memstat"
		DD	MM_PrintStat
cmdFreeMCBs	DB 8,"freemcbs"
		DD	MM_DebugFreeMCBs
cmdGrabFile	DB 8,"grabfile"
		DD	0
cmdGetISS	DB 6,"getiss"
		DD	RKDT_GetISS

cmdSchedStat	DB	4,"stat"
		DD	MT_PrintSchedStat
cmdThreadStat	DB	2,"ts"
		DD	MT_DumpReadyThreads
cmdReboot	DB	6,"reboot"
		DD	RKDT_Reboot
		DB	0


; --- Variables ---

section .bss

SBuffer		RESB	80


; --- Code ---

section .text

		; RKDT_DispatchCmd - dispatch entered command.
		; Input: ESI=address of command line.
		; Output: none.
proc RKDT_DispatchCmd
		push	edi
		xor	ecx,ecx
		mov	edi,cmdQuestion
		
.Loop:		mov	cl,[edi]			; Command length
		or	cl,cl
		jz	short .Done
		inc	edi
		call	StrLComp
		jz	short .GotCmd
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


		; RKDT_Main - entry point of RKDT.
		; Input: none.
		; Output: never.
proc RKDT_Main
		mPrintString msg_Banner
.Loop:		mPrintString msg_DbgPrompt
		mov	esi,offset SBuffer
		mov	cl,48
		call	ReadString
		and	ecx,0FFh
		mov	byte [esi+ecx],0

		call	RKDT_DispatchCmd
		jmp	.Loop
endp		;---------------------------------------------------------------


		; RKDT_Help - print a short help message.
proc RKDT_Help
		mPrintString msg_Help
		ret
endp		;---------------------------------------------------------------


		; RKDT_CallMonitor - just int3.
proc RKDT_CallMonitor
		int3
		ret
endp		;---------------------------------------------------------------


		; RKDT_Reboot - reboot machine.
proc RKDT_Reboot
		mPrintString msg_Rebooting
		call	SysReboot
		ret
endp		;---------------------------------------------------------------


		; RKDT_Probe - misc probing calls.
proc RKDT_Probe
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	TMR_CountCPUspeed
		mPrintChar NL
		mov	eax,ecx
		call	PrintDwordDec

		cli					; 10 sec test
		mov	ecx,10000
		call	K_LDelayMs
		sti

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RKDT_GetISS - get and print driver initialization status
		;		string.
proc RKDT_GetISS
		mpush	ecx,esi

		add	esi,ecx
		cmp	byte [esi],0
		je	short .Exit
		inc	esi

		call	DRV_FindName
		jnc	short .GotDID
		call	RKDT_ErrorHandler
		jmp	short .Exit

.GotDID:	mCallDriverCtrl eax,DRVCTL_GetInitStatStr
		jnc	short .Print
                call	RKDT_ErrorHandler
		jmp	short .Exit

.Print:		mPrintChar NL
		mPrintString

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RKDT_ErrorHandler - error handler.
		; Input: AX=error code.
		; Output: none.
proc RKDT_ErrorHandler
		mPrintString msg_Err
		call	PrintWordHex
		xor	eax,eax
.Exit:		ret
endp		;---------------------------------------------------------------
