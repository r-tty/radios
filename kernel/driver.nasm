;*******************************************************************************
;  driver.nasm - RadiOS drivers management.
;  Copyright (c) 1999 RET & COM research.
;*******************************************************************************

module kernel.driver

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "drvctrl.ah"


; --- Exports ---

global DRV_InitTable, DRV_ReleaseTable
global DRV_InstallNew, DRV_GetFlags, DRV_GetName
global DRV_FindName, DRV_CallDriver

global DSF_Block, DSF_Run
global DSF_Yield, DSF_Yield1ms


; --- Imports ---

library kernel
extern K_DescriptorAddress:near
extern K_GetDescriptorBase:near
extern K_SetDescriptorLimit:near, K_SetDescriptorAR:near

library kernel.misc
extern StrCopy:near, StrComp:near, StrScan:near
extern ValByteDec:near
extern K_LDelayMs:near

library kernel.paging
extern PG_AllocContBlock:near


; --- Definitions ---

; Driver information structure
struc tKDriver
.ID		RESD	1			; Driver ID
.IntName	RESB	DRVNAMELEN		; Driver name
.Entries	RESD	1			; Entry points table address
.Flags		RESW	1			; Flags
.ExtrnCS	RESW	1			; CS selector (for externals)
.Reserved	RESD	1
endstruc

%define	DRVSTRUCSZSHIFT		5
%define	DRVNAMESEPARATOR	'.'


; --- Data ---

section .data

DRV_EmptyName	TIMES	DRVNAMELEN DB 0
DRV_NullName	DB	"%null"
		TIMES	16-$+DRV_NullName DB 0


; --- Variables ---

section .bss

?NumInstDrivers	RESD	1			; Number of installed drivers
?MaxDrivers	RESD	1			; Maximum number of drivers
?TableAddr	RESD	1			; Table address


; --- Procedures ---

section .text

		; DRV_InitTable - initialize drivers memory blocks.
		; Input: EAX=maximum number of installed drivers.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc DRV_InitTable
		mpush	ebx,ecx,edx,esi
		mov	[?MaxDrivers],eax
		mov	ecx,tKDriver_size
		mul	ecx
		mov	ecx,eax
		xor	dl,dl
		call	PG_AllocContBlock
		jc	short .Exit
		mov	[?TableAddr],ebx

		xor	eax,eax
		xor	ebx,ebx
		xor	ecx,ecx
		mov	edx,KERNELCODE
		shl	edx,16
		mov	esi,DRV_NullName
		call	DRV_ChangeInfo
		inc	eax
		mov	[?NumInstDrivers],eax
		mov	ecx,[?MaxDrivers]

.Loop:		cmp	eax,ecx
		jae	short .OK
		call	DRV_Uninstall
		inc	eax
		jmp	.Loop

.OK:		clc
.Exit:		mpop	esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; DRV_GetFreeID - find a slot for new driver.
		; Input: none.
		; Output: CF=0 - OK, EAX=ID of free slot;
		;	  CF=1 - error, AX=error code.
proc DRV_GetFreeID
		push	edx
		mov	edx,[?TableAddr]
		xor	eax,eax
.Loop:		cmp	dword [edx+tKDriver.ID],-1	; Free structure?
		je	short .OK
		add	edx,tKDriver_size
		inc	eax
		cmp	eax,[?MaxDrivers]
		je	short .Err
		jmp	.Loop

.OK:		clc
.Exit:		pop	edx
		ret

.Err:		mov	ax,ERR_DRV_NoIDs
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; DRV_InstallNew - install new driver.
		; Input: EBX=pointer to driver main structure;
		;	 DX=CS selector (for external) or 0 (for internal).
		; Output: CF=0 - OK, EAX=driver ID;
		;	  CF=1 - error, AX=error code.
proc DRV_InstallNew
		call	DRV_GetFreeID
		jc	short .Exit
		mpush	ebx,ecx,edx,esi
		xor	ecx,ecx				; Reserved field=0
		or	dx,dx
		jnz	short .Extern
		mov	dx,KERNELCODE
.Extern:	shl	edx,16				; ExtrnCS field
		mov	dx,[ebx+tDriver.Flags]		; Flags
		lea	esi,[ebx+tDriver.DrvName]	; Name
		mov	ebx,[ebx+tDriver.Entries]	; Entries table addr
		call	DRV_ChangeInfo
		mpop	esi,edx,ecx,ebx
		jc	short .Exit
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_Uninstall - uninstall driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX-error code.
proc DRV_Uninstall
		cmp	eax,[?MaxDrivers]
		jae	short .Err
		mpush	eax,ebx,ecx,edx,esi
		xor	ebx,ebx
		mov	edx,ebx
		mov	ecx,ebx
		mov	esi,DRV_EmptyName
		call	DRV_ChangeInfo
		call	DRV_GetInfoAddr
		xor	ecx,ecx
		not	ecx
		mov	[eax+tKDriver.ID],ecx
		mpop	esi,edx,ecx,ebx,eax
		clc
		jmp	short .Exit
.Err:		mov	ax,ERR_DRV_BadID
		stc
.Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_ChangeInfo - change driver information.
		; Input: EAX=driver ID,
		;	 ESI=pointer to internal name,
		;	 EBX=entry points table address,
		;	 EDX=driver flags,
		;	 ECX=reserved information.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc DRV_ChangeInfo
		cmp	eax,[?MaxDrivers]
		jae	short .Err
		mpush	esi,edi,ecx

		push	eax
		call	DRV_GetInfoAddr
		mov	edi,eax
		pop	eax

		mov	[edi+tKDriver.ID],eax
		mov	[edi+tKDriver.Entries],ebx
		mov	[edi+tKDriver.Reserved],ecx
		mov	[edi+tKDriver.Flags],edx
		add	edi,tKDriver.IntName			; Prepare to
		mov	ecx,DRVNAMELEN				; copying
		shr	ecx,2					; driver name
		cld
		rep	movsd
		mpop	ecx,edi,esi
		clc
		ret
.Err:		mov	ax,ERR_DRV_BadID
		stc
		ret
endp		;---------------------------------------------------------------


		; DRV_GetInfoAddr - get driver information structure address.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, EAX=structure address;
		;	  CF=1 - error, AX=error code.
proc DRV_GetInfoAddr
		and	eax,0FFFFh				; Mask minor
		cmp	eax,[?MaxDrivers]
		jae     short .Err
		shl	eax,DRVSTRUCSZSHIFT
		add	eax,[?TableAddr]
		clc
		ret
.Err:		mov	ax,ERR_DRV_BadID
		stc
		ret
endp		;---------------------------------------------------------------


		; DRV_GetFlags - get driver flags.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, AX=flags;
		;	  CF=1 - error.
proc DRV_GetFlags
		call	DRV_GetInfoAddr
		jc	short .Exit
		mov	ax,[eax+tKDriver.Flags]
.Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_GetName - get pointer to driver name.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, ESI=pointer to name;
		;	  CF=1 - error.
proc DRV_GetName
		push	eax
		call	DRV_GetInfoAddr
		jc	short .Exit
		lea	esi,[eax+tKDriver.IntName]
.Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; DRV_ChkInst - check whether driver installed or not.
		; Input: EAX=driver ID.
		; Output: CF=0 - driver installed,
		;	  CF=1 - invalid ID or driver not installed.
proc DRV_ChkInst
		push	eax
		call	DRV_GetInfoAddr
		jc	short .Exit
		cmp	dword [eax+tKDriver.ID],-1
		je	short .NotInst
		clc
		jmp	short .Exit
.NotInst:	stc
.Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; DRV_FindName - search driver by name.
		; Input: ESI=pointer to name (ASCIIZ).
		; Output: CF=0 - OK, EAX=driver ID;
		;	  CF=1 - error (driver name or number not found).
proc DRV_FindName
		prologue 2*DRVNAMELEN
		mpush	ebx,ecx,edx,esi,edi
		mov	edi,ebp
		sub	edi,2*DRVNAMELEN
		call	StrCopy
		call	DRV_GetMinor			; Get minor number
		jc	short .Exit
		mov	esi,edi
		mov	edx,[?TableAddr]
		xor	ecx,ecx
.Loop:		cmp	dword [edx+tKDriver.ID],-1	; Free structure?
		je	short .Err
		lea	edi,[edx+tKDriver.IntName]
		call	StrComp
		or	al,al
		jz	short .OK
		add	edx,tKDriver_size
		inc	ecx
		cmp	ecx,[?MaxDrivers]
		je	short .Err
		jmp	.Loop
.OK:		mov	eax,[edx+tKDriver.ID]	; Major number
		shl	ebx,16
		or	eax,ebx				; OR with minor
		clc

.Exit:		mpop	edi,esi,edx,ecx,ebx
		epilogue
		ret

.Err:		mov	ax,ERR_DRV_NameNotFound
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; DRV_GetMinor - get driver minor number from name.
		; Input: EDI=name pointer.
		; Output: CF=0 - OK, BX=minor number;
		;	  CF=1 - error.
		; Note: cuts off minor part from driver name.
proc DRV_GetMinor
		mpush	eax,edx,esi,edi
		xor	ebx,ebx
		xor	dl,dl
		dec	edi

.Loop:		inc	edi
		inc	dl
		cmp	dl,DRVNAMELEN*2
		cmc
		jc	short .Exit
		mov	al,[edi]
		or	al,al
		jz	short .OK
		cmp	al,'0'
		jb	short .Loop
		cmp	al,'9'+1
		jae	short .Loop

		mov	edx,edi				; Store pointer in EDX
		mov	al,DRVNAMESEPARATOR
		call	StrScan				; Search separator
		or	edi,edi				; Minor2 present?
		jz	short .Minor1
		mov	[edi],bl
		inc	edi
		mov	esi,edi
		call	ValByteDec			; Get value of minor2
		jc	short .Exit
		mov	bh,al
.Minor1:	mov	esi,edx
		call	ValByteDec
		jc	short .Exit
		mov	[esi],bl
		mov	bl,al
.OK:		clc
.Exit:		mpop	edi,esi,edx,eax
		ret
endp		;---------------------------------------------------------------



		; DRV_CallDriver - call specified driver (Pascal-style):
		; Function DRV_CallDriver(DriverNum,DriverFun:longint):longint;
		; Input: DriverNum - full driver number;
		;	 DriverFun - function number.
		; Note: if function is "control", then high word of DriverFun
		;	is subfunction number.
proc DRV_CallDriver
%define	.DriverNum	ebp+12				; Parameters
%define	.DrvMajor	ebp+12
%define	.DrvMinor	ebp+14
%define	.DriverFun	ebp+8
%define	.SubFun		ebp+10

%define	.selector	ebp-4
%define	.offset		ebp-8				; Local variables

		prologue 0
		pushfd					; Keep flags
		sub	esp,4
		push	eax				; Keep EAX
		push	eax
		mov	eax,[ebp-4]
		mov	[esp],eax			; Keep flags in stack

		movzx	eax,word [.DrvMajor]		; Driver number
		call	DRV_GetInfoAddr			; Get structure address
		jc	short .Exit
		cmp	dword [eax+tKDriver.ID],-1	; Installed?
		stc
		je	short .Exit

		push	eax
		mov	eax,[eax+tKDriver.Entries]
		mov	[.offset],eax
		movzx	eax,word [.DriverFun]		; Driver function
		shl	eax,2				; Count vector
		add	eax,[.offset]
                mov	eax,[eax]
		cmp	word [.DriverFun],DRVF_Control ; Control function?
		jne	short .1
		push	esi
		movzx	esi,word [.SubFun]		; Count vector
		mov	eax,[eax+esi*4]
		pop	esi

.1:		or	eax,eax				; Function present?
		jnz	short .Present
		add	esp,8				; Restore stack
		pop	eax
		stc
		jmp	short .Exit

.Present:	mov	[.offset],eax
		shl	edx,16				; Load minor number
		mov	dx,word [.DrvMinor]		; in high word of EDX
		ror	edx,16
		pop	eax
		cmp	word [eax+tKDriver.ExtrnCS],KERNELCODE
		jne	short .Extern

		popfd					; Restore flags
		pop	eax				; Restore EAX
		call	dword [.offset]			; Call (internal)
		jmp	short .Exit

.Extern:	movzx	eax,word [eax+tKDriver.ExtrnCS]
		mov	[.selector],eax
		popfd					; Restore flags
		pop	eax				; Restore EAX
		call	dword far [.offset]		; Call (external)

.Exit:		epilogue
		ret	8
endp		;---------------------------------------------------------------

