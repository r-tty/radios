;*******************************************************************************
;  parport.as - parallel port driver.
;  Based upon Linux code of parport_pc.c.
;*******************************************************************************

module hw.parport

%define extcall near

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "biosdata.ah"
%include "hw/parport.ah"

; --- Exports ---

global DrvParport


; --- Imports ---

library kernel.misc
extern StrCopy:extcall, StrEnd:extcall, StrAppend:extcall
extern K_HexW2Str:extcall, K_DecD2Str:extcall
extern K_MicroDelay:extcall

; --- Definitions ---

; Private port data
struc tPPprivate
.CTR		RESB	1			; Contents of CTR
endstruc

; Structure of device parameters
struc tPPdevParm
.BasePort	RESW	1
.BasePortHi	RESW	1
.IRQ		RESB	1
.DMA		RESB	1
.Modes		RESB	1
.State		RESB	1
.OpenCount	RESB	1
.Private	RESB	tPPprivate_size
.Reserved	RESB	6			; Pad to 16 bytes
endstruc

%define	PPDstrucShift	4


; --- Data ---

section .data

; Driver main structure
DrvParport	DB	"%parport"
		TIMES	16-$+DrvParport DB 0
		DD	DrvParportET
		DW	DRVFL_Char

; Driver entry points table
DrvParportET	DD	PAR_Init
		DD	PAR_HandleEvent
		DD	PAR_Open
		DD	PAR_Close
		DD	PAR_Read
		DD	PAR_Write
		DD	NULL
		DD	DrvPar_Ctrl

DrvPar_Ctrl	DD	PAR_GetInitStatStr
		DD	PAR_GetParameters

PP_InitStatStr	DB	9,": 0 port(s) detected",0
PP_BaseStr	DB	9,": base port ",0
PP_IRQstr	DB	", IRQ ",0
PP_DMAstr	DB	", DMA ",0

ParPortBases	DW	378h			; Port base addresses
		DW	278h
		DW	3BCh
		DW	2BCh
		DW	0,0,0,0

ParPortIRQs	DB	7			; Port IRQs
		DB	5
		DB	0,0,0,0,0,0

PP_IRQlookup	DB	0,7,9,10,11,14,15,5


; --- Variables ---

section .bss

PPdevTable	RESB	tPPdevParm_size*PARPORT_MAX
NumOfParPorts	RESB	1			; Number of supported ports


; --- Procedures ---

section .text

		; PAR_Init - initialize driver.
		; Input: AL!=0 - maximum number of supported ports (1..8);
		;	 AL==0 - get number of ports and base addresses
		;		 from BIOS data area.
		;	 ESI=buffer for init status string.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PAR_Init
		mpush	ebx,ecx,esi,edi
		or	al,al
		jz	.FromBIOS
		cmp	al,PARPORT_MAX
		ja	.Err
		mov	cl,al
		mov	edi,ParPortBases
		jmp	short .BeginInit

.FromBIOS:	mov	cx,[BIOSDA_Begin+tBIOSDA.Hardware]
		shr	ecx,14
		lea	edi,[BIOSDA_Begin+tBIOSDA.LPT1addr]

.BeginInit:	or	cl,cl
		jz	short .FillString
		mov	[NumOfParPorts],cl
		mov	ebx,PPdevTable
		xor	ecx,ecx
		mov	edx,ParPortIRQs

.FillTblLoop:	mov	ax,[edi]
		mov	[ebx+tPPdevParm.BasePort],ax
		add	ax,400h
		mov	[ebx+tPPdevParm.BasePortHi],ax
		mov	al,[edx]
		mov	[ebx+tPPdevParm.IRQ],al
		xor	eax,eax
		mov	[ebx+tPPdevParm.State],al
		mov	[ebx+tPPdevParm.OpenCount],al
		inc	cl
		cmp	cl,[NumOfParPorts]
		je	short .FillString
		add	ebx,tPPdevParm_size
		inc	edi
		inc	edi
		inc	edx
		jmp	.FillTblLoop

.FillString:	xor	edx,edx
		call	PAR_GetInitStatStr

.Exit:		mpop	edi,esi,ecx,ebx
		ret
.Err:		mov	ax,ERR_PAR_BadNumOfPorts
		stc
		jmp	short .Exit
endp		;---------------------------------------------------------------


		; PAR_Open - "open" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc PAR_Open
		mpush	ebx,edx
		call	PAR_Minor2PortNum
		jc	short .Exit
		cmp	byte [ebx+tPPdevParm.OpenCount],255
		je	short .Err
		inc	byte [ebx+tPPdevParm.OpenCount]
		clc
.Exit:		mpop	edx,ebx
		ret
.Err:		mov	ax,ERR_DRV_OpenOverflow
		stc
		jmp	short .Exit
endp		;---------------------------------------------------------------


		; PAR_Close -  "close" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc PAR_Close
		ret
endp		;---------------------------------------------------------------


		; PAR_Read - read one byte from port (ECP/EPP only).
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, AL=byte;
		;	  CF=1 - error, AX=error code.
proc PAR_Read
		ret
endp		;---------------------------------------------------------------


		; PAR_Write - write one byte to port.
		; Input: EDX (high word) = full minor number of device,
		;	 AL=byte to write.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc PAR_Write
		ret
endp		;---------------------------------------------------------------


		; PAR_HandleEvent - handle parallel port interrupts.
		; Input: EAX=event code.
		; Output: none.
proc PAR_HandleEvent
		ret
endp		;---------------------------------------------------------------


		; PAR_GetInitStatStr - get initialization status string.
		; Input: ESI=buffer for string.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc PAR_GetInitStatStr
		mpush	ebx,esi,edi
		mov	edi,esi
		mov	esi,DrvParport			; Copy "%parallel"
		call	StrCopy
		call	StrEnd

		test	edx,0FFFF0000h			; Minor present?
		jnz	short .Minor
		mov	esi,offset PP_InitStatStr
		call	StrCopy
		mov	al,[NumOfParPorts]
		add	al,30h
		mov	[edi+3],al
		jmp	short .OK

.Minor:		call	PAR_Minor2PortNum		; Get port number
		jc	short .Exit			; and DPS address
		add	dl,'1'
		mov	[edi],dl
		inc	edi
		mov	esi,PP_BaseStr
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	ax,[ebx+tPPdevParm.BasePort]
		call	K_HexW2Str
		mov	edi,esi
		mov	byte [edi],'h'
		inc	edi
		mov	esi,PP_IRQstr
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		xor	eax,eax
		mov	al,[ebx+tPPdevParm.IRQ]
		call	K_DecD2Str

.OK:		clc
.Exit:		mpop	edi,esi,ebx
		ret
endp		;---------------------------------------------------------------


		; PAR_GetParameters - get device parameters.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc PAR_GetParameters
		ret
endp		;---------------------------------------------------------------


; === Implementation routines ===

		; PAR_Minor2PortNum - convert minor number to port number
		;		      and get address of parameters structure.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK:
		;		    DL=port number (0..),
		;		    EBX=structure address;
		;	  CF=1 - error, AX=error code.
proc PAR_Minor2PortNum
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl
		jz	short .Err1
		dec	bl
		cmp	bl,[NumOfParPorts]
		jae	short .Err2
		mov	dl,bl
		shl	ebx,PPDstrucShift
		add	ebx,PPdevTable
		clc
		ret

.Err1:		mov	ax,ERR_DRV_NoMinor
		stc
		ret
.Err2:		mov	ax,ERR_DRV_BadMinor
		stc
		ret
endp		;---------------------------------------------------------------


; --- Mode detection ---

		; PAR_EPPclearTimeout - clear TIMEOUT bit in EPP mode.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK;
		;	  CF=1 - cannot clear.
proc PAR_EPPclearTimeout
		ParPort_ReadStatus ebx
		test	al,1
		jnz	short .More
.OK:		clc
		ret
		
		; To clear timeout some chips require double read
.More:		in	al,dx
		in	al,dx
		mov	ah,al
		or	al,1			; Some reset by writing 1
		out	dx,al
		mov	ah,al
		and	al,0FEh 		; Others by writing 0
		out	dx,al
		in	al,dx
		test	al,1
		jz	short .OK
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckSPP - Checks for port existence.
		;		 All ports support SPP mode.
		; Input: EBX=address of port parameters structure,
		;	 CL=0 - user didn't specify port presence manually;
		;	 CL=1 - user specified port presencs manually.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - port not detected.
proc PAR_CheckSPP
		; First clear an eventually pending EPP timeout.
		call	PAR_EPPclearTimeout

		; Do a simple read-write test to make sure the port exists.
		mov	ah,0Ch
		ParPort_WriteControl ebx,ah

		; Can we read from the control register?  Some ports don't
		; allow reads, so ReadControl just returns a software
		; copy. Some ports _do_ allow reads, so bypass the software
		; copy here.  In addition, some bits aren't writable.
		in	al,dx
		and	al,0Fh
		cmp	al,ah
		jne	short .TryDR
		mov	al,0Eh
		out	dx,al
		in	al,dx
		mov	ah,al
		mov	al,0Ch
		out	dx,al
		and	ah,0Fh
		cmp	ah,0Eh
		je	short .RetSPP

		; That didn't work, but the user thinks there's a port here..

		; Try the data register.  The data lines aren't tri-stated at
		; this stage, so we expect back what we wrote.
.TryDR:		mov	ah,0AAh
		ParPort_WriteData ebx,ah
		in	al,dx
		cmp	al,ah
		jne	short .TrustUser
		mov	al,55h
		out	dx,al
		in	al,dx
		cmp	al,55h
		je	short .RetSPP

		; Didn't work with 0xaa, but the user is convinced
		; this is the place.

		; It's possible that we can't read the control register or
		; the data register.  In that case just believe the user.
.TrustUser:	or	cl,cl
		jz	short .NotDetected
.RetSPP:	mov	al,PARPORT_MODE_PCSPP
		clc
		ret

.NotDetected:	xor	al,al
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckECR - check for ECR presence.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - not detected.
		; Comment:
		; Old style XT ports alias io ports every 0x400, hence
		; accessing ECR  on these cards actually accesses the CTR.
		;
	 	; Modern cards don't do this but reading from ECR will
		; return 0xff regardless of what is written here if the card
		; does NOT support  ECP.
		;
		; We will write 0x2c to ECR and 0xcc to CTR since both of
		; these values are "safe" on the CTR since bits 6-7 of CTR
		; are unused.
proc PAR_CheckECR
		ParPort_WriteControl ebx,0Ch
		in	al,dx
		mov	ah,al
		ParPort_ReadEControl ebx
		xor	al,ah
		and	al,3
		jnz	short .1
		xor	ah,2
		ParPort_WriteControl ebx,ah
		in	al,dx
		mov	ah,al
		ParPort_ReadEControl ebx
		xor	al,ah
		and	al,2
		jnz	short .NoReg
		
.1:		ParPort_ReadEControl ebx
		and	al,3
		cmp	al,1
		jne	short .NoReg

		mov	al,34h
		out	dx,al
		in	al,dx
		cmp	al,35h
		jne	short .NoReg
		ParPort_WriteControl ebx,0Ch

		; Go to mode 000; SPP, reset FIFO
		ParPort_WriteMaskControl ebx,0E0h,0
		clc
		mov	al,PARPORT_MODE_PCECR
		ret

.NoReg:		ParPort_WriteControl ebx,0Ch
		xor	al,al
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckECPsupport - check for ECP support.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - ECP not supported.
proc PAR_CheckECPsupport
		test	byte [ebx+tPPdevParm.Modes],PARPORT_MODE_PCECR
		jnz	short .TestFIFO
.NotDetected:	xor	al,al
		stc
		ret
		
.TestFIFO:	ParPort_ReadEControl ebx
		mov	ah,al
		
		; Using LGS chipset it uses ECR register, but
		; it doesn't support ECP or FIFO MODE
		mov	al,0C0h
		out	dx,al				; Test FIFO
		mov	ecx,1024
.Loop:		ParPort_ReadEControl ebx
		test	al,1
		jnz	short .1
		ParPort_WriteFIFO ebx,0AAh
		loop	.Loop

.1:		ParPort_WriteEControl ebx,ah
		or	ecx,ecx				; FIFO test passed?
		jz	short .NotDetected
		mov	al,PARPORT_MODE_PCECP
		clc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckEPPsupport - ckeck for EPP support.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - EPP not supported.
		; Comment:
		; Bit 0 of STR is the EPP timeout bit, this bit is 0
		; when EPP is possible and is set high when an EPP timeout
		; occurs (EPP uses the HALT line to stop the CPU while it does
		; the byte transfer, an EPP timeout occurs if the attached
		; device fails to respond after 10 micro seconds).
		;
		; This bit is cleared by either reading it (NSC)
		; or writing a 1 to the bit (SMC, UMC, WinBond), others ???
		; This bit is always high in non EPP modes.
proc PAR_CheckEPPsupport
		; If EPP timeout bit clear then EPP available
		call	PAR_EPPclearTimeout
		jc	short .NoEPP

		ParPort_ReadControl ebx
		or	al,20h
		out	dx,al
		in	al,dx
		or	al,10h
		out	dx,al
		call	PAR_EPPclearTimeout

		ParPort_ReadEPP ebx
		mov	ecx,30				; Wait for possible
		call	K_MicroDelay			; EPP timeout

		ParPort_ReadStatus ebx
		test	al,1
		jz	short .NoEPP
		call	PAR_EPPclearTimeout
		mov	al,PARPORT_MODE_PCEPP
		ret

.NoEPP:		xor	al,al
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckECPEPPsupport - check for ECPEPP support.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - mode not supported.
proc PAR_CheckECPEPPsupport
		test	byte [ebx+tPPdevParm.Modes],PARPORT_MODE_PCECR
		jz	short .NotSupported

		ParPort_ReadEControl ebx
		mov	ah,al
		
		; Search for SMC style EPP+ECP mode
		mov	al,80h
		out	dx,al

		push	edx
		call	PAR_CheckEPPsupport
		pop	edx
		xchg	al,ah
		out	dx,al

		or	ah,ah
		jz	short .NotSupported
		mov	al,PARPORT_MODE_PCECPEPP
		clc
		ret

.NotSupported:	xor	al,al
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckPS2support - check PS/2 support.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - mode not supported.
		; Comment:
		; Bit 5 (0x20) sets the PS/2 data direction; setting this high
		; allows us to read data from the data lines.  In theory we
		; would get back 0FFh but any peripheral attached to the port
		; may drag some or all of the lines down to zero. So if we get
		; back anything that isn't the contents
		; of the data register we deem PS/2 support to be present.
		;
		; Some SPP ports have "half PS/2" ability - you can't turn off
 		; the line drivers, but an external peripheral with
 		; sufficiently beefy drivers of its own can overpower them and
 		; assert its own levels onto the bus, from where they can then
 		; be read back as normal.  Ports with this property and the
		; right type of device attached are likely to fail the SPP
 		; test, (as they will appear to have stuck bits) and so the
 		; fact that they might  be misdetected here is rather academic.
proc PAR_CheckPS2support
		ParPort_ReadControl ebx
		mov	ch,al

		call	PAR_EPPclearTimeout
		mov	al,ch
		or	al,20h			; Try to tri-state the buffer
		out	dx,al

		xor	cl,cl
		ParPort_WriteData ebx,55h
		in	al,dx
		cmp	al,55h
		je	short .1
		inc	cl

.1:		mov	al,0AAh
		out	dx,al
		in	al,dx
		cmp	al,0AAh
		je	short .2
		inc	cl

.2		ParPort_WriteControl ebx,ch		; Cancel input mode
		or	cl,cl
		jz	short .NotDetected
		mov	al,PARPORT_MODE_PCPS2
		clc
		ret

.NotDetected:	xor	al,al
		stc
		ret
endp		;---------------------------------------------------------------


		; PAR_CheckECPPS2support - check for PS/2 ECP support.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AL=port mode;
		;	  CF=1 - mode not supported.
proc PAR_CheckECPPS2support
		test	byte [ebx+tPPdevParm.Modes],PARPORT_MODE_PCECR
		jz	short .NotSupported

		ParPort_ReadEControl ebx
		mov	ah,al
		mov	al,20h
		out	dx,al

		push	edx
		call	PAR_CheckPS2support
		pop	edx
		xchg	ah,al
		out	dx,al

		or	ah,ah
		jz	short .NotSupported
		mov	al,PARPORT_MODE_PCECPPS2
		clc
		ret

.NotSupported:	xor	al,al
		stc
		ret
endp		;---------------------------------------------------------------


; --- IRQ detection ---

		; PAR_CheckProgIRQsupport - check for programmable IRQ support.
		; Input: EBX=address of port parameters structure.
		; Output: CF=0 - OK, AH=IRQ;
		;	  CF=1 - no supported.
		; Note: only if supports ECP mode.
proc PAR_CheckProgIRQsupport
		ParPort_ReadEControl ebx
		mov	ah,al
		mov	al,0E0h				; Configuration Mode
		out	dx,al

		ParPort_ReadConfigB ebx
		shr	al,3
		and	al,7
		push	ebx
		mov	ebx,PP_IRQlookup
		xlatb
		pop	ebx
		xchg	al,ah
		ParPort_WriteEControl ebx
		or	ah,ah
		jz	short .No
		ret

.No:		stc
		ret
endp		;---------------------------------------------------------------

