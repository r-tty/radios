		jmp	SCAN

STARTEBX	DD	?
EXPORTFILE	DB	128 dup (?)
EXPFILESZ	DW	?
HANDLE		DW	?

		; Scan command line
SCAN:		push	cs
		pop	ds
		mov	[STARTEBX],ebx
		xor	bx,bx

		cmp	[byte es:bx+81h],0Dh
		je	short MOVESELF

SCLOOP:		mov	al,[es:bx+82h]
		cmp	al,0Dh
		je	short OPENFILE
		mov	[EXPORTFILE+bx],al
		inc	bx
		jmp	SCLOOP

		; Open file
OPENFILE:	mov	ah,3Dh			; Open file
		xor	al,al
		mov	dx,offset EXPORTFILE
		int	21h
		jc	short MOVESELF
		mov	[HANDLE],ax

		mov	ax,4202h		; Move FPTR to EOF
		mov	bx,[HANDLE]
		xor	cx,cx
		xor	dx,dx
		int	21h
		mov	[EXPFILESZ],ax		; AX=file size (<=64K)

		mov	ax,4200h		; Move FPTR to 0
		xor	cx,cx
		xor	dx,dx
		int	21h

		; Load file
		mov	cx,[EXPFILESZ]
		mov	bx,[HANDLE]
		push	8000h
		pop	ds
		mov	dx,2
		mov	ah,3Fh
		int	21h
		mov	[0],ax			; Store file size

		; Close file
		mov	ah,3Eh
		int	21h

		; Move kernel
MOVESELF:	cli
		mov	ebx,[CS:STARTEBX]
		mov	ax,cs				; Move startup code
		mov	ds,ax				; to HMA
		mov	ax,0FFFFh
		mov	es,ax
		mov	si,offset MOVEKERNEL
		mov	di,si
		mov	cx,200h
		cld
		rep	movsb
		DB	0EAh				; Far jump in HMA
		DW	offset MOVEKERNEL
		DW	0FFFFh

MOVEKERNEL:	mov	ax,KCODE			; Move kernel code
		mov	ds,ax				; to 0:1000h
		sub	bx,ax
		mov	ax,100h
		mov	es,ax
		mov	si,1000h
		xor	di,di
		mov	cx,0FFF0h
		cld
		rep	movsb

		mov	ax,cs				; Move startup config
		mov	ds,ax				; to 0:500h
		mov	ax,50h
		mov	es,ax
		mov	si,offset STARTUPCFG
		xor	di,di
		mov	cx,200h
		cld
		rep	movsb
		jmp	ENDMOVE

STARTUPCFG:	DD	SCFG_Signature
		DW	4				; Number of items
		DW	@SCFG0-STARTUPCFG		; Item addresses
		DW	@SCFG1-STARTUPCFG
		DW	@SCFG2-STARTUPCFG
		DW	@SCFG3-STARTUPCFG
		DW	@SCFG4-STARTUPCFG

@SCFG0:		DB	"%ramdisk",0			; Root device
@SCFG1:		DB	"F:",0				; Root linkpoint
@SCFG2:		DW	1440				; RAM-disk size
@SCFG3:		DW	512				; Buffers memory (KB)
@SCFG4:		DB	0				; Swap device

ENDMOVE: