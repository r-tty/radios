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

library $libc
importproc _InterruptAttach
importproc _ThreadCtl, _ThreadCreate, _ThreadDetach
importproc _puts

; Interrupt request lines
%define	IRQ_IDE1	14		; Default IRQ for interface 1
%define	IRQ_IDE2	15		; Default IRQ for interface 2
%define	IRQ_IDE3	11		; Default IRQ for interface 3
%define	IRQ_IDE4	12		; Default IRQ for interface 4

; Miscellaneous
%define	IDE_MAXDRIVES	4		; Maximum number of supported drives
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
Txt~Thread	DB	"Unable to create thread",0
Txt~IOpriv	DB	"Unable to get I/O privilege",0
Txt~Intr	DB	"Unable to attach interrupt",0

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
		arg	argc, argv
		prologue

		; Initialize port addresses and IRQs
		mov	dword [?BasePorts],PORT_HDC_IDE1 + (PORT_HDC_IDE2 << 16)
		mov	dword [?BasePorts+4],PORT_HDC_IDE3 + (PORT_HDC_IDE4 << 16)
		mov	dword [?IRQlines],IRQ_IDE1 + (IRQ_IDE2 << 8) + (IRQ_IDE3 << 16) + (IRQ_IDE4 << 24)

		; For each enabled channel create a handling thread
		xor	ecx,ecx
.LoopChan:	Ccall	_ThreadCreate, 0, IDE_ChannelThread, ecx, 0
		test	eax,eax
		js	.ErrThread
		inc	ecx
		cmp	ecx,IDE_MAXCHANNELS
		jne	.LoopChan
		Ccall	_ThreadDetach, 0

.Exit:		epilogue
		ret

.ErrThread:	Ccall	_puts, Txt~Thread
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Per-channel thread. It probes for devices on the channel,
		; and if disk drive(s) found registers them in the pathman
		; and starts message processing loop.
proc IDE_ChannelThread
		arg	idechan
		locauto	ev, tSigEvent_size
		prologue

		; Get I/O privileges
		Ccall	_ThreadCtl, TCTL_IO, 0
		test	eax,eax
		js	.ErrIOpriv

		; Attach an interrupt event
		mov	ecx,[%$idechan]
		movzx	eax,byte [ecx+?IRQlines]
		lea	edx,[%$ev]
		Ccall	_InterruptAttach, eax, 0, edx, tSigEvent_size, 0
		test	eax,eax
		stc
		js	.ErrIntr
		
.Exit:		epilogue
		ret

.ErrIOpriv:	Ccall	_puts, Txt~IOpriv
		jmp	.Exit
.ErrIntr:	Ccall	_puts, Txt~Intr
		jmp	.Exit
endp		;---------------------------------------------------------------
