;*******************************************************************************
;  ess1868.asm - ES1868 AudioDrive (DSP and extended mixer) driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

%include "tasmlike.mac"

global ??DrvESS1868


section .data

??DrvESS1868	DD	ESS_Init
		DD	ESS_HandleEvents
		DD	ESS_Open
		DD	ESS_Close
		DD	ESS_Read
		DD	ESS_Write
		DD	0
		DD	ESS_Control

ESS_Control	DD	ESS_GetISS
		DD	ESS_GetParams
		DD	ESS_SetParams
		DD	0,0,0,0
		DD	ESS_DSPcontrol

section .text

		; ESS_Init - initialize the driver.
		; Input: ESI=buffer for init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ESS_Init
		ret
endp		;---------------------------------------------------------------


		; ESS_HandleEvents - handle driver events.
		; Input: EAX=event code.
		; Output: none.
proc ESS_HandleEvents
		ret
endp		;---------------------------------------------------------------


		; ESS_Open - open the device.
		; Input:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ESS_Open
		ret
endp		;---------------------------------------------------------------


		; ESS_Close - close the device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ESS_Close
		ret
endp		;---------------------------------------------------------------


		; ESS_Read - read a block from the DSP.
		; Input: ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ESS_Read
		ret
endp		;---------------------------------------------------------------


		; ESS_Write - write a block to the DSP.
		; Input: ESI=block address,
		;	 ECX=block size.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ESS_Write
		ret
endp		;---------------------------------------------------------------


		; ESS_GetISS - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc ESS_GetISS
		ret
endp		;---------------------------------------------------------------


		; ESS_GetParams - get device parameters.
		; Input: none.
		; Output: CF=0 - OK:
		;
		;	  CF=1 - error, AX=error code.
proc ESS_GetParams
		ret
endp		;---------------------------------------------------------------


		; ESS_SetParams - set device parameters.
		; Input:
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc ESS_SetParams
		ret
endp		;---------------------------------------------------------------


		; ESS_DSPcontrol - extended DSP control.
		; Input:
		; Output:
proc ESS_DSPcontrol
		ret
endp		;---------------------------------------------------------------

end
