;-------------------------------------------------------------------------------
;  dma.asm - Direct memory access controllers control module.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Command register bits
DMACMD_MemMem		EQU	1
DMACMD_Ch0Hold		EQU	2
DMACMD_DisCtrl		EQU	4
DMACMD_ComprTim		EQU	8
DMACMD_RotPrior		EQU	16
DMACMD_ExtWrite		EQU	32
DMACMD_DRQhi		EQU	64
DMACMD_DACKhi		EQU	128

; Request and single mask bit registers control bytes
DMA_CH0			EQU	0
DMA_CH1			EQU	1
DMA_CH2			EQU	2
DMA_CH3			EQU	3
DMARQMS_Set		EQU	4

; Mode register
DMAMODE_Verify		EQU	0
DMAMODE_Write		EQU	4
DMAMODE_Read		EQU	8
DMAMODE_AutoInit	EQU	16
DMAMODE_AddrInc		EQU	32
DMAMODE_Demand		EQU	0
DMAMODE_Single		EQU	64
DMAMODE_Block		EQU	128
DMAMODE_Cascade		EQU	192

; All mask register bits
DMAMASK_CH0		EQU	1
DMAMASK_CH1		EQU	2
DMAMASK_CH2		EQU	4
DMAMASK_CH3		EQU	8


; --- Data ---
DMA1_PageRegs		DB PORT_DMA1_P0,PORT_DMA1_P1,PORT_DMA1_P2,PORT_DMA1_P3
DMA2_PageRegs		DB PORT_DMA2_P4,PORT_DMA2_P5,PORT_DMA2_P6,PORT_DMA2_P7
			DB 253 dup (?)

; --- Procedures ---

		; DMA_Reset - reset of DMA controller.
		; Input: AL=controller number (1,2).
		; Output: none.
proc DMA_Reset near
		cmp	al,1
		jne	@@DMA2
		out	PORT_DMA1_MastClr,al
		jmp	@@Exit
@@DMA2:		out	PORT_DMA2_MastClr,al
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DMA_InitCnannel - initialize DMA channel.
		; Input: AL=channel number (0..7),
		;	 AH=mode (bits 2..7 only!),
		;	 EBX=data address,
		;	 CX=number of bytes-1 (DMA #1)/words-1 (DMA #2),
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc DMA_InitChannel near
		cmp	al,8				; Check channel number
		jae	@@Err1
		cmp	ebx,1000000h			; Check address
		jae	@@Err2
		cmp	al,4				; Slave controller?
		jae	@@Slave
		push	ebx
		add	bx,cx
		pop	ebx
		jc	@@Err3

		push	eax
		push	ebx
		push	edx
		pushfd
		cli
		mov	dl,al				; Keep channel number
		shl	edx,16				; in high word of EDX
		push	ebx
		mov	ebx,offset DMA1_PageRegs
		xlatb
		pop	ebx
		mov     dl,al				; DX=page reg. addr.
		ror	ebx,16				; Get page in BX
		mov	al,bl
		out	dx,al

		shr	edx,16
		mov	al,dl
		add	al,ah				; Add channel number
		out	PORT_DMA1_Mode,al
		out	PORT_DMA1_ClrBPFF,al
		xor	dh,dh
		shl	dl,1				; DX=base addr. reg.
                ror	ebx,16				; Restore offset
		mov	al,bl
		out	dx,al
		mov	al,bh
		out	dx,al
		inc	dx				; DX=size reg.
		mov	al,cl
		out	dx,al
		mov	al,ch
		out	dx,al

		popfd
		pop	edx
		pop	ebx
		pop	eax
		jmp	short @@OK

@@Slave:	test	bl,1				; Even address?
		jnz	@@Err4
		push	ebx				; Test page overflow
		push	ecx
		and	ebx,1FFFFh			; Mask page
		movzx	ecx,cx
		shl	ecx,1
		add	ebx,ecx
		test	ebx,20000h			; Overflow?
		pop	ecx
		pop	ebx
		jnz	@@Err3



@@OK:		clc
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_DMA_BadChNum
		jmp	short @@Err
@@Err2:		mov	ax,ERR_DMA_BadAddr
		jmp	short @@Err
@@Err3:		mov	ax,ERR_DMA_PageOut
		jmp	short @@Err
@@Err4:		mov	ax,ERR_DMA_AddrOdd
		jmp	short @@Err
@@Err:		stc
@@Exit:		ret
endp		;---------------------------------------------------------------
