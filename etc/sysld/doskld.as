;*******************************************************************************
;  doskld.as - load kernel file into XM (using BIOS int 15h).
;  (c) 1999 RET & COM Research.
;*******************************************************************************

%include "biosxma.ah"

; --- Definitions ---

%define	BUFADDR		0x7000
%define	BUFSIZE		0x8000

%define KERNELADDR	0x110000

; --- Imports ---

extern rld_start, StartupCfg, PrintStr, Error
extern KernelAddress, KernelSize
extern ValDwordHex


; --- Code ---

section .text
bits 16

begin:		jmp	Start

		; ScanEnv - search 'INT15' variable in the environment.
		; Input: none.
		; Output: EAX=original INT15h handler address or 0.
proc ScanEnv
		mov	ax,[2Ch]
		mov	es,ax
		push	cs
		pop	ds
		xor	di,di
		cld

.Loop:		xor	al,al
		mov	cx,8000h
		push	di
		repne	scasb
		mov	dx,di
		pop	di

		mov	si,Int15var
		mov	cx,6
		repe	cmpsb
		jz	.Found

		mov	di,dx
		cmp	byte [es:di],0
		je	.NotFound
		jmp	.Loop

.Found:		push	es
		pop	ds
		mov	si,di
		call	ValDwordHex

.Done:		mov	dx,cs
		mov	ds,dx
		mov	es,dx
		ret

.NotFound:	xor	eax,eax
		jmp	.Done
endp		;---------------------------------------------------------------


		; ScanCmdLine - scan command line.
		; Input: none.
		; Output: none.
proc ScanCmdLine
		mov	word [KernelFileName],DfltKFile
		mov	[KernelFileName+2],ds
		mov	dword [ExportFileName],0

		mov	bx,82h
		cmp	byte [es:bx-1],0Dh
		je	.Done
		mov	[KernelFileName],bx
		mov	[KernelFileName+2],es

.Loop:		mov	al,[es:bx]
		cmp	al,' '
		je	.ExpFile
		cmp	al,0Dh
		je	.Done
		inc	bx
		jmp	.Loop

.ExpFile:	mov	byte [es:bx],0
		inc	bx
		mov	[ExportFileName],bx
		mov	[ExportFileName+2],es
		jmp	.Loop
.Done:		mov	byte [es:bx],0
		ret
endp		;---------------------------------------------------------------


		; GetFileLen - get file length.
		; Input: BX=file handle.
		; Output: ECX=file length.
proc GetFileLen
		mov	ax,4202h		; Move FPTR to EOF
		xor	cx,cx
		xor	dx,dx
		int	21h
		push	dx			; DX:AX=file length
		push	ax
		mov	ax,4200h		; Move FPTR to 0
		xor	cx,cx
		xor	dx,dx
		int	21h
		pop	ecx			; Get file length
		ret
endp		;---------------------------------------------------------------


		; Load kernel into XM.
		; Input: none.
		; Output: CF=0 - OK, EBX=address of loaded kernel;
		;	  CF=1 - error.
proc LoadKernel
		lds	dx,[KernelFileName]
		mov	ax,3D00h
		int	21h
		push	cs
		pop	ds
		jc	near Err1
		mov	bx,ax				; Keep file handle

		call    GetFileLen
		mov	[KernelSize],ecx

		xor	eax,eax
		mov	ah,88h
		int	15h
		shl	eax,10
		cmp	eax,[KernelSize]
		jb	near Err3

		xor	eax,eax
		mov	di,BIOSGDT
		mov	cx,NumBIOSdesc*tDescriptor_size/4
		cld
		rep	stosd
		not	ax
		mov	word [BIOSGDT+DescSrc+tDescriptor.Lim],ax
		mov	word [BIOSGDT+DescTarg+tDescriptor.Lim],ax
		mov	eax,ds
		shl	eax,4
		add	eax,BUFADDR+(DescARs<<24)
		mov	[BIOSGDT+DescSrc+tDescriptor.BaseAndARs],eax
		mov	eax,KERNELADDR+(DescARs<<24)
		mov	[BIOSGDT+DescTarg+tDescriptor.BaseAndARs],eax
		push	cs
		pop	es
		mov	dx,BUFADDR

.Loop:		mov	cx,BUFSIZE
		mov	ah,3Fh
		int	21h
		jc	Err2
		mpush	ax,bx
		shr	ax,1
		inc	ax
		mov	cx,ax
		mov	si,BIOSGDT
		mov	ah,87h
		int	15h
		mpop	bx,ax
		jc	Err4
		movzx	eax,ax
		add	[BIOSGDT+DescTarg+tDescriptor.BaseAndARs],eax
		cmp	ax,BUFSIZE
		je	.Loop

		mov	ah,3Eh				; Close file
		int	21h

.OK:		clc
		mov	dword [KernelAddress],KERNELADDR
		ret

Err1:		mov	si,MsgErrOpen
		jmp	Err

Err2:		mov	si,MsgErrLoad
		jmp	Err

Err3:		mov	si,MsgErrNoXM
		jmp	Err

Err4:		mov	si,MsgErrXMaccess
Err:		call	PrintStr
		stc
Done:		ret
endp		;---------------------------------------------------------------


		; Load exported file (if specified) at (ConvMemTop)-64K
proc LoadExpFile
		cmp	dword [ExportFileName],0
		je	Done
		lds	dx,[ExportFileName]
		mov	ax,3D00h
		int	21h
		push	cs
		pop	ds
		jc	Err1
		mov	bx,ax				; Keep file handle

		call	GetFileLen
		mov	[ExpFileSize],cx
		shr	ecx,4
		inc	cx
		xchg	bx,cx
		mov	ah,48h				; Allocate memory
		int	21h
		xchg	bx,cx
		jc	.Err5
		mov	cx,[ExpFileSize]
		mov	ds,ax
		xor	dx,dx
		mov	ah,3Fh
		int	21h
		jc	Err2

		mov	ah,3Eh				; Close file
		int	21h

		xor	eax,eax				; Get amount
		int	12h				; of conventional
		shl	eax,10				; memory (in KB)
		sub	eax,10000h			; Up to 64 KB
		shr	eax,4
		mov	es,ax

		cli
		cld
		xor	si,si
		xor	di,di
		mov	ax,cx
		stosw					; Store file size
		shr	cx,2
		inc	cx
		rep	movsd

		mov	ax,cs				; Restore segment regs
		mov	ds,ax
		mov	es,ax
		clc
		ret

.Err5:		mov	si,MsgErrNoDosMem
		jmp	Error
endp		;---------------------------------------------------------------


		; Startup routine.
proc Start
		mov	ax,3				; Clear screen
		int	10h

		smsw	ax				; Check whether we are
		test	al,1				; in real mode
		jz	.RM
                mov	si,MsgNotInRM
                call	PrintStr
		jmp	short .Exit

.RM:		mov	bx,400h				; 16K is larger
		mov	ah,4Ah				; than program size
		int	21h
		call	ScanEnv				; Scan environment
		mov	[Int15handler],eax
.ScanCmdLn:	call	ScanCmdLine
		call	LoadKernel
		jc	.Exit
		call	LoadExpFile
		jc	.Exit

		mov	si,StartupCfg			; Move startup config
		mov	ax,50h				; table to 50h:0
		mov	es,ax
		xor	di,di
		mov	cx,40h
		cld
		cli
		rep	movsd

		mov	al,255				; Disable all IRQs
		out	21h,al
		jmp	short $+2
		out	0A1h,al

		mov	eax,[Int15handler]
		or	eax,eax
		jz	.Go
		push	byte 0
		pop	fs
		mov	dword [fs:15h*4],eax

.Go:		call	rld_start

.Exit:		mov	ax,4C01h
		int	21h
endp		;---------------------------------------------------------------


; --- Data ---

section .data

Int15var	DB	"INT15="
DfltKFile	DB	"main.rdx",0
MsgNotInRM	DB	"not in real mode",0
MsgErrOpen	DB	"error opening file",0
MsgErrLoad	DB	"error loading file",0
MsgErrNoXM	DB	"not enough extended memory",0
MsgErrXMaccess	DB	"error accessing extended memory",0
MsgErrNoDosMem	DB	"not enough memory for export file",0


; --- Variables ---

section .bss

KernelFileName	RESD	1			; Far pointer to kernel file name
ExportFileName	RESD	1			; Far pointer to exporting file name
ExpFileSize	RESW	1			; Exported file size
Int15handler	RESD	1			; Original int 15h handler

BIOSGDT		istruc	tBIOSGDT iend		; GDT for int 15h
