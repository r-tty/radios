;*******************************************************************************
;  module.as - RadiOS module primitives.
;  Copyright (c) 1999,2000 RET & COM Research.
;*******************************************************************************

module kernel.module

%include "sys.ah"
%include "errors.ah"
%include "module.ah"
%include "driver.ah"
%include "drvctrl.ah"


; --- Exports ---

global MOD_InitMem, MOD_InitKernelMod
global MOD_Register, MOD_Unregister
global MOD_Load, MOD_Unload
global MOD_GetType, MOD_GetIDbyName


; --- Imports ---

library kernel.misc
extern StrCopy:near, BZero:near

library kernel.driver
extern DRV_CallDriver:near, DRV_GetFlags:near

library kernel.paging
extern PG_AllocContBlock:near

; --- Definitions ---

%define	MOD_MAXBINFORMATS	16		; Max. number of binfmt drivers


; --- Data ---

section .data

KernelModName	DB	"kernel",0


; --- Variables ---

section .bss

NumLoadedMods	RESD	1			; Number of loaded modules
MaxNumMods	RESD	1			; Maximum number of loaded mods
ModTableAddr	RESD	1			; Module table address

BinFmtDrivers	RESD	MOD_MAXBINFORMATS	; Binfmt drivers IDs


; --- Procedures ---

section .text

		; MOD_InitMem - initialize memory for kernel module information.
		; Input: EAX=maximum number of loaded modules.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error.
proc MOD_InitMem
		mpush	ebx,ecx,esi
		mov	[MaxNumMods],eax
		mov	ecx,tKModInfo_size
		mul	ecx
		mov	ecx,eax
		xor	dl,dl
		call	PG_AllocContBlock
		jc	short .Exit
		mov	[ModTableAddr],ebx
		call	BZero
		xor	eax,eax
.Exit:		mpop	esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; MOD_InitKernelMod - initialize kernel module (module 0).
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_InitKernelMod
		mpush	esi,edi
		call	MOD_AllocStruc
		jc	short .Exit
		mov	dword [edi+tKModInfo.Driver],0
		mov	dword [edi+tKModInfo.PID],0
		mov	eax,100000h
		mov	[edi+tKModInfo.Sections],eax
		mov	dword [edi+tKModInfo.StackSize],8000h
		mov	byte [edi+tKModInfo.Type],MODTYPE_LIBRARY
		mov	esi,KernelModName
		lea	edi,[edi+tKModInfo.ModName]
		call	StrCopy
		mpop	edi,esi
.Exit:		ret
endp		;---------------------------------------------------------------


		; MOD_Register - register binary format driver.
		; Input: EAX=module driver ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Register
		mpush	ecx,edi
		xor	ecx,ecx
		mov	cl,MOD_MAXBINFORMATS
		mov	edi,offset BinFmtDrivers
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


		; MOD_Unregister - unregister binary format driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Unregister
		mpush	ecx,edi
		xor	ecx,ecx
		mov	cl,MOD_MAXBINFORMATS
		mov	edi,BinFmtDrivers
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


		; MOD_Load - load module in memory.
		; Input: EAX=PID,
		;	 ESI=module file name.
		; Output: CF=0 - OK, EAX=module ID;
		;	  CF=1 - error, AX=error code.
proc MOD_Load
%define	.pid		ebp-4

		prologue 4
		mpush	ebx,edx,edi

		mov	[.pid],eax
		call	MOD_CheckSignature
		jc	short .Exit

		call	MOD_AllocStruc
		jc	short .CloseAndExit

		mCallDriver edx, byte DRVF_Open			; Load module
		jc	short .CloseAndExit
.Resolve:	mCallDriverCtrl edx,DRVCTL_BINFMT_ResolveLinks
		jc	short .CloseAndExit
		mov	[edi+tKModInfo.Driver],edx		; Keep driver ID
		mov	eax,[.pid]
		mov	[edi+tKModInfo.PID],eax			; Keep PID

	;	call	CFS_Close	;XXX
.Exit:		mpop	edi,edx,ebx
		epilogue
		ret

.CloseAndExit:	push	eax					; If failed-
	;	call	CFS_Close	;XXX			; close file
		pop	eax					; and keep
		stc						; error code
		jmp	.Exit
endp		;---------------------------------------------------------------


		; MOD_Unload - unload module from memory.
		; Input: EAX=module ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Unload
		push	edx
		call	MOD_GetStrucAddr
		jc	short .Exit
                mov	edx,[edi+tKModInfo.Driver]
		mCallDriver edx, byte DRVF_Close		; Unload module
		jc	short .Exit				; and free its
		call	MOD_FreeStruc				; structure
.Exit:		pop	edx
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

		; MOD_AllocStruc - allocate module information structure.
		; Input: none.
		; Output: CF=0 - OK:
		;		    EAX=module ID,
		;		    EDI=pointer to allocated structure;
		;	  CF=1 - error, AX=error code.
proc MOD_AllocStruc
		mov	edi,[ModTableAddr]
		xor	eax,eax
.Loop:		cmp	dword [edi],0			; Unused?
		je	short .OK
		inc	eax
		cmp	eax,[MaxNumMods]
		je	short .Err
		add	edi,tKModInfo_size
		jmp	.Loop
.OK:		clc
		ret

.Err:		mov	ax,ERR_MOD_TooManyModules
		stc
		ret
endp		;---------------------------------------------------------------


		; MOD_FreeStruc - free module information structure.
		; Input: EDI=pointer to structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_FreeStruc
		mov	dword [edi],0
		ret
endp		;---------------------------------------------------------------


		; MOD_GetStrucAddr - get module information structure by
		;		     module ID.
		; Input: EAX=module ID.
		; Output: CF=0 - OK, EDI=address;
		;	  CF=1 - error, AX=error code.
proc MOD_GetStrucAddr
		cmp	eax,[MaxNumMods]
		jae	short .Err
		push	edx
		mov	edi,tKModInfo_size
		mul	edi
		pop	edx
		add	eax,[ModTableAddr]
		mov	edi,eax
		ret

.Err:		mov	ax,ERR_MOD_BadID
		stc
		ret
endp		;---------------------------------------------------------------


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
.Loop:		mov	edx,[offset BinFmtDrivers+ecx*4]
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
		mov	edi,[ModTableAddr]
		xor	eax,eax
.Loop:		cmp	dword [edi],0
		je	short .Next
		mCallDriverCtrl dword [edi+tKModInfo.Driver],DRVCTL_BINFMT_ResolveULinks
.Next:		inc	eax
		cmp	eax,[MaxNumMods]
		je	short .Exit
		add	edi,tKModInfo_size
		jmp	.Loop
.Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------
