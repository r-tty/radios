;*******************************************************************************
;  rfsboot.asm - RFS boot sector.
;  (c) 1999 Yuri Zaporogets.
;*******************************************************************************

bits 16

; --- Definitions ---

%define	BOOTSEG		7C0h
%define	CONFIGSEG	50h
%define	KERNELSEG	100h

struc tMasterBlock
.JmpCOP		RESB	1
.JmpOfs		RESB	1
.ID		RESB	10
.BootProg	RESB	20
.Ver		RESD	1
.NumBAMs	RESD	1
.KBperBAM	RESD	1
.RootDir	RESD	1
.LoaderOfs	RESD	1		; Offset from begin of partition to
					; system loader (in sectors)
.LoaderSize	RESD	1		; Size of system loader (in sectors)
endstruc


section .text
org 0

Header		DB	0EBh
		DB	tMasterBlock_size-2
		DB	"RFS 01.00 "
		DB	"system_loader       "
		DD	1,0,0,0,0,0

		; Move loader to (MemoryTop)-64K
		mov	ax,BOOTSEG
		mov	ds,ax
		int	12h				; Get base memory size
		shl	ax,6				; KB -> paragraphs
		sub	ax,1000h
		mov	[UpSeg],ax
		jmp	short $+2			; Clear pipeline
		mov	es,ax
		xor	si,si
		xor	di,di
		mov	cx,256
		cld
		rep	movsw
		DB	0EAh
		DW	offset Main
UpSeg		DW	0

; --- Vars ---
Drive		DB	0
Head		DB	0
Cyl		DB	0
Sector		DB	3

Addr		DW	100h
TargSeg		DW	0F0h

MaxHead		DB	1
SPT		DB	18

SectorsInFile	DB	80


; --- Code ---

		; Main - main entry.
proc Main
		mov	ax,cs
		mov	ds,ax
		mov	ss,ax
		mov	sp,4000h
		mov	si,offset MsgLoading
		call	WrString

		; Load config sector
		mov	dh,[Drive]
		xor	dl,dl
		mov	cx,2
		mov	ax,CONFIGSEG
		mov	es,ax
		xor	bx,bx
		mov	ax,0201h
		int	13h
		jc	near .ErrInt13

		mov	di,5				; Error counter

.Loop:		mov	ax,[TargSeg]
		mov	es,ax
		mov	bx,[Addr]
		mov	dl,[Drive]			; Drive
		mov	dh,[Head]			; Head
		mov	ch,[Cyl]			; Cyl
		mov	cl,[Sector]			; Sec
		mov	al,[SPT]			; Number of sectors
		sub	al,cl
		inc	al
		mov	ah,2				; Function=read
		int	13h
		jnc	.TrackOK
		xor	ah,ah				; Reset controller
		int	13h
		dec	di				; up to 5 times
		jnz	.Loop
		jmp	short .ErrInt13

.TrackOK:	mov	di,5
		sub	[SectorsInFile],al
		xor	ah,ah
		shl	ax,5
		add	[TargSeg],ax
		mov	byte [Sector],1
		mov	bx,7
		mov	ax,0E2Eh			; Print dot
		int	10h

		mov	al,[Head]
		cmp	al,[MaxHead]
		je	short .NextCyl
		inc	byte [Head]
		jmp	short .Check

.NextCyl:	mov	byte [Head],0
		inc	byte [Cyl]

.Check:		cmp	byte [SectorsInFile],0
		jge	.Loop


.Start:		call	StopMotor
		mov	ax,KERNELSEG-10h
		mov	ds,ax
		mov	es,ax
		xor	ax,ax
		mov	ss,ax
		mov	sp,0E00h

		int	12h
		shl	ax,6			; Set parameters
		mov	[2],ax			; for unpacker
		DB	0EAh			; Far jump to loaded program
		DW	100h,0F0h

.ErrInt13:	mov	si,MsgErr
		call	WrString

.Halt:		jmp	.Halt

endp		;---------------------------------------------------------------


		; WrString - write ASCIIZ-string.
		; Input: SI=pointer to string.
		; Output: none.
proc WrString
		cld
.Loop:		lodsb
		or	al,al
		jz	.Exit
		mov	ah,0Eh
		xor	bh,bh
		int	10h
		jmp	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------


		; StopMotor - stop all FDD motors.
		; Input: none.
		; Output: none.
proc StopMotor
		mov	dx,03F2h
		xor	al,al
		out	dx,al
		ret
endp		;---------------------------------------------------------------


; --- Data ---

section .data

MsgLoading	DB	13,10,"Loading",0
MsgErr		DB	"Int 13h error",0

		TIMES	170 DB 0
		DW	0AA55h
