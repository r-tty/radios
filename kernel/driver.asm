;*******************************************************************************
;  driver.asm - RadiOS drivers control routines.
;  Copyright (c) 1998 RET & COM research.
;*******************************************************************************

include "drvctrl.ah"

; --- Definitions ---

; Driver information structure
struc tDRIVERINFO
 ID		DD	?			; Driver ID
 IntName	DB DRVNAMELEN dup (0)		; Driver name
 Entries	DD	?			; Entry points table address
 Flags		DW	?			; Flags
 ExtrnCS	DW	?			; CS selector (for externals)
 Reserved	DD	?
ends

DRVNAMESEPARATOR	EQU	'.'
DRVSTRUCSZSHIFT		EQU	5

; External driver definitions

; --- Data ---
segment KDATA
DRV_EmptyName	DB DRVNAMELEN dup (0)
DRV_NullName	DB "%null",11 dup (0)
DRV_NullEntry	DD	DrvNULL

EDRV_CodeFreeBl	DD	?
EDRV_DataFreeBl	DD	?
ends


; --- Variables ---
segment KVARS
NumInstDrivers	DD	?			; Number of installed drivers
DRV_MaxQuantity	DD	?			; Maximum number of drivers
DRV_TableHnd	DW	?			; Table block handle
DRV_TableAddr	DD	?			; Table address
ends


; --- Procedures ---

		; DRV_InitTable - initialize drivers memory blocks.
		; Input: EAX=maximum number of installed drivers.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc DRV_InitTable near
		push	ebx ecx edx esi
		mov	[DRV_MaxQuantity],eax
		mov	ecx,size tDRIVERINFO
		mul	ecx
		mov	ecx,eax
		call	KH_Alloc
		jc	short @@Exit
		mov	[DRV_TableHnd],ax
		mov	[DRV_TableAddr],ebx

		xor	eax,eax
		mov	ebx,offset DRV_NullEntry
		xor	ecx,ecx
		mov	edx,KERNELCODE
		shl	edx,16
		mov	esi,offset DRV_NullName
		call	DRV_ChangeInfo
		inc	eax
		mov	[NumInstDrivers],eax
		mov	ecx,[DRV_MaxQuantity]

@@Loop:		cmp	eax,ecx
		jae	short @@InitEDRV
		call	DRV_Uninstall
		inc	eax
		jmp	@@Loop

		; Initialize external driver variables
@@InitEDRV:	call	EDRV_InitCodeAlloc
		call	EDRV_InitDataAlloc

@@OK:		clc
@@Exit:		pop	esi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; DRV_ReleaseTable - release drivers table.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF-1 - error, AX=error code.
proc DRV_ReleaseTable near
		mov	ax,[DRV_TableHnd]
		call	KH_Free
		ret
endp		;---------------------------------------------------------------


		; DRV_GetFreeID - search free driver information structure.
		; Input: none.
		; Output: CF=0 - OK, EAX=free ID;
		;	  CF=1 - error, AX=error code.
proc DRV_GetFreeID near
		push	edx
		mov	edx,[DRV_TableAddr]
		xor	eax,eax
@@Loop:		cmp	[edx+tDRIVERINFO.ID],-1		; Free structure?
		je	short @@OK
		add	edx,size tDRIVERINFO
		inc	eax
		cmp	eax,[DRV_MaxQuantity]
		je	short @@Err
		jmp	@@Loop

@@OK:		clc
@@Exit:		pop	edx
		ret

@@Err:		mov	ax,ERR_DRV_NoIDs
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; DRV_InstallNew - install new driver.
		; Input: EBX=pointer to driver main structure;
		;	 DX=CS selector (for external) or 0 (for internal).
		; Output: CF=0 - OK, EAX=driver ID;
		;	  CF=1 - error, AX=error code.
proc DRV_InstallNew near
		call	DRV_GetFreeID
		jc	short @@Exit
		push	ebx ecx edx esi
		xor	ecx,ecx				; Reserved field=0
		or	dx,dx
		jnz	short @@Extern
		mov	dx,KERNELCODE
@@Extern:	shl	edx,16				; ExtrnCS field
		mov	dx,[ebx+tDriver.Flags]		; Flags
		lea	esi,[ebx+tDriver.DrvName]	; Name
		mov	ebx,[ebx+tDriver.Entries]	; Entries table addr
		call	DRV_ChangeInfo
		pop	esi edx ecx ebx
		jc	short @@Exit
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_Uninstall - uninstall driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX-error code.
proc DRV_Uninstall near
		cmp	eax,[DRV_MaxQuantity]
		jae	short @@Err
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	esi
		xor	ebx,ebx
		mov	edx,ebx
		mov	ecx,ebx
		mov	esi,offset DRV_EmptyName
		call	DRV_ChangeInfo
		call	DRV_GetInfoAddr
		xor	ecx,ecx
		not	ecx
		mov	[eax+tDRIVERINFO.ID],ecx
		pop	esi
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		clc
		jmp	short @@Exit
@@Err:		mov	ax,ERR_DRV_BadID
		stc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_ChangeInfo - change driver information.
		; Input: EAX=driver ID,
		;	 ESI=pointer to internal name,
		;	 EBX=entry points table address,
		;	 EDX=driver flags,
		;	 ECX=reserved information.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc DRV_ChangeInfo near
		cmp	eax,[DRV_MaxQuantity]
		jae	short @@Err
		push	esi edi ecx

		push	eax
		call	DRV_GetInfoAddr
		mov	edi,eax
		pop	eax

		mov	[edi+tDRIVERINFO.ID],eax
		mov	[edi+tDRIVERINFO.Entries],ebx
		mov	[edi+tDRIVERINFO.Reserved],ecx
		mov	[dword edi+tDRIVERINFO.Flags],edx
		add	edi,offset (tDRIVERINFO).IntName	; Prepare to
		mov	ecx,DRVNAMELEN				; copying
		shr	ecx,2					; driver name
		cld
		rep	movs [dword edi],[dword esi]
		pop	ecx edi esi
		clc
		ret
@@Err:		mov	ax,ERR_DRV_BadID
		stc
		ret
endp		;---------------------------------------------------------------


		; DRV_GetInfoAddr - get driver information structure address.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, EAX=structure address;
		;	  CF=1 - error, AX=error code.
proc DRV_GetInfoAddr near
		and	eax,0FFFFh				; Mask minor
		cmp	eax,[DRV_MaxQuantity]
		jae     short @@Err
		shl	eax,DRVSTRUCSZSHIFT
		add	eax,[DRV_TableAddr]
		clc
		ret
@@Err:		mov	ax,ERR_DRV_BadID
		stc
		ret
endp		;---------------------------------------------------------------


		; DRV_GetFlags - get driver flags.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, AX=flags;
		;	  CF=1 - error.
proc DRV_GetFlags near
		call	DRV_GetInfoAddr
		jc	short @@Exit
		mov	ax,[eax+tDRIVERINFO.Flags]
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_GetName - get pointer to driver name.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, ESI=pointer to name;
		;	  CF=1 - error.
proc DRV_GetName near
		push	eax
		call	DRV_GetInfoAddr
		jc	short @@Exit
		lea	esi,[eax+tDRIVERINFO.IntName]
@@Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; DRV_ChkInst - check whether driver installed or not.
		; Input: EAX=driver ID.
		; Output: CF=0 - driver installed,
		;	  CF=1 - invalid ID or driver not installed.
proc DRV_ChkInst near
		push	eax
		call	DRV_GetInfoAddr
		jc	short @@Exit
		cmp	[eax+tDRIVERINFO.ID],-1
		je	short @@NotInst
		clc
		jmp	short @@Exit
@@NotInst:	stc
@@Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------


		; DRV_FindName - search driver by name.
		; Input: ESI=pointer to name (ASCIIZ).
		; Output: CF=0 - OK, EAX=driver ID;
		;	  CF=1 - error (driver name or number not found).
proc DRV_FindName near
		push	ebp
		mov	ebp,esp				; Alloc space
		sub	esp,2*DRVNAMELEN		; for name buffer
		push	ebx ecx edx esi edi
		mov	edi,ebp
		sub	edi,2*DRVNAMELEN
		call	StrCopy
		call	DRV_GetMinor			; Get minor number
		jc	short @@Exit
		mov	esi,edi
		mov	edx,[DRV_TableAddr]
		xor	ecx,ecx
@@Loop:		cmp	[edx+tDRIVERINFO.ID],-1		; Free structure?
		je	short @@Err
		lea	edi,[edx+tDRIVERINFO.IntName]
		call	StrComp
		or	al,al
		jz	short @@OK
		add	edx,size tDRIVERINFO
		inc	ecx
		cmp	ecx,[DRV_MaxQuantity]
		je	short @@Err
		jmp	@@Loop
@@OK:		mov	eax,[edx+tDRIVERINFO.ID]	; Major number
		shl	ebx,16
		or	eax,ebx				; OR with minor
		clc

@@Exit:		pop	edi esi edx ecx ebx
		leave
		ret

@@Err:		mov	ax,ERR_DRV_NameNotFound
		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; DRV_GetMinor - get driver minor number from name.
		; Input: EDI=name pointer.
		; Output: CF=0 - OK, BX=minor number;
		;	  CF=1 - error.
		; Note: cuts off minor part from driver name.
proc DRV_GetMinor near
		push	eax edx esi edi
		xor	ebx,ebx
		xor	dl,dl
		dec	edi

@@Loop:		inc	edi
		inc	dl
		cmp	dl,DRVNAMELEN*2
		cmc
		jc	short @@Exit
		mov	al,[edi]
		or	al,al
		jz	short @@OK
		cmp	al,'0'
		jb	short @@Loop
		cmp	al,'9'+1
		jae	short @@Loop

		mov	edx,edi			; Store pointer in EDX
		mov	al,DRVNAMESEPARATOR
		call	StrScan			; Search separator
		or	edi,edi			; Minor2 present?
		jz	short @@Minor1
		mov	[edi],bl
		inc	edi
		mov	esi,edi
		call	ValByteDec		; Get value of minor2
		jc	short @@Exit
		mov	bh,al
@@Minor1:	mov	esi,edx
		call	ValByteDec
		jc	short @@Exit
		mov	[esi],bl
		mov	bl,al
@@OK:		clc
@@Exit:		pop	edi esi edx eax
		ret
endp		;---------------------------------------------------------------



		; DRV_CallDriver - call specified driver (Pascal-style):
		; Function DRV_CallDriver(DriverNum,DriverFun:longint):longint;
		; Input: DriverNum - full driver number;
		;	 DriverFun - function number.
		; Note: if function is "control", then high word of DriverFun
		;	is subfunction number.
proc DRV_CallDriver near

@@DriverNum	EQU	[ebp+12]			; Parameters
@@DrvMajor	EQU	[word ebp+12]
@@DrvMinor	EQU	[word ebp+14]
@@DriverFun	EQU	[word ebp+8]
@@SubFun	EQU	[word ebp+10]

@@offset	EQU	[dword ebp-8]			; Local variables
@@selector	EQU	[dword ebp-4]
@@faraddr	EQU	[fword ebp-8]

		push	ebp
		mov	ebp,esp
		pushfd					; Keep flags
		sub	esp,4
		push	eax				; Keep EAX
		push	eax
		mov	eax,[ebp-4]
		mov	[esp],eax			; Keep flags in stack

		movzx	eax,@@DrvMajor			; Driver number
		call	DRV_GetInfoAddr			; Get structure address
		jc	short @@Exit
		cmp	[eax+tDRIVERINFO.ID],-1		; Installed?
		stc
		je	short @@Exit

		push	eax
		mov	eax,[eax+tDRIVERINFO.Entries]
		mov	@@offset,eax
		movzx	eax,@@DriverFun			; Driver function
		shl	eax,2				; Count vector
		add	eax,@@offset
                mov	eax,[eax]
		cmp	@@DriverFun,DRVF_Control	; "Control" function?
		jne	short @@1
		push	esi
		movzx	esi,@@SubFun			; Count vector
		mov	eax,[eax+esi*4]
		pop	esi

@@1:		or	eax,eax				; Function present?
		jnz	short @@Present
		add	esp,8				; Restore stack
		pop	eax
		stc
		jmp	short @@Exit

@@Present:	mov	@@offset,eax
		shl	edx,16				; Load minor number
		mov	dx,@@DrvMinor			; in high word of EDX
		ror	edx,16
		pop	eax
		cmp	[eax+tDRIVERINFO.ExtrnCS],KERNELCODE
		jne	short @@Extern

		popfd					; Restore flags
		pop	eax				; Restore EAX
		call	@@offset			; Call (internal)
		jmp	short @@Exit

@@Extern:       movzx	eax,[eax+tDRIVERINFO.ExtrnCS]
		mov	@@selector,eax
		popfd					; Restore flags
		pop	eax				; Restore EAX
		call	@@faraddr			; Call (external)

@@Exit:		mov	esp,ebp
		pop	ebp
		ret	8
endp		;---------------------------------------------------------------


;---------------------- External driver support functions ----------------------


		; EDRV_GetCodeSegAddr - get base address of external drivers'
		;			code segment.
		; Input: none.
		; Output: EDI=address.
proc EDRV_GetCodeSegAddr near
		push	ebx edx
		mov	dx,EDRVCODE
		call	K_DescriptorAddress
		call	K_GetDescriptorBase
		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; EDRV_GetDataSegAddr - get base address of external drivers'
		;			data segment.
		; Input: none.
		; Output: EDI=address.
proc EDRV_GetDataSegAddr near
		push	ebx edx
		mov	dx,EDRVDATA
		call	K_DescriptorAddress
		call	K_GetDescriptorBase
		pop	edx ebx
		ret
endp		;---------------------------------------------------------------


		; EDRV_InitCodeAlloc - init code allocation variable.
		; Input: none.
		; Output: none.
proc EDRV_InitCodeAlloc near
		push	edi
		call	EDRV_GetCodeSegAddr
		mov	[EDRV_CodeFreeBl],edi
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; EDRV_InitDataAlloc - init data allocation variable.
		; Input: none.
		; Output: none.
proc EDRV_InitDataAlloc near
		push	edi
		call	EDRV_GetDataSegAddr
		mov	[EDRV_DataFreeBl],edi
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; EDRV_AllocCode - allocate block in external drivers'
		;		   code segment.
		; Input: ECX=block size.
		; Output: CF=0 - OK, EBX=block address;
		;	  CF=1 - error.
proc EDRV_AllocCode near
		mov	ebx,[EDRV_CodeFreeBl]
		add	[EDRV_CodeFreeBl],ecx
		clc
		ret
endp		;---------------------------------------------------------------


		; EDRV_AllocData - allocate block in external drivers'
		;		   data segment.
		; Input: ECX=block size.
		; Output: CF=0 - OK, EBX=block address;
		;	  CF=1 - error.
proc EDRV_AllocData near
		mov	ebx,[EDRV_DataFreeBl]
		add	[EDRV_DataFreeBl],ecx
		clc
		ret
endp		;---------------------------------------------------------------


		; EDRV_FixDrvSegLimit - fix limit of external drivers' segment
		;			by setting limit field in descriptor.
		; Input: AL=0 - fix limit of data segment;
		;	 AL=1 - fix limit of code segment.
		; Output: none.
proc EDRV_FixDrvSegLimit near
		push	eax ebx edx edi
		or	al,al
		jz	short @@DataSeg
		mov	dx,EDRVCODE
		mov	eax,[EDRV_CodeFreeBl]
		jmp	short @@CountLim

@@DataSeg:	mov	dx,EDRVDATA
		mov	eax,[EDRV_DataFreeBl]

@@CountLim:	call	K_DescriptorAddress
		call	K_GetDescriptorBase		; EDI=segment base addr.
		sub	eax,edi				; Count size of segment
		or	eax,eax				; Zero size?
		jnz	short @@SetLim			; No, set limit
		call	K_SetDescriptorAR		; Else mark segment
		jmp	short @@Exit			; as invalid

@@SetLim:	dec	eax				; Count limit
		call	K_SetDescriptorLimit		; Set limit

@@Exit:		pop	edi edx ebx eax
		ret
endp		;---------------------------------------------------------------


;----------------------- Driver service functions (DSF) ------------------------

		; DSF_Yield - yield execution of driver.
		; Input: ECX=time interval (in milliseconds).
		; Output: none.
proc DSF_Yield near
	call K_LDelayMs
		ret
endp		;---------------------------------------------------------------


		; DSF_Yield1ms - yield execution of driver thread on 1 ms.
		; Input: none.
		; Output: none.
proc DSF_Yield1ms near
	push ecx
	xor ecx,ecx
	inc ecx
	call K_LDelayMs
	pop ecx
		ret
endp		;---------------------------------------------------------------


		; DSF_Block - block thread execution.
		; Input:
		; Output:
proc DSF_Block near
		ret
endp		;---------------------------------------------------------------


		; DSF_Run - resume thread execution.
		; Input:
		; Output:
proc DSF_Run near
		ret
endp		;---------------------------------------------------------------
