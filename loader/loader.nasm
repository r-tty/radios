;*******************************************************************************
; loader.nasm - RadiOS boot-time setup.
; Copyright (c) 2000-2002 RET & COM Research.
;*******************************************************************************

%include "boot/bootdefs.ah"
%include "boot/mb_info.ah"
%include "rdm.ah"

%define	KIMGADDR		110000h
%define	KCMDLINE		500h
%define	BUFADDR			800h
%define	KERNELCODEADDR		4000h
%define	MMAPADDR		2000h

section .text

		; Loader entry point
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

%include "cons.nasm"
%include "module.nasm"

		; CopyMMap - copy BIOS memory map to new location.
		; Input: none.
		; Output: none.
proc CopyMMap
		mov	ebx,[MBinfoAddr]
		test	dword [ebx+tMBinfo.Flags],MB_INFO_MEM_MAP
		jz	short .NoMemMap
		mov	esi,[ebx+tMBinfo.MMapAddr]
		mov	edi,MMAPADDR
		mov	[BIOSMemMapAddr],edi
		mov	ecx,[ebx+tMBinfo.MMapLength]
		mov	[BIOSMemMapSize],ecx
		cld
		rep	movsb
		ret
		
.NoMemMap:	xor	eax,eax
		mov	[BIOSMemMapAddr],eax
		mov	[BIOSMemMapSize],eax
		ret
endp		;---------------------------------------------------------------


;--- RDM image manipulations ---------------------------------------------------

		; ImgRead - copy bytes from RDM image.
		; Input: EDI=target address,
		;	 ECX=number of bytes to read
		; Output: none.
proc ImgRead
		mpush	ecx,edx,esi,edi
		mov	esi,[RImgCurrPos]
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
		add	[RImgCurrPos],ecx
		sub	edx,ecx
		jnz	.Loop
.Exit:		mpop	edi,esi,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; Set read position.
		; Input: EBX=new position (from begin).
proc ImgSeek
		push	edx
		mov	edx,[RImgStart]
		add	edx,ebx
		mov	[RImgCurrPos],edx
		pop	edx
		ret
endp		;---------------------------------------------------------------


;--- RDM records handling ------------------------------------------------------

		; Read relocation records and handle it.
		; Also handle BSS record (clear BSS space and initialize
		; 'DrvHlpTableAddr' variable)
proc DoRelocation
		mov	ebx,tRDMmaster_size		; Seek to begin
		call	ImgSeek				; of header
		xor	edx,edx

.Loop:		cmp	edx,[RImgHeaderLen]		; All records handled?
		je	near .Done
		mov	ecx,2				; Read type
		mov	edi,ebp				; and length of record
		call	ImgRead
		movzx	ecx,byte [ebp+1]		; ECX=length
		add	edi,byte 2
		call	ImgRead				; Read rest of record
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
		mov	ebx,[KernelDataSect]
		jmp	.1
.RelocInCode:	mov	ebx,[KernelCodeSect]
.1:		add	ebx,[ebp+tRDMreloc.Ofs]
		mov	eax,[KernelCodeSect]
		mov	cx,[ebp+tRDMreloc.RefSeg]
		or	cx,cx
		jz	.DoReloc
		mov	eax,[KernelDataSect]
		dec	cx
		jz	.DoReloc
		mov	eax,[KernelBSSsect]
.DoReloc:       add	[ebx],eax
		jmp	.Loop

.AllocBSS:	mov	eax,[ebp+tRDM_BSS.Amount]		; Clear BSS area
		mov	ecx,eax
		mov	ebx,[KernelBSSsect]
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
		xor	eax,eax
		mov	[WhatSysCall],al
		mov	[SysCallsFound],al
		mov	eax,[DrvHlpTableAddr]		; Begin address of
		mov	[SysCallRecAddr],eax		; DrvHlp table
		
		mov	ebx,tRDMmaster_size		; Seek to begin
		call	ImgSeek				; of header
		xor	edx,edx

.Loop:		cmp	edx,[RImgHeaderLen]		; All records handled?
		je	near .Done
		mov	ecx,2				; Read type
		mov	edi,ebp				; and length of record
		call	ImgRead
		movzx	ecx,byte [ebp+1]		; ECX=length
		add	edi,byte 2
		call	ImgRead				; Read rest of record
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
		add	eax,[KernelCodeSect]		; address of kernel
		mov	[KernelEntryPoint],eax		; entry point
		jmp	.Loop

.IsSysCall:	cmp	byte [ebp+tRDMexport.Seg],0	; Only code section
		jne	.Loop				; entries can be syscalls
		mov	eax,[KernelCodeSect]		; Add address of
		add	[ebp+tRDMexport.Ofs],eax	; code section

		sub	byte [ebp+tRDMexport.RecLen],4	; Adjust record length
		sub	ecx,byte 10			; because function name
		mov	esi,ebp				; will be cut
		mov	edi,[SysCallRecAddr]		; (4 bytes is a length
		push	ecx				; of 'xxx_' and 6 bytes
		movsd					; flags+seg+offset occupy)
		movsd					; Copy type,reclen,flags, and offset
		add	esi,byte 4			; Copy function name
		rep	movsb				; without 'xxx_'
		mov	byte [edi],0
		pop	ecx
		add	ecx,byte 8			; +type, reclen, flags, seg
		add	[SysCallRecAddr],ecx		; and offset length
		jmp	.Loop

.ModName:	lea	esi,[ebp+tRDM_ModName.ModName]	; Analyse module name
		mov	edi,TxtSyscall			; Begins with "$syscall"?
		mov	cl,8
		cld
		repe	cmpsb
		jz	.SysCallModule			; Yes, handle record
		cmp	byte [WhatSysCall],0		; All syscalls handled?
		je	near .Loop			; No, continue
		inc	dword [SysCallRecAddr]		; Else mark end of
		mov	byte [WhatSysCall],0		; syscalls table
		mov	byte [SysCallsFound],1		; And set flag they here
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

.Done:		xor	eax,eax
		cmp	[SysCallsFound],al
		jne	short .SysCallsBuilt
		mov	dword [DrvHlpTableAddr],eax
		mov	dword [UserAPIsTableAddr],eax
.SysCallsBuilt:	mov	eax,[SysCallRecAddr]
		inc	eax
		mov	[KernelFreeMemStart],eax
		movzx	eax,word [BDA(BaseMemSize)]	; BIOS size of base mem
		shl	eax,10
		mov	[KernelFreeMemEnd],eax
		ret
endp		;---------------------------------------------------------------


;--- Main procedure ------------------------------------------------------------

proc Start
		mov	esp,BUFADDR+800h		; Stack size = 2K
		mov	ebp,BUFADDR			; EBP always store BUFADDR

		mov	dword [RImgStart],KIMGADDR	; Set address of kernel
		mov	dword [RImgCurrPos],KIMGADDR	; image

		xor	eax,eax
		mov	[MBinfoAddr],eax
		cmp	edx,MULTIBOOT_VALID		; Multiboot loader?
		jne	short .ReadKernHdr
		mov	[MBinfoAddr],ebx		; Store address of MB info
		
		mov	esi,[ebx+tMBinfo.CmdLine]	; Copy kernel cmdline
		mov	edi,KCMDLINE
		call	CopyCmdLine
		
		test	dword [ebx+tMBinfo.Flags],MB_INFO_MEMORY
		jz	short .NoMemInfo
		mov	eax,[ebx+tMBinfo.MemLower]
		mov	[LowerMemSizeKB],eax
		mov	eax,[ebx+tMBinfo.MemUpper]
		mov	[UpperMemSizeKB],eax
		jmp	short .PrepMods
		
.NoMemInfo:	xor	eax,eax
		mov	[LowerMemSizeKB],eax
		mov	[UpperMemSizeKB],eax
		
.PrepMods:	call	ModPrepare			; Prepare modules
		call	CopyMMap			; Copy BIOS MMap
		
.ReadKernHdr:	mov	edi,ebp
		mov	cl,tRDMmaster_size		; Read master header
		call	ImgRead

		mov	esi,TxtRDOFF2			; Check its signature
		mov	cl,6
		cld
		repe	cmpsb
		jnz	near .ErrBadRDM

		mov	ebx,[ebp+tRDMmaster.HdrLen]	; Seek to code header
		mov	[RImgHeaderLen],ebx
		add	ebx,byte tRDMmaster_size
		call	ImgSeek

		mov	edi,ebp				; Load code section header
		mov	cl,tRDMsegHeader_size
		call	ImgRead

		call	ConsInit			; Initialize console
		mov	esi,MsgBuildKrnl		; Print message
		call	PrintStr
		mov	eax,KERNELCODEADDR		; and code address
		mov	edi,eax
		call	PrintDwordHex

		mov	[KernelCodeSect],edi
		mov	ecx,[ebp+tRDMsegHeader.Length]	; Load code section
		call	ImgRead

		push	ecx				; Load data header
		mov	edi,ebp
		mov	ecx,tRDMsegHeader_size
		call	ImgRead
		pop	edi
		add	edi,KERNELCODEADDR
		add	edi,byte 15			; Align by paragraph
		and	edi,0FFF0h

		mov	esi,MsgData			; Print message
		call	PrintStr
		mov	eax,edi				; and data address
		call	PrintDwordHex

		mov	[KernelDataSect],edi
		mov	ecx,[ebp+tRDMsegHeader.Length]	; Load data section
		call	ImgRead

		add	edi,ecx				; Count BSS address
		mov	[KernelBSSsect],edi
		mov	esi,MsgBSS
		call	PrintStr
		mov	eax,edi
		call	PrintDwordHex
		mov	esi,MsgBracket
		call	PrintStr
		
		call	DoRelocation
		call	BuildSysCallTable
		
		mov	dword [LoaderServiceEntryPoint],ServiceEntry
		
		mov	eax,[KernelEntryPoint]
		or	eax,eax
		jz	short .ErrNoStart
		jmp	eax
		

.ErrBadRDM:	mov	esi,MsgBadRDM
		jmp	.FatalErr
		
.ErrNoStart:	mov	esi,MsgNoKernStart
		jmp	.FatalErr
		
.FatalErr:	mov	byte [Color],12
		push	esi
		mov	esi,MsgFatal
		call	PrintStr
		pop	esi
		call	PrintStr
.Halt:		jmp	$		
endp		;---------------------------------------------------------------


; --- Data ---

section .data

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
MsgBracket	DB	"h)",10,10,0

MsgFatal	DB	"FATAL:",0
MsgBadRDM	DB	" invalid RDM signature",10,0
MsgNoKernStart	DB	" no kernel start entry",10,0

TxtRDOFF2	DB	"RDOFF2"
TxtStart	DB	"Start",0
TxtSyscall	DB	"$syscall"
TxtDrvHlp	DB	".drvhlp"
TxtUser		DB	".user"

; --- Variables ---

section .bss

MBinfoAddr		RESD	1	; Address of multiboot information

RImgStart		RESD	1	; Address of loaded RDM image
RImgSize		RESD	1	; RDM image size
RImgCurrPos		RESD	1	; Current read position in RDM image
RImgHeaderLen		RESD	1	; Length of RDM image header

KernelEntryPoint	RESD	1	; Start entry

; Used by 'BuildSysCallTable'
SysCallRecAddr		RESD	1	; Address of syscall record being built
WhatSysCall		RESB	1	; 1=DrvHlp, 2=user
SysCallsFound		RESB	1	; 1 if any syscalls found