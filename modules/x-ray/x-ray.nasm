;*******************************************************************************
;  x-ray.nasm - a simple kernel debugging tool.
;  Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module rkdt

%include "sys.ah"
%include "errors.ah"
%include "pool.ah"
%include "process.ah"
%include "driver.ah"
%include "drvctrl.ah"
%include "kconio.ah"
%include "asciictl.ah"
%include "fs/cfs.ah"
%include "memman.ah"

global XR_ErrorHandler, XR_Main

library kernel.paging
extern PG_GetNumFreePages:near

library kernel.mm
extern MM_AllocBlock:near, MM_FreeBlock:near
extern MM_FreeMCBarea:near
extern MM_DebugAllocMem:near, MM_DebugFreeMem:near
extern MM_PrintStat:near, MM_DebugFreeMCBs:near

library kernel.mt
extern ?ProcListPtr
extern MT_DumpReadyThreads:near, MT_PrintSchedStat:near

library kernel.strutil
extern StrLComp:near, StrScan:near

library kernel.time
extern K_LDelayMs:near

library kernel.kconio
extern PrintChar:near, PrintString:near
extern PrintDwordDec:near,
extern PrintByteHex:near, PrintWordHex:near, PrintDwordHex:near
extern ReadString:near
extern DecD2Str:near

library init
extern SysReboot:near

library hw.onboard
extern TMR_CountCPUspeed:near


; --- Macros ---

%macro mPrintMsg 1
 mPrintString msg_Debugging
 mPrintString %1
%endmacro


; --- Data ---

section .data

msg_Banner	DB NL,"x-ray - RadiOS kernel debugging tool",NL
		DB "Copyright (c) 2002 RET & COM Research.",NL,0

msg_Help	DB NL,"Commands:",NL
		DB "S                    - call monitor (g to go back)",NL
		DB "stat                 - view scheduler statistics",NL
		DB "ts                   - view thread statistics",NL
		DB "allocmem [pid] size  - allocate <size> bytes to [pid] (default 0)",NL
		DB "freemem [pid] addr   - free memory block",NL
		DB "memstat [pid]        - print memory allocation info",NL
		DB "reboot               - reboot machine",NL,0
		
msg_DbgPrompt	DB NL,"x-ray>",0
msg_Err		DB NL,NL,7,"ERROR ",0
msg_Debugging	DB NL,"DEBUGGING: ",0
msg_Rebooting	DB NL,"...rebooting...",0

CommandTable	DB 1,"?"
		DD	XR_Help
		DB 4,"help"
		DD	XR_Help
		DB 1,"S"
		DD	XR_CallMonitor
		DB 7,"cpuinfo"
		DD	XR_CPUinfo
		DB 8,"allocmem"
		DD	MM_DebugAllocMem
		DB 7,"freemem"
		DD	MM_DebugFreeMem
		DB 7,"memstat"
		DD	MM_PrintStat
		DB 8,"freemcbs"
		DD	MM_DebugFreeMCBs

		DB	4,"stat"
		DD	MT_PrintSchedStat
		DB	2,"ts"
		DD	MT_DumpReadyThreads
		DB	6,"reboot"
		DD	XR_Reboot
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


		; XR_Main - entry point of RKDT.
		; Input: none.
		; Output: never.
proc XR_Main
		mPrintString msg_Banner
.Loop:		mPrintString msg_DbgPrompt
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
		mPrintString msg_Help
		ret
endp		;---------------------------------------------------------------


		; XR_CallMonitor - just int3.
proc XR_CallMonitor
		int3
		ret
endp		;---------------------------------------------------------------


		; XR_Reboot - reboot machine.
proc XR_Reboot
		mPrintString msg_Rebooting
		call	SysReboot
		ret
endp		;---------------------------------------------------------------


		; XR_CPUinfo - print CPU information.
proc XR_CPUinfo
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		call	TMR_CountCPUspeed
		mPrintChar NL
		mov	eax,ecx
		push	eax
		cli					; 10 sec test
		mov	ecx,10000
		call	K_LDelayMs
		sti
		pop	eax
		call	PrintDwordDec

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; XR_GetISS - get and print driver initialization status
		;		string.
proc XR_GetISS
		mpush	ecx,esi

		add	esi,ecx
		cmp	byte [esi],0
		je	short .Exit
		inc	esi

		call	DRV_FindName
		jnc	short .GotDID
		call	XR_ErrorHandler
		jmp	short .Exit

.GotDID:	mCallDriverCtrl eax,DRVCTL_GetInitStatStr
		jnc	short .Print
                call	XR_ErrorHandler
		jmp	short .Exit

.Print:		mPrintChar NL
		mPrintString

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; XR_ErrorHandler - error handler.
		; Input: AX=error code.
		; Output: none.
proc XR_ErrorHandler
		mPrintString msg_Err
		call	PrintWordHex
		xor	eax,eax
.Exit:		ret
endp		;---------------------------------------------------------------
