;-------------------------------------------------------------------------------
;  dma.nasm - Direct memory access control routines.
;-------------------------------------------------------------------------------

; --- Definitions ---

; Command register bits
%define	DMACMD_MemMem		1
%define	DMACMD_Ch0Hold		2
%define	DMACMD_DisCtrl		4
%define	DMACMD_ComprTim		8
%define	DMACMD_RotPrior		16
%define	DMACMD_ExtWrite		32
%define	DMACMD_DRQhi		64
%define	DMACMD_DACKhi		128

; Request and single mask bit registers control bytes
%define	DMA_CH0			0
%define	DMA_CH1			1
%define	DMA_CH2			2
%define	DMA_CH3			3
%define	DMARQMS_Set		4

; Mode register
%define	DMAMODE_Verify		0
%define	DMAMODE_Write		4
%define	DMAMODE_Read		8
%define	DMAMODE_AutoInit	16
%define	DMAMODE_AddrInc		32
%define	DMAMODE_Demand		0
%define	DMAMODE_Single		64
%define	DMAMODE_Block		128
%define	DMAMODE_Cascade		192

; All mask register bits
%define	DMAMASK_CH0		1
%define	DMAMASK_CH1		2
%define	DMAMASK_CH2		4
%define	DMAMASK_CH3		8


; --- Exports ---

global DMA_Reset, DMA_InitChannel


; --- Data ---

section .data

DMA1_PageRegs		DB PORT_DMA1_P0,PORT_DMA1_P1,PORT_DMA1_P2,PORT_DMA1_P3
DMA2_PageRegs		DB PORT_DMA2_P4,PORT_DMA2_P5,PORT_DMA2_P6,PORT_DMA2_P7


; --- Procedures ---

section .text

		; DMA_Reset - reset DMA controller.
		; Input: AL=controller number (1,2).
		; Output: none.
proc DMA_Reset
		cmp	al,1
		jne	short .DMA2
		out	PORT_DMA1_MastClr,al
		jmp	short .Exit
.DMA2:		out	PORT_DMA2_MastClr,al
.Exit:		ret
endp		;---------------------------------------------------------------


		; DMA_InitCnannel - initialize DMA channel.
		; Input: AL=channel number (0..7),
		;	 AH=mode (bits 2..7 only!),
		;	 EBX=data address,
		;	 CX=number of bytes-1 (DMA #1)/words-1 (DMA #2),
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc DMA_InitChannel
		cmp	al,8				; Check channel number
		jae	short .Err1
		cmp	ebx,1000000h			; Check address
		jae	short .Err2
		cmp	al,4				; Slave controller?
		jae	short .Slave
		push	ebx
		add	bx,cx
		pop	ebx
		jc	short .Err3

		mpush	eax,ebx,edx
		pushfd
		cli
		mov	dl,al				; Keep channel number
		shl	edx,16				; in high word of EDX
		push	ebx
		mov	ebx,DMA1_PageRegs
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
		mpop	edx,ebx,eax
		jmp	short .OK

.Slave:		test	bl,1				; Even address?
		jnz	short .Err4
		push	ebx				; Test page overflow
		push	ecx
		and	ebx,1FFFFh			; Mask page
		movzx	ecx,cx
		shl	ecx,1
		add	ebx,ecx
		test	ebx,20000h			; Overflow?
		pop	ecx
		pop	ebx
		jnz	short .Err3



.OK:		clc
		ret

.Err1:		mov	ax,ERR_DMA_BadChNum
		jmp	short .Err
.Err2:		mov	ax,ERR_DMA_BadAddr
		jmp	short .Err
.Err3:		mov	ax,ERR_DMA_PageOut
		jmp	short .Err
.Err4:		mov	ax,ERR_DMA_AddrOdd
.Err:		stc
		ret
endp		;---------------------------------------------------------------
