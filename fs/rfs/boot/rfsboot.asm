;*******************************************************************************
;  rfsboot.asm - RFS boot sector.
;  (c) 1999 Yuri Zaporogets.
;*******************************************************************************

.386
Ideal

; --- Definitions ---

BOOTSEG		EQU	7C0h
CONFIGSEG	EQU	50h
KERNELSEG	EQU	100h

struc tMasterBlock
 JmpCOP		DB	?
 JmpOfs		DB	?
 ID		DB	10 dup (?)
 BootProg	DB	20 dup (?)
 Ver		DD	?
 NumBAMs	DD	?
 KBperBAM	DD	?
 RootDir	DD	?
 LoaderOfs	DD	?		; Offset from begin of partition to
					; system loader (in sectors)
 LoaderSize	DD	?		; Size of system loader (in sectors)
ends


segment CODE public 'CODE'
assume CS:CODE, DS:CODE, ES:CODE, SS:CODE
org 0

label Boot near
Header		tMasterBlock < 0EBh,(size tMasterBlock)-2,\
				"RFS 01.00 ",\
				"system_loader       ",\
				1,0,0,0,0,0 >

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
UpSeg		DW	?

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
proc Main near
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
		jc	@ErrInt13

		mov	di,5				; Error counter

@Loop:		mov	ax,[TargSeg]
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
		jnc	short @TrackOK
		xor	ah,ah				; Reset controller
		int	13h
		dec	di				; up to 5 times
		jnz	@Loop
		jmp	short @ErrInt13

@TrackOK:	mov	di,5
		sub	[SectorsInFile],al
		xor	ah,ah
		shl	ax,5
		add	[TargSeg],ax
		mov	[Sector],1
		mov	bx,7
		mov	ax,0E2Eh			; Print dot
		int	10h

		mov	al,[Head]
		cmp	al,[MaxHead]
		je	short @NextCyl
		inc	[Head]
		jmp	short @Check

@NextCyl:	mov	[Head],0
		inc	[Cyl]

@Check:		cmp	[SectorsInFile],0
		jge	@Loop


@Start:		call	StopMotor
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

@ErrInt13:	mov	si,offset MsgErr
		call	WrString

@Halt:		jmp	@Halt

endp		;---------------------------------------------------------------


		; WrString - write ASCIIZ-string.
		; Input: SI=pointer to string.
		; Output: none.
proc WrString near
		cld
@@Loop:		lodsb
		or	al,al
		jz	@@Exit
		mov	ah,0Eh
		xor	bh,bh
		int	10h
		jmp	@@Loop
@@Exit:		ret
endp		;---------------------------------------------------------------


		; StopMotor - stop all FDD motors.
		; Input: none.
		; Output: none.
proc StopMotor near
		mov	dx,03F2h
		xor	al,al
		out	dx,al
		ret
endp		;---------------------------------------------------------------


; --- Data ---

MsgLoading	DB	13,10,"Loading",0
MsgErr		DB	"Int 13h error",0

		DB	174 dup (0)
		DW	0AA55h

ends

end Boot
