;*******************************************************************************
;  rdoff.nasm - Relocatable Dynamic Modules driver (RDOFF 2.0).
;  Copyright (c) 1999-2002 RET & COM Research.
;*******************************************************************************

module kernel.rdoff

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "memman.ah"

%include "rdm.ah"


; --- Exports ---

global DrvRDM


; --- Imports ---

library kernel.mm
extern MM_AllocRegion:extcall

library kernel.misc
extern StrComp:extcall, StrLComp:extcall, StrLen:extcall


; --- Data ---

section .data

RDM_Signature	DB	"RDOFF",0
StartLabel	DB	"Start",0
StackLabel	DB	"Stack",0



; --- Interface procedures ---

section .text

		; RDM_Init - initialize driver.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDM_Init
		ret
endp		;---------------------------------------------------------------


		; RDM_Load - load RDM module.
		; Input: EAX=PID,
		;	 EBX=file handle,
		;	 EDX=relocation base,
		;	 EDI=address of kernel module structure.
		; Output: CF=0 - OK, EBX=module ID;
		;	  CF=1 - error, AX=error code.
proc RDM_Load
%define	.pid		ebp-4
%define	.fhandle	ebp-8
%define	.sectcount	ebp-12				; Sections counter
%define	.firstsect	ebp-16				; First section MCB
%define	.codeaddr	ebp-20				; Code section address
%define	.dataaddr	ebp-24				; Data section address
%define	.bssaddr	ebp-28				; BSS section address
%define .relocbase	ebp-32
%define	.masterhdr	ebp-32-(tRDMmaster_size+2)	; Space for master hdr
%define	.space		ebp-32-(tRDMmaster_size+2)-128	; Space for mod records
							; or section headers
		prologue 32+tRDMmaster_size+2+128
		mpush	ebx,ecx,edx
int3
		mov	[.pid],eax
		mov	[.fhandle],ebx
		mov	[.relocbase],edx

		; Read the master header
		lea	esi,[.masterhdr]
		mov	ecx,tRDMmaster_size
	;	call	CFS_Read		;XXX
		jc	near .Exit

		; Seek at begin of the sections
		mov	ecx,[esi+tRDMmaster.HdrLen]
		add	ecx,tRDMmaster_size
		xor	dl,dl
	;	call	CFS_SetPos		;XXX
		jc	near .Exit
		mov	dword [.codeaddr],-1
		mov	dword [.dataaddr],-1
		mov	byte [.sectcount],0		; Section counter

		; Sections load loop
.LoadSect:	lea	esi,[.space]			; Load section header
		mov	ecx,tRDMsegHeader_size
	;	call	CFS_Read		;XXX
		jc	near .Exit

		mov	ecx,[esi+tRDMsegHeader.Length]
		mov	dx,[esi+tRDMsegHeader.Type]
		cmp	dx,RDMSEG_NULL
		je	short .LoadOK
		cmp	dx,RDMSEG_Bad
		je	near .Err1
		mov	al,REGTYPE_TEXT
		cmp	dx,RDMSEG_Text			; Code section?
		je	short .AllocReg
		mov	al,REGTYPE_DATA			; Data section?
		cmp	dx,RDMSEG_Data
		je	short .AllocReg			
		mov	dx,REGTYPE_OTHER		

.AllocReg:	mov	dl,al
		mov	eax,[.pid]			; Allocate private
		call	MM_AllocRegion			; region
		jc	near .Exit
		cmp	dl,REGTYPE_TEXT
		je	short .CodeAllocOK
		cmp	dl,REGTYPE_DATA
		jne	short .1
		mov	[.dataaddr],ebx
		jmp	short .1

.CodeAllocOK:	mov	[.codeaddr],ebx

.1:		cmp	byte [.sectcount],0
		jne	short .NotFirst
		mov	[.firstsect],eax
.NotFirst:	mov	esi,ebx
		mov	ebx,[.fhandle]
	;	call	CFS_Read		;XXX
		jc	near .Exit

		cmp	byte [.sectcount],RDM_MAXSEGS
		jae	near .Err2
		inc	byte [.sectcount]
		jmp	.LoadSect

		; Sections loaded. Register first section MCB address
		; in the kernel module structure and initialize 'StackSize'
		; and 'EntryPoint' fields to -1 (assume that module is a
		; library without initialization code)
.LoadOK:	mov	ebx,[.firstsect]
		mov	[edi+tKModInfo.Sections],ebx
		mov	dword [edi+tKModInfo.StackSize],-1
		mov	dword [edi+tKModInfo.EntryPoint],-1
		mov	byte [edi+tKModInfo.Type],MODTYPE_LIBRARY

		; BSS, Stack, ModName and relocation records handling
		mov	ecx,tRDMmaster_size
		xor	dl,dl
		mov	ebx,[.fhandle]
	;	call	CFS_SetPos		;XXX
		jc	near .Exit
		lea	esi,[.space]

		; Records loading loop
.RecScan:	mov	ecx,2					; 2 bytes: type
		mov	ebx,[.fhandle]				; and length
	;	call	CFS_Read		;XXX
		jc	near .Exit
		sub	[.masterhdr+tRDMmaster.HdrLen],eax
		mov	dl,[esi]				; DL=record type
		mov	cl,[esi+1]				; CL=record len
	;	call	CFS_Read		;XXX
		jc	near .Exit
		sub	[.masterhdr+tRDMmaster.HdrLen],eax	; EAX=number of
		cmp	dl,RDMREC_Reloc				; read bytes
		je	.RelocRec
		cmp	dl,RDMREC_BSS
		je	near .BSSrec
		cmp	dl,RDMREC_Export		; Scan for 'Stack'
		je	near .ChkNames			; and 'Start' names
		cmp	dl,RDMREC_ModName		; Handle module name
		je	near .ModNameRec

.ChkHdrEnd:	cmp	byte [.masterhdr+tRDMmaster.HdrLen],0
		jne	.RecScan
		jmp	.OK

		; Relocations handling
.RelocRec:	mov	al,[esi-2+tRDMreloc.Seg]
		mov	ebx,[esi-2+tRDMreloc.Ofs]
		or	al,al					; In code section?
		jz	short .InCode
		dec	al					; In data section?
		jnz	.ChkHdrEnd
		mov	eax,[.dataaddr]
		jmp	short .ChkSectIn

.InCode:	mov	eax,[.codeaddr]

.ChkSectIn:	cmp	eax,-1
		je	near .Err5
		cmp	byte [esi-2+tRDMreloc.Len],4		; Sure that reloc
		jne	near .Err6				; is 32-bit
		add	ebx,eax
int3
		mov	ax,[esi-2+tRDMreloc.RefSeg]
		or	ax,ax
		jz	short .RefCode
		dec	ax
		jz	short .RefData
		dec	ax
		jz	short .RefBSS
		jmp	.ChkHdrEnd

.RefCode:	mov	eax,[.codeaddr]
		jmp	short .ChkSectTo
.RefData:	mov	eax,[.dataaddr]
		jmp	short .ChkSectTo
.RefBSS:	mov	eax,[.bssaddr]

.ChkSectTo:	cmp	eax,-1
		je	near .Err5
		sub	eax,[.relocbase]
		add	[ebx],eax			; Do relocation
		jmp	.ChkHdrEnd

		; BSS space may be splitted on 2 areas: BSS area (first)
		; and stack area (last). Stack region allocates if 'stack'
		; export record encountered in the file.
.BSSrec:	mov	ecx,[esi-2+tRDM_BSS.Amount]
		mov	eax,[edi+tKModInfo.StackSize]	; Allocate stack region?
		cmp	eax,-1
		je	short .AllocRestBSS
		push	eax
		sub	ecx,eax
		mov	[edi+tKModInfo.StackSize],ecx	; Now field contains
		mov	dl,REGTYPE_STACK		; true stack size value
		mov	eax,[.pid]
		call	MM_AllocRegion
		pop	ecx				; ECX=rest of BSS
		jc	near .Exit

.AllocRestBSS:	or	ecx,ecx				; Zero BSS length?
		jz	near .ChkHdrEnd
		mov	dl,REGTYPE_BSS			; No, allocate as
		call	MM_AllocRegion			; 'bss' region
		jc	.Exit
		mov	[.bssaddr],ebx			; Store BSS address
		push	edi				; and clear it
		mov	edi,ebx
		xor	al,al
		cld
		rep	stosb
		pop	edi
		jmp	.ChkHdrEnd

		; Check for start entry point and stack reservation
		; and address of startup entry point
.ChkNames:	mpush	esi,edi
		lea	esi,[esi-2+tRDMexport.Lbl]
		mov	edi,StartLabel				; Start entry?
		call	StrComp
		or	al,al
		jz	.Start
		mov	edi,StackLabel				; Check for
		call	StrComp					; stack
		mpop	edi,esi
		or	al,al
		jz	.Stack
		jmp	.ChkHdrEnd

.Start:		mpop	edi,esi
		mov	eax,[esi-2+tRDMexport.Ofs]	; Initialize entry point
		mov	[edi+tKModInfo.EntryPoint],eax	; field
		jmp	.ChkHdrEnd

.Stack:		cmp	byte [esi-2+tRDMexport.Seg],2	; Check whether
		jne	short .Err3			; stack in BSS
		mov	eax,[esi-2+tRDMexport.Ofs]	; EAX=not stack size,
		mov	[edi+tKModInfo.StackSize],eax	; it's offset within BSS!
		mov	byte [edi+tKModInfo.Type],MODTYPE_EXECUTABLE ; If module has stack-
		jmp	.ChkHdrEnd				; mark it as executable

.ModNameRec:	lea	esi,[esi-2+tRDM_ModName.ModName]
		lea	edi,[edi+tKModInfo.ModName]
		xchg	esi,edi				; Check name length
		call	StrLen
		cmp	ecx,byte 16
		jb	short .NoTrunc
		mov	byte [edi+15],0
		mov	cl,16
.NoTrunc:	xchg	esi,edi
		cld
		rep	movsb
		jmp	.ChkHdrEnd

.OK:		clc

.Exit:		mpop	edx,ecx,ebx
		epilogue
		ret

.Err1:		mov	ax,ERR_RDM_BadSection
		stc
		jmp	.Exit

.Err2:		mov	ax,ERR_RDM_TooManySections
		stc
		jmp	.Exit

.Err3:		mov	ax,ERR_RDM_StackNotInBSS
		stc
		jmp	.Exit

.Err4:		mov	ax,ERR_RDM_InvLibName
		stc
		jmp	.Exit

.Err5:		mov	ax,ERR_RDM_NoSection
		stc
		jmp	.Exit

.Err6:		mov	ax,ERR_RDM_16bitReloc
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; RDM_Unload - unload RDM module.
		; Input: EDI=pointer to kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDM_Unload
		ret
endp		;---------------------------------------------------------------


		; RDM_ResolveLinks - resolve all module links.
		; Input: EDI=address of kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDM_ResolveLinks
		mov	ebx,[edi+tKModInfo.Inode]
	;	call	CFS_OpenByIndex			;XXX
		jc	.Done

.Done:		ret
endp		;---------------------------------------------------------------


		; RDM_ResolveULinks - resolve only undefined module links.
		; Input: EDI=address of kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDM_ResolveULinks

		ret
endp		;---------------------------------------------------------------


		; RDM_CheckSignature - check module signature.
		; Input: EBX=file handle.
		; Output: CF=0 - signature OK;
		;	  CF=1 - bad signature or version.
proc RDM_CheckSignature
%define	.header		ebp-(tRDMmaster_size+2)

		prologue tRDMmaster_size+2
		mpush	ecx,esi

		lea	esi,[.header]				; Read master
		mov	ecx,tRDMmaster_size			; header
	;	call	CFS_Read		;XXX
		jc	short .Exit
		xor	ecx,ecx
		cmp	eax,tRDMmaster_size
		jb	short .Done

		push	edi
		mov	edi,RDM_Signature
		mov	cl,5
		call	StrLComp				; Check
		pop	edi					; signature
		jnz	short .Done
		inc	ch					; Signature OK
		cmp	byte [esi+tRDMmaster.AVersion],'2'
		jb	short .Done
		inc	ch					; Version OK

.Done:		mpush	ecx,edx
		xor	ecx,ecx					; Set FP to 0
		xor	dl,dl
	;	call	CFS_SetPos		;XXX
		mpop	edx,ecx
		jc	short .Exit
		cmp	ch,2					; CF=1 if error

.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; RDM_GetFirstMCBaddr - scan allocated memory blocks and return
		; MCB address of reqired region type encountered.
		; Input: EBX=address of first MCB,
		;	 DL=region type.
		; Output: CF=0 - OK, EBX=address of MCB found;
		;	  CF=1 - error (region not found).
proc RDM_GetCodeMCB
		or	ebx,ebx
		stc
		jz	short .Exit
		cmp	[ebx+tMCB.Type],dl			; If equals-
		je	short .Exit				; ZF=CF=0
		mov	ebx,[ebx+tMCB.Next]
.Exit:		ret
endp		;---------------------------------------------------------------

