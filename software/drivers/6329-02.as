;*******************************************************************************
;  6329-02.asm - Robotron CM6329.02-M (IFSP) printer driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

%include "tasmlike.mac"

global ??DrvCM6329


; --- Data ---
section .data

??DrvCM6329	DD	CM_Init				; Initialize
		DD	CM_HandleEvents			; Handle interrupts
		DD	CM_Open				; Open device
		DD	CM_Close			; Close device
		DD	0
		DD	CM_Write			; Write character
		DD	0
		DD	CM_Control			; IOCTL

CM_Control	DD	CM_GetISS

Message		DB "Robotron CM6329.02-M printer driver, version 1.0",0Ah
                DB "Copyright (c) 1998 RET & COM research",0Ah,0



section .text

; --- Interface procedures ---

		; CM_Init - initialize a driver.
		; Input: ESI=pointer to arguments line.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CM_Init
		ret
endp		;---------------------------------------------------------------


		; CM_HandleEvents - handle driver events.
		; Input: EAX=event code.
		; Output: none.
proc CM_HandleEvents
		ret
endp		;---------------------------------------------------------------


		; CM_Open - open device.
		; Input:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CM_Open
		ret
endp		;---------------------------------------------------------------


		; CM_Close - close device.
		; Input:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CM_Close
		ret
endp		;---------------------------------------------------------------


		; CM_Write - write one character to printer.
		; Input: AL=character code.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CM_Write
		ret
endp		;---------------------------------------------------------------


		; CM_GetISS - get driver init status string.
		; Input: ESI=pointer to buffer.
		; Output: none.
proc CM_GetISS
		mpush	esi,edi
		mov	edi,esi
		mov	esi,Message
.Copy:		lodsb
		or	al,al
		jz	short .Exit
		stosb
		jmp	short .Copy
		
.Exit:		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------

end
