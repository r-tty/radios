;*******************************************************************************
;  module.as - RadiOS module primitives.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

module kernel.module

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "pool.ah"
%include "driver.ah"
%include "drvctrl.ah"


; --- Exports ---

global MOD_InitMem, MOD_InitKernelMod
global MOD_RegisterFormat, MOD_UnregisterFormat
global MOD_Insert, MOD_Remove
global MOD_GetType, MOD_GetIDbyName


; --- Imports ---

library kernel.misc
extern StrCopy:near

library kernel.driver
extern DRV_CallDriver:near, DRV_GetFlags:near

library kernel.pool
extern K_PoolInit:near
extern K_PoolAllocChunk:near, K_PoolFreeChunk:near

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

?BinFmtDrivers	RESD	MOD_MAXBINFORMATS	; Binfmt drivers IDs


; --- Procedures ---

section .text

		; MOD_InitMem - initialize modules management.
		; Input: EAX=maximum number of loaded modules.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_InitMem
		mov	[?MaxModules],eax
		mov	ebx,?ModulePool
		mov	ecx,tKModInfo_size
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
		mov	dword [esi+tKModInfo.Driver],0
		mov	dword [esi+tKModInfo.PCB],0
		mov	eax,100000h
		mov	[esi+tKModInfo.Sections],eax
		mov	dword [esi+tKModInfo.StackSize],8000h
		mov	byte [esi+tKModInfo.Type],MODTYPE_LIBRARY
		lea	edi,[esi+tKModInfo.ModName]
		mov	esi,KernelModName
		call	StrCopy
.Exit:		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; MOD_RegisterFormat - register binary format driver.
		; Input: EAX=module driver ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_RegisterFormat
		mpush	ecx,edi
		xor	ecx,ecx
		mov	cl,MOD_MAXBINFORMATS
		mov	edi,?BinFmtDrivers
		cld
		push	eax
		xor	eax,eax
		repne	scasd
		pop	eax
		jnz	short .Err1
		mov	ecx,eax
		call	DRV_GetFlags			; Check BINFMT flag
		jc	short .Exit
		test	ax,DRVFL_BinFmt
		jz	short .Err2
		mCallDriver ecx, byte DRVF_Init		; Initialize driver
		jc	short .Exit
		mov	[edi-4],ecx
		clc
.Exit:		mpop	edi,ecx
		ret

.Err1:		mov	ax,ERR_MOD_TooManyBinFmts
		stc
		jmp	.Exit
.Err2:		mov	ax,ERR_MOD_NotBinFmt
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MOD_UnregisterFormat - unregister binary format driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_UnregisterFormat
		mpush	ecx,edi
		xor	ecx,ecx
		mov	cl,MOD_MAXBINFORMATS
		mov	edi,?BinFmtDrivers
		cld
		repne	scasd
		jnz	short .Err
		mCallDriver dword [edi-4], byte DRVF_Done
		mov	dword [edi-4],0
		clc
.Exit:		mpop	edi,ecx
		ret

.Err:		mov	ax,ERR_MOD_BinFmtNotFound
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MOD_Insert - register and link a module.
		; Input: EBX=module image address;
		;	 ESI=PCB address.
		; Output: CF=0 - OK, EAX=module ID;
		;	  CF=1 - error, AX=error code.
proc MOD_Insert
	ret
	int3
		mpush	ebx,edx,edi

		call	MOD_CheckSignature
		jc	short .Exit

		mov	ebx,?ModulePool
		call	K_PoolAllocChunk
		jc	short .Exit
		mov	edi,esi

		mCallDriver edx, byte DRVF_Open			; Load module
		jc	short .Exit
.Resolve:	mCallDriverCtrl edx,DRVCTL_BINFMT_ResolveLinks
		jc	short .Exit
		mov	[edi+tKModInfo.Driver],edx		; Save driver ID
		;mov	[edi+tKModInfo.PCB],esi

.Exit:		mpop	edi,edx,ebx
		ret
endp		;---------------------------------------------------------------


		; MOD_Remove - unregister a module.
		; Input: EDI=module information structure address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Remove
		mpush	edx,esi
                mov	edx,[edi+tKModInfo.Driver]
		mCallDriver edx, byte DRVF_Close		; Unload module
		jc	short .Exit				; and free its
		mov	esi,edi					; structure
		call	K_PoolFreeChunk
.Exit:		mpop	esi,edx
		ret
endp		;---------------------------------------------------------------


		; MOD_GetType - get module type.
		; Input: EAX=module ID.
		; Output: CF=0 - OK, EDX=module type;
		;	  CF=1 - error, AX=error code.
proc MOD_GetType
		ret
endp		;---------------------------------------------------------------


		; MOD_GetIDbyName - get module ID by name.
		; Input: ESI=module name.
		; Output: CF=0 - OK, EAX=module ID;
		;	  CF=1 - error, AX=error code.
proc MOD_GetIDbyName
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---


		; MOD_CheckSignature - determine module format by its signature.
		; Input: EAX=PID,
		;	 ESI=pointer to file name.
		; Output: CF=0 - OK:
		;		    EBX=opened file handle,
		;		    EDX=module driver ID;
		;	  CF=1 - error, AX=error code.
		; Note: closes file if signature is not detected.
proc MOD_CheckSignature
		push	ecx
		xor	dx,dx					; Open file
	;	call	CFS_Open		;XXX
		jc	short .Exit

		xor	ecx,ecx
.Loop:		mov	edx,[?BinFmtDrivers+ecx*4]
		or	edx,edx
		jz	short .Next
		mCallDriverCtrl edx,DRVCTL_BINFMT_CheckSignature
		jnc	short .OK
.Next:		inc	cl
		cmp	cl,MOD_MAXBINFORMATS
		je	short .Err1
		mov	eax,edi
		jmp	.Loop

.OK:		clc
.Exit:		pop	ecx
		ret

.Err1:	;	call	CFS_Close	;XXX			; Close file
		jc	.Exit
		mov	ax,ERR_MOD_UnknownSignature
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MOD_ResolveForEach - resolve undefined links in all modules.
		; Input: none.
		; Output: none.
proc MOD_ResolveForEach
		push	edi
		mov	edi,[?ModListHead]
.Loop:		mCallDriverCtrl dword [edi+tKModInfo.Driver],DRVCTL_BINFMT_ResolveULinks
		mov	edi,[edi+tKModInfo.Next]
		cmp	edi,[?ModListHead]
		jne	short .Loop
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------
