;*******************************************************************************
; rdoff.nasm - basic RDOFF routines needed for setting up boot modules.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module kernel.rdoff

%include "sys.ah"
%include "errors.ah"
%include "rdm.ah"
%include "module.ah"

publicdata BinFmtRDOFF

section .data

BinFmtRDOFF: instance tBinFmtFunctions
	member(Init)
	member(Shutdown)
	member(CheckSig)
	member(GetModSize)
	member(Relocate)
	member(GetArchMember)
	member(GetSectInfo)
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
		cmp	byte [ebx+tRDMmaster.AVersion],'2'	; RDOFF version
		jne	.Err
		mov	ecx,[ebx+tRDMmaster.ModLen]
		add	ecx,tRDMmaster.HdrLen
		clc
		ret
		
.Err:		mov	ax,ERR_MOD_BadVersion
		stc
		ret
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


		; GetSectInfo - get addresses of the module sections.
		; Input: EBX=module address.
		; Output: CF=0 - OK:
		;		EBX=code section address,
		;		EDX=data section address,
		;		EDI=BSS section address,
		;		ECX=module image size (i.e. all sections);
		;	  CF=1 - error, AX=error code.
proc GetSectInfo
		push	esi
		mov	esi,ebx
		mov	ebx,[esi+tRDMmaster.HdrLen]
		mov	ecx,[esi+tRDMmaster.ModLen]
		sub	ecx,ebx
		pop	esi
		ret
endp		;--------------------------------------------------------------
