;*******************************************************************************
;  ide.asm - IDE driver.
;  Ported from Adri Koppes's Minix AT HD driver.
;  RadiOS version 1.0 by Yuri Zaporogets.
;*******************************************************************************

.386
Ideal

;DEBUG=1

include "segments.ah"
include "errdefs.ah"
include "sysdata.ah"
include "drvctrl.ah"
include "drivers.ah"
include "hardware.ah"
include "kernel.ah"
include "strings.ah"
include "portsdef.ah"
include "hd.ah"

IFDEF DEBUG
include "macros.ah"
include "misc.ah"
ENDIF

; --- Definitions ---

; HDD controller registers
REG_DATA	EQU	0		; Data register
REG_PRECOMP	EQU	1		; Start of write precompensation
REG_COUNT	EQU	2		; Sectors to transfer
REG_SECTOR	EQU	3		; Sector number
REG_CYL_LO	EQU	4		; Low byte of cylinder number
REG_CYL_HI	EQU	5		; High byte of cylinder number
REG_LDH		EQU	6		; LBA, drive and head
REG_COMMAND	EQU	7		; Command register
REG_STATUS	EQU	7		; Status register
REG_ERROR	EQU     1		; Error code register
REG_CTL		EQU	206h		; Control register

; LBA, drive and head values
LDH_DEFAULT	EQU	0A0h		; ECC enable, 512 bytes per sector
LDH_LBA		EQU	40h		; Use LBA addressing

; Status register values
STATUS_BSY	EQU	80h		; controller busy
STATUS_RDY	EQU	40h		; drive ready
STATUS_WF	EQU	20h		; write fault
STATUS_SC	EQU	10h		; seek complete (obsolete)
STATUS_DRQ	EQU	08h		; data transfer request
STATUS_CRD	EQU	04h		; corrected data
STATUS_IDX	EQU	02h		; index pulse
STATUS_ERR	EQU	01h		; error

; Error register values
ERROR_BB	EQU	80h		; bad block
ERROR_ECC	EQU	40h		; bad ecc bytes
ERROR_ID	EQU	10h		; ID not found
ERROR_AC	EQU	04h		; aborted command
ERROR_TK	EQU	02h		; track zero error
ERROR_DM	EQU	01h		; no data address mark

; Commands
CMD_IDLE	EQU	00h		; Drive idle
CMD_RECALIBRATE	EQU	10h		; Recalibrate drive
CMD_READ	EQU	20h		; Read data
CMD_WRITE	EQU	30h		; Write data
CMD_READVERIFY	EQU	40h		; Read verify
CMD_FORMAT	EQU	50h		; Format track
CMD_SEEK	EQU	70h		; Seek cylinder
CMD_DIAG	EQU	90h		; Execute device diagnostics
CMD_SPECIFY	EQU	91h		; Specify parameters

ATA_IDENTIFY	EQU	0ECh		; Identify drive
ATA_READMULT	EQU	0C4h		; Read multiple
ATA_WRITEMULT	EQU	0C5h		; Write multiple
ATA_SETMULTMODE	EQU	0C6h		; Set multiple mode
ATA_READDMA	EQU	0C8h		; Read through DMA
ATA_WRITEDMA	EQU	0CAh		; Write through DMA
ATA_READBUF	EQU	0E4h		; Read buffer
ATA_WRITEBUF	EQU	0E8h		; Write buffer

; Device control register values
CTL_NORETRY	EQU	80h		; Disable access retry
CTL_NOECC	EQU	40h		; Disable ECC retry
CTL_EIGHTHEADS	EQU	08h		; More than eight heads
CTL_RESET	EQU	04h		; Reset controller
CTL_INTDISABLE	EQU	02h		; Disable interrupts

; Interrupt request lines
IRQ_IDE1	EQU	14		; Default IRQ for controller 1
IRQ_IDE2	EQU	15		; Default IRQ for controller 2
IRQ_IDE3	EQU	11		; Default IRQ for controller 3
IRQ_IDE4	EQU	12		; Default IRQ for controller 4

; Miscellaneous
IDE_MAXDRIVES		EQU	8	; Maximum number of supported drives

; Time intervals (in milliseconds)
IDE_MAXTIMEOUT		EQU	32000	; Controller maximum timeout
IDE_RECOVERYTIME	EQU	500	; Controller recovery time
IDE_IRQWAITTIME		EQU	10000	; Maximum wait for an IRQ to happen

; Status flags
IDE_INITIALIZED		EQU	1	; Drive is initialized
IDE_DEAF		EQU	2	; Controller must be reset
IDE_INTELLIGENT		EQU	4	; Intelligent ATA IDE drive
IDE_BLOCKMODEON		EQU	8	; Block mode turned on

; Structure of common command block
struc	tIDE_Command
 Precomp	DB	?		; REG_PRECOMP, etc.
 Count		DB	?
 Sector		DB	?
 Cyl_Lo		DB	?
 Cyl_Hi		DB	?
 LDH		DB	?
 Command	DB	?
ends

; Structure of IDE device parameters
struc tIDEdev
 BasePort	DW	?	; Controller base port address
 IRQ		DB	?	; IRQ line number
 State		DB	?	; State flags
 LCyls		DW	?	; Logical (BIOS-compatible) parameters
 LHeads		DW	?
 LSectors	DW	?
 PCyls		DW	?	; Physical parameters
 PHeads		DW	?
 PSectors	DW	?
 TotalSectors	DD	?	; Total addressable sectors (LBA)
 LDHpref	DB	?	; Top four bits of the LDH (head) register
 Precomp	DW	?	; Write precompensation cylinder / 4
 MaxCount	DB	?	; Max request for this drive
 OpenCount	DB	?	; In-use count
 DriveNum	DB	?	; Drive number
 SecPerInt	DB	?	; Sectors per interrupt (R/W multiple)
 CommonDesc	DD	?	; Common HD descriptor (for DIHD routines)
 ModelStr	DB 40 dup (?)
 Reserved	DB 57 dup (?)	; Complement to 128 bytes
ends

; Structure of identify drive information
struc tIDE_IDinfo
 Flags		DW	?
 NumHardCyls	DW	?
 Reserved1	DW	?
 NumHeads	DW	?
 UnformBPT	DW	?
 UnformBPS	DW	?
 Sectors	DW	?
 Reserved2	DW	3 dup (?)
 SerNumber	DW	10 dup(?)
 BufType	DW	?
 BufSize	DW	?
 NumECCbytes	DW	?
 Revision	DW	4 dup (?)
 ModelStr	DW	20 dup (?)
 RWMultiSecs	DW	?
 DoubleWordIO	DW	?
 Capabilities	DW	?
 Reserved3	DW	?
 PIOdataCTM	DW	?
 DMAdataCTM	DW	?
 Reserved4	DW	7 dup (?)
 LBAtotalSecs	DD	?
 Reserved5	DW	194 dup (?)
ends


; --- Data ---
segment KDATA
; HD driver main structure
DrvHDIDE	tDriver <"%hd             ",offset DrvIDEET,DRVFL_Block>

; Driver entry points table
DrvIDEET	tDrvEntries < IDE_Init,\
			      IDE_HandleEvent,\
			      IDE_Open,\
			      IDE_Close,\
			      IDE_Read,\
			      IDE_Write,\
			      IDE_DoneMem,\
			      DrvIDE_Ctrl >
; Driver control functions
DrvIDE_Ctrl	DD	IDE_GetInitStatStr
		DD	IDE_GetParameters

; Init status string pieces
IDE_InitStatStr	DB	9,9,": IDE ATA, 0 controller(s), 0 drive(s)",0
IDE_MBstr	DB	" MB",0
IDE_LBAstr	DB	", LBA",0
IDE_CHSstr	DB	", CHS=",0
IDE_MaxMultStr	DB	", MaxMult=",0

ends


; --- Variables ---

segment KVARS
IDE_TableHnd	DW	0		; Device parameters table handle
IDE_TableAddr	DD	0		; and address

IDE_BasePorts	DW	PORT_HDC_IDE1	; Controller base ports
		DW	PORT_HDC_IDE2
		DW	PORT_HDC_IDE3
		DW	PORT_HDC_IDE4

IDE_IRQlines	DB	IRQ_IDE1	; IRQ lines
		DB	IRQ_IDE2
		DB	IRQ_IDE3
		DB	IRQ_IDE4

IDE_Command	DB	0		; Current command in execution
		DB	0
		DB	0
		DB	0

IDE_Status	DB	0		; Status after interrupt
		DB	0
		DB	0
		DB	0

IDE_NumInstDevs	DB	0		; Number of installed devices
IDE_NumCntrlrs	DB	0		; Number of installed IDE controllers
ends


; --- Interface procedures ---
segment KCODE

		; IDE_Init - driver initialization.
		; Input: DL=maximum number of devices to search,
		;	 ESI=pointer to buffer for init status string.
		; Output: CF=0 - OK:
		;		  DH=number of interfaces found,
		;		  DL=number of drives found.
		;	  CF=1 - error.
		; Action: 1. if memory blocks not allocated, allocate them;
		;	  2. initialize IDE interfaces;
		;	  3. search drives and fill parameters structure.
proc IDE_Init near
		push	ebx
		mov	dh,dl
		xor	dl,dl
		xor	ebx,ebx
		dec	bh
		cmp	[IDE_TableHnd],0	; Memory allocated?
		jne	short @@Loop
		mov	al,IDE_MAXDRIVES
		call	IDE_InitMem		; Allocate memory

@@Loop:		inc	bh
		call	IDE_Probe
		jc	short @@1
		inc	dl
		cmp	dl,dh
		jae	short @@2
@@1:		cmp	bh,IDE_MAXDRIVES-1
		jb	@@Loop

@@2:		mov	dh,dl			; Count number of interfaces
		or	dh,dh
		jz	short @@GetStr
		dec	dh
		shr	dh,1
		inc	dh
		mov	[IDE_NumInstDevs],dl	; Store number of drives found
		mov	[IDE_NumCntrlrs],dh

@@GetStr:	movzx	edx,dx
		call	IDE_GetInitStatStr
		clc
		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_HandleEvent - handle all hardware interrupts.
		; Input: EAX=event code.
		; Output: none.
proc IDE_HandleEvent near
		test	eax,EV_IRQ
		jnz	short @@HandleIRQ
		stc
		ret
@@HandleIRQ:	push	ebx edx
		and	eax,3				; EAX=interface number
		mov	ebx,eax
		add	eax,offset IDE_BasePorts
		mov	dx,[eax]
		add	dx,REG_STATUS
		in	al,dx
		add	ebx,offset IDE_Status
		mov	[ebx],al
@@OK:		call	DSF_Run
		pop	edx ebx
		clc
		ret
endp		;---------------------------------------------------------------


		; IDE_Open - "open" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IDE_Open near
		test	edx,0FF000000h			; Subminor given?
		jz	short @@Do			; No, all right
		mov	ax,ERR_DRV_BadMinor		; Else error
		stc					; (bad minor number)
		ret
@@Do:		push	ebx edx edi
		call	IDE_Minor2HDN			; Get disk number
		jc	short @@Exit			; and structure address
		cmp	[edi+tIDEdev.OpenCount],0	; Already opened?
		jne	short @@Err
		mov	dx,DRVID_HDIDE			; Major number of driver
		push	edi
		mov	edi,offset IDE_Operation
		call	HD_Open				; Partition disk
		pop	edi
		jc	short @@Exit
		mov	[edi+tIDEdev.CommonDesc],eax	; Store disk descriptor
		inc	[edi+tIDEdev.OpenCount]
		xor	eax,eax
		jmp	short @@Exit

@@Err:		mov	ax,ERR_DRV_AlreadyOpened
		stc
@@Exit:		pop	edi edx ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_Close - "close" device.
		; Input: EDX (high word) = full minor number of device.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error, AX=error code.
proc IDE_Close near
		test	edx,0FF000000h			; Subminor given?
		jz	short @@Do			; No, all right
		mov	ax,ERR_DRV_BadMinor		; Else error
		stc					; (bad minor number)
		ret
@@Do:		push	ebx edx edi
		call	IDE_Minor2HDN			; Get disk number
		jc	short @@Exit			; and structure address
		mov	eax,[edi+tIDEdev.CommonDesc]	; Major number of driver
		call	HD_Close			; "Close" disk
		jc	short @@Exit
		xor	eax,eax
		cmp	[edi+tIDEdev.OpenCount],0
		je	short @@Exit
		dec	[edi+tIDEdev.OpenCount]
		xor	al,al
@@Exit:		pop	edi edx ebx
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
proc IDE_Read near
		test	edx,0FF000000h			; Check subminor
		jz	short @@Absolute
		push	edi
		push	ebx
		call	IDE_Minor2HDN
		pop	ebx
		jc	short @@ExitRel
		cmp	[edi+tIDEdev.OpenCount],0	; Device opened?
		je	short @@Err
		mov	eax,[edi+tIDEdev.CommonDesc]
		mov	edi,offset IDE_Operation
		call	HD_Read
		jmp	short @@ExitRel
@@Err:		mov	ax,ERR_DRV_NotOpened
		stc
@@ExitRel:	pop	edi
		ret

@@Absolute:     push	ecx
		mov	al,cl			; Keep count
		mov	ecx,ebx			; ECX=absolute sector
		call	IDE_Minor2HDN		; BH=drive
		jc	short @@Exit
		mov	bl,al			; BL=count
		mov	ah,HD_opREADSEC		; Operation code
		call	IDE_Operation
@@Exit:		pop	ecx
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
proc IDE_Write near
		test	edx,0FF000000h			; Check subminor
		jz	short @@Absolute
		push	edi
		push	ebx
		call	IDE_Minor2HDN
		pop	ebx
		jc	short @@ExitRel
		cmp	[edi+tIDEdev.OpenCount],0	; Device opened?
		je	short @@Err
		mov	eax,[edi+tIDEdev.CommonDesc]
		mov	edi,offset IDE_Operation
		call	HD_Read
		jmp	short @@ExitRel
@@Err:		mov	ax,ERR_DRV_NotOpened
		stc
@@ExitRel:	pop	edi
		ret

@@Absolute:     push	ecx
		mov	al,cl			; Keep count
		mov	ecx,ebx			; ECX=absolute sector
		call	IDE_Minor2HDN		; BH=drive
		jc	short @@Exit
		mov	bl,al			; BL=count
		mov	ah,HD_opWRITESEC	; Operation code
		call	IDE_Operation
@@Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; IDE_GetInitStatStr - get initialization status string.
		; Input: ESI=buffer for string.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
		; Note: if the minor number is given, forms string with
		;	hard disk model, else forms string with controller
		;	information and number of drives found.
proc IDE_GetInitStatStr near
		push	eax ebx esi edi
		mov	edi,esi
		mov	esi,offset DrvHDIDE		; Copy "%hd"
		call	StrCopy
		call	StrEnd

		test	edx,0FFFF0000h			; Minor present?
		jnz	short @@ChkSubMinor

		mov	esi,offset IDE_InitStatStr
		call	StrCopy
		mov	al,[IDE_NumInstDevs]
		mov	ah,[IDE_NumCntrlrs]
		add	ax,3030h
		mov	[edi+13],al
		mov	[edi+30],ah
		mov	esi,ebx
                jmp	@@Exit

@@ChkSubMinor:	cld
		test	edx,0FF000000h
		jz	short @@DriveModel
		mov	ebx,edx
		shr	ebx,16
		mov	eax,ebx
		add	ax,3030h
		stosb					; Store minor number,
		mov	al,'.'				; dot and
		stosw					; subminor number
		mov	eax,203A0920h			; Tabs and ':'
		stosd
		xchg	bh,bl				; BL=partition number
		dec	bh				; BH=disk number
		push	edi				; Keep buffer address
		call	IDE_GetDPSaddr
		mov	eax,[edi+tIDEdev.CommonDesc]
		pop	edi
		jc	@@Exit
		mov	esi,edi
		call	HD_GetPartInfoStr
		jmp	@@Exit

@@DriveModel:	mov	ebx,edx
		shr	ebx,8
		mov	al,bh
		add	al,30h
		cld
		stosb					; Store minor number
		dec	bh
		push	edi				; Keep buffer address
		call	IDE_GetDPSaddr
		mov	ebx,edi
		pop	edi
		jc	@@Exit
		lea	esi,[ebx+tIDEdev.ModelStr]	; ESI=pointer to model
		mov	eax,203A0909h			; Tabs & ':'
		stosd
		call	StrCopy

		call	StrEnd				; Store size string
		mov	ax," ,"
		stosw
		mov	esi,edi
		mov	eax,[ebx+tIDEdev.TotalSectors]
		shr	eax,11
		call	K_DecD2Str
		mov	esi,offset IDE_MBstr
		call	StrAppend

		test	[ebx+tIDEdev.LDHpref],LDH_LBA	; LBA?
		jz	short @@CHS
		mov	esi,offset IDE_LBAstr
		call	StrAppend
@@CHS:		mov	esi,offset IDE_CHSstr
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		movzx	eax,[ebx+tIDEdev.LCyls]
		call	K_DecD2Str
		call	StrEnd
		mov	[byte edi],'/'
		lea	esi,[edi+1]
		mov	ax,[ebx+tIDEdev.LHeads]
		call	K_DecD2Str
		call	StrEnd
		mov	[byte edi],'/'
		lea	esi,[edi+1]
		mov	ax,[ebx+tIDEdev.LSectors]
		call	K_DecD2Str

		mov	al,[ebx+tIDEdev.SecPerInt]
		cmp	al,1
		je	short @@Exit
		mov	esi,offset IDE_MaxMultStr
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		call	K_DecD2Str
@@OK:		clc
@@Exit:		pop	edi esi ebx eax
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
proc IDE_GetParameters near
		push	ebx edi
		call	IDE_Minor2HDN
		jc	short @@Exit
		or	bl,bl				; Subminor given?
		jz	short @@NoSubMinor
		mov	eax,[edi+tIDEdev.CommonDesc]
		call	HD_GetPartParams
                jc	short @@Exit

@@NoSubMinor:	mov	cx,[edi+tIDEdev.LCyls]
		mov	dl,[byte edi+tIDEdev.LSectors]
		mov	dh,[byte edi+tIDEdev.LHeads]
		clc
@@Exit:		pop	edi ebx
		ret
endp		;---------------------------------------------------------------



; --- Internal procedures ---

		; IDE_InitMem - initialize driver memory blocks.
		; Input:  AL=maximum number of physical HD drives.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IDE_InitMem near
		cmp	al,IDE_MAXDRIVES
		jbe	short @@Do
		mov	ax,ERR_IDE_InitTooManyDrv
		stc
		ret
@@Do:		push	ebx ecx edx
		movzx	eax,al
		xor	edx,edx
		mov	ecx,size tIDEdev
		mul	ecx			; Allocate memory
		mov	ecx,eax
		call	KH_Alloc		; for table
		jc	short @@Exit
		mov	[IDE_TableHnd],ax	; Store block handle
		mov	[IDE_TableAddr],ebx	; Store block address
		call	KH_FillZero		; Clear table entries
		xor	ax,ax
		mov	[IDE_NumInstDevs],al
@@Exit:		pop	edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_DoneMem - release driver memory blocks.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IDE_DoneMem near
		mov	ax,[IDE_TableHnd]
		call	KH_Free
		ret
endp		;---------------------------------------------------------------


		; IDE_Probe - check of drive presence and read its parameters.
		; Input: BH=drive number (0..IDE_MAXDRIVES).
		; Output: CF=0 - OK, drive present;
		;	  CF=1 - drive not found.
proc IDE_Probe near
		cmp	bh,IDE_MAXDRIVES
		jb	short @@Do
		stc
		ret

@@Do:           push	ebp
		mov	ebp,esp				; Allocate buffer
		sub	esp,512				; for information sector
		push	eax ebx ecx edx esi edi

		; Get base port (DX) and IRQ (CL)
		xor	eax,eax
		mov	al,bh
		and	al,254
		mov	dx,[eax+offset IDE_BasePorts]
		mov	cl,[eax+offset IDE_IRQlines]

		; Check if the one of the registers exists
		add	dx,REG_CYL_LO
		in	al,dx
		mov	ah,al
		not	al
		out	dx,al
		in	al,dx
		sub	dx,REG_CYL_LO
		cmp	al,ah
		je	@@NotExist

		; Fill device parameters structure
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
		jc	@@NotExist			; No, exit

		; Intelligent drive: read identify drive information
		or	[edi+tIDEdev.State],IDE_INTELLIGENT
		mov	ebx,edi				; Keep structure address
		lea	edi,[ebp-512]			; Buffer address
		mov	cx,256				; 256 words
		cld
		rep	insw				; DX at data reg now

		; Fill another fields of parameters structure
		lea	esi,[ebp-512]
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
		or	al,al					; Block mode
		jnz	short @@SecPerInt			; enabled?
		inc	al
@@SecPerInt:	mov	[edi+tIDEdev.SecPerInt],al

		mov	ax,[esi+tIDE_IDinfo.Capabilities]
		test	ah,2					; LBA?
		jz	short @@Model
		or	[edi+tIDEdev.LDHpref],LDH_LBA
		mov	eax,[esi+tIDE_IDinfo.LBAtotalSecs]	; Total sectors
		mov	[edi+tIDEdev.TotalSectors],eax

@@Model:	add	esi,offset (tIDE_IDinfo).ModelStr
		add	edi,offset (tIDEdev).ModelStr
		mov	cl,40
		cld
@@ModelLoop:	lodsw					; Copy model string
		dec	cl
		dec	cl
		jz	short @@Term
		cmp	ax,2020h
		je	short @@Term
		xchg	al,ah				; Convert
		stosw					; to little-endian
		jmp	@@ModelLoop

@@Term:		xor	al,al				; NULL-terminator
		mov	[edi],al

		; Initialize logical parameters (for BIOS compatibility)
		mov	edi,ebx				; Restore pointer
		mov	ax,[edi+tIDEdev.LCyls]
		mov	bx,[edi+tIDEdev.LHeads]
@@LogLoop:	cmp	ax,1024				; <=1024 cylinders?
		jbe	short @@StoreLogPar		; Yes, store new values
		shr	ax,1				; Else cylinders/=2
		shl	bx,1				; and heads*=2
		jmp	@@LogLoop
@@StoreLogPar:	mov	[edi+tIDEdev.LCyls],ax
		mov	[edi+tIDEdev.LHeads],bx

		; Initialize drive parameters
		call	IDE_Specify
		jnc	short @@SetBlkMode
		call	IDE_Specify
		jc	short @@NotExist

		; Initialize block mode
@@SetBlkMode:	mov	dl,[edi+tIDEdev.SecPerInt]
		cmp	dl,1
		je	short @@OK
		call	IDE_SetBlockMode
		jmp	short @@Exit

@@OK:		clc
		jmp	short @@Exit
@@NotExist:	stc
@@Exit:		pop	edi esi edx ecx ebx eax
		leave
		ret
endp		;---------------------------------------------------------------


		; IDE_Specify - specify some drive parameters.
		; Input: EDI=device parameters structure address.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc IDE_Specify near
		push	eax ebx ecx edi

		test	[edi+tIDEdev.State],IDE_DEAF	; Need reset?
		jz	short @@NoRes
		call	IDE_Reset
		jc	short @@Exit

@@NoRes:	mov	bl,[byte edi+tIDEdev.Precomp]
		mov	bh,[edi+tIDEdev.LDHpref]
		mov	al,[byte edi+tIDEdev.PHeads]
		dec	al				; BH |=PHeads
		or	bh,al
		xor	ecx,ecx
		mov	cl,[byte edi+tIDEdev.PSectors]
		mov	ah,CMD_SPECIFY
		call	IDE_OutCmdSimple
		jc	short @@Exit
		or	[edi+tIDEdev.State],IDE_INITIALIZED

@@Exit:		pop	edi ecx ebx eax
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
proc IDE_OutCommand near
		push	edx esi
		xor	edx,edx
                mov	dx,[edi+tIDEdev.BasePort]
		mov	si,ax				; Keep command
		shl	esi,16
		mov	si,dx				; Keep baseport

		; Wait until controller will be ready
		mov	ax,STATUS_BSY
		call	IDE_WaitFor
		jc	@@Exit

		; Select drive
		mov	edx,esi
		add	dx,REG_LDH
		mov	al,bh
		out	dx,al

		; Check drive ready
		mov	edx,esi
		mov	ax,256*STATUS_RDY+STATUS_BSY+STATUS_RDY
		call	IDE_WaitFor
		jc	@@Exit

		; Mask interrupt
		mov	al,[edi+tIDEdev.IRQ]
		call	PIC_DisIRQ

		; Out CTL byte
		cmp	[edi+tIDEdev.PHeads],8
		jae	short @@G8heads
		xor	al,al
		jmp	short @@OutCTL
@@G8heads:	mov	al,CTL_EIGHTHEADS
@@OutCTL:	add	dx,REG_CTL
		out	dx,al

		; Out parameters
		mov	edx,esi
		inc	dl			; DX=REG_PRECOMP
		or	bl,bl			; Precomp. cyl. given?
		jz	short @@NoPrecomp
		mov	al,bl
		out	dx,al
@@NoPrecomp:	inc	dl
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
		mov	[ebx+offset IDE_Command],al
		mov	[byte ebx+offset IDE_Status],STATUS_BSY
		sti
		pop	ebx

		; Unmask interrupt
		mov	al,[edi+tIDEdev.IRQ]
		call	PIC_EnbIRQ

		xor	ax,ax

@@Exit:		pop	esi edx
		ret
endp		;---------------------------------------------------------------


		; IDE_OutCmdSimple - out simple controller command: only one
		;		     interrupt and no data-out phase.
		; Input: same as IDE_OutCommand.
		; Output: same as IDE_OutCommand.
proc IDE_OutCmdSimple near
		call	IDE_OutCommand
		jc	short @@CmdErr
		call	IDE_WaitIntr
@@CmdErr:	pushfd					; Keep flags
		push	eax				; Keep error code
		xor	eax,eax
		mov	al,[edi+tIDEdev.DriveNum]	; Get controller number
		shr	al,1				; in EBX
		mov	[byte eax+offset IDE_Command],CMD_IDLE
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
proc IDE_WaitFor near
		push	eax ebx ecx edx
		add	dx,REG_STATUS
		mov	bl,al
		mov	ecx,IDE_MAXTIMEOUT
@@Loop:		in	al,dx
		and	al,bl
		cmp	al,ah
		je	short @@OK
		call	DSF_Yield1ms			; Yield on 1 ms
		dec	ecx
		jnz	@@Loop
		call	IDE_NeedReset			; Controller gone deaf
		stc
		jmp	short @@Exit
@@OK:		clc
@@Exit:		pop	edx ecx ebx eax
		ret
endp		;---------------------------------------------------------------


		; IDE_NeedReset - set drive flags so the controller needs
		;		  to be reset.
		; Input: EDI=device parameters structure address.
		; Output: none.
proc IDE_NeedReset near
		push	eax edi
		call	@@SetFlags
		xor	eax,eax
		mov	al,size tIDEdev
		test	[edi+tIDEdev.DriveNum],1
		jnz	short @@Slave
		add	edi,eax
		jmp	short @@1
@@Slave:	sub	edi,eax
@@1:		call	@@SetFlags
		pop	edi eax
		ret
@@SetFlags:	mov	al,[edi+tIDEdev.State]
		or	al,IDE_DEAF
		and	al,not IDE_INITIALIZED
		mov	[edi+tIDEdev.State],al
		ret
endp		;---------------------------------------------------------------


		; IDE_Reset - reset controller.
		; Input: EDI=device parameters structure address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc IDE_Reset near
		push	ecx edx edi

		; Wait for any internal drive recovery
		mov	ecx,IDE_RECOVERYTIME
		call	DSF_Yield

		; Strobe reset bit
		mov	dx,[edi+tIDEdev.BasePort]
		mov	al,CTL_RESET
		out	dx,al
		call	DSF_Yield1ms
		xor	al,al
		out	dx,al

		; Wait for controller ready
		mov	ax,256*STATUS_RDY+STATUS_BSY+STATUS_RDY
		call	IDE_WaitFor
		jc	short @@Err1

		; Clear DEAF flags for all drives on this controller
		mov	dl,not IDE_DEAF
		and	[edi+tIDEdev.State],dl			; This drive
		xor	eax,eax
		mov	al,size tIDEdev
		test	[edi+tIDEdev.DriveNum],1		; Slave?
		jnz	short @@Slave
		add	edi,eax
		jmp	short @@1
@@Slave:	sub	edi,eax
@@1:		and	[edi+tIDEdev.State],dl			; Another drive
		xor	ax,ax
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_IDE_ResFailed
@@Error:	stc
@@Exit:		pop	edi edx ecx
		ret
endp		;---------------------------------------------------------------


		; IDE_Recalibrate - recalibrate drive.
		; Input: BH=drive number.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc IDE_Recalibrate near
		push	ebx ecx edx edi
		call	IDE_GetDPSaddr
		jc	short @@Exit
		shr	bh,4
		or	bh,[edi+tIDEdev.LDHpref]
		xor	bl,bl
		xor	ecx,ecx
		mov	ah,CMD_RECALIBRATE
		call	IDE_OutCmdSimple
@@Exit:		pop	edi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_WaitIntr - wait for completion interrupt and return
		;		 result.
		; Input: EDI=device parameters structure address.
		; Outut: CF=0 - OK;
		;	 CF=1 - error, AX=error code.
proc IDE_WaitIntr near
		push	ebx edx
		xor	ebx,ebx
		mov	bl,[edi+tIDEdev.DriveNum]
		shr	bl,1
@@Loop:		call	DSF_Block			; Block current thread
		mov	al,[ebx+offset IDE_Status]
		test	al,STATUS_BSY
		jnz	@@Loop

		cli
		mov	ah,al
		and	al,STATUS_BSY+STATUS_RDY+STATUS_WF+STATUS_ERR
		cmp	al,STATUS_RDY
		je	short @@OK
		test	ah,STATUS_ERR
		jz	short @@GeneralErr
		mov	dx,[edi+tIDEdev.BasePort]
		add	dx,REG_ERROR
		in	al,dx
		and	al,ERROR_BB
		jz	short @@GeneralErr
		mov	ax,ERR_IDE_BadSector		; BadSector  error
		jmp	short @@Err

@@OK:		or	[byte ebx+offset IDE_Status],STATUS_BSY
		xor	ax,ax
		jmp	short @@Exit
@@GeneralErr:	mov	ax,ERR_IDE_General		; General error
@@Err:		stc
@@Exit:         sti
		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


                ; IDE_Timeout - called if disk operation is timed out.
		; Input: EDI=device parameters structure address.
		; Output: none.
proc IDE_Timeout near
		push	eax ebx
		xor	ebx,ebx
		mov	bl,[edi+tIDEdev.DriveNum]
		shr	bl,1
		mov	al,[ebx+offset IDE_Command]	; Last command
		cmp	al,CMD_IDLE
		je	short @@Exit
		cmp	al,CMD_READ
		jne	short @@Other
		cmp	al,CMD_WRITE
		jne	short @@Other

		jmp	short @@Exit
@@Other:	call	IDE_NeedReset
		mov	[byte ebx+offset IDE_Status],0
@@Exit:		pop	ebx eax
		ret
endp		;---------------------------------------------------------------


		; IDE_SetBlockMode - enable/disable block mode.
		; Input: EDI=device parameters structure address;
		;	 DL=number of sectors in block.
                ; Output: CF=0 - OK, AX=0;
		;	  CF=1 - error, AX=error code.
		; Note: set DL=0 to disable block mode.
proc IDE_SetBlockMode near
		push	ebx ecx edx
		xor	ecx,ecx
		mov	cl,dl
		or	cl,cl				; Enable block mode?
		jnz	short @@Enable
		and	[edi+tIDEdev.State],not IDE_BLOCKMODEON
		jmp	short @@NoCorr
@@Enable:	mov	dl,[edi+tIDEdev.SecPerInt]
		cmp	dl,cl
		jae	short @@NoCorr
		mov	cl,dl

@@NoCorr:	mov	bh,[edi+tIDEdev.DriveNum]
		shl	bh,4
		or	bh,[edi+tIDEdev.LDHpref]
		xor	bl,bl
		mov	ah,ATA_SETMULTMODE
		call	IDE_OutCmdSimple
		jc	short @@Exit
		or	cl,cl
		jz	short @@OK
		or	[edi+tIDEdev.State],IDE_BLOCKMODEON
@@OK:		clc
@@Exit:		pop	edx ecx ebx
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
proc IDE_Operation near
		push	ebx ecx edx esi edi

		; Get drive parameters structure address
		call	IDE_GetDPSaddr
		jc	@@Err1

		; Check drive presence
		cmp	[edi+tIDEdev.PCyls],0
		je	@@Err1

		; If not LBA - count cylinder, head and sector
		test	[edi+tIDEdev.LDHpref],LDH_LBA
		jnz	short @@LBA
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
		jmp	short @@1

@@LBA:		ror	ecx,16
		test	ch,0F0h				; LBA correct?
		jnz	@@Err2
		mov	dh,bh				; Keep drive number
		shl	bh,4
		or	bh,[edi+tIDEdev.LDHpref]
		or	bh,ch
		ror	ecx,8				; Prepare to call
		mov	cl,bl				; IDE_OutCommand

@@1:		mov	bl,[byte edi+tIDEdev.Precomp]

		; More than 1 sector?
		cmp	cl,1
		je	short @@Single

		; Check device Multiple R/W capability
		mov	al,[edi+tIDEdev.SecPerInt]
		cmp	al,1
		je	@@Err4
		test	[edi+tIDEdev.State],IDE_BLOCKMODEON
		jz	@@Err5

		; Check number of sectors requested
		cmp	al,cl
		jb	@@Err4

		; Read or write?
		cmp	ah,HD_opREADSEC
		je	short @@ReadMult
		cmp	ah,HD_opWRITESEC
		jne	short @@Err3

		; Write multiple
;		mov	ah,ATA_WRITEMULT
;		call	IDE_OutCommand
;		jc	short @@Exit
;		call	IDE_WaitIntr
;		jc	short @@Exit
;		mov	dx,[edi+tIDEdev.BasePort]
;		and	ecx,0FFh
;		shl	ecx,8
;		rep	outsw
		jmp	short @@OK

		; Read multiple
@@ReadMult:	mov	ah,ATA_READMULT
		call	IDE_OutCommand
		jc	short @@Exit
		call	IDE_WaitIntr
		jc	short @@Exit
		mov	dx,[edi+tIDEdev.BasePort]
		and	ecx,0FFh
		shl	ecx,8
		mov	edi,esi
		rep	insw
		jmp	short @@OK


		; R/W single sector
@@Single:	cmp	ah,HD_opREADSEC
		je	short @@ReadOne
		cmp	ah,HD_opWRITESEC
		jne	short @@Err3

		; Write one sector
;		mov	ah,CMD_WRITE
;		call	IDE_OutCommand
;		jc	short @@Exit
;		call	IDE_WaitIntr
;		jc	short @@Exit
;		mov	dx,[edi+tIDEdev.BasePort]
;		mov	ecx,256
;		rep	outsw
		jmp	short @@OK

		; Read one sector
@@ReadOne:	mov	ah,CMD_READ
		call	IDE_OutCommand
		jc	short @@Exit
		call	IDE_WaitIntr
		jc	short @@Exit
		mov	dx,[edi+tIDEdev.BasePort]
		mov	edi,esi
		mov	ecx,256
		rep	insw
		jmp	short @@OK

@@OK:		xor	ax,ax
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_IDE_BadDriveNum
		jmp	short @@Error
@@Err2:		mov	ax,ERR_IDE_BadLBA
		jmp	short @@Error
@@Err3:		mov	ax,ERR_HD_NoDiskOp
		jmp	short @@Error
@@Err4:		mov	ax,ERR_IDE_TooManySectors
		jmp	short @@Error
@@Err5:		mov	ax,ERR_IDE_NoBlockMode
@@Error:	stc
@@Exit:		pop	edi esi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; IDE_GetDPSaddr - get drive parameters structure address.
		; Input: BH=drive number (0..IDE_MAXDRIVES).
		; Output: CF=0 - OK, EDI=structure address;
		;	  CF=1 - error.
proc IDE_GetDPSaddr near
		cmp	bh,IDE_MAXDRIVES
		cmc
		jc	short @@Exit
		push	eax
		mov	edi,[IDE_TableAddr]
		xor	eax,eax
		mov	al,bh
		shl	eax,7			; Size of tIDEdev=128 bytes
		add	edi,eax
		pop	eax
		clc
@@Exit:		ret
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
proc IDE_Minor2HDN near
		mov	ebx,edx
		shr	ebx,16
		or	bl,bl			; Minor number nonzero?
		jz	short @@Err1
		xchg	bl,bh
		dec	bh			; Get disk number
		call	IDE_GetDPSaddr		; Get structure address
		jc	short @@Err2
		clc
		ret
@@Err1:		mov	ax,ERR_DRV_NoMinor
		jmp	short @@Error
@@Err2:		mov	ax,ERR_DRV_BadMinor
@@Error:	stc
		ret
endp		;---------------------------------------------------------------


; --- Debug routines ---
ifdef DEBUG
proc __test__ near
	enter 8192,0
	pushad

	mov ecx,254
	mov bx,1
	mov dl,63
	mov dh,64
	call HD_CHS2LBA
	mov ecx,ebx

	xor ebx,ebx
	mov bl,16
	mov ah,HD_opREADSEC
	lea esi,[ebp-8192]
	call IDE_Operation
	jnc short @@Exit
@@err:	call SPK_Beep

@@Exit:	popad
	leave
	ret
endp
endif

ends

end
