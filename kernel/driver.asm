;*******************************************************************************
;  drivers.asm - RadiOS drivers control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

include "drvctrl.ah"

; --- Definitions ---

; Driver information structure
struc tDRIVERINFO
 ID		DD	?			; Driver ID
 IntName	DB DRVNAMELEN dup (0)		; Driver name
 Entries	DD	?			; Entry points table address
 ExtrnCS	DW	?			; CS selector (for externals)
 Flags		DW	?			; Flags
 Reserved	DD	?
ends

; --- Data ---
EMPTYDRVNAME	DB DRVNAMELEN dup (0)


; --- Variables ---
NumInstDrivers	DD	1			; Number of installed drivers

; Table of driver information structures
; *** WARNING: driver names (in quotes) are completed with NULL characters.
; *** Don't change!
DriversTable	tDRIVERINFO <DRVID_Null,    "%null           ",offset DrvNULL,0,0>
		tDRIVERINFO MAXNUMDRIVERS-1 dup (<-1,"                ",offset DrvNULL,0,0>)


; --- Procedures ---

		; DRV_GetFreeID - search free driver information structure.
		; Input: none.
		; Output: CF=0 - OK, EAX=free ID;
		;	  CF=1 - error, AX=error code.
proc DRV_GetFreeID near
		push	ecx
		push	edx
		mov	edx,offset DriversTable
		xor	eax,eax
@@Loop:		cmp	[(tDRIVERINFO ptr edx).ID],-1	; Free structure?
		je	@@OK
		add	edx,size tDRIVERINFO
		inc	eax
		cmp	eax,MAXNUMDRIVERS
		je	@@Err
		jmp	@@Loop

@@OK:		clc
		jmp	short @@Exit

@@Err:		mov	ax,ERR_DRV_NoIDs	; Error: no more driver IDs
		stc
@@Exit:		pop	edx
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; DRV_InstallNew - install new driver.
		; Input: EBX=pointer to driver main structure;
		;	 DX=CS selector (for external) or 0 (for internal).
		; Output: CF=0 - OK, EAX=driver ID;
		;	  CF=1 - error, AX=error code.
proc DRV_InstallNew near
		call	DRV_GetFreeID
		jc	@@Exit
		push	ebx
		push	ecx
		push	edx
		push	esi
		xor	ecx,ecx				; Reserved field=0
		shl	edx,16				; ExtrnCS field
		mov	dx,[ebx+(tDriver).Flags]	; Flags
		lea	esi,[ebx+(tDriver).DrvName]	; Name
		mov	ebx,[ebx+(tDriver).Entries]	; Entries table addr
		call	DRV_ChangeInfo
		pop	esi
		pop	edx
		pop	ecx
		pop	ebx
		jc	@@Exit
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_Uninstall - uninstall driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX-error code.
proc DRV_Uninstall near
		cmp	eax,MAXNUMDRIVERS
		jae	@@Err
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	esi
		xor	ebx,ebx
		mov	edx,ebx
		mov	ecx,ebx
		mov	esi,offset EMPTYDRVNAME
		call	DRV_ChangeInfo
		call	DRV_GetInfoAddr
		xor	ecx,ecx
		not	ecx
		mov	[(tDRIVERINFO ptr eax).ID],ecx
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
		cmp	eax,MAXNUMDRIVERS
		jae	@@Err
		push	esi
		push	edi
		push	ecx

		push	eax
		call	DRV_GetInfoAddr
		mov	edi,eax
		pop	eax

		mov	[(tDRIVERINFO ptr edi).ID],eax
		mov	[(tDRIVERINFO ptr edi).Entries],ebx
		mov	[(tDRIVERINFO ptr edi).Reserved],ecx
		mov	[(tDRIVERINFO ptr edi).Flags],dx
		add	edi,offset (tDRIVERINFO).IntName	; Prepare to
		mov	ecx,DRVNAMELEN				; copying
		shr	ecx,2					; driver name
		cld
		rep	movs [dword edi],[dword esi]
		pop	ecx
		pop	edi
		pop	esi
		clc
		jmp	short @@Exit
@@Err:		mov	ax,ERR_DRV_BadID
		stc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_GetInfoAddr - get driver information structure address.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK, EAX=structure address;
		;	  CF=1 - error, AX=error code.
proc DRV_GetInfoAddr near
		cmp	eax,MAXNUMDRIVERS
		jae     @@Err
		push	ecx
		push	edx
		mov	ecx,size tDRIVERINFO
		xor	edx,edx
		mul	ecx
		add	eax,offset DriversTable
		pop	edx
		pop	ecx
		clc
		jmp	short @@Exit
@@Err:		mov	ax,ERR_DRV_BadID
		stc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; DRV_ChkInst - check whether driver installed or not.
		; Input: EAX=driver ID.
		; Output: CF=0 - driver installed,
		;	  CF=1 - invalid ID or driver not installed.
proc DRV_ChkInst near
		push	eax
		call	DRV_GetInfoAddr
		jc	@@Exit
		cmp	[(tDRIVERINFO ptr eax).ID],-1
		je	@@NotInst
		clc
		jmp	short @@Exit
@@NotInst:	stc
@@Exit:		pop	eax
		ret
endp		;---------------------------------------------------------------



		; DRV_CallDriver - call specified driver (Pascal-style):
		; Function DRV_CallDriver(DriverNum,DriverFun:longint):longint;
		; Input: DriverNum - full driver number;
		;	 DriverFun - function number.
		; Note: if function is "control", then high word of DriverFun
		;	is subfunction number.
proc DRV_CallDriver near
		push	ebp
		mov	ebp,esp
		push	eax				; Keep EAX
		lahf					; Keep flags
		sub	esp,8
		mov	[ebp-12],eax			; Keep flags in stack

		mov	eax,[ebp+12]			; Driver number
		call	DRV_ChkInst			; Installed?
		jc	@@Exit
		call	DRV_GetInfoAddr
		jc	@@Exit

		push	eax
		mov	eax,[(tDRIVERINFO ptr eax).Entries]
		mov	[ebp-8],eax
		movzx	eax,[word ebp+8]		; Driver function
		lea	eax,[eax*4]			; Count vector
		add	eax,[ebp-8]
                mov	eax,[eax]
		cmp	[word ebp+8],DRVF_Control	; "Control" function?
		jne	@@1
		push	esi
		movzx	esi,[word ebp+10]		; Count vector
		mov	eax,[eax+esi*4]
		pop	esi

@@1:		mov	[ebp-8],eax
		pop	eax

		cmp	[(tDRIVERINFO ptr eax).ExtrnCS],offset (tRGDT).DrvCode
		jae	@@Extern

		mov	eax,[ebp-12]			; Restore flags
		sahf
		mov	eax,[ebp-4]			; Restore EAX
		call	[dword ebp-8]			; Call (internal)
		jmp	short @@Exit

@@Extern:       movzx	eax,[(tDRIVERINFO ptr eax).ExtrnCS]
		xchg	[ebp-4],eax			; Restore EAX
		push	eax
		mov	eax,[ebp-12]			; Restore flags
		sahf
		pop	eax
		call	[fword ebp-8]			; Call (external)

@@Exit:		leave
		ret	8
endp		;---------------------------------------------------------------


		; DRV_HandleEvent - call "Handle event" driver function.
		; Input: EAX=driver ID.
		;	 EDX=event.
		; Output: driver output results or CF=1, if driver ID is
		;	  incorrect.
		; Note: destroys EAX.
proc DRV_HandleEvent near
		push	eax				; Driver ID
		push	DRVF_HandleEv			; Function number
		call    DRV_CallDriver
		ret
endp		;---------------------------------------------------------------


		; DevNULL - NULL device driver.
		; Action: simply does RET.
proc DrvNULL near
		ret
endp		;---------------------------------------------------------------


