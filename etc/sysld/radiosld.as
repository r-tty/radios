;*******************************************************************************
;  radiosld.as - RadiOS kernel loading routines.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

%include "rdm.ah"
%include "biosxma.ah"

%define DrvAPIsTableAddr	700h
%define	UserAPIsTableAddr	704h
%define	KernelHeapBegin		708h
%define	KernelHeapEnd		70Ch

%define	BUFADDR			800h
%define	GDTSEG			90h
%define	KERNELCODEADDR		1000h


; --- Exports ---

global PrintChar, PrintStr, Error
global rld_start
global KernelAddress,KernelSize


; --- Imports ---

extern PrintDwordHex


; --- Code ---

section .text
bits 16

; --- Generic routines ---------------------------------------------------------

		; PrintChar - print character (direct in video memory).
		; Input: AL=character.
proc PrintChar
		mpush	ds,es,bx,cx,si
		mov	cl,al
		mov	ax,40h
		mov	ds,ax
		mov	ax,0B800h
		mov	es,ax
		mov	bx,[4Eh]			; BX=Video page offset
		movzx	si,byte [62h]			; SI=active video page
		shl	si,1
		cmp	cl,0Ah
		je	.LF
		xor	eax,eax
		mov	al,[si+50h]			; AL=cursor column
		shl	al,1
		add	bx,ax
		mov	al,[si+51h]			; AL=cursor row
		shl	ax,5
		lea	eax,[eax*4+eax]			; Row*=160
		add	bx,ax
		mov	ch,15				; White color
		mov	[es:bx],cx
		inc	byte [si+50h]
		jmp	short .Done
.LF:		inc	byte [si+51h]
		mov	byte [si+50h],0
.Done:		mpop	si,cx,bx,es,ds
		ret
endp		;---------------------------------------------------------------


		; PrintStr - print ASCIIZ string.
		; Input: DS:SI=pointer to string.
proc PrintStr
		cld
.Loop:		lodsb
		or	al,al
		jz	.Done
		call	PrintChar
		jmp	.Loop
.Done:		ret
endp		;---------------------------------------------------------------


		; Error - print error message and halt.
		; Input: CS:SI=pointer to message.
		; Output: none.
proc Error
		push	cs
		pop	ds
                call	PrintStr
		jmp	$
endp		;---------------------------------------------------------------


		; Convert linear address (EBX) into seg:offs (ES:DI)
proc Linear2Seg
		mov	edi,ebx
		ror	edi,4
		mov	es,di
		shr	edi,28
		ret
endp		;---------------------------------------------------------------


; --- Routines to read kernel from XM via int 15h ------------------------------

		; kOpen -  open kernel image in XM.
		; Input: none.
		; Output: none.
proc kOpen
		push	es
		mov	ax,GDTSEG
		mov	es,ax
		xor	di,di
		xor	eax,eax
		mov	cx,NumBIOSdesc*tDescriptor_size/4
		cld
		rep	stosd
		not	ax
		mov	word [es:DescSrc+tDescriptor.Lim],ax
		mov	byte [KernelAddress+3],DescARs
		mov	ebx,[KernelAddress]
		mov	[es:DescSrc+tDescriptor.BaseAndARs],ebx
		mov	[es:DescTarg+tDescriptor.Lim],ax
		pop	es
		ret
endp		;---------------------------------------------------------------


		; kRead - read kernel from XM.
		; Input: EDI=address,
		;	 ECX=number of bytes to read
		; Output: CF=0 - OK;
		;	  CF=1 - error, AL=error code.
proc kRead
		mpush	ecx,edx,es
		mov	ax,GDTSEG
		mov	es,ax
		mov	[es:DescTarg+tDescriptor.BaseAndARs],edi
		mov	byte [es:DescTarg+tDescriptor.BaseAndARs+3],DescARs
		xor	si,si
		mov	edx,ecx
		mov	ecx,10000h

.Loop:		cmp	edx,ecx
		ja	.Read
		mov	ecx,edx
.Read		push	ecx
		shr	ecx,byte 1
		jnc	.Even
		inc	cx
.Even:		mov	ah,87h
		int	15h
		cli
		pop	ecx
		jc	.Exit
		add	[es:DescSrc+tDescriptor.BaseAndARs],ecx
		add	[es:DescTarg+tDescriptor.BaseAndARs],ecx
		sub	edx,ecx
		jnz	.Loop
.Exit:		mpop	es,edx,ecx
		ret
endp		;---------------------------------------------------------------


		; Set read position.
		; Input: EBX=new position (from begin).
proc kSetFPos
		mpush	edx,es
		mov	ax,GDTSEG
		mov	es,ax
		mov	edx,[KernelAddress]
		add	edx,ebx
		mov	[es:DescSrc+tDescriptor.BaseAndARs],edx
		mpop	es,edx
		ret
endp		;---------------------------------------------------------------


;--- RDM records handling ------------------------------------------------------

		; Read relocation records and handle it.
		; Also handle BSS record (clear BSS space and initialize
		; 'DrvAPIsTableAddr' variable)
proc DoRelocation
		mov	ebx,tRDMmaster_size		; Seek to begin
		call	kSetFPos			; of header
		xor	edx,edx

.Loop:		cmp	edx,[KernelHeaderLen]		; All records handled?
		je	near .Done
		mov	ecx,2				; Read type
		mov	edi,BUFADDR			; and length of record
		call	kRead
		movzx	ecx,byte [gs:1]			; ECX=length
		add	di,2
		call	kRead				; Read rest of record
		add	edx,byte 2
		add	edx,ecx
		mov	al,[gs:0]			; AL=type
		cmp	al,RDMREC_Reloc
		je	.Reloc
		cmp	al,RDMREC_BSS
		je	.AllocBSS
		jmp	.Loop

.Reloc:		mov	al,[gs:tRDMreloc.Seg]
		cmp	al,2
		jae	.Loop
		or	al,al
		je	.RelocInCode
		mov	ebx,[DataSectAddr]
		jmp	.1
.RelocInCode:	mov	ebx,[CodeSectAddr]
.1:		add	ebx,[gs:tRDMreloc.Ofs]
		mov	eax,[CodeSectAddr]
		mov	cx,[gs:tRDMreloc.RefSeg]
		or	cx,cx
		jz	.DoReloc
		mov	eax,[DataSectAddr]
		dec	cx
		jz	.DoReloc
		mov	eax,[BSSsectAddr]
.DoReloc:       push	es
		call	Linear2Seg
		add	[es:di],eax
		pop	es
		jmp	.Loop


.AllocBSS:	mov	eax,[gs:tRDM_BSS.Amount]		; Clear BSS area
		mov	ecx,eax
		mov	ebx,[BSSsectAddr]
		add	eax,ebx
		mov	[fs:DrvAPIsTableAddr],eax
		push	es
		call	Linear2Seg
		xor	eax,eax
		cld
		rep	stosb
		pop	es
		jmp	.Loop

.Done:		ret
endp		;---------------------------------------------------------------


		; Build APIs symbol table.
proc BuildAPItable
%define	.WhatAPI	bp-2				; 1=driver, 2=user
%define	.APIrecAddr	bp-6

		enter	6,0
		mov	byte [.WhatAPI],0		; APi type = 0
		mov	eax,[fs:DrvAPIsTableAddr]	; Begin address of
		mov	[.APIrecAddr],eax		; driver API table

		mov	ebx,tRDMmaster_size		; Seek to begin
		call	kSetFPos			; of header
		xor	edx,edx

.Loop:		cmp	edx,[KernelHeaderLen]		; All records handled?
		je	near .Done
		mov	ecx,2				; Read type
		mov	edi,BUFADDR			; and length of record
		call	kRead
		movzx	ecx,byte [gs:1]			; ECX=length
		add	di,2
		call	kRead				; Read rest of record
		add	edx,byte 2
		add	edx,ecx
		mov	al,[gs:0]			; AL=record type
		cmp	al,RDMREC_Export
		je	.Export
		cmp	al,RDMREC_ModName
		je	.ModName
		jmp	.Loop

.Export:	cmp	byte [.WhatAPI],0		; API type set?
		jne	.IsAPI				; Yes, handle it
		mov	si,tRDMexport.Lbl
		mov	di,TxtStart			; Start entry point?
		mov	cx,6
	gs	repe	cmpsb
		jnz	.Loop				; No, continue
		mov	eax,[gs:tRDMexport.Ofs]		; Else count physical
		add	eax,[CodeSectAddr]		; address of kernel
		mov	[KernelEntryPoint],eax		; entry point
		jmp	.Loop

.IsAPI:		cmp	byte [gs:tRDMexport.Seg],0	; Only code section
		jne	.Loop				; entries can be APIs
		mov	eax,[CodeSectAddr]		; Add address of
		add	[gs:tRDMexport.Ofs],eax		; code section

		sub	byte [gs:tRDMexport.RecLen],5	; Adjust record length
		sub	ecx,byte 10			; because function name
		xor	si,si				; will be cut
		mov	ebx,[.APIrecAddr]		; (5 bytes is a length
		mpush	ecx,es				; of '?API-' and 5 bytes
		call	Linear2Seg			; occupies seg & offset)
	gs	movsd					; Copy type,reclen,seg
	gs	movsd					; and offset
		dec	di
		add	si,4				; Copy function name
	gs	rep	movsb				; without '?API_'
		mov	byte [es:di],0
		mpop	es,ecx
		add	ecx,byte 7			; +type, reclen, seg
		add	[.APIrecAddr],ecx		; and offset length
		jmp	.Loop

.ModName:	mov	si,tRDM_ModName.ModName		; Analyse module name
		mov	di,TxtSyscall			; Begins with "syscall"?
		mov	cx,7
		cld
	gs	repe	cmpsb
		jz	.APImodule			; Yes, handle record
		cmp	byte [.WhatAPI],0		; All APIs handled?
		je	near .Loop			; No, continue
		inc	dword [.APIrecAddr]		; Else mark end of
		mov	byte [.WhatAPI],0		; API table
		jmp	.Loop

.APImodule:	mov	di,TxtDrvHlp			; Driver helper?
		mov	cl,7
		push	si
	gs	repe	cmpsb
		pop	si
		jz	.DriverHelper
		mov	di,TxtUser			; User API?
		mov	cl,5
	gs	repe	cmpsb
		jnz	near .Loop

		mov	byte [.WhatAPI],2		; Set user API type
		inc	dword [.APIrecAddr]
		mov	eax,[.APIrecAddr]
		mov	[fs:UserAPIsTableAddr],eax	; Set begin of
		dec	eax				; user API table
		cmp	eax,[fs:DrvAPIsTableAddr]
		jne	near .Loop			; Driver API table empty?
		mov	dword [fs:DrvAPIsTableAddr],0	; Else set driver API
		jmp	.Loop				; table address to 0

.DriverHelper:	mov	byte [.WhatAPI],1		; Set syscall type
		jmp	.Loop

.Done:		mov	eax,[.APIrecAddr]
		inc	eax
		mov	[fs:KernelHeapBegin],eax
		mov	ax,[fs:413h]
		shl	eax,10
		mov	[fs:KernelHeapEnd],eax
		leave
		ret
endp		;---------------------------------------------------------------


;--- Startup and main routines -------------------------------------------------

		; Entry point.
proc rld_start
		mov	si,Banner
		call	PrintStr

		push	cs				; Prepare to move
		pop	ds				; itself to unused
		mov	si,100h				; text video page
		mov	di,si
		mov	ax,0BF00h
		mov	es,ax
		push	es
		push	word rld_main
		mov	cx,1000h			; 16 K
		cld
		rep	movsd
		retf					; To rld_main
endp		;---------------------------------------------------------------


		; Main routine.
proc rld_main
		mov	ax,cs
		mov	ds,ax
		mov	ax,BUFADDR >> 4
		mov	gs,ax				; GS=work area seg.
		mov	ss,ax
		mov	sp,800h				; Stack size = 2K
		xor	ax,ax
		mov	fs,ax				; FS=0

		call	kOpen
		mov	edi,BUFADDR
		mov	ecx,tRDMmaster_size		; Read master header
		call	kRead

		xor	si,si
		mov	di,TxtRDOFF2
		mov	cl,6
		cld
	gs	repe	cmpsb
		jnz	near .Err1

		mov	ebx,[gs:tRDMmaster.HdrLen]	; Seek to code header
		mov	[KernelHeaderLen],ebx
		add	ebx,byte tRDMmaster_size
		call	kSetFPos

		mov	di,BUFADDR			; Load code header
		mov	cl,tRDMsegHeader_size
		call	kRead

		mov	si,MsgBuildKrnl			; Print message
		call	PrintStr
		mov	eax,KERNELCODEADDR		; and code address
		mov	edi,eax
		call	PrintDwordHex

		mov	[CodeSectAddr],edi
		mov	ecx,[gs:tRDMsegHeader.Length]	; Load code section
		call	kRead

		push	ecx				; Load data header
		mov	edi,BUFADDR
		mov	ecx,tRDMsegHeader_size
		call	kRead
		pop	edi
		add	edi,KERNELCODEADDR
		add	edi,byte 15			; Align by paragraph
		and	di,0FFF0h

		mov	si,MsgData			; Print message
		call	PrintStr
		mov	eax,edi				; and data address
		call	PrintDwordHex

		mov	[DataSectAddr],edi
		mov	ecx,[gs:tRDMsegHeader.Length]	; Load data section
		call	kRead

		add	edi,ecx				; Count BSS address
		mov	[BSSsectAddr],edi
		mov	si,MsgBSS
		call	PrintStr
		mov	eax,edi
		call	PrintDwordHex
		mov	si,MsgBracket
		call	PrintStr

		call	DoRelocation
		call	BuildAPItable

		mov	ax,GDTSEG
		mov	es,ax
		mov	eax,0FFFFh			; Initialize GDT
		mov	[es:DescGDTseg],eax
		mov	[es:DescSrc],eax
		mov	dword [es:DescGDTseg+4],4F9A00h
		mov	dword [es:DescSrc+4],0CF9200h

		mov	word [GDTaddrLim],23
		mov	eax,es
		shl	eax,4
		mov	[GDTaddrLim+2],eax

		mov	ebx,[KernelEntryPoint]
		mov	word [gs:0],0E3FFh		; 'jmp ebx' opcode
		cli
		lgdt	[GDTaddrLim]
		mov	eax,cr0
		or	al,1
		mov	cr0,eax
		mov	ax,10h
		mov	ds,ax
		jmp	8:BUFADDR

.Halt:		jmp	$

.Err1:		mov	si,MsgErrInvKImg
		call	Error
endp		;---------------------------------------------------------------


; --- Data ---

section .data

Banner		DB	10,"RadiOS kernel loader, v1.00 (c) 1999 RET & COM Research",10,10,0

MsgBuildKrnl	DB	"Building kernel: code (",0
MsgData		DB	"h), data (",0
MsgBSS		DB	"h), bss (",0
MsgBracket	DB	"h)",10,0

MsgErrInvKImg	DB	"invalid kernel image",0

TxtRDOFF2	DB	"RDOFF2"
TxtStart	DB	"Start",0
TxtSyscall	DB	"syscall"
TxtDriver	DB	".drvhlp"
TxtUser		DB	".user"


; --- Variables ---

section .bss

KernelAddress		RESD	1
KernelSize		RESD	1
KernelHeaderLen		RESD	1

CodeSectAddr		RESD	1
DataSectAddr		RESD	1
BSSsectAddr		RESD	1

KernelEntryPoint	RESD	1

GDTaddrLim		RESB	6
