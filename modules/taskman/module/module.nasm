;*******************************************************************************
; module.nasm - module handling routines.
; Copyright (c) 2000-2002 RET & COM Research.
;*******************************************************************************

module tm.module

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "pool.ah"
%include "thread.ah"
%include "tm/binfmt.ah"


; --- Exports ---

publicproc TM_InitModules, TM_IterateModList
publicproc TM_RegisterBinFmt, TM_UnregisterBinFmt
publicproc TM_LoadModule, TM_UnloadModule
publicproc TM_GetModType, TM_GetModIdByName


; --- Imports ---

library tm.proc
extern ?ProcListPtr
extern TM_NewProcess

library tm.svcif
externproc PoolInit
externproc PoolAllocChunk, PoolFreeChunk

library $libc
importproc _strchr, _strend, _strcpy, _strncmp

; --- Definitions ---

%define	MOD_MAXBINFORMATS	16		; Max. number of BinFmt drivers


; --- Variables ---

section .bss

?NumLoadedMods	RESD	1			; Number of loaded modules
?MaxModules	RESD	1			; Maximum number of loaded mods
?ModulePool	RESB	tMasterPool_size	; Modules master pool
?ModListHead	RESD	1			; Head of module list

?BinFmtDrivers	RESD	MOD_MAXBINFORMATS	; Binfmt entries


; --- Procedures ---

section .text

		; TM_InitModules - initialize modules management.
		; Input: EAX=maximum number of loaded modules,
		;	 ESI=address of boot modules descriptors array
		;	     (0 if no modules present).
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_InitModules
		mov	[?MaxModules],eax
		xor	ecx,ecx
		mov	[?ModListHead],ecx
		mov	ebx,?ModulePool
		mov	cl,tModule_size
		call	PoolInit
		jc	.Exit
		
		or	esi,esi
		jz	.Exit
		cld

		; Create module descriptor linked list for boot modules
.Loop:		push	esi
		call	PoolAllocChunk
		mov	edi,esi
		pop	esi
		jc	near .Exit
		mov	edx,edi
		mov	cl,tModule_size
		rep	movsb
		mEnqueue dword [?ModListHead], Next, Prev, edx, tModule
		cmp	dword [esi+tModule.Size],0
		jnz	.Loop
		clc

.Exit:		ret
endp		;---------------------------------------------------------------


		; TM_InterateModList - iterate through module list applying
		;			the function.
		; Input: EDX=function address.
		; Output: CF=0 - OK, all modules have been processed;
		;	  CF=1 - function error, AX=error code.
proc TM_IterateModList
		push	ebx
		mov	ebx,[?ModListHead]
.Loop:		or	ebx,ebx
		jz	.Exit
		call	edx
		jc	.Exit
.Next:		mov	ebx,[ebx+tModule.Next]
		jmp	.Loop
.Exit:		pop	ebx
		ret
endp		;---------------------------------------------------------------


		; TM_RegisterBinFmt - register binary format driver.
		; Input: EDX=address of tBinFmtFunctions table.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_RegisterBinFmt
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


		; TM_UnregisterBinFmt - unregister binary format driver.
		; Input: EDX=address of tBinFmtFunctions table.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_UnregisterBinFmt
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


		; TM_LoadModule - load a module.
		; Input: EBX=module image start address,
		;	 ECX=module image size,
		;	 ESI=module command line.
		; Output: CF=0 - OK, EDI=module descriptor address;
		;	  CF=1 - error, AX=error code.
		; Note: it's possible to load the whole archive - this routine
		;	uses recursion. When the whole archive was loaded,
		;	EDI returns the descriptor of the last module.
proc TM_LoadModule
		locals	imgstart,imgend,cmdline
		locals	moduledesc, bfdesc
		prologue
		mpush	ebx,ecx,edx,esi

		mov	[%$imgstart],ebx
		lea	eax,[ebx+ecx]
		mov	[%$imgend],eax
		mov	[%$cmdline],esi
		call	MOD_CheckSignature
		jc	near .Exit
		mov	[%$bfdesc],edx
		or	al,al					; Single module?
		jz	.Single

		; Otherwise, it should be an archive. EBX now addresses a
		; header of the first member.
.LibLoop: 	callsafe dword [edx+tBinFmtFunctions.GetArchMember]
		jc	near .Exit
		callsafe dword [edx+tBinFmtFunctions.GetModSize]
		jc	near .Exit
		call	TM_LoadModule
		jc	near .Exit
		add	ebx,ecx
		cmp	ebx,[%$imgend]
		jae	near .Exit
		jmp	.LibLoop
		
.Single:	callsafe dword [edx+tBinFmtFunctions.GetModType]
		jc	near .Exit

		; DX now contains module type. We'll use it later.
		mov	ebx,?ModulePool
		call	PoolAllocChunk
		jc	near .Exit
		mov	[%$moduledesc],esi

		; Trim absolute path off module name
		mov	edi,[%$cmdline]
		cmp	byte [edi],'/'
		jne	.CopyModName
		mov	al,' '
		Ccall	_strchr, edi, eax
		or	eax,eax
		jz	.NoArgs
		mov	byte [eax],0
		jmp	.TrimPathLoop
.NoArgs:	Ccall	_strend, dword [%$cmdline]
.TrimPathLoop:	dec	eax
		cmp	byte [eax],'/'
		jne	.TrimPathLoop
		inc	eax
		mov	[%$cmdline],eax
		
		; Copy module name (argv[0])
.CopyModName:	lea	esi,[esi+tModule.Name]
		xchg	esi,edi
		Ccall	_strcpy, esi, edi
		
		mov	edi,[%$moduledesc]
		mov	[edi+tModule.Type],dl

		; If the module is executable - create a new process
		mov	esi,[?ProcListPtr]
		cmp	dl,MODTYPE_KERNEL
		je	.LoadMod
		cmp	dl,MODTYPE_LIBRARY
		je	.LoadMod
		cmp	dl,MODTYPE_EXECUTABLE
		jne	.Err1
		call	TM_NewProcess
		jc	.Exit

		; Load sections and fill in appropriate fields
.LoadMod:	mov	ebx,[%$imgstart]
		xor	edx,edx
		mov	eax,[%$bfdesc]
		call	dword [eax+tBinFmtFunctions.LoadModule]
		jc	.Exit
		
		; Fill in some other fields of module descriptor
		mov	edx,[%$bfdesc]
		mov	[edi+tModule.BinFmt],edx		; Binary format
		
		; Put module descriptor into a linked list
		mEnqueue dword [?ModListHead], Next, Prev, edi, tModule
		clc

.Exit:		mpop	esi,edx,ecx,ebx
		epilogue
		ret

.Err1:		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; TM_UnloadModule - unload the module.
		; Input: EDI=module descriptor address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_UnloadModule
		mpush	ebx,edx,esi
		mov	edx,[edi+tModule.BinFmt]
		;callsafe dword [edx+tBinFmtFunctions.FreeSections]
		;jc	.Exit
		mDequeue dword [?ModListHead], Next, Prev, edi, tModule
		mov	esi,edi
		call	PoolFreeChunk
.Exit:		mpop	esi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; TM_GetModType - get module type.
		; Input: EDI=module descriptor address.
		; Output: CF=0 - OK, EDX=module type;
		;	  CF=1 - error, AX=error code.
proc TM_GetModType
		ret
endp		;---------------------------------------------------------------


		; TM_GetModIdByName - get module descriptor address by name.
		; Input: ESI=module name.
		; Output: CF=0 - OK, EDI=module descriptor address.
		;	  CF=1 - error, AX=error code.
proc TM_GetModIdByName
		mpush	ebx,ecx
		xor	ecx,ecx
		mov	ebx,[?ModListHead]
.Loop:		or	ebx,ebx
		jz	.NotFound
		lea	edi,[ebx+tModule.Name]
		mov	cl,MAXMODNAMELEN
		cld
		push	esi
		repe	cmpsb
		pop	esi
		je	.Found
		cmp	byte [edi-1],0
		je	.Found
		mov	ebx,[ebx+tModule.Next]
		jmp	.Loop

.NotFound:	mov	ax,ERR_MOD_NotFound
		stc
.Exit:		mpop	ecx,ebx
		ret

.Found:		mov	edi,ebx
		clc
		jmp	.Exit
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

