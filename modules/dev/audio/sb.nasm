;*******************************************************************************
;  sb.nasm - Sound Blaster compatible DSP driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

module hw.audio.sb

%define	extcall near

%include "sys.ah"

; --- Exports ---

global DrvAudio


; --- Imports ---


; --- Definitions ---

; SB ports
%define	MixerAddr		4
%define	MixerData		5
%define	DSPReset		6
%define	DSPReadData		10
%define	DSPWriteData		12
%define	DSPWriteStatus		12
%define	DSPDataAvail		15

; Timeout loop
%define	DSP_TimeoutLoop		07FFFh


; --- Data ---

section .data

; Audio driver main structure
DrvAudio	DB	"%audio"
		TIMES	16-$+DrvAudio DB 0
		DD	DrvAudioET
		DW	0

; Driver entry points table
DrvAudioET	DD	SB_Init
		DD	SB_HandleEvent
		DD	SB_Open
		DD	SB_Close
		DD	SB_Read
		DD	SB_Write
		DD	NULL
		DD	SB_Control

SB_Control	DD	SB_GetInitStatStr
		DD	SB_GetParameters
		DD	SB_SetParameters


; --- Variables ---

section .bss

; SB ports
DSP_BasePort	RESW	1			; DSP base port address
DSP_IRQ		RESB	1			; IRQ line
DSP_DMA8	RESB	1			; 8-bit DMA channel
DSP_DMA16	RESB	1			; 16-bit DMA channel (SB16)


; --- Interface procedures ---

section .text

		; SB_Init - initialize the audio device.
		; Input: ESI=buffer of init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Init
		stc
		ret
endp		;---------------------------------------------------------------


		; SB_HandleEvent - handle events.
		; Input: EAX=event code.
		; Output: none.
proc SB_HandleEvent
		ret
endp		;---------------------------------------------------------------


		; SB_Open - open the device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Open
		ret
endp		;---------------------------------------------------------------


		; SB_Close - close the device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Close
		ret
endp		;---------------------------------------------------------------


		; SB_Read - read a block from the DSP.
		; Input: ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Read
		ret
endp		;---------------------------------------------------------------


		; SB_Write - write a block to DSP.
		; Input: ESI=block address;
		;	 ECX-block size.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Write
		ret
endp		;---------------------------------------------------------------


		; SB_GetInitStatStr - get driver init status string.
proc SB_GetInitStatStr
		ret
endp		;---------------------------------------------------------------


		; SB_GetParameters - get device parameters.
		; Input:
		; Output:
proc SB_GetParameters
		ret
endp		;---------------------------------------------------------------


		; SB_SetParameters - set device parameters.
		; Input:
		; Output:
proc SB_SetParameters
		ret
endp		;---------------------------------------------------------------



; --- Implementation routines ---

		; SB_MixerStereo - enable stereo output.
		; Input: none.
		; Output: none.
		; Note: valid only for DSP versions 3.00 <= ver < 4.00
proc SB_MixerStereo
		push	eax
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,MixerAddr
		mov	al,15
		out	dx,al
		inc	dx				; DX=mixer data port
		in	al,dx
		or	al,2				; Enable stereo
		out	dx,al
		pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_MixerMono - disable stereo output.
		; Input: none.
		; Output: none.
		; Note: valid only for DSP versions 3.00 <= ver < 4.00
proc SB_MixerMono
		push	eax
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,MixerAddr
		mov	al,15
		out	dx,al
		inc	dx				; DX=mixer data port
		in	al,dx
		and	al,0FDh				; Disable stereo
		out	dx,al
		pop	edx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_WaitDSPWrite - wait until the DSP is ready
		;		    to be written to.
		; Input: none.
		; Output: CF=0 - OK, DSP is ready;
		;	  CF=1 - timeout.
proc SB_WaitDSPWrite
		push	eax
		push	ecx
		push	edx
		mov	ecx,DSP_TimeoutLoop
		mov	dx,[DSP_BasePort]
		add     dx,DSPWriteStatus
.1:		in	al,dx
		and	al,80h
		loopnz	.1
		clc
		jz	.Exit
		stc
.Exit:		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_WaitDSPRead - wait until the DSP is ready to read from.
		; Input: none.
		; Output: CF=0 - OK, DSP is ready;
		;	  CF=1 - timeout.
proc SB_WaitDSPRead
		push	eax
		push	ecx
		push	edx
		mov	ecx,DSP_TimeoutLoop
		mov	dx,[DSP_BasePort]
		add     dx,DSPDataAvail
.1:		in	al,dx
		and	al,80h
		loopz	.1
		clc
		jnz	.Exit
		stc
.Exit:		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_WriteDSP - write byte to DSP.
		; Input: AL=byte.
		; Output: CF=0 - OK;
		;	  CF=1 - timeout.
proc SB_WriteDSP
		call	SB_WaitDSPWrite
		jc	.Exit
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,DSPWriteData
		out	dx,al
		pop	edx
.Exit:		ret
endp		;---------------------------------------------------------------


		; SB_ReadDSP - read byte from DSP.
		; Input: none.
		; Output: CF=0 - OK, AL=read byte;
		;	  CF=1 - timeout.
proc SB_ReadDSP
		call	SB_WaitDSPRead
		jc	.Exit
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,DSPReadData
		in	al,dx
		pop	edx
.Exit:		ret
endp		;---------------------------------------------------------------


		; SB_EnableOutput - enable DAC output.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - DSP writing timeout.
proc SB_EnableOutput
		push	eax
		mov	al,0D1h
		call	SB_WriteDSP
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_DisableOutput - disable DAC output.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - DSP writing timeout.
proc SB_DisableOutput
		push	eax
		mov	al,0D3h
		call	SB_WriteDSP
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_ResetDSP - reset the DSP.
		; Input: none.
		; Output: none.
proc SB_ResetDSP
		push	eax
		push	ecx
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,DSPReset
		xor	al,al
		inc	al
		out	dx,al
		xor	ecx,ecx
		mov	cl,7
.1:		in	al,dx				; Delay
		loop	.1
		xor	al,al
		out	dx,al
		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_Ping - check SB presence (reset and wait echo).
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - SB is not present.
proc SB_Ping
		push	eax
		call	SB_ResetDSP
		call	SB_ReadDSP
		cmp	al,0AAh
		je	.OK
		stc
		jmp	short .Exit
.OK:		clc
.Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_GetDSPVer - get DSP version.
		; Input: none.
		; Output: CF=0 - OK, AX=DSP version;
		;	  CF=1 - timeout.
proc SB_GetDSPVer
		push	eax
		mov	al,0E1h
		call	SB_WriteDSP
		pop	eax
		jc	.Exit
		call	SB_ReadDSP
		mov	ah,al
		call	SB_ReadDSP
.Exit:		ret
endp		;---------------------------------------------------------------
