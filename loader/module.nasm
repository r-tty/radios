;-------------------------------------------------------------------------------
; module.nasm - boot-time modules routines.
;-------------------------------------------------------------------------------

%define MODLIST			1000h		; Module list begin addr
%define	MODCMDLINES		1200h		; Buffer for module command lines
%define MAXMODULES		32		; Maximum number of modules


section .text

		; ModPrepare - arrange module table and command lines.
		; Input: EBX=address of multiboot info structure.
		; Output: none.
proc ModPrepare
		; Check whether bootable modules are loaded
		test	dword [ebx+tMBinfo.Flags],MB_INFO_MODS
		jz	short .Done
		mov	eax,[ebx+tMBinfo.ModsCount]
		cmp	eax,MAXMODULES
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

