;*******************************************************************************
;  module.asm - common modules support routines.
;  Copyright (c) 1999 RET & COM Research.
;*******************************************************************************

include "cfs_func.ah"
include "module.ah"

; --- Definitions ---
MOD_MAXBINFORMATS	EQU	16		; Max. number of binfmt drivers

; --- Data ---
segment KDATA
KernelModName	DB "KERNEL",0
ends

; --- Variables ---
segment KVARS
NumLoadedMods	DD	?			; Number of loaded modules
MaxNumMods	DD	?			; Maximum number of loaded mods
ModTableHnd	DW	?			; Module table block handle
ModTableAddr	DD	?			; Module table address

BinFmtDrivers	DD MOD_MAXBINFORMATS dup (0)	; Binfmt drivers IDs
ends


; --- Public routines ---

		; MOD_InitMem - initialize memory for kernel module information.
		; Input: EAX=maximum number of loaded modules.
		; Output: CF=0 - OK, EAX=0;
		;	  CF=1 - error.
proc MOD_InitMem near
		push	ebx ecx esi
		mov	[MaxNumMods],eax
		mov	ecx,size tKModInfo
		mul	ecx
		mov	ecx,eax
		call	KH_Alloc
		jc	short @@Exit
		mov	[ModTableHnd],ax
		mov	[ModTableAddr],ebx
		call	KH_FillZero
		xor	eax,eax
@@Exit:		pop	esi ecx ebx
		ret
endp		;---------------------------------------------------------------


		; MOD_InitKernelMod - initialize kernel module (module 0).
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_InitKernelMod near
		push	esi edi
		call	MOD_AllocStruc
		jc	short @@Exit
		mov	[edi+tKModInfo.Driver],0
		mov	[edi+tKModInfo.PID],0
		mov	eax,100000h
		mov	[edi+tKModInfo.Sections],eax
		mov	[edi+tKModInfo.StackSize],16384
		mov	[edi+tKModInfo.RModExportTbl],offset KRModNamesTbl
		mov	[edi+tKModInfo.Type],MODTYPE_LIBRARY
		mov	esi,offset KernelModName
		lea	edi,[edi+tKModInfo.ModName]
		call	StrCopy
		pop	edi esi
@@Exit:		ret
endp		;---------------------------------------------------------------


		; MOD_Register - register binary format driver.
		; Input: EAX=module driver ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Register near
		push	ecx edi
		xor	ecx,ecx
		mov	cl,MOD_MAXBINFORMATS
		mov	edi,offset BinFmtDrivers
		cld
		push	eax
		xor	eax,eax
		repne	scasd
		pop	eax
		jnz	short @@Err1
		mov	ecx,eax
		call	DRV_GetFlags			; Check BINFMT flag
		jc	short @@Exit
		test	ax,DRVFL_BinFmt
		jz	short @@Err2
		mCallDriver ecx,DRVF_Init		; Initialize driver
		jc	short @@Exit
		mov	[edi-4],ecx
		clc
@@Exit:		pop	edi ecx
		ret

@@Err1:		mov	ax,ERR_MOD_TooManyBinFmts
		stc
		jmp	@@Exit
@@Err2:		mov	ax,ERR_MOD_NotBinFmt
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MOD_Unregister - unregister binary format driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Unregister near
		push	ecx edi
		xor	ecx,ecx
		mov	cl,MOD_MAXBINFORMATS
		mov	edi,offset BinFmtDrivers
		cld
		repne	scasd
		jnz	short @@Err
		mov	eax,[edi-4]
		mCallDriver eax,DRVF_Done
		mov	[dword edi-4],0
		clc
@@Exit:		pop	edi ecx
		ret

@@Err:		mov	ax,ERR_MOD_BinFmtNotFound
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MOD_Load - load module in memory.
		; Input: EAX=PID,
		;	 ESI=module file name.
		; Output: CF=0 - OK, EAX=module ID;
		;	  CF=1 - error, AX=error code.
proc MOD_Load near
@@pid		EQU	ebp-4

		push	ebp
		mov	ebp,esp
		sub	esp,4
		push	ebx edx edi

		mov	[@@pid],eax
		call	MOD_CheckSignature
		jc	short @@Exit

		call	MOD_AllocStruc
		jc	short @@CloseAndExit

		mCallDriver edx,DRVF_Open			; Load module
		jc	short @@CloseAndExit
@@Resolve:	mCallDriverCtrl edx,DRVCTL_BINFMT_ResolveLinks
		jc	short @@CloseAndExit
		mov	[edi+tKModInfo.Driver],edx		; Keep driver ID
		mov	eax,[@@pid]
		mov	[edi+tKModInfo.PID],eax			; Keep PID

		call	CFS_Close
@@Exit:		pop	edi edx ebx
		mov	esp,ebp
		pop	ebp
		ret

@@CloseAndExit:	push	eax					; If failed-
		call	CFS_Close				; close file
		pop	eax					; and keep
		stc						; error code
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MOD_Unload - unload module from memory.
		; Input: EAX=module ID.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_Unload near
		push	edx
		call	MOD_GetStrucAddr
		jc	short @@Exit
                mov	edx,[edi+tKModInfo.Driver]
		mCallDriver edx,DRVF_Close			; Unload module
		jc	short @@Exit				; and free its
		call	MOD_FreeStruc				; structure
@@Exit:		pop	edx
		ret
endp		;---------------------------------------------------------------


		; MOD_GetType - get module type.
		; Input: EAX=module ID.
		; Output: CF=0 - OK, EDX=module type;
		;	  CF=1 - error, AX=error code.
proc MOD_GetType near
		ret
endp		;---------------------------------------------------------------


		; MOD_GetIDbyName - get module ID by name.
		; Input: ESI=module name.
		; Output: CF=0 - OK, EAX=module ID;
		;	  CF=1 - error, AX=error code.
proc MOD_GetIDbyName near
		ret
endp		;---------------------------------------------------------------


; --- Implementation routines ---

		; MOD_AllocStruc - allocate module information structure.
		; Input: none.
		; Output: CF=0 - OK:
		;		    EAX=module ID,
		;		    EDI=pointer to allocated structure;
		;	  CF=1 - error, AX=error code.
proc MOD_AllocStruc near
		mov	edi,[ModTableAddr]
		xor	eax,eax
@@Loop:		cmp	[dword edi],0			; Unused?
		je	short @@OK
		inc	eax
		cmp	eax,[MaxNumMods]
		je	short @@Err
		add	edi,size tKModInfo
		jmp	@@Loop
@@OK:		clc
		ret

@@Err:		mov	ax,ERR_MOD_TooManyModules
		stc
		ret
endp		;---------------------------------------------------------------


		; MOD_FreeStruc - free module information structure.
		; Input: EDI=pointer to structure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc MOD_FreeStruc near
		mov	[dword edi],0
		ret
endp		;---------------------------------------------------------------


		; MOD_GetStrucAddr - get module information structure by
		;		     module ID.
		; Input: EAX=module ID.
		; Output: CF=0 - OK, EDI=address;
		;	  CF=1 - error, AX=error code.
proc MOD_GetStrucAddr near
		cmp	eax,[MaxNumMods]
		jae	short @@Err
		push	edx
		mov	edi,size tKModInfo
		mul	edi
		pop	edx
		add	eax,[ModTableAddr]
		mov	edi,eax
		ret

@@Err:		mov	ax,ERR_MOD_BadID
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
proc MOD_CheckSignature near
		push	ecx
		xor	dx,dx					; Open file
		call	CFS_Open
		jc	short @@Exit

		xor	ecx,ecx
@@Loop:		mov	edx,[offset BinFmtDrivers+ecx*4]
		or	edx,edx
		jz	short @@Next
		mCallDriverCtrl edx,DRVCTL_BINFMT_CheckSignature
		jnc	short @@OK
@@Next:		inc	cl
		cmp	cl,MOD_MAXBINFORMATS
		je	short @@Err1
		mov	eax,edi
		jmp	@@Loop

@@OK:		clc
@@Exit:		pop	ecx
		ret

@@Err1:		call	CFS_Close				; Close file
		jc	@@Exit
		mov	ax,ERR_MOD_UnknownSignature
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MOD_ResolveForEach - resolve undefined links in all modules.
		; Input: none.
		; Output: none.
proc MOD_ResolveForEach near
		mov	edi,[ModTableAddr]
		xor	eax,eax
@@Loop:		cmp	[dword edi],0
		je	short @@Next
		mCallDriverCtrl [edi+tKModInfo.Driver],DRVCTL_BINFMT_ResolveULinks
@@Next:		inc	eax
		cmp	eax,[MaxNumMods]
		je	short @@Exit
		add	edi,size tKModInfo
		jmp	@@Loop
@@Exit:		pop	edi
		ret
endp		;---------------------------------------------------------------
