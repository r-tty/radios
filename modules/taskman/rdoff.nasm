;*******************************************************************************
; rdoff.nasm - basic RDOFF routines needed for setting up boot modules.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module kernel.rdoff

%include "sys.ah"
%include "errors.ah"
%include "rdf.ah"
%include "module.ah"
%include "process.ah"
%include "memman.ah"
%include "cpu/paging.ah"

publicdata BinFmtRDOFF

library kernel
extern BZero

library kernel.mm
extern MM_AllocRegion

library kernel.strutil
extern StrComp, StrLen

section .data

BinFmtRDOFF: instance tBinFmtFunctions
	member(Init)
	member(Shutdown)
	member(CheckSig)
	member(GetModSize)
	member(GetModType)
	member(LoadModule)
	member(Relocate)
	member(GetArchMember)
iend

string RDOFFsignature,	{"RDOFF2"}
string RDLIBsignature,	{".sig",0,"RDLIB2"}
string StartLabel,	{"Start",0}
string StackLabel,	{"Stack",0}


section .text

		; Init - initialize this binary format.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc Init
		clc
		ret
endp		;---------------------------------------------------------------


		; Shutdown - do a final cleanup.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc Shutdown
		clc
		ret
endp		;---------------------------------------------------------------


		; CheckSig - check a module signature.
		; Input: EBX=address of module image.
		; Output: CF=0 - OK:
		;		    AL=1 - OK, this is an archive:
		;		     EBX=address of the first module name;
		;		    AL=0 - OK, this is a single module;
		;		    AL=-1 - signature mismatch.
		;	  CF=1 - error, AX=error code.
proc CheckSig
		mpush	ecx,esi,edi
		xor	al,al
		mov	edi,ebx
		mov	esi,RDOFFsignature
		mov	ecx,RDOFFsignature_size
		cld
		repe	cmpsb
		jz	.OK
		mov	edi,ebx
		mov	esi,RDLIBsignature
		mov	ecx,RDLIBsignature_size
		repe	cmpsb
		jnz	.Mismatch
		
		; This is a RDF library. Adjust EBX to point at the name
		; of the first module.
		add	ebx,RDLIBsignature_size
		mov	ecx,[ebx]			; Content length
		lea	ebx,[ebx+4+ecx]
		mov	al,1
.OK:		clc
.Done:		mpop	edi,esi,ecx
		ret
		
.Mismatch:	mov	al,-1
		jmp	.Done
endp		;---------------------------------------------------------------


		; GetModSize - get a size of the module.
		; Input: EBX=module image address.
		; Output: CF=0 - OK, ECX=size;
		;	  CF=1 - error, AX=error code.
proc GetModSize
		cmp	byte [ebx+tRDFmaster.AVersion],'2'	; RDOFF version
		jne	.Err
		mov	ecx,[ebx+tRDFmaster.ModLen]
		add	ecx,tRDFmaster.HdrLen
		clc
		ret
		
.Err:		mov	ax,ERR_MOD_BadVersion
		stc
		ret
endp		;---------------------------------------------------------------


		; GetModType - get module type information.
		; Input: EBX=module image address.
		; Output: CF=0 - OK, DX=type;
		;	  CF=1 - error, AX=error code.
proc GetModType
		push	ebx
		add	ebx,byte tRDFmaster_size
		
		; Read first record, it should be "Generic"
		cmp	byte [ebx], RDFREC_Generic
		jne	.Err
		add	ebx,tRDFgeneric.Data
		cmp	dword [ebx+tModInfoTag.Signature],RBM_SIGNATURE
		jne	.Err
		mov	dx,[ebx+tModInfoTag.ModType]
		clc
		
.Exit:		pop	ebx
		ret

.Err:		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; Relocate - relocate a module.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc Relocate
		clc
		ret
endp		;---------------------------------------------------------------


		; GetArchMember - get a module of the archive.
		; Input: EBX=address of archive member header.
		; Output: CF=0 - OK:
		;		    EBX=module address,
		;		    ESI=pointer to module name;
		;	  CF=1 - error, AX=error code.
proc GetArchMember
		mpush	ecx,edi
		
		; Find a NULL terminator
		mov	ecx,MODNAMEMAXLEN
		mov	edi,ebx
		xor	al,al
		cld
		repne	scasb
		jne	.Err
		
		mov	esi,edi
		xchg	esi,ebx
		clc
		
.Done:		mpop	edi,ecx
		ret
		
.Err:		mov	ax,ERR_MOD_BadArchMember
		stc
		jmp	.Done
endp		;---------------------------------------------------------------


		; LoadModule - load module sections, initialize bss, stack and
		;	       entry point.
		; Input: EBX=RDOFF image address,
		;	 EDX=relocation base,
		;	 ESI=PCB address,
		;	 EDI=module descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc LoadModule
		locals	rdoffimg,pcb,moddesc,relocbase
		locals	sectcount,pos,loadedsize,hdrlen
		
		prologue
		mpush	ebx,ecx,edx,esi,edi

		mov	[%$rdoffimg],ebx
		mov	[%$pcb],esi
		mov	[%$moddesc],edi

		xor	eax,eax
		mov	[%$sectcount],eax
		mov	[%$loadedsize],eax
		
		; -1 indicates that there is no such section
		not	eax
		mov	[edi+tModuleDesc.CodeSect],eax
		mov	[edi+tModuleDesc.DataSect],eax
		mov	[edi+tModuleDesc.BSS_Sect],eax
		
		; No entry point and no stack
		mov	[edi+tModuleDesc.StackSize],eax
		mov	[edi+tModuleDesc.EntryPoint],eax
		mov	ecx,[ebx+tRDFmaster.HdrLen]
		mov	[%$hdrlen],ecx
		lea	esi,[ebx+ecx+tRDFmaster_size]
		mov	[%$pos],esi
	
.LoadLoop:	mov	ecx,[esi+tRDFsegHeader.Length]
		add	dword [%$pos],tRDFsegHeader_size	; Update position
		add	[%$pos],ecx
		mov	ax,[esi+tRDFsegHeader.Type]
		cmp	ax,RDFSEG_NULL
		je	near .SectLoadOK
		cmp	ax,RDFSEG_Bad
		je	near .Err1
		mov	dh,REGTYPE_TEXT
		cmp	ax,RDFSEG_Text			; Code section?
		je	short .AllocReg
		mov	dh,REGTYPE_DATA			; Data section?
		cmp	ax,RDFSEG_Data
		je	short .AllocReg			
		mov	dh,REGTYPE_OTHER		

.AllocReg:	jecxz	.CheckCount
		mov	esi,[%$pcb]
		mov	dl,[edi+tModuleDesc.Type]	; Kluge ;)
		call	MM_AllocRegion			; Allocate region
		jc	near .Exit
		cmp	dh,REGTYPE_TEXT
		je	short .CodeAllocOK
		cmp	dh,REGTYPE_DATA
		jne	short .DoCopy
		mov	[edi+tModuleDesc.DataSect],ebx
		jmp	short .DoCopy

.CodeAllocOK:	mov	[edi+tModuleDesc.CodeSect],ebx

.DoCopy:	mpush	ecx,edi
		mov	edi,[%$pcb]
		xchg	ebx,edi
		mCopyToUser [%$pos],,,ebx
		mpop	edi,ecx
		mAlignOnPage ecx
		add	[%$loadedsize],ecx

.CheckCount:	cmp	byte [%$sectcount],RDF_MAXSEGS
		jae	near .Err2
		inc	byte [%$sectcount]
		mov	esi,[%$pos]
		jmp	.LoadLoop

		; Sections loaded. Now walk through the header and initialize
		; BSS and stack. Finally set up all relocations.
.SectLoadOK:	mov	eax,[%$loadedsize]		; Store module size
		mov	[edi+tModuleDesc.Size],eax

		mov	esi,[%$rdoffimg]
		add	esi,byte tRDFmaster_size
		mov	[%$pos],esi

		; Records scan loop
.RecScan:	mov	dl,[esi+tRDFgeneric.Type]		; DL=record type
		movzx	ecx,byte [esi+tRDFgeneric.RecLen]	; CL=record length
		add	ecx,byte tRDFgeneric.Data	; i.e. ECX+=2
		add	[%$pos],ecx
		sub	[%$hdrlen],ecx
		
		cmp	dl,RDFREC_Reloc				; read bytes
		je	.RelocRec
		cmp	dl,RDFREC_BSS
		je	near .BSSrec
		cmp	dl,RDFREC_Export		; Scan for 'Stack'
		je	near .ChkNames			; and 'Start' names
		cmp	dl,RDFREC_ModName		; Handle module name
		je	near .ModNameRec

.ChkHdrEnd:	cmp	dword [%$hdrlen],0
		jz	near .OK
		mov	esi,[%$pos]			; Update position
		jmp	.RecScan

		; Relocations handling
.RelocRec:	mov	al,[esi+tRDFreloc.Seg]
		mov	ebx,[esi+tRDFreloc.Ofs]
		or	al,al					; In code section?
		jz	short .InCode
		dec	al					; In data section?
		jnz	.ChkHdrEnd
		mov	eax,[edi+tModuleDesc.DataSect]
		jmp	short .ChkSectIn

.InCode:	mov	eax,[edi+tModuleDesc.CodeSect]

.ChkSectIn:	cmp	eax,-1
		je	near .Err5
		cmp	byte [esi+tRDFreloc.Len],4		; Sure that reloc
		jne	near .Err6				; is 32-bit
		add	ebx,eax
		mov	ax,[esi+tRDFreloc.RefSeg]
		or	ax,ax
		jz	short .RefCode
		dec	ax
		jz	short .RefData
		dec	ax
		jz	short .RefBSS
		jmp	.ChkHdrEnd

.RefCode:	mov	eax,[edi+tModuleDesc.CodeSect]
		jmp	short .ChkSectTo
.RefData:	mov	eax,[edi+tModuleDesc.DataSect]
		jmp	short .ChkSectTo
.RefBSS:	mov	eax,[edi+tModuleDesc.BSS_Sect]

.ChkSectTo:	cmp	eax,-1
		je	near .Err5
		sub	eax,[%$relocbase]
		add	[ebx],eax			; Do relocation
		jmp	.ChkHdrEnd

		; BSS space may be splitted on 2 areas: BSS area (first)
		; and stack area (last). Stack region allocates if 'Stack'
		; export record encountered in the file.
.BSSrec:	mov	ecx,[esi+tRDF_BSS.Amount]
		mov	eax,[edi+tModuleDesc.StackSize]	; Allocate stack region?
		cmp	eax,-1
		je	short .AllocRestBSS
		push	eax
		sub	ecx,eax
		mov	[edi+tModuleDesc.StackSize],ecx	; Now field contains
		mov	dh,REGTYPE_STACK		; true stack size value
		mov	esi,[%$pcb]
		call	MM_AllocRegion
		pop	ecx				; ECX=rest of BSS
		jc	near .Exit

.AllocRestBSS:	or	ecx,ecx				; Zero BSS length?
		jz	near .ChkHdrEnd
		mov	dh,REGTYPE_BSS			; No, allocate as
		call	MM_AllocRegion			; 'bss' region
		jc	near .Exit
		mov	[edi+tModuleDesc.BSS_Sect],ebx	; Store BSS address
		call	BZero				; and clear it
		jmp	.ChkHdrEnd

		; Check for start entry point and stack reservation
		; and address of startup entry point
.ChkNames:	mpush	esi,edi
		add	esi,byte tRDFexport.Lbl
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
		mov	eax,[esi+tRDFexport.Ofs]	; Initialize entry point
		mov	[edi+tModuleDesc.EntryPoint],eax	; field
		jmp	.ChkHdrEnd

.Stack:		cmp	byte [esi+tRDFexport.Seg],2	; Check whether
		jne	short .Err3			; stack in BSS
		mov	eax,[esi+tRDFexport.Ofs]	; EAX=not stack size,
		mov	[edi+tModuleDesc.StackSize],eax	; it's offset within BSS!
		mov	byte [edi+tModuleDesc.Type],MODTYPE_EXECUTABLE ; If module has stack-
		jmp	.ChkHdrEnd				; mark it as executable

.ModNameRec:	mpush	esi,edi
		add	esi,byte tRDF_ModName.ModName
		add	edi,byte tModuleDesc.ModName
		xchg	esi,edi				; Check name length
		call	StrLen
		cmp	ecx,byte MODNAMEMAXLEN
		jb	short .NoTrunc
		mov	ecx,MODNAMEMAXLEN-1
.NoTrunc:	xchg	esi,edi
		cld
		rep	movsb
		mov	byte [edi],0
		mpop	edi,esi
		jmp	.ChkHdrEnd

.OK:		clc
.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret

.Err1:		mov	ax,ERR_RDM_BadSection
.Err:		stc
		jmp	.Exit

.Err2:		mov	ax,ERR_RDM_TooManySections
		jmp	.Err

.Err3:		mov	ax,ERR_RDM_StackNotInBSS
		jmp	.Err

.Err4:		mov	ax,ERR_RDM_InvLibName
		jmp	.Err

.Err5:		mov	ax,ERR_RDM_NoSection
		jmp	.Err

.Err6:		mov	ax,ERR_RDM_16bitReloc
		jmp	.Err
endp		;--------------------------------------------------------------
