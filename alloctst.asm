.386c

include sysdefs.ah
include errdefs.ah


		org	0

		extrn setvector:	far
                extrn GetIntFN:		far
		extrn IntAllOK:		far
		extrn IntFail:		far

		extrn whexout:		far
		extrn dhexout:		far


; *** Code segment ***
code		segment public 'code' use16
		assume CS:code,DS:SYSVARSEG,ES:SYSVARSEG

start:		jmp begintest

include int12h.asm


		; Load segments
begintest:      cli
		mov	ax,Stack
		mov	ss,ax
 		mov	sp,STACKSIZE
		sti

		mov	ax,SYSVARSEG
		mov	ds,ax

		push	cs
		pop	es

		lea	bx,CS:Int12handler
		mov	al,MEMCTL
		call	setvector

		mov	ax,Z_heap
		cwde
		shl	eax,4
		mov	ebx,eax
		call	SetHeapBot

		call	GetHeapBot
                mov	dword ptr [MM_FstBlAddr],0

		mov	ecx,24
		call	lmalloc
		jnc	Cont0
		call	whexout

Cont0:		mov	ecx,10000h
		call	lmalloc
		jc	Cont1
		call	whexout

		call	lmfree
		jc	Exit
		mov	ax,1
		call	lmfree
		jc	Exit

		call	GetHeapFreeSp

		jmp	Exit


Cont1:		call	lmGetAttr
		jnc	NoErr
		call	whexout
		jmp	Exit

 NoErr:		call	whexout

 Exit:		mov	ax,4C00h
		int	21h

code		ends

SYSVARSEG	segment public 'DATA' use16
		assume ES:SYSVARSEG

; FAT-level I/O system variables (total length: 1536 bytes=1.5 KB)
FT_s_name  		DB MaxFNameLen dup (?)
FT_n_name		DB MaxFNameLen dup (?)
FT_nofile		DB MaxFNameLen dup (?)
FT_updir		DB MaxFNameLen dup (?)

FT_boot			DW ?
FT_marker		DW ?
FT_marker_attrib	DW ?

FT_buffer		DB SectorSize dup (?)
FT_path			DB MaxPathLen dup (?)

FT_reserved		DB 432 dup (?)

FT_NumHD		DB ?		; HDs quantity

FT_HD0ncyl		DW ?		; First HD parameters
FT_HD0nhead		DB ?
FT_HD0nsect		DB ?

FT_HDXparms		DB 14 dup (?)	; Another HDs parameters


; Memory management system variables (length: 1024 bytes=1 KB)
MM_HeapBottom		DD	?		; 32-bit addr of heap bottom
MM_FstBlAddr		DD	?		; 32-bit addr of first block

MM_Reserved		DB 1016 dup (?)

; Another system variables (length: 336 bytes)


SYSVARSEG	ends


; *** Data segment ***
Data		segment 'DATA' use16
Data		ends


; *** Stack segment ***
Stack		segment stack 'STACK' use16
		DB	STACKSIZE dup (0)
Stack		ends

; *** Heap segment ***
Z_heap		segment 'Z_heap' use16
Z_heap		ends

		end start