;*******************************************************************************
;  module.nasm - RadiOS module primitives.
;  Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module kernel.module

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "pool.ah"
%include "macros/inlines.ah"


; --- Exports ---

publicproc MOD_InitMem, MOD_InitKernelMod
publicproc MOD_RegisterFormat, MOD_UnregisterFormat
publicproc MOD_Insert, MOD_Remove
publicproc MOD_GetType, MOD_GetIDbyName


; --- Imports ---

library kernel.pool
extern K_PoolInit
extern K_PoolAllocChunk, K_PoolFreeChunk

; --- Definitions ---

%define	MOD_MAXBINFORMATS	16		; Max. number of binfmt drivers


; --- Data ---

section .data

KernelModName	DB	"kernel",0


; --- Variables ---

section .bss

?NumLoadedMods	RESD	1			; Number of loaded modules
?MaxModules	RESD	1			; Maximum number of loaded mods
?ModulePool	RESB	tMasterPool_size	; Modules master pool
?ModListHead	RESD	1			; Head of module list

?BinFmtDrivers	RESD	MOD_MAXBINFORMATS	; Binfmt entries


; --- Procedures ---

section .text

		; MOD_InitMem - initialize modules management.
		; Input: EAX=maximum number of loaded modules.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_InitMem
		mov	[?MaxModules],eax
		mov	ebx,?ModulePool
		mov	ecx,tModuleDesc_size
		xor	edx,edx
		call	K_PoolInit
		ret
endp		;---------------------------------------------------------------


		; MOD_InitKernelMod - initialize kernel module (module 0).
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_InitKernelMod
		mpush	esi,edi
		mov	ebx,?ModulePool
		call	K_PoolAllocChunk
		jc	short .Exit
		mov	eax,100000h
		mov	[esi+tModuleDesc.Sections],eax
		mov	dword [esi+tModuleDesc.StackSize],8000h
		mov	byte [esi+tModuleDesc.Type],MODTYPE_LIBRARY
		lea	edi,[esi+tModuleDesc.ModName]
		cld
		mStrcpy KernelModName,,MODNAMEMAXLEN
.Exit:		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; MOD_RegisterFormat - register binary format driver.
		; Input: EDX=address of tBinFmtFunctions table.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_RegisterFormat
		mpush	ecx,edi
		mov	ecx,MOD_MAXBINFORMATS
		mov	edi,?BinFmtDrivers
		cld
		xor	eax,eax				; Find a free slot
		repne	scasd
		jnz	short .Err
		callsafe dword [edx+tBinFmtFunctions.Init] ; Initialize BinFmt

		mov	[edi-4],edx
.Exit:		mpop	edi,ecx
		ret

.Err:		mov	ax,ERR_MOD_TooManyBinFmts
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MOD_UnregisterFormat - unregister binary format driver.
		; Input: EDX=address of tBinFmtFunctions table.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_UnregisterFormat
		mpush	ecx,edi
		mov	eax,edx
		mov	ecx,MOD_MAXBINFORMATS
		mov	edi,?BinFmtDrivers
		cld
		repne	scasd
		jnz	short .Err
		callsafe dword [edx+tBinFmtFunctions.Shutdown]
		jc	.Exit
		mov	dword [edi-4],0
.Exit:		mpop	edi,ecx
		ret

.Err:		mov	ax,ERR_MOD_BinFmtNotFound
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MOD_Insert - insert a module.
		; Input: EBX=module image start address,
		;	 EDX=module image end address,
		;	 ESI=module command line.
		; Output: CF=0 - OK, EDI=module descriptor address;
		;	  CF=1 - error, AX=error code.
proc MOD_Insert
		locals	imgstart,imgend,cmdline
		prologue
		mpush	ebx,ecx,edx
		
		mov	[%$imgstart],ebx
		mov	[%$imgend],ebx
		mov	[%$cmdline],esi
		call	MOD_CheckSignature
		jc	.Exit
		or	al,al					; Single module?
		jz	.Single

		; Otherwise, it should be an archive. EBX now addresses a
		; header of the first member.
		callsafe dword [edx+tBinFmtFunctions.GetArchMember]
		jc	.Exit
		callsafe dword [edx+tBinFmtFunctions.GetModSize]
		jc	.Exit
		
.Single:	mov	ebx,?ModulePool
		call	K_PoolAllocChunk
		jc	short .Exit
		mov	edi,esi

		mov	[edi+tModuleDesc.BinFmt],edx		; Binary format 

.Exit:		mpop	edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; MOD_Remove - unregister a module.
		; Input: EDI=module descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Remove
		mpush	ebx,edx,esi
		mov	edx,[edi+tModuleDesc.BinFmt]
		;callsafe dword [edx+tBinFmtFunctions.FreeSections]	; Unload module
		jc	.Exit					; and free its
		mov	esi,edi					; structure
		call	K_PoolFreeChunk
.Exit:		mpop	esi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; MOD_GetType - get module type.
		; Input: EDI=module descriptor address.
		; Output: CF=0 - OK, EDX=module type;
		;	  CF=1 - error, AX=error code.
proc MOD_GetType
		ret
endp		;---------------------------------------------------------------


		; MOD_GetIDbyName - get module descriptor address by name.
		; Input: ESI=module name.
		; Output: CF=0 - OK, EDI=module descriptor address.
		;	  CF=1 - error, AX=error code.
proc MOD_GetIDbyName
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---


		; MOD_CheckSignature - determine module format by its signature.
		; Input: EBX=module image address.
		; Output: CF=0 - OK:
		;		    AL=1 - this is an archive;
		;		    AL=0 - this is a single module;
		;		    EDX=address of binary format dispatch table;
		;	  CF=1 - error, AX=error code.
proc MOD_CheckSignature
		push	ecx
		xor	ecx,ecx
		
.Loop:		mov	edx,[?BinFmtDrivers+ecx*4]
		or	edx,edx
		jz	short .Next
		
		callsafe dword [edx+tBinFmtFunctions.CheckSig]
		or	al,al
		jge	short .OK
.Next:		inc	cl
		cmp	cl,MOD_MAXBINFORMATS
		je	short .Err
		mov	eax,edi
		jmp	.Loop

.OK:		clc
.Exit:		pop	ecx
		ret

.Err:		mov	ax,ERR_MOD_UnknownSignature
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------

