;-------------------------------------------------------------------------------
; mb_tramp.nasm - multiboot header and trampoline to embed into the kernel.
;-------------------------------------------------------------------------------

; Definitions
RDXPOS		EQU	110000h		; Kernel image will be placed here
BTL_DEST	EQU	100000h		; Target address of BTL
BTL_SIZE	EQU	16384		; Size of BTL (with spare)

; RDOFF master header
struc tRDOFFmaster
.Signature	RESB	5
.AVersion	RESB	1
.ModLen		RESD	1
.HdrLen		RESD	1
endstruc

; Multiboot header
struc tMultiBootHeader
.Magic		RESD	1
.Flags		RESD	1
.Checksum	RESD	1
.HeaderAddr	RESD	1
.LoadAddr	RESD	1
.LoadEndAddr	RESD	1
.BSSendAddr	RESD	1
.Entry		RESD	1
endstruc

MBH_MAGIC	EQU	1BADB002h
MBH_FLAGS	EQU	00010003h

MBHPOS		EQU	RDXPOS+10h

; We are in flat binary format, specify origin and 32-bit mode
bits 32
org MBHPOS

; Multiboot header itself
MBheader	DD	MBH_MAGIC			; Magic
		DD	MBH_FLAGS			; Flags
		DD	-(MBH_MAGIC+MBH_FLAGS)		; Checksum
		DD	MBHPOS				; Multiboot header addr
		DD	RDXPOS				; Loading addr
		DD	0				; == entire file
		DD	0				; == no BSS
		DD	MBHPOS+tMultiBootHeader_size	; Entry point

; Execution begins here
		mov	esi,[RDXPOS+tRDOFFmaster.ModLen]
		add	esi,RDXPOS+10
		mov	edi,BTL_DEST
		mov	edx,edi
		mov	ecx,BTL_SIZE / 4
		cld
		rep	movsd
		jmp	edx
