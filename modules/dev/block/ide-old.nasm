;*******************************************************************************
; ide.nasm - E-IDE resource manager.
; Based on Minix 2.0.0 code.
;*******************************************************************************

module $eide

%include "rmk.ah"
%include "errors.ah"
%include "module.ah"
%include "thread.ah"
%include "hw/ports.ah"

%include "ide.ah"
%include "hd.ah"

externproc HD_Open, HD_Close
externproc HD_Read, HD_Write
externproc HD_GetPartParams, HD_GetPartInfoStr
externproc HD_LBA2CHS

library $libc
importproc _ThreadCtl, _ThreadCreate

; Interrupt request lines
%define	IRQ_IDE1	14		; Default IRQ for interface 1
%define	IRQ_IDE2	15		; Default IRQ for interface 2
%define	IRQ_IDE3	11		; Default IRQ for interface 3
%define	IRQ_IDE4	12		; Default IRQ for interface 4

; Miscellaneous
%define	IDE_MAXDRIVES	8		; Maximum number of supported drives
%define	IDE_MAXCHANNELS	IDE_MAXDRIVES/2	; Max. 2 drives/channel

; Time intervals (in milliseconds)
%define	IDE_MAXTIMEOUT		32000	; Controller maximum timeout
%define	IDE_RECOVERYTIME	500	; Controller recovery time
%define	IDE_IRQWAITTIME		10000	; Maximum wait for an IRQ to happen

; Status flags
%define	IDE_INITIALIZED		1	; Drive is initialized
%define	IDE_DEAF		2	; Controller must be reset
%define	IDE_INTELLIGENT		4	; Intelligent ATA IDE drive
%define	IDE_BLOCKMODEON		8	; Block mode turned on

; Structure of IDE device parameters
struc tIDEdev
.BasePort	RESW	1	; Interface base port
.IRQ		RESB	1	; IRQ line number
.State		RESB	1	; State flags
.LCyls		RESW	1	; Logical (BIOS-compatible) parameters
.LHeads		RESW	1
.LSectors	RESW	1
.PCyls		RESW	1	; Physical parameters
.PHeads		RESW	1
.PSectors	RESW	1
.TotalSectors	RESD	1	; Total addressable sectors (LBA)
.LDHpref	RESB	1	; Top four bits of the LDH (head) register
.Precomp	RESW	1	; Write precompensation cylinder / 4
.MaxCount	RESB	1	; Max request for this drive
.OpenCount	RESB	1	; In-use count
.DriveNum	RESB	1	; Drive number
.SecPerInt	RESB	1	; Sectors per interrupt (R/W multiple)
.CommonDesc	RESD	1	; Common HD descriptor (for DIHD routines)
.ModelStr	RESB	40
.Reserved	RESB	41	; Pad to 128 bytes
endstruc


section .data

ModuleInfo: instance tModInfoTag
    field(Signature,	DD	RBM_SIGNATURE)
    field(ModVersion,	DD	1)
    field(ModType,	DB	MODTYPE_EXECUTABLE)
    field(Flags,	DB	MODFLAGS_RESMGR)
    field(OStype,	DW	1)
    field(OSversion,	DD	0)
    field(Base,		DD	0)
    field(Entry,	DD	IDE_Main)
iend

TxtRegistering	DB	"Registering "
HdDevPath	DB	"%hd",0


section .bss

?DevTable	RESB	tIDEdev_size*IDE_MAXDRIVES		; IDE devices table

?BasePorts	RESW	IDE_MAXCHANNELS	; Controller base ports

?IRQlines	RESB	IDE_MAXCHANNELS	; IRQ lines

?CurrCommand	RESB	IDE_MAXCHANNELS	; Current command in execution

?CurrStatus	RESB	IDE_MAXCHANNELS	; Status after interrupt

?NumInstDevs	RESB	1		; Number of found hard disk drives
?NumChannels	RESB	1		; Number of found IDE channels


section .text

		; IDE_Main - resource manager initialization.
proc IDE_Main
		; Get I/O privileges
		Ccall	_ThreadCtl, TCTL_IO, 0
		test	eax,eax
		js	near .ErrIOpriv

		; Create the interrupt handling thread
		Ccall	_ThreadCreate, 0, IDE_InterruptThread, 0, 0
		test	eax,eax
		js	near .ErrIntThr

		; Initialize port addresses and IRQs
		mov	dword [?BasePorts],PORT_HDC_IDE1 + (PORT_HDC_IDE2 << 16)
		mov	dword [?BasePorts+4],PORT_HDC_IDE3 + (PORT_HDC_IDE4 << 16)
		mov	dword [?IRQlines],IRQ_IDE1 + (IRQ_IDE2 << 8) + (IRQ_IDE3 << 16) + (IRQ_IDE4 << 24)

		push	ebx
		mov	dh,dl
		xor	dl,dl
		xor	bh,bh

.Loop:		call	IDE_Probe
		jc	.1
		inc	dl
.1:		inc	bh
		inc	bh			; Kluge
		cmp	bh,dh
		jc	.Loop

.2:		mov	[?NumInstDevs],dl	; Store number of drives found

		; Count number of IDE channels
		xor	dh,dh
		xor	ecx,ecx
.CountChannels:	cmp	byte [ecx+?CurrStatus],0
		je	.NextChan
		inc	dh
.NextChan:	inc	cl
		cmp	cl,IDE_MAXCHANNELS
		jne	.CountChannels
		mov	[?NumChannels],dh
		clc

		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_HandleEvent - handle all hardware interrupts.
		; Input: none.
		; Output: none.
proc IDE_HandleEvent
		mpush	ebx,ecx,edx
		shr	eax,16				; AL=IRQ#
		
		xor	ecx,ecx
.FindChannel:	cmp	al,[?IRQlines+ecx]
		je	.GotChannel
		inc	ecx
		cmp	ecx,IDE_MAXCHANNELS
		jne	.FindChannel
		jmp	.Exit			; No channel found
		
.GotChannel:	mov	dx,[?BasePorts+ecx*2]
		add	dx,REG_STATUS
		in	al,dx
		mov	[?CurrStatus+ecx],al
.Exit:		mpop	edx,ecx,ebx
		clc
		ret
endp		;---------------------------------------------------------------


		; IDE_Open - "open" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IDE_Open
		test	edx,0FF000000h			; Subminor given?
		jz	.Do			; No, all right
		mov	ax,ERR_DRV_BadMinor		; Else error
		stc					; (bad minor number)
		ret
.Do:		mpush	ebx,edx,edi
		call	IDE_Minor2HDN			; Get disk number
		jc	.Exit			; and structure address
		cmp	byte [edi+tIDEdev.OpenCount],0	; Already opened?
		jne	.Err
		mov	dx,DRVID_HDIDE			; Major number of driver
		push	edi
		mov	edi,IDE_Operation
		call	HD_Open				; Partition disk
		pop	edi
		jc	.Exit
		mov	[edi+tIDEdev.CommonDesc],eax	; Store disk descriptor
		inc	byte [edi+tIDEdev.OpenCount]
		xor	eax,eax
		jmp	.Exit

.Err:		mov	ax,ERR_DRV_AlreadyOpened
		stc
.Exit:		mpop	edi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_Close - "close" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IDE_Close
		test	edx,0FF000000h			; Subminor given?
		jz	.Do			; No, all right
		mov	ax,ERR_DRV_BadMinor		; Else error
		stc					; (bad minor number)
		ret
.Do:		mpush	ebx,edx,edi
		call	IDE_Minor2HDN			; Get disk number
		jc	.Exit			; and structure address
		mov	eax,[edi+tIDEdev.CommonDesc]	; Major number of driver
		call	HD_Close			; "Close" disk
		jc	.Exit
		xor	eax,eax
		cmp	byte [edi+tIDEdev.OpenCount],0
		je	.Exit
		dec	byte [edi+tIDEdev.OpenCount]
		xor	al,al
.Exit:		mpop	edi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_Read - read sectors.
		; Input: EDX (high word) - full minor number of device,
		;	 EBX=relative sector number (if subminor!=0)
		;	     or absolute sector number (if subminor==0),
		;	 CX=number of sectors to read,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
		; Note: number of sectors to read absolute is limited to 255.
proc IDE_Read
		test	edx,0FF000000h			; Check subminor
		jz	.Absolute
		push	edi
		push	ebx
		call	IDE_Minor2HDN
		pop	ebx
		jc	.ExitRel
		cmp	byte [edi+tIDEdev.OpenCount],0	; Device opened?
		je	.Err
		mov	eax,[edi+tIDEdev.CommonDesc]
		mov	edi,IDE_Operation
		call	HD_Read
		jmp	.ExitRel
.Err:		mov	ax,ERR_DRV_NotOpened
		stc
.ExitRel:	pop	edi
		ret

.Absolute:	push	ecx
		mov	al,cl			; Keep count
		mov	ecx,ebx			; ECX=absolute sector
		call	IDE_Minor2HDN		; BH=drive
		jc	.Exit
		mov	bl,al			; BL=count
		mov	ah,HD_opREADSEC		; Operation code
		call	IDE_Operation
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; IDE_Write - write sectors.
		; Input: EDX (high word) - full minor number of device,
		;	 EBX=relative sector number (if subminor!=0)
		;	     or absolute sector number (if subminor==0),
		;	 CX=number of sectors to write,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IDE_Write
		test	edx,0FF000000h			; Check subminor
		jz	.Absolute
		push	edi
		push	ebx
		call	IDE_Minor2HDN
		pop	ebx
		jc	.ExitRel
		cmp	byte [edi+tIDEdev.OpenCount],0	; Device opened?
		je	.Err
		mov	eax,[edi+tIDEdev.CommonDesc]
		mov	edi,IDE_Operation
		call	HD_Read
		jmp	.ExitRel
.Err:		mov	ax,ERR_DRV_NotOpened
		stc
.ExitRel:	pop	edi
		ret

.Absolute:	push	ecx
		mov	al,cl			; Keep count
		mov	ecx,ebx			; ECX=absolute sector
		call	IDE_Minor2HDN		; BH=drive
		jc	.Exit
		mov	bl,al			; BL=count
		mov	ah,HD_opWRITESEC	; Operation code
		call	IDE_Operation
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; IDE_GetParameters - get device parameters.
		; Input: EDX (high word) = device minor number.
		; Output: CF=0 - OK: if subminor number==0 - returns
		;		     drive geometry:
		;		      CX=cylinders (logical),
		;		      DL=sectors per track,
		;		      DH=heads (logical);
		;		     else returns partition information:
		;		      AL=system code,
		;		      ECX=size in sectors.
		;	  CF=1 - error.
proc IDE_GetParameters
		mpush	ebx,edi
		call	IDE_Minor2HDN
		jc	.Exit
		or	bl,bl				; Subminor given?
		jz	.NoSubMinor
		mov	eax,[edi+tIDEdev.CommonDesc]
		call	HD_GetPartParams
                jc	.Exit

.NoSubMinor:	mov	cx,[edi+tIDEdev.LCyls]
		mov	dl,[byte edi+tIDEdev.LSectors]
		mov	dh,[byte edi+tIDEdev.LHeads]
		clc
.Exit:		mpop	edi,ebx
		ret
endp		;---------------------------------------------------------------



; --- Internal procedures ---

		; IDE_Probe - check for drive presence and read its parameters.
		; Input: BH=drive number (0..IDE_MAXDRIVES).
		; Output: CF=0 - OK, drive present;
		;	  CF=1 - drive not found.
proc IDE_Probe
		locauto	secbuf, 512
		prologue
		savereg ebx,ecx,edx,esi,edi

		cmp	bh,IDE_MAXDRIVES
		cmc
		jc	.Exit

		; Get base port (DX) and IRQ (CL)
		xor	eax,eax
		mov	al,bh
		shr	al,1				; AL=channel number
		mov	cl,[?IRQlines+eax]
		mov	dx,[?BasePorts+eax*2]

		; Check if the one of the registers exists
		add	dx,REG_CYL_LO
		in	al,dx
		mov	ah,al
		not	al
		out	dx,al
		in	al,dx
		sub	dx,REG_CYL_LO
		cmp	al,ah
		je	near .NotExist

		; Fill in the device parameters structure
		call	IDE_GetDPSaddr			; Get structure address
		mov	[edi+tIDEdev.DriveNum],bh
		mov	[edi+tIDEdev.BasePort],dx
		mov	[edi+tIDEdev.IRQ],cl
		xor	eax,eax
		mov	[edi+tIDEdev.State],al
		mov	[edi+tIDEdev.Precomp],ax	; Precomp. cyl. =0
		shl	bh,4
		or	bh,LDH_DEFAULT
		mov	[edi+tIDEdev.LDHpref],bh

		; Try an ATA identify command
		mov	ah,ATA_IDENTIFY			; Command
		xor	ecx,ecx				; No parameters
		call	IDE_OutCmdSimple		; Intelligent drive?
		jc	near .NotExist			; No, exit

		; Intelligent drive: read identify drive information
		or	byte [edi+tIDEdev.State],IDE_INTELLIGENT
		mov	ebx,edi				; Keep structure address
		lea	edi,[%$secbuf]			; Buffer address
		mov	cx,256				; 256 words
		cld
		rep	insw				; DX at data reg now

		; Fill another fields of parameters structure
		lea	esi,[%$secbuf]
		mov	edi,ebx
		mov	ax,[esi+tIDE_IDinfo.NumHardCyls]
		mov	[edi+tIDEdev.PCyls],ax
		mov	[edi+tIDEdev.LCyls],ax
		mov	ax,[esi+tIDE_IDinfo.NumHeads]
		mov	[edi+tIDEdev.PHeads],ax
		mov	[edi+tIDEdev.LHeads],ax
		mov	ax,[esi+tIDE_IDinfo.Sectors]
		mov	[edi+tIDEdev.PSectors],ax
		mov	[edi+tIDEdev.LSectors],ax
		mov	al,[byte esi+tIDE_IDinfo.RWMultiSecs]
		or	al,al				; Block mode enabled?
		jnz	.SecPerInt
		inc	al
.SecPerInt:	mov	[edi+tIDEdev.SecPerInt],al

		mov	ax,[esi+tIDE_IDinfo.Capabilities]
		test	ah,2					; LBA?
		jz	.Model
		or	byte [edi+tIDEdev.LDHpref],LDH_LBA
		mov	eax,[esi+tIDE_IDinfo.LBAtotalSecs]	; Total sectors
		mov	[edi+tIDEdev.TotalSectors],eax

.Model:		add	esi,tIDE_IDinfo.ModelStr
		add	edi,tIDEdev.ModelStr
		mov	cl,40
		cld
.ModelLoop:	lodsw					; Copy model string
		dec	cl
		dec	cl
		jz	.Term
		cmp	ax,2020h
		je	.Term
		xchg	al,ah				; Convert
		stosw					; to little-endian
		jmp	.ModelLoop

.Term:		xor	al,al				; NULL-terminator
		mov	[edi],al

		; Initialize logical parameters (for BIOS compatibility)
		mov	edi,ebx				; Restore pointer
		mov	ax,[edi+tIDEdev.LCyls]
		mov	bx,[edi+tIDEdev.LHeads]
.LogLoop:	cmp	ax,1024				; <=1024 cylinders?
		jbe	.StoreLogPar		; Yes, store new values
		shr	ax,1				; Else cylinders/=2
		shl	bx,1				; and heads*=2
		jmp	.LogLoop
.StoreLogPar:	mov	[edi+tIDEdev.LCyls],ax
		mov	[edi+tIDEdev.LHeads],bx

		; Initialize drive parameters
		call	IDE_Specify
		jnc	.SetBlkMode
		call	IDE_Specify
		jc	.NotExist

		; Initialize block mode
.SetBlkMode:	mov	dl,[edi+tIDEdev.SecPerInt]
		cmp	dl,1
		je	.OK
		call	IDE_SetBlockMode
		jmp	.Exit

.OK:		clc
		jmp	.Exit
.NotExist:	stc
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; IDE_Specify - specify some drive parameters.
		; Input: EDI=device parameters structure address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc IDE_Specify
		mpush	eax,ebx,ecx,edi

		test	byte [edi+tIDEdev.State],IDE_DEAF	; Need reset?
		jz	.NoRes
		call	IDE_Reset
		jc	.Exit

.NoRes:		mov	bl,[byte edi+tIDEdev.Precomp]
		mov	bh,[edi+tIDEdev.LDHpref]
		mov	al,[byte edi+tIDEdev.PHeads]
		dec	al					; BH |=PHeads
		or	bh,al
		xor	ecx,ecx
		mov	cl,[byte edi+tIDEdev.PSectors]
		mov	ah,CMD_SPECIFY
		call	IDE_OutCmdSimple
		jc	.Exit
		or	byte [edi+tIDEdev.State],IDE_INITIALIZED

.Exit:		mpop	edi,ecx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; IDE_OutCommand - output command to controller.
		; Input: AH=command,
		;	 BH=LBA, drive and head (LDH),
		;	 BL=precompensation cylinder,
		;	 ECX=cylinder,sector and number of sectors,
		;	 EDI=device parameters structure address.
		; Output: CF=0 - OK, AX=0;
		;	  CF=1 - error, AX=error code.
proc IDE_OutCommand
		mpush	edx,esi
		xor	edx,edx
                mov	dx,[edi+tIDEdev.BasePort]
		mov	si,ax				; Keep command
		shl	esi,16
		mov	si,dx				; Keep baseport

		; Wait until controller will be ready
		mov	ax,STATUS_BSY
		call	IDE_WaitFor
		jc	near .Exit

		; Select drive
		mov	edx,esi
		add	dx,REG_LDH
		mov	al,bh
		out	dx,al

		; Check drive ready
		mov	edx,esi
		mov	ax,256*STATUS_RDY+STATUS_BSY+STATUS_RDY
		call	IDE_WaitFor
		jc	.Exit

		; Mask interrupt
		mov	al,[edi+tIDEdev.IRQ]
		call	PIC_DisIRQ

		; Out CTL byte
		cmp	byte [edi+tIDEdev.PHeads],8
		jae	.G8heads
		xor	al,al
		jmp	.OutCTL
.G8heads:	mov	al,CTL_EIGHTHEADS
.OutCTL:	add	dx,REG_CTL
		out	dx,al

		; Out parameters
		mov	edx,esi
		inc	dl			; DX=REG_PRECOMP
		or	bl,bl			; Precomp. cyl. given?
		jz	.NoPrecomp
		mov	al,bl
		out	dx,al
.NoPrecomp:	inc	dl
		mov	al,cl			; Sectors count
		out	dx,al
		inc	dl
		mov	al,ch			; Begin sector number
		out	dx,al
		inc	dl
		ror	ecx,16
		mov	al,cl			; Low byte of cyl
		out	dx,al
		inc	dl
		mov	al,ch			; High byte of cyl
		out	dx,al
		ror	ecx,16

		; Count controller number (EBX)
		push	ebx
		xor	ebx,ebx
		mov	bl,[edi+tIDEdev.DriveNum]
		shr	bl,1

		; Out command code
		mov	edx,esi
		add	dx,REG_COMMAND
		mov	eax,esi
		shr	eax,24
		cli
		out	dx,al
		mov	[ebx+?CurrCommand],al
		mov	byte [ebx+?CurrStatus],STATUS_BSY
		sti
		pop	ebx

		; Unmask interrupt
		mov	al,[edi+tIDEdev.IRQ]
		call	PIC_EnbIRQ

		xor	ax,ax

.Exit:		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------


		; IDE_OutCmdSimple - out simple controller command: only one
		;		     interrupt and no data-out phase.
		; Input: same as IDE_OutCommand.
		; Output: same as IDE_OutCommand.
proc IDE_OutCmdSimple
		call	IDE_OutCommand
		jc	.CmdErr
		call	IDE_WaitIntr
.CmdErr:	pushfd					; Keep flags
		push	eax				; Keep error code
		xor	eax,eax
		mov	al,[edi+tIDEdev.DriveNum]	; Get controller number
		shr	al,1				; in EAX
		mov	byte [eax+?CurrCommand],CMD_IDLE
		pop	eax
		popfd
		ret
endp		;---------------------------------------------------------------


		; IDE_WaitFor - wait until controller is in the required state.
		; Input: AL=status mask,
		;	 AH=required status,
		;	 DX=controller address.
		; Output: CF=0 - OK;
		;	  CF=1 - timeout.
		; Note: calls IDE_NeedReset if timeout.
proc IDE_WaitFor
		mpush	eax,ebx,ecx,edx
		add	dx,REG_STATUS
		mov	bl,al
		mov	ecx,IDE_MAXTIMEOUT
.Loop:		in	al,dx
		and	al,bl
		cmp	al,ah
		je	.OK
		call	MT_SuspendCurr1ms		; Suspend on 1 ms
		dec	ecx
		jnz	.Loop
		call	IDE_NeedReset			; Controller gone deaf
		stc
		jmp	.Exit
.OK:		clc
.Exit:		mpop	edx,ecx,ebx,eax
		ret
endp		;---------------------------------------------------------------


		; IDE_NeedReset - set drive flags so the controller needs
		;		  to be reset.
		; Input: EDI=device parameters structure address.
		; Output: none.
proc IDE_NeedReset
		mpush	eax,edi
		call	.SetFlags
		xor	eax,eax
		mov	al,tIDEdev_size
		test	byte [edi+tIDEdev.DriveNum],1
		jnz	.Slave
		add	edi,eax
		jmp	.1
.Slave:		sub	edi,eax
.1:		call	.SetFlags
		mpop	edi,eax
		ret
.SetFlags:	mov	al,[edi+tIDEdev.State]
		or	al,IDE_DEAF
		and	al,~IDE_INITIALIZED
		mov	[edi+tIDEdev.State],al
		ret
endp		;---------------------------------------------------------------


		; IDE_Reset - reset controller.
		; Input: EDI=device parameters structure address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IDE_Reset
		mpush	ecx,edx,edi

		; Wait for any internal drive recovery
		mov	ecx,IDE_RECOVERYTIME
		call	MT_SuspendCurr

		; Strobe reset bit
		mov	dx,[edi+tIDEdev.BasePort]
		mov	al,CTL_RESET
		out	dx,al
		call	MT_SuspendCurr1ms
		xor	al,al
		out	dx,al

		; Wait for controller ready
		mov	ax,256*STATUS_RDY+STATUS_BSY+STATUS_RDY
		call	IDE_WaitFor
		jc	.Err1

		; Clear DEAF flags for all drives on this controller
		mov	dl,~IDE_DEAF
		and	[edi+tIDEdev.State],dl			; This drive
		xor	eax,eax
		mov	al,tIDEdev_size
		test	byte [edi+tIDEdev.DriveNum],1		; Slave?
		jnz	.Slave
		add	edi,eax
		jmp	.1
.Slave:		sub	edi,eax
.1:		and	[edi+tIDEdev.State],dl			; Another drive
		xor	ax,ax
		jmp	.Exit

.Err1:		mov	ax,ERR_IDE_ResFailed
.Error:		stc
.Exit:		mpop	edi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; IDE_Recalibrate - recalibrate drive.
		; Input: BH=drive number.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc IDE_Recalibrate
		mpush	ebx,ecx,edx,edi
		call	IDE_GetDPSaddr
		jc	.Exit
		shr	bh,4
		or	bh,[edi+tIDEdev.LDHpref]
		xor	bl,bl
		xor	ecx,ecx
		mov	ah,CMD_RECALIBRATE
		call	IDE_OutCmdSimple
.Exit:		mpop	edi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_WaitIntr - wait for completion interrupt and return
		;		 result.
		; Input: EDI=device parameters structure address.
		; Outut: CF=0 - OK;
		;	 CF=1 - error, AX=error code.
proc IDE_WaitIntr
		mpush	ebx,edx
		xor	ebx,ebx
		mov	bl,[edi+tIDEdev.DriveNum]
		shr	bl,1
.Loop:		push	ebx
		pushfd
		cli
		mov	edx,[?CurrThread]
		or	edx,edx
		jz	.SkipThrSleep
		call	MT_ThreadSleep			; Sleep current thread
		popfd
		pop	ebx
		call	MT_Schedule
		jmp	.ChkStatus
.SkipThrSleep:	popfd
		pop	ebx		
.ChkStatus:	mov	al,[ebx+?CurrStatus]
		test	al,STATUS_BSY
		jnz	.Loop

		cli
		mov	ah,al
		and	al,STATUS_BSY+STATUS_RDY+STATUS_WF+STATUS_ERR
		cmp	al,STATUS_RDY
		je	.OK
		test	ah,STATUS_ERR
		jz	.GeneralErr
		mov	dx,[edi+tIDEdev.BasePort]
		add	dx,REG_ERROR
		in	al,dx
		and	al,ERROR_BB
		jz	.GeneralErr
		mov	ax,ERR_IDE_BadSector		; BadSector  error
		jmp	.Err

.OK:		or	byte [ebx+?CurrStatus],STATUS_BSY
		xor	ax,ax
		jmp	.Exit
.GeneralErr:	mov	ax,ERR_IDE_General		; General error
.Err:		stc
.Exit:		sti
		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------


                ; IDE_Timeout - called if disk operation is timed out.
		; Input: EDI=device parameters structure address.
		; Output: none.
proc IDE_Timeout
		mpush	eax,ebx
		xor	ebx,ebx
		mov	bl,[edi+tIDEdev.DriveNum]
		shr	bl,1
		mov	al,[ebx+?CurrCommand]		; Last command
		cmp	al,CMD_IDLE
		je	.Exit
		cmp	al,CMD_READ
		jne	.Other
		cmp	al,CMD_WRITE
		jne	.Other

		jmp	.Exit
.Other:		call	IDE_NeedReset
		mov	byte [ebx+?CurrStatus],0
.Exit:		mpop	ebx,eax
		ret
endp		;---------------------------------------------------------------


		; IDE_SetBlockMode - enable/disable block mode.
		; Input: EDI=device parameters structure address;
		;	 DL=number of sectors in block.
                ; Output: CF=0 - OK, AX=0;
		;	  CF=1 - error, AX=error code.
		; Note: set DL=0 to disable block mode.
proc IDE_SetBlockMode
		mpush	ebx,ecx,edx
		xor	ecx,ecx
		mov	cl,dl
		or	cl,cl				; Enable block mode?
		jnz	.Enable
		and	byte [edi+tIDEdev.State],~IDE_BLOCKMODEON
		jmp	.NoCorr
.Enable:	mov	dl,[edi+tIDEdev.SecPerInt]
		cmp	dl,cl
		jae	.NoCorr
		mov	cl,dl

.NoCorr:	mov	bh,[edi+tIDEdev.DriveNum]
		shl	bh,4
		or	bh,[edi+tIDEdev.LDHpref]
		xor	bl,bl
		mov	ah,ATA_SETMULTMODE
		call	IDE_OutCmdSimple
		jc	.Exit
		or	cl,cl
		jz	.OK
		or	byte [edi+tIDEdev.State],IDE_BLOCKMODEON
.OK:		clc
.Exit:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_Operation - perform disk operation (read/write sectors).
		; Input: AH=common disk operation code,
		;	 BH=drive,
		;	 BL=number of sectors,
		;	 ECX=logical sector number,
		;	 ESI=physical buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IDE_Operation
		mpush	ebx,ecx,edx,esi,edi

		; Get drive parameters structure address
		call	IDE_GetDPSaddr
		jc	near .Err1

		; Check drive presence
		cmp	word [edi+tIDEdev.PCyls],0
		je	near .Err1

		; If not LBA - count cylinder, head and sector
		test	byte [edi+tIDEdev.LDHpref],LDH_LBA
		jnz	.LBA
		mov	eax,ebx				; Keep drive & count
		mov	ebx,ecx
		mov	dl,[byte edi+tIDEdev.LSectors]
		mov	dh,[byte edi+tIDEdev.LHeads]
		call	HD_LBA2CHS
		shl	ecx,16				; Form ECX
		mov	ch,bl				; for IDE_OutCommand
		mov	cl,al				; Number of sectors
		shl	ah,4				; LDH =head
		or	bh,ah				; LDH |=drive
		or	bh,LDH_DEFAULT
		jmp	.1

.LBA:		ror	ecx,16
		test	ch,0F0h				; LBA correct?
		jnz	near .Err2
		mov	dh,bh				; Keep drive number
		shl	bh,4
		or	bh,[edi+tIDEdev.LDHpref]
		or	bh,ch
		ror	ecx,8				; Prepare to call
		mov	cl,bl				; IDE_OutCommand

.1:		mov	bl,[byte edi+tIDEdev.Precomp]

		; More than 1 sector?
		cmp	cl,1
		je	.Single

		; Check device Multiple R/W capability
		mov	al,[edi+tIDEdev.SecPerInt]
		cmp	al,1
		je	.Err4
		test	byte [edi+tIDEdev.State],IDE_BLOCKMODEON
		jz	.Err5

		; Check number of sectors requested
		cmp	al,cl
		jb	.Err4

		; Read or write?
		cmp	ah,HD_opREADSEC
		je	.ReadMult
		cmp	ah,HD_opWRITESEC
		jne	.Err3

		; Write multiple
;		mov	ah,ATA_WRITEMULT
;		call	IDE_OutCommand
;		jc	.Exit
;		call	IDE_WaitIntr
;		jc	.Exit
;		mov	dx,[edi+tIDEdev.BasePort]
;		and	ecx,0FFh
;		shl	ecx,8
;		rep	outsw
		jmp	.OK

		; Read multiple
.ReadMult:	mov	ah,ATA_READMULT
		call	IDE_OutCommand
		jc	.Exit
		call	IDE_WaitIntr
		jc	.Exit
		mov	dx,[edi+tIDEdev.BasePort]
		and	ecx,0FFh
		shl	ecx,8
		mov	edi,esi
		rep	insw
		jmp	.OK


		; R/W single sector
.Single:	cmp	ah,HD_opREADSEC
		je	.ReadOne
		cmp	ah,HD_opWRITESEC
		jne	.Err3

		; Write one sector
;		mov	ah,CMD_WRITE
;		call	IDE_OutCommand
;		jc	.Exit
;		call	IDE_WaitIntr
;		jc	.Exit
;		mov	dx,[edi+tIDEdev.BasePort]
;		mov	ecx,256
;		rep	outsw
		jmp	.OK

		; Read one sector
.ReadOne:	mov	ah,CMD_READ
		call	IDE_OutCommand
		jc	.Exit
		call	IDE_WaitIntr
		jc	.Exit
		mov	dx,[edi+tIDEdev.BasePort]
		mov	edi,esi
		mov	ecx,256
		rep	insw
		jmp	.OK

.OK:		xor	ax,ax
		jmp	.Exit

.Err1:		mov	ax,ERR_IDE_BadDriveNum
		jmp	.Error
.Err2:		mov	ax,ERR_IDE_BadLBA
		jmp	.Error
.Err3:		mov	ax,ERR_HD_NoDiskOp
		jmp	.Error
.Err4:		mov	ax,ERR_IDE_TooManySectors
		jmp	.Error
.Err5:		mov	ax,ERR_IDE_NoBlockMode
.Error:		stc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_GetDPSaddr - get drive parameters structure address.
		; Input: BH=drive number (0..IDE_MAXDRIVES).
		; Output: CF=0 - OK, EDI=structure address;
		;	  CF=1 - error.
proc IDE_GetDPSaddr
		cmp	bh,IDE_MAXDRIVES
		cmc
		jc	.Exit
		push	eax
		mov	edi,?DevTable
		xor	eax,eax
		mov	al,bh
		shl	eax,7			; Size of tIDEdev=128 bytes
		add	edi,eax
		pop	eax
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; IDE_Minor2HDN - get the hard disk number and address of
		;		  device parameters structure from full
		;		  minor number.
		; Input: EDX (high word) - full minor number.
		; Output: CF=0 - OK:
		;		    BH=hard disk number,
		;		    BL=subminor number,
		;		    EDI=device parameters structure address.
		;	  CF=1 - error, AX=error code.
proc IDE_Minor2HDN
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl			; Minor number nonzero?
		jz	.Err1
		xchg	bl,bh
		dec	bh			; Get disk number
		call	IDE_GetDPSaddr		; Get structure address
		jc	.Err2
		clc
		ret
.Err1:		mov	ax,ERR_DRV_NoMinor
		jmp	.Error
.Err2:		mov	ax,ERR_DRV_BadMinor
.Error:		stc
		ret
endp		;---------------------------------------------------------------

