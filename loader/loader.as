;*******************************************************************************
;  loader.as - load kernel in base memory and parse kernel options.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

%include "rdm.ah"
%include "mb_info.ah"

%define DrvHlpTableAddr		700h
%define	UserAPIsTableAddr	704h
%define	KernelHeapBegin		708h
%define	KernelHeapEnd		70Ch
%define BootModulesListAddr	710h

%define	KIMGADDR		110000h
%define	BUFADDR			800h
%define	KERNELCODEADDR		1000h

%define MODLIST			600h			; Module list begin addr
%define MAXMODULES		16			; Max. number of modules

section .text
bits 32

		lgdt	[GDTaddrLim]
		mov	edx,eax				; Keep MB magic value
		xor	eax,eax
		mov	al,10h
		mov	ds,eax
		mov	es,eax
		mov	fs,eax
		mov	gs,eax
		mov	ss,eax
		jmp	Start
		
;--- Miscellaneous routines ----------------------------------------------------

%include "util.as"
		
		; PrintChar - print character (direct in video memory).
		; Input: AL=character.
proc PrintChar
		mpush	ebx,ecx,esi
		mov	cl,al
		mov	ebx,0B8000h
		add	bx,[44Eh]			; BX=Video page offset
		movzx	esi,byte [462h]			; SI=active video page
		shl	esi,1
		cmp	cl,0Ah
		je	.LF
		xor	eax,eax
		mov	al,[esi+450h]			; AL=cursor column
		cmp	al,80
		jb	.NoLF
		inc	byte [esi+451h]
		xor	al,al
		mov	byte [esi+450h],al
.NoLF		shl	al,1
		add	ebx,eax
		mov	al,[esi+451h]			; AL=cursor row
		shl	eax,byte 5
		lea	eax,[eax*4+eax]			; Row*=160
		add	ebx,eax
		mov	ch,15				; White color
		mov	[ebx],cx
		inc	byte [esi+450h]
		jmp	short .Done
.LF:		inc	byte [esi+451h]
		mov	byte [esi+450h],0
.Done:		mpop	esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; PrintStr - print ASCIIZ string.
		; Input: ESI=pointer to string.
proc PrintStr
		push	esi
		cld
.Loop:		lodsb
		or	al,al
		jz	.Done
		call	PrintChar
		jmp	.Loop
.Done:		pop	esi
		ret
endp		;---------------------------------------------------------------


;--- Kernel image manipulations ------------------------------------------------

		; kimg_read - read from "pseudo-file" of the kernel image.
		; Input: EDI=target address,
		;	 ECX=number of bytes to read
		; Output: none.
proc kimg_read
		mpush	ecx,edx,esi,edi
		mov	esi,[KImgCurrPos]
		mov	edx,ecx
		mov	ecx,10000h

.Loop:		cmp	edx,ecx
		ja	.Read
		mov	ecx,edx
.Read		push	ecx
		shr	ecx,byte 1
		jnc	.Even
		inc	ecx
.Even:		cld
		rep	movsw
		pop	ecx
		add	[KImgCurrPos],ecx
		sub	edx,ecx
		jnz	.Loop
.Exit:		mpop	edi,esi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; Set read position.
		; Input: EBX=new position (from begin).
proc kimg_seek
		push	edx
		mov	edx,[KImgStart]
		add	edx,ebx
		mov	[KImgCurrPos],edx
		pop	edx
		ret
endp		;---------------------------------------------------------------


;--- RDM records handling ------------------------------------------------------

		; Read relocation records and handle it.
		; Also handle BSS record (clear BSS space and initialize
		; 'DrvHlpTableAddr' variable)
proc DoRelocation
		mov	ebx,tRDMmaster_size		; Seek to begin
		call	kimg_seek			; of header
		xor	edx,edx

.Loop:		cmp	edx,[KImgHeaderLen]		; All records handled?
		je	near .Done
		mov	ecx,2				; Read type
		mov	edi,ebp				; and length of record
		call	kimg_read
		movzx	ecx,byte [ebp+1]		; ECX=length
		add	edi,byte 2
		call	kimg_read			; Read rest of record
		add	edx,byte 2
		add	edx,ecx
		mov	al,[ebp]			; AL=type
		cmp	al,RDMREC_Reloc
		je	.Reloc
		cmp	al,RDMREC_BSS
		je	.AllocBSS
		jmp	.Loop

.Reloc:		mov	al,[ebp+tRDMreloc.Seg]
		cmp	al,2
		jae	.Loop
		or	al,al
		je	.RelocInCode
		mov	ebx,[DataSectAddr]
		jmp	.1
.RelocInCode:	mov	ebx,[CodeSectAddr]
.1:		add	ebx,[ebp+tRDMreloc.Ofs]
		mov	eax,[CodeSectAddr]
		mov	cx,[ebp+tRDMreloc.RefSeg]
		or	cx,cx
		jz	.DoReloc
		mov	eax,[DataSectAddr]
		dec	cx
		jz	.DoReloc
		mov	eax,[BSSsectAddr]
.DoReloc:       add	[ebx],eax
		jmp	.Loop

.AllocBSS:	mov	eax,[ebp+tRDM_BSS.Amount]		; Clear BSS area
		mov	ecx,eax
		mov	ebx,[BSSsectAddr]
		add	eax,ebx
		mov	[DrvHlpTableAddr],eax
		mov	edi,ebx
		xor	eax,eax
		cld
		rep	stosb
		jmp	.Loop

.Done:		ret
endp		;---------------------------------------------------------------


		; Build system calls table.
proc BuildSysCallTable
		mov	dword [WhatSysCall],0
		mov	eax,[DrvHlpTableAddr]		; Begin address of
		mov	[SysCallRecAddr],eax		; DrvHlp table
		
		mov	ebx,tRDMmaster_size		; Seek to begin
		call	kimg_seek			; of header
		xor	edx,edx

.Loop:		cmp	edx,[KImgHeaderLen]		; All records handled?
		je	near .Done
		mov	ecx,2				; Read type
		mov	edi,ebp				; and length of record
		call	kimg_read
		movzx	ecx,byte [ebp+1]		; ECX=length
		add	edi,byte 2
		call	kimg_read			; Read rest of record
		add	edx,byte 2
		add	edx,ecx
		mov	al,[ebp]			; AL=record type
		cmp	al,RDMREC_Export
		je	.Export
		cmp	al,RDMREC_ModName
		je	.ModName
		jmp	.Loop

.Export:	cmp	byte [WhatSysCall],0		; SysCall type set?
		jne	.IsSysCall			; Yes, handle it
		lea	esi,[ebp+tRDMexport.Lbl]
		mov	edi,TxtStart			; Start entry point?
		mov	cx,6
		repe	cmpsb
		jnz	.Loop				; No, continue
		mov	eax,[ebp+tRDMexport.Ofs]	; Else count physical
		add	eax,[CodeSectAddr]		; address of kernel
		mov	[KernelEntryPoint],eax		; entry point
		jmp	.Loop

.IsSysCall:	cmp	byte [ebp+tRDMexport.Seg],0	; Only code section
		jne	.Loop				; entries can be syscalls
		mov	eax,[CodeSectAddr]		; Add address of
		add	[ebp+tRDMexport.Ofs],eax	; code section

		sub	byte [ebp+tRDMexport.RecLen],5	; Adjust record length
		sub	ecx,byte 10			; because function name
		mov	esi,ebp				; will be cut
		mov	edi,[SysCallRecAddr]		; (5 bytes is a length
		push	ecx				; of 'xxxx_' and 5 bytes
		movsd					; seg & offset occupy)
		movsd					; Copy type,reclen,seg
		dec	edi				; and offset
		add	esi,byte 4			; Copy function name
		rep	movsb				; without 'xxxx_'
		mov	byte [edi],0
		pop	ecx
		add	ecx,byte 7			; +type, reclen, seg
		add	[SysCallRecAddr],ecx		; and offset length
		jmp	.Loop

.ModName:	lea	esi,[ebp+tRDM_ModName.ModName]	; Analyse module name
		mov	edi,TxtSyscall			; Begins with "syscall"?
		mov	cl,7
		cld
		repe	cmpsb
		jz	.SysCallModule			; Yes, handle record
		cmp	byte [WhatSysCall],0		; All syscalls handled?
		je	near .Loop			; No, continue
		inc	dword [SysCallRecAddr]		; Else mark end of
		mov	byte [WhatSysCall],0		; syscalls table
		jmp	.Loop

.SysCallModule:	mov	edi,TxtDrvHlp			; Driver helper?
		mov	cl,7
		push	esi
		repe	cmpsb
		pop	esi
		jz	.DriverHelper
		mov	edi,TxtUser			; User API?
		mov	cl,5
		repe	cmpsb
		jnz	near .Loop

		mov	byte [WhatSysCall],2		; Set user API type
		inc	dword [SysCallRecAddr]
		mov	eax,[SysCallRecAddr]
		mov	[UserAPIsTableAddr],eax		; Set begin of
		dec	eax				; user API table
		cmp	eax,[DrvHlpTableAddr]
		jne	near .Loop			; DrvHlp table empty?
		mov	dword [DrvHlpTableAddr],0	; Else set DrvHlp
		jmp	.Loop				; table address to 0

.DriverHelper:	mov	byte [WhatSysCall],1		; Set syscall type
		jmp	.Loop

.Done:		mov	eax,[SysCallRecAddr]
		inc	eax
		mov	[KernelHeapBegin],eax
		mov	ax,[413h]
		shl	eax,10
		mov	[KernelHeapEnd],eax
		ret
endp		;---------------------------------------------------------------


;--- Main procedure ------------------------------------------------------------

proc Start
		mov	esp,BUFADDR+800h		; Stack size = 2K
		mov	ebp,BUFADDR			; EBP always store BUFADDR

		mov	dword [KImgStart],KIMGADDR	; Set address of kernel
		mov	dword [KImgCurrPos],KIMGADDR	; image

		xor	eax,eax
		mov	[MBinfoAddr],eax
		cmp	edx,MULTIBOOT_VALID		; Multiboot loader?
		jne	short .CopySCfg
		mov	[MBinfoAddr],ebx		; Store address of MB info
		
		; Check whether bootable modules are loaded
		test	dword [ebx+tMBinfo.Flags],MB_INFO_MODS
		jz	short .NoModules
		mov	al,[ebx+tMBinfo.ModsCount]
		cmp	al,MAXMODULES			; No more than 16 mods
		jbe	.NumModsOK
		mov	al,MAXMODULES
.NumModsOK:	mov	[sNumMods],al
		or	al,al
		jz	.NoModules
		
		; Copy module list to new location
		shl	al,2				; Assumes tModList_size
		movzx	ecx,al
		mov	esi,[ebx+tMBinfo.ModsAddr]
		mov	edi,MODLIST
		cld
		rep	movsd
		
.NoModules:
		
.CopySCfg:	mov	esi,StartupCfg			; Move startup config
		mov	edi,500h			; table to 500h
		xor	ecx,ecx
		mov	cl,40h
		cld
		rep	movsd

		mov	edi,ebp
		mov	cl,tRDMmaster_size		; Read master header
		call	kimg_read

		mov	esi,TxtRDOFF2
		mov	cl,6
		cld
		repe	cmpsb
		jnz	near .Err1

		mov	ebx,[ebp+tRDMmaster.HdrLen]	; Seek to code header
		mov	[KImgHeaderLen],ebx
		add	ebx,byte tRDMmaster_size
		call	kimg_seek

		mov	edi,ebp				; Load code section header
		mov	cl,tRDMsegHeader_size
		call	kimg_read

		mov	esi,MsgBuildKrnl		; Print message
		call	PrintStr
		mov	eax,KERNELCODEADDR		; and code address
		mov	edi,eax
		call	PrintDwordHex

		mov	[CodeSectAddr],edi
		mov	ecx,[ebp+tRDMsegHeader.Length]	; Load code section
		call	kimg_read

		push	ecx				; Load data header
		mov	edi,ebp
		mov	ecx,tRDMsegHeader_size
		call	kimg_read
		pop	edi
		add	edi,KERNELCODEADDR
		add	edi,byte 15			; Align by paragraph
		and	edi,0FFF0h

		mov	esi,MsgData			; Print message
		call	PrintStr
		mov	eax,edi				; and data address
		call	PrintDwordHex

		mov	[DataSectAddr],edi
		mov	ecx,[ebp+tRDMsegHeader.Length]	; Load data section
		call	kimg_read

		add	edi,ecx				; Count BSS address
		mov	[BSSsectAddr],edi
		mov	esi,MsgBSS
		call	PrintStr
		mov	eax,edi
		call	PrintDwordHex
		mov	esi,MsgBracket
		call	PrintStr
		
		call	DoRelocation
		call	BuildSysCallTable

		jmp	[KernelEntryPoint]
.Halt:		jmp	$

.Err1:		mov	si,MsgErrInvKImg
		call	PrintStr
		jmp	.Halt
endp		;---------------------------------------------------------------


; --- Data ---

section .data

%include "scfg.as"

GDTaddrLim	DW	23				; GDT address and limit
		DD	GDT
GDT		DD	0,0
		DW	0FFFFh,0			; Code segment
		DB	0,9Ah,0CFh,0
		DW	0FFFFh,0			; Data segment
		DB	0,92h,0CFh,0

MsgBuildKrnl	DB	"Building kernel: code (",0
MsgData		DB	"h), data (",0
MsgBSS		DB	"h), bss (",0
MsgBracket	DB	"h)",0

MsgErrInvKImg	DB	"invalid kernel image",0

TxtRDOFF2	DB	"RDOFF2"
TxtStart	DB	"Start",0
TxtSyscall	DB	"syscall"
TxtDrvHlp	DB	".drvhlp"
TxtUser		DB	".user"

TxtRootDev	DB	7,"rootdev"
TxtRootLP	DB	6,"rootlp"
TxtRDsize	DB	6,"rdsize"
TxtBufMem	DB	6,"bufmem"
TxtSwapDev	DB	7,"swapdev"

; --- Variables ---

section .bss

MBinfoAddr		RESD	1	; Address of multiboot information

KImgStart		RESD	1	; Address of loaded kernel image
KImgSize		RESD	1	; Kernel image size
KImgHeaderLen		RESD	1	; Length of kernel image header
KImgCurrPos		RESD	1	; Current read position in kernel image

CodeSectAddr		RESD	1	; Address of code (text) section
DataSectAddr		RESD	1	; Data section address
BSSsectAddr		RESD	1	; BSS address

KernelEntryPoint	RESD	1

; Used by 'BuildSysCallTable'
WhatSysCall		RESD	1	; 1=DrvHlp, 2=user
SysCallRecAddr		RESD	1	; Address of syscall record being built

