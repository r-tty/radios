;-------------------------------------------------------------------------------
;  module.as - boot-time modules linker.
;-------------------------------------------------------------------------------

%define MODLIST			1000h		; Module list begin addr
%define	MODCMDLINES		1200h		; Buffer for module command lines
%define MAXMODULES		32		; Maximum number of modules


section .data

MsgModHeader	DB	10,"Module		Driver		code	data	bss",10,0


section .text

		; ModPrepare - prepare modules to link.
		; Input: EBX=address of multiboot info structure.
		; Output: none.
proc ModPrepare
		; Check whether bootable modules are loaded
		test	dword [ebx+tMBinfo.Flags],MB_INFO_MODS
		jz	short .Done
		mov	eax,[ebx+tMBinfo.ModsCount]
		cmp	eax,MAXMODULES			; No more than 16 mods
		jbe	short .NumModsOK
		mov	eax,MAXMODULES
.NumModsOK:	mov	[BootModulesCount],eax
		or	eax,eax
		jz	short .Done
		
		; Copy module list to new location
		mov	ecx,eax
		mov	esi,[ebx+tMBinfo.ModsAddr]
		mov	edi,MODLIST
		mov	[BootModulesListAddr],edi
		mov	edx,MODCMDLINES
		mov	[BootModulesCmdLines],edx
		cld
		
.Loop:		movsd				; Copy 'Start' field
		movsd				; Copy 'End' field
		mpush	esi,edi
		mov	esi,[esi]
		mov	edi,edx
		call	CopyCmdLine
		mpop	edi,esi			; EAX=cmdline length
		mov	[esi],edx		; New cmdline address
		movsd				; Copy 'Cmdline'
		movsd				; and 'Pad' fields
		add	edx,eax
		inc	edx
		loop	.Loop
		
.Done:		ret
endp		;---------------------------------------------------------------


		; CopyCmdLine - copy ASCIIZ command line to a new address.
		; Input: ESI=source address,
		;	 EDI=destination address.
		; Output: EAX=string length (without trailing 0).
proc CopyCmdLine
		xor	eax,eax
.Loop:		cmp	byte [esi],0
		je	short .Done
		movsb
		inc	eax
		jmp	short .Loop
.Done:		movsb					; Copy trailing zero
		ret
endp		;---------------------------------------------------------------


		; LinkModules - link all loaded modules to a kernel.
		; Input: EBP=buffer address.
		; Output: none.
proc LinkModules
		cmp	dword [BootModulesCount],0	; Are there modules?
		jnz	short .PrintHdr
		ret
		
.PrintHdr:	mov	byte [Color],14			; Fancy :)
		mov	esi,MsgModHeader
		call	PrintStr
		
		mov	ecx,[BootModulesCount]
		mov	ebx,MODLIST
		
.Loop:		mov	esi,[ebx+tModList.Start]
		mov	edi,[ebx+tModList.End]
		call	ProceedModule
		add	ebx,tModList_size
		loop	.Loop
		ret
endp		;---------------------------------------------------------------


		; ProceedOneModule - relocate and link a module.
		; Input: ESI=RDM start,
		;	 EDI=RDM end.
		; Output: none.
proc ProceedModule
		mpush	ebx,ecx
		xor	ecx,ecx
		
		; Prepare variables
		mov	[RImgStart],esi
		mov	[RImgCurrPos],esi
		sub	edi,esi
		mov	[RImgSize],edi
		
		; Read RDM master header.
		mov	edi,ebp
		mov	cl,tRDMmaster_size
		call	ImgRead

		; Check its signature
		mov	esi,TxtRDOFF2
		mov	cl,6
		cld
		repe	cmpsb
		jnz	near .ErrBadRDM
		
.Done:		mpop	ecx,ebx
		ret
		
.ErrBadRDM:	mov	esi,MsgBadRDM
		call	PrintStr
		jmp	short .Done
endp		;---------------------------------------------------------------
