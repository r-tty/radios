;*******************************************************************************
;  ide.asm - IDE controllers and drives control module.
;  Ported from Adri Koppes's Minix AT HD driver.
;*******************************************************************************

; --- Definitions ---

; HDD controllers ports

; Read and write registers
REG_DATA	EQU	0		; data register
REG_PRECOMP	EQU	1		; start of write precompensation
REG_COUNT	EQU	2		; sectors to transfer
REG_SECTOR	EQU	3		; sector number
REG_CYL_LO	EQU	4		; low byte of cylinder number
REG_CYL_HI	EQU	5		; high byte of cylinder number
REG_LDH		EQU	6		; LBA, drive and head
LDH_DEFAULT	EQU	0A0h		; ECC enable, 512 bytes per sector
LDH_LBA		EQU	40h		; Use LBA addressing

macro ldh_init drive
;;	LDH_DEFAULT .or. (drive << 4)
endm

; Read only registers
REG_STATUS	EQU	7		; status register
STATUS_BSY	EQU	80h		; controller busy
STATUS_RDY	EQU	40h		; drive ready
STATUS_WF	EQU	20h		; write fault
STATUS_SC	EQU	10h		; seek complete (obsolete)
STATUS_DRQ	EQU	08h		; data transfer request
STATUS_CRD	EQU	04h		; corrected data
STATUS_IDX	EQU	02h		; index pulse
STATUS_ERR	EQU	01h		; error

REG_ERROR	EQU     1		; error code register
ERROR_BB	EQU	80h		; bad block
ERROR_ECC	EQU	40h		; bad ecc bytes
ERROR_ID	EQU	10h		; id not found
ERROR_AC	EQU	04h		; aborted command
ERROR_TK	EQU	02h		; track zero error
ERROR_DM	EQU	01h		; no data address mark

; Write only registers
REG_COMMAND	EQU	7		; command register
CMD_IDLE	EQU	00h		; for w_command: drive idle
CMD_RECALIBRATE	EQU	10h		; recalibrate drive
CMD_READ	EQU	20h		; read data
CMD_WRITE	EQU	30h		; write data
CMD_READVERIFY	EQU	40h		; read verify
CMD_FORMAT	EQU	50h		; format track
CMD_SEEK	EQU	70h		; seek cylinder
CMD_DIAG	EQU	90h		; execute device diagnostics
CMD_SPECIFY	EQU	91h		; specify parameters
ATA_IDENTIFY	EQU	ECh		; identify drive

REG_CTL		EQU	206h		; control register
CTL_NORETRY	EQU	80h		; disable access retry
CTL_NOECC	EQU	40h		; disable ecc retry
CTL_EIGHTHEADS	EQU	08h		; more than eight heads
CTL_RESET	EQU	04h		; reset controller
CTL_INTDISABLE	EQU	02h		; disable interrupts

; Interrupt request lines.
IRQ_IDE1	EQU	14		; IRQ for controller 1
IRQ_IDE2	EQU	15		; IRQ for controller 2
IRQ_IDE3	EQU	11		; IRQ for controller 3
IRQ_IDE4	EQU	12		; IRQ for controller 4

; Structure of common command block
struc	IDE_Command
 Precomp	DB	?		; REG_PRECOMP, etc.
 Count		DB	?
 Sector		DB	?
 Cyl_Lo		DB	?
 Cyl_Hi		DB	?
 LDH		DB	?
 Command	DB	?
ends


; --- Data ---

; HD driver main structure
DrvHDIDE	tDriver <"%hd             ",offset DrvIDEET,0>

; Driver entry points table
DrvIDEET	tDrvEntries < IDE_Init,\
			      IDE_HandleEvent,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL >

; --- Publics ---

		public DrvHDIDE


; --- Procedures ---

		; IDE_Init
proc IDE_Init near
		ret
endp		;---------------------------------------------------------------


		; IDE_HandleEvent
proc IDE_HandleEvent near
		ret
endp		;---------------------------------------------------------------
