;*******************************************************************************
;  rdf.asm - RDF 2.0 modules driver.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

include "module.ah"
include "BINFMT\rdf.ah"

; --- Data ---
segment KDATA
DrvRDF		tDriver <"%BINFMT_RDF     ",DrvRDF_ET,DRVFL_BinFmt>

DrvRDF_ET	tDrvEntries < RDF_Init, \
			      NULL, \
			      RDF_Load, \
			      RDF_Unload, \
			      NULL, \
			      NULL, \
			      RDF_Done, \
			      DrvRDF_Ctrl >

DrvRDF_Ctrl	DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	NULL
		DD	RDF_CheckSignature
		DD	RDF_ResolveLinks
		DD	RDF_ResolveULinks

RDF_Signature	DB	"RDOFF",0

RDF_StackStr	DB	"stack",0
ends


; --- Interface procedures ---
segment KCODE

		; RDF_Init - initialize driver.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDF_Init near
		ret
endp		;---------------------------------------------------------------


		; RDF_Done - release driver memory blocks.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDF_Done near
		ret
endp		;---------------------------------------------------------------


		; RDF_Load - load RDF module.
		; Input: EBX=file handle,
		;	 EDI=address of kernel module structure.
		; Output: CF=0 - OK, EBX=module ID;
		;	  CF=1 - error, AX=error code.
proc RDF_Load near
@@pid		EQU	ebp-4
@@fhandle	EQU	ebp-8
@@sectcount	EQU	byte ebp-12			; Sections counter
@@firstsect	EQU	ebp-16				; First section MCB
@@codeaddr	EQU	ebp-20				; Code section address
@@dataaddr	EQU	ebp-24				; Data section address
@@bssaddr	EQU	ebp-28				; BSS section address
@@masterhdr	EQU	ebp-28-RDF_MASTERHDRSIZE	; Space for master hdr
@@space		EQU	ebp-28-RDF_MASTERHDRSIZE-128	; Space for mod records
							; or section headers
		push	ebp
		mov	ebp,esp
		sub	esp,28+RDF_MASTERHDRSIZE+128
		push	ebx ecx edx

		mov	eax,[K_CurrPID]
		mov	[@@pid],eax
		mov	[@@fhandle],ebx

		; Read the master header
		lea	esi,[@@masterhdr]
		mov	ecx,size tRDFmaster
		call	CFS_Read
		jc	@@Exit

		; Seek at begin of the sections
		mov	ecx,[esi+tRDFmaster.HdrLen]
		add	ecx,size tRDFmaster
		xor	dl,dl
		call	CFS_SetPos
		jc	@@Exit
		mov	[dword @@codeaddr],-1
		mov	[dword @@dataaddr],-1
		mov	[@@sectcount],0			; Section counter

		; Sections load loop
@@LoadSect:	lea	esi,[@@space]			; Load section header
		mov	ecx,size tRDFsegHeader
		call	CFS_Read
		jc	@@Exit

		mov	ecx,[esi+tRDFsegHeader.Length]
		mov	dx,[esi+tRDFsegHeader.Type]
		cmp	dx,RDFSEG_NULL
		je	short @@LoadOK
		cmp	dx,RDFSEG_Bad
		je	@@Err1
		mov	al,REGTYPE_CODE
		cmp	dx,RDFSEG_Text			; Code section?
		je	short @@AllocReg
		mov	al,REGTYPE_VARS			; Data section?
		cmp	dx,RDFSEG_Data			; Yes, it may contains
		je	short @@AllocReg		; variables
		mov	dx,REGTYPE_OTHER		; Else read-only data

@@AllocReg:	mov	dl,al
		mov	eax,[@@pid]			; Allocate private
		call	MM_AllocRegion			; region
		jc	@@Exit
		cmp	dl,REGTYPE_CODE
		je	short @@CodeAllocOK
		cmp	dl,REGTYPE_VARS
		jne	short @@1
		mov	[@@dataaddr],ebx
		jmp	short @@1

@@CodeAllocOK:	mov	[@@codeaddr],ebx

@@1:		cmp	[@@sectcount],0
		jne	short @@NotFirst
		mov	[@@firstsect],eax
@@NotFirst:	mov	esi,ebx
		mov	ebx,[@@fhandle]
		call	CFS_Read
		jc	@@Exit

		cmp	[@@sectcount],RDF_MAXSEGS
		jae	@@Err2
		inc	[@@sectcount]
		jmp	@@LoadSect

		; Sections loaded. Register first section MCB address
		; in the kernel module structure and initialize 'StackSize'
		; and 'EntryPoint' fields to -1 (assume that module is a
		; library without initialization code)
@@LoadOK:	mov	ebx,[@@firstsect]
		mov	[edi+tKModInfo.Sections],ebx
		mov	[edi+tKModInfo.StackSize],-1
		mov	[edi+tKModInfo.EntryPoint],-1
		mov	[edi+tKModInfo.Type],MODTYPE_LIBRARY

		; BSS, Stack, EntryPoint and relocation records handling
		mov	ecx,size tRDFmaster
		xor	dl,dl
		mov	ebx,[@@fhandle]
		call	CFS_SetPos
		jc	@@Exit
		lea	esi,[@@space]

		; Records loading loop
@@RecScan:	mov	ecx,2					; 2 bytes: type
		mov	ebx,[@@fhandle]				; and length
		call	CFS_Read
		jc	@@Exit
		sub	[@@masterhdr+tRDFmaster.HdrLen],eax
		mov	dl,[esi]				; DL=record type
		mov	cl,[esi+1]				; CL=record len
		call	CFS_Read
		jc	@@Exit
		sub	[@@masterhdr+tRDFmaster.HdrLen],eax	; EAX=number of
		cmp	dl,RDFREC_Reloc				; read bytes
		je	short @@RelocRec
		cmp	dl,RDFREC_BSS
		je	short @@BSSrec
		cmp	dl,RDFREC_Export
		je	@@ChkNames			; Scan for 'stack'
							; and 'main' names
@@ChkHdrEnd:	cmp	[@@masterhdr+tRDFmaster.HdrLen],0
		jne	@@RecScan
		jmp	@@OK

		; Relocations handling
@@RelocRec:	mov	al,[esi-2+tRDFreloc.Seg]
		mov	ebx,[esi-2+tRDFreloc.Ofs]
		or	al,al					; In code section?
		jz	short @@InCode
		dec	al					; In data section?
		jnz	@@ChkHdrEnd
		mov	eax,[dword @@dataaddr]
		jmp	short @@ChkSectIn

@@InCode:	mov	eax,[@@codeaddr]

@@ChkSectIn:	cmp	eax,-1
		je	@@Err5
		cmp	[esi-2+tRDFreloc.Len],4			; Sure that reloc
		jne	@@Err6					; is 32-bit
		add	ebx,eax
int 3
		mov	ax,[esi-2+tRDFreloc.RefSeg]	
		or	ax,ax				
		jz	short @@RefCode			
		dec	ax
		jz	short @@RefData
		dec	ax
		jz	short @@RefBSS
		jmp	@@ChkHdrEnd

@@RefCode:	mov	eax,[@@codeaddr]
		jmp	short @@ChkSectTo
@@RefData:	mov	eax,[@@dataaddr]
		jmp	short @@ChkSectTo
@@RefBSS:	mov	eax,[@@bssaddr]

@@ChkSectTo:	cmp	eax,-1
		je	@@Err5
		sub	eax,[HeapBegin]			; Make user address
		add	[ebx],eax			; Do relocation
		jmp	@@ChkHdrEnd

		; BSS space may be splitted on 2 areas: BSS area (first)
		; and stack area (last). Stack region allocates if 'stack'
		; export record encountered in the file.
@@BSSrec:	mov	ecx,[esi-2+tRDF_BSS.Amount]
		mov	eax,[edi+tKModInfo.StackSize]	; Allocate stack region?
		cmp	eax,-1
		je	short @@AllocRestBSS
		push	eax
		sub	ecx,eax
		mov	[edi+tKModInfo.StackSize],ecx	; Now field contains
		mov	dl,REGTYPE_STACK		; true stack size value
		mov	eax,[@@pid]
		call	MM_AllocRegion
		pop	ecx				; ECX=rest of BSS
		jc	@@Exit

@@AllocRestBSS:	or	ecx,ecx				; Zero BSS length?
		jz	@@ChkHdrEnd
		mov	dl,REGTYPE_VARS			; No, allocate as
		call	MM_AllocRegion			; 'vars' region
		jc	short @@Exit
		mov	[@@bssaddr],ebx			; Store BSS address
		push	edi				; and clear it
		mov	edi,ebx
		xor	al,al
		cld
		rep	stosb
		pop	edi
		jmp	@@ChkHdrEnd

		; "??" at the begin of the name indicates module name
		; and address of startup entry point
@@ChkNames:	push	esi edi
		lea	esi,[esi-2+tRDFexport.Lbl]
		cmp	[word esi],"??"				; Module name?
		je	short @@NameAndEP
		mov	edi,offset RDF_StackStr			; Check for
		call	StrComp					; stack
		pop	edi esi
		or	al,al
		jz	short @@Stack
		jmp	@@ChkHdrEnd

@@NameAndEP:	inc	esi
		inc	esi				; ESI=pointer to name
		lea	edi,[edi+tKModInfo.ModName]
		xchg	esi,edi				; Check name length
		call	StrLen
		cmp	ecx,16
		jb	short @@NoTrunc
		mov	[byte edi+15],0
		mov	cl,16
@@NoTrunc:	xchg	esi,edi
		cld
		rep	movsb
		pop	edi esi
		mov	eax,[esi-2+tRDFexport.Ofs]	; Initialize entry point
		mov	[edi+tKModInfo.EntryPoint],eax	; field
		jmp	@@ChkHdrEnd

@@Stack:	mov	al,[esi-2+tRDFexport.Seg]		; Check whether
		cmp	al,2					; stack in BSS
		jne	short @@Err3
		mov	eax,[esi-2+tRDFexport.Ofs]	; EAX=not stack size,
		mov	[edi+tKModInfo.StackSize],eax	; it's offset within BSS!
		mov	[edi+tKModInfo.Type],MODTYPE_EXECUTABLE	; If module has stack-
		jmp	@@ChkHdrEnd				; mark it as executable

@@OK:		clc

@@Exit:		pop	edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret

@@Err1:		mov	ax,ERR_RDF_BadSection
		stc
		jmp	@@Exit

@@Err2:		mov	ax,ERR_RDF_TooManySections
		stc
		jmp	@@Exit

@@Err3:		mov	ax,ERR_RDF_StackNotInBSS
		stc
		jmp	@@Exit

@@Err4:		mov	ax,ERR_RDF_InvLibName
		stc
		jmp	@@Exit

@@Err5:		mov	ax,ERR_RDF_NoSection
		stc
		jmp	@@Exit

@@Err6:		mov	ax,ERR_RDF_16bitReloc
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; RDF_Unload - unload RDF module.
		; Input: EDI=pointer to kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDF_Unload near
		ret
endp		;---------------------------------------------------------------


		; RDF_ResolveLinks - resolve all module links.
		; Input: EDI=address of kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDF_ResolveLinks near
		mov	ebx,[edi+tKModInfo.Index]
		ret
endp		;---------------------------------------------------------------


		; RDF_ResolveULinks - resolve only undefined module links.
		; Input: EDI=address of kernel module structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RDF_ResolveULinks near

		ret
endp		;---------------------------------------------------------------


		; RDF_CheckSignature - check module signature.
		; Input: EBX=file handle.
		; Output: CF=0 - signature OK;
		;	  CF=1 - bad signature or version.
proc RDF_CheckSignature near
@@header	EQU	ebp-RDF_MASTERHDRSIZE
		push	ebp
		mov	ebp,esp
		sub	esp,RDF_MASTERHDRSIZE
		push	ecx esi

		lea	esi,[@@header]				; Read master
		mov	ecx,size tRDFmaster			; header
		call	CFS_Read
		jc	short @@Exit
		xor	ecx,ecx
		cmp	eax,size tRDFmaster
		jb	short @@Done

		push	edi
		mov	edi,offset RDF_Signature
		mov	cl,5
		call	StrLComp				; Check
		pop	edi					; signature
		jnz	short @@Done
		inc	ch					; Signature OK
		cmp	[esi+tRDFmaster.AVersion],'2'
		jb	short @@Done
		inc	ch					; Version OK

@@Done:		push	ecx edx
		xor	ecx,ecx					; Set FP to 0
		xor	dl,dl
		call	CFS_SetPos
		pop	edx ecx
		jc	short @@Exit
		cmp	ch,2					; CF=1 if error

@@Exit:		pop	esi ecx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; RDF_GetFirstMCBaddr - scan allocated memory blocks and return
		; MCB address of reqired region type encountered.
		; Input: EBX=address of first MCB,
		;	 DL=region type.
		; Output: CF=0 - OK, EBX=address of MCB found;
		;	  CF=1 - error (region not found).
proc RDF_GetCodeMCB near
		or	ebx,ebx
		stc
		jz	short @@Exit
		cmp	[ebx+tMCB.Type],dl			; If equals-
		je	short @@Exit				; ZF=CF=0
		mov	ebx,[ebx+tMCB.Next]
@@Exit:		ret
endp		;---------------------------------------------------------------

ends
