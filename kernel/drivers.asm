;*******************************************************************************
;  drivers.asm - RadiOS drivers control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Definitions ---

MAXNUMDRIVERS		EQU	256		; Maximum number of drivers
NUMDFLTDRIVERS		EQU	10		; Number of default drivers
DRVNAMELEN		EQU	16		; Length of driver name

; Driver information structure
struc tDRIVERINFO
 ID		DD	?			; Driver ID
 IntName	DB DRVNAMELEN dup (0)		; Internal name
 Entry		DD	?			; Driver entry point
 Flags		DD	?			; Flags & CS (for extern)
 Reserved	DD	?
ends

; Driver flags
DRVFL_Extern		EQU	1000h		; External driver (far call)


; --- Externals ---

; Default hardware drivers entries
		extrn DrvKeyboard:	near
		extrn DrvVideo:		near
		extrn DrvAudio:		near
		extrn DrvNet:		near
		extrn DrvSerial:	near
		extrn DrvParallel:	near
		extrn DrvFDD:		near
		extrn DrvHDD:		near


; --- Data ---
EMPTYDRVNAME	DB DRVNAMELEN dup (' ')


; --- Variables ---

NumInstDrivers	DD	NUMDFLTDRIVERS		; Number of installed drivers

; Default hardware drivers table
DriversTable	tDRIVERINFO <0,"NULL            ",offset DrvNULL,0,0>
		tDRIVERINFO <1,"MEMORY          ",offset DrvMemory,0,0>
		tDRIVERINFO <2,"KEYBOARD        ",offset DrvKeyboard,0,0>
		tDRIVERINFO <3,"VIDEODEV        ",offset DrvVideo,0,0>
		tDRIVERINFO <4,"AUDIODEV        ",offset DrvAudio,0,0>
		tDRIVERINFO <5,"NETDEV          ",offset DrvNet,0,0>
		tDRIVERINFO <6,"SERIALDEV       ",offset DrvSerial,0,0>
		tDRIVERINFO <7,"PARALLELDEV     ",offset DrvParallel,0,0>
		tDRIVERINFO <8,"FLOPPYDISK      ",offset DrvFDD,0,0>
		tDRIVERINFO <9,"HARDDISK        ",offset DrvHDD,0,0>

		tDRIVERINFO MAXNUMDRIVERS-NUMDFLTDRIVERS dup\
			   (<-1,"                ",offset DrvNULL,0,0>)

; --- Routines ---

		; DRV_GetFreeID - search free driver information structure.
		; Input: none.
		; Output: CF=0 - OK, EAX=free ID;
		;	  CF=1 - error, AX=error code.
proc DRV_GetFreeID near
		push	ecx
		push	edx
		mov	eax,offset DriversTable
		mov	ecx,size tDRIVERINFO
drGFI_Loop:	cmp	[(tDRIVERINFO ptr eax).ID],-1	; Free structure?
		je	drGFI_OK
		add	eax,ecx
		cmp	eax,MAXNUMDRIVERS*size tDRIVERINFO
		je	drGFI_Err
		jmp	short drGFI_Loop
drGFI_OK:	xor	edx,edx
		div	ecx
		clc
		jmp	drGFI_Exit

drGFI_Err:	mov	ax,ERR_DRV_NoIDs	; Error: no more driver IDs
		stc
drGFI_Exit:	pop	edx
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; DRV_InstallNew - install new driver.
		; Input: ESI=pointer to internal name,
		;	 EBX=entry point address,
		;	 EDX=driver flags.
		; Output: CF=0 - OK, EAX=driver ID;
		;	  CF=1 - error, AX=error code.
proc DRV_InstallNew near
		call	DRV_GetFreeID
		jc	drInst_Exit
		push	ecx
		xor	ecx,ecx
		call	DRV_ChangeInfo
		pop	ecx
		jc	drInst_Exit
		clc
drInst_Exit:	ret
endp		;---------------------------------------------------------------


		; DRV_Uninstall - uninstall driver.
		; Input: EAX=driver ID.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX-error code.
proc DRV_Uninstall near
		cmp	eax,MAXNUMDRIVERS
		jae	drUninst_Err
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
		xor	edx,edx
		mov	ecx,size tDRIVERINFO
		mul	ecx
		xor	ecx,ecx
		not	ecx
		mov	[(tDRIVERINFO ptr eax).ID],ecx
		pop	esi
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax
		clc
		jmp	drUnInst_Exit
drUninst_Err:   mov	ax,ERR_DRV_BadID
		stc
drUnInst_Exit:	ret
endp		;---------------------------------------------------------------


		; DRV_ChangeInfo - change driver information.
		; Input: EAX=driver ID,
		;	 ESI=pointer to internal name,
		;	 EBX=entry point address,
		;	 EDX=driver flags,
		;	 ECX=reserved information.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc DRV_ChangeInfo near
		cmp	eax,MAXNUMDRIVERS
		jae	drChgInfo_Err
		push	esi
		push	edi
		push	ecx

		push	eax
		push	ebx
		push	ecx
		push	edx
		xor	edx,edx
		mov	ecx,size tDRIVERINFO
		mul	ecx
		mov	edi,eax			; EDI=driver info address
		pop	edx
		pop	ecx
		pop	ebx
		pop	eax

		mov	[(tDRIVERINFO ptr edi).ID],eax
		mov	[(tDRIVERINFO ptr edi).Entry],ebx
		mov	[(tDRIVERINFO ptr edi).Reserved],ecx
		mov	[(tDRIVERINFO ptr edi).Flags],edx
		add	edi,offset (tDRIVERINFO).IntName	; Prepare to
		mov	ecx,DRVNAMELEN				; copying
		shr	ecx,2					; driver name
		cld
		rep	movs [dword edi],[dword esi]
		pop	ecx
		pop	edi
		pop	esi
		clc
		jmp	drChgInfo_Exit
drChgInfo_Err:	mov	ax,ERR_DRV_BadID
		stc
drChgInfo_Exit:	ret
endp		;---------------------------------------------------------------


		; DevNULL - NULL device driver.
		; Action: simply does RET.
proc DrvNULL near
		ret
endp