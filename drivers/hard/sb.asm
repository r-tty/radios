;*******************************************************************************
;  sb.asm - Sound Blaster compatible DSP driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

; --- Definitions ---

; SB ports
MixerAddr		EQU	4
MixerData		EQU	5
DSPReset		EQU	6
DSPReadData		EQU	10
DSPWriteData		EQU	12
DSPWriteStatus		EQU	12
DSPDataAvail		EQU	15

; Timeout loop
DSP_TimeoutLoop		EQU	07FFFh


; --- Data ---
segment KDATA
; Audio driver main structure
DrvAudio	tDriver <"%audio          ",offset DrvAudioET,0>

; Driver entry points table
DrvAudioET	tDrvEntries < SB_Init,\
			      SB_HandleEvent,\
			      SB_Open,\
			      SB_Close,\
			      SB_Read,\
			      SB_Write,\
			      NULL,\
			      SB_Control >

SB_Control	DD	SB_GetInitStatStr
		DD	SB_GetParameters
		DD	SB_SetParameters
ends


; --- Variables ---
segment KVARS

; SB ports
DSP_BasePort	DW	220h			; DSP base port address
DSP_IRQ		DB	5			; IRQ line
DSP_DMA8	DB	1			; 8-bit DMA channel
DSP_DMA16	DB	5			; 16-bit DMA channel (SB16)

ends


; --- Interface procedures ---

		; SB_Init - initialize the audio device.
		; Input: ESI=buffer of init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Init near
		ret
endp		;---------------------------------------------------------------


		; SB_HandleEvent - handle events.
		; Input: EAX=event code.
		; Output: none.
proc SB_HandleEvent near
		ret
endp		;---------------------------------------------------------------


		; SB_Open - open the device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Open near
		ret
endp		;---------------------------------------------------------------


		; SB_Close - close the device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Close near
		ret
endp		;---------------------------------------------------------------


		; SB_Read - read a block from the DSP.
		; Input: ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Read near
		ret
endp		;---------------------------------------------------------------


		; SB_Write - write a block to DSP.
		; Input: ESI=block address;
		;	 ECX-block size.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc SB_Write near
		ret
endp		;---------------------------------------------------------------


		; SB_GetInitStatStr - get driver init status string.
proc SB_GetInitStatStr near
		ret
endp		;---------------------------------------------------------------


		; SB_GetParameters - get device parameters.
		; Input:
		; Output:
proc SB_GetParameters near
		ret
endp		;---------------------------------------------------------------


		; SB_SetParameters - set device parameters.
		; Input:
		; Output:
proc SB_SetParameters near
		ret
endp		;---------------------------------------------------------------



; --- Implementation routines ---

		; SB_MixerStereo - enable stereo output.
		; Input: none.
		; Output: none.
		; Note: valid only for DSP versions 3.00 <= ver < 4.00
proc SB_MixerStereo near
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
proc SB_MixerMono near
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
proc SB_WaitDSPWrite near
		push	eax
		push	ecx
		push	edx
		mov	ecx,DSP_TimeoutLoop
		mov	dx,[DSP_BasePort]
		add     dx,DSPWriteStatus
@@1:		in	al,dx
		and	al,80h
		loopnz	@@1
		clc
		jz	@@Exit
		stc
@@Exit:		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_WaitDSPRead - wait until the DSP is ready to read from.
		; Input: none.
		; Output: CF=0 - OK, DSP is ready;
		;	  CF=1 - timeout.
proc SB_WaitDSPRead near
		push	eax
		push	ecx
		push	edx
		mov	ecx,DSP_TimeoutLoop
		mov	dx,[DSP_BasePort]
		add     dx,DSPDataAvail
@@1:		in	al,dx
		and	al,80h
		loopz	@@1
		clc
		jnz	@@Exit
		stc
@@Exit:		pop	edx
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_WriteDSP - write byte to DSP.
		; Input: AL=byte.
		; Output: CF=0 - OK;
		;	  CF=1 - timeout.
proc SB_WriteDSP near
		call	SB_WaitDSPWrite
		jc	@@Exit
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,DSPWriteData
		out	dx,al
		pop	edx
@@Exit:		ret
endp		;---------------------------------------------------------------


		; SB_ReadDSP - read byte from DSP.
		; Input: none.
		; Output: CF=0 - OK, AL=read byte;
		;	  CF=1 - timeout.
proc SB_ReadDSP near
		call	SB_WaitDSPRead
		jc	@@Exit
		push	edx
		mov	dx,[DSP_BasePort]
		add	dx,DSPReadData
		in	al,dx
		pop	edx
@@Exit:		ret
endp		;---------------------------------------------------------------


		; SB_EnableOutput - enable DAC output.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - DSP writing timeout.
proc SB_EnableOutput near
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
proc SB_DisableOutput near
		push	eax
		mov	al,0D3h
		call	SB_WriteDSP
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_ResetDSP - reset the DSP.
		; Input: none.
		; Output: none.
proc SB_ResetDSP near
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
@@1:		in	al,dx				; Delay
		loop	@@1
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
proc SB_Ping near
		push	eax
		call	SB_ResetDSP
		call	SB_ReadDSP
		cmp	al,0AAh
		je	@@OK
		stc
		jmp	short @@Exit
@@OK:		clc
@@Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; SB_GetDSPVer - get DSP version.
		; Input: none.
		; Output: CF=0 - OK, AX=DSP version;
		;	  CF=1 - timeout.
proc SB_GetDSPVer near
		push	eax
		mov	al,0E1h
		call	SB_WriteDSP
		pop	eax
		jc	@@Exit
		call	SB_ReadDSP
		mov	ah,al
		call	SB_ReadDSP
@@Exit:		ret
endp		;---------------------------------------------------------------
