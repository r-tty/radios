;*******************************************************************************
; rdoff.nasm - RDOFF binary format driver.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module binfmt.rdoff

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "tm/process.ah"
%include "tm/memman.ah"
%include "tm/binfmt.ah"
%include "tm/rdf.ah"
%include "cpu/paging.ah"

publicdata BinFmtRDOFF

library taskman.mm
externproc MM_ReallocBlock

library $libc
importproc _strcmp, _strlen, _memset


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
		mov	ecx,MAXMODNAMELEN
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

		mov	[edi+tModule.BSSlen],eax
		; -1 indicates that there is no such section
		not	eax
		mov	[edi+tModule.CodeStart],eax
		mov	[edi+tModule.DataStart],eax

		; No entry point and no stack
		mov	[edi+tModule.Entry],eax
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
		mov	dh,REGTYPE_CODE
		cmp	ax,RDFSEG_Text			; Code section?
		je	short .AllocReg
		mov	dh,REGTYPE_DATA			; Data section?
		cmp	ax,RDFSEG_Data
		je	short .AllocReg			
		mov	dh,REGTYPE_OTHER		

.AllocReg:	jecxz	.CheckCount
		mov	esi,[%$pcb]
		mov	dl,[edi+tModule.Type]		; XXX Kluge
	;	call	MM_AllocRegion			; XXX FIX!
		jc	near .Exit
		cmp	dh,REGTYPE_CODE
		je	short .CodeAllocOK
		cmp	dh,REGTYPE_DATA
		jne	short .DoCopy
		mov	[edi+tModule.DataStart],ebx
		jmp	short .DoCopy

.CodeAllocOK:	mov	[edi+tModule.CodeStart],ebx

.DoCopy:	mpush	ecx,edi
		mov	edi,[%$pcb]
		xchg	ebx,edi
	;	mCopyToUser [%$pos],,,ebx			; XXX
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
		mov	[edi+tModule.Size],eax

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
		mov	eax,[edi+tModule.DataStart]
		jmp	short .ChkSectIn

.InCode:	mov	eax,[edi+tModule.CodeStart]

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

.RefCode:	mov	eax,[edi+tModule.CodeStart]
		jmp	.ChkSectTo
.RefData:	mov	eax,[edi+tModule.DataStart]
		jmp	.ChkSectTo
.RefBSS:	mov	eax,[edi+tModule.DataStart]
		add	eax,[edi+tModule.DataLen]

.ChkSectTo:	cmp	eax,-1
		je	near .Err5
		sub	eax,[%$relocbase]
		add	[ebx],eax			; Do relocation
		jmp	.ChkHdrEnd

.BSSrec:	mov	ecx,[esi+tRDF_BSS.Amount]
		or	ecx,ecx				; Zero BSS length?
		jz	near .ChkHdrEnd
		mov	ebx,[edi+tModule.DataStart]
		call	MM_ReallocBlock
		jc	near .Exit
		mov	[edi+tModule.DataStart],ebx	; Store new data addr
		mov	[edi+tModule.BSSlen],ecx	; Store BSS size
		Ccall	_memset, ebx, ecx, byte 0
		jmp	.ChkHdrEnd

		; Check for start entry point and stack reservation
		; and address of startup entry point
.ChkNames:	push	esi
		add	esi,byte tRDFexport.Lbl
		Ccall	_strcmp, esi, StartLabel
		pop	esi
		or	eax,eax				; Start entry?
		jnz	.ChkHdrEnd
		mov	eax,[esi+tRDFexport.Ofs]	; Initialize entry point
		mov	[edi+tModule.Entry],eax		; field
		jmp	.ChkHdrEnd

.ModNameRec:	add	edi,byte tModule.Name
		add	esi,byte tRDF_ModName.ModName
		Ccall	_strlen, esi
		cmp	eax,byte MAXMODNAMELEN
		jb	.NoTrunc
		mov	eax,MAXMODNAMELEN-1
.NoTrunc:	mov	ecx,eax
		cld
		rep	movsb
		mov	byte [edi],0
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
