;*******************************************************************************
;  ramdisk.asm - RAM disk driver.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

include "commonfs.ah"
include "cfs_func.ah"

; --- Data ---
segment KDATA

; RAM-disk driver main structure
DrvRD		tDriver <"%ramdisk        ",offset DrvRDET,DRVFL_Block>

; Driver entry points table
DrvRDET		tDrvEntries < RD_Init,\
			      RD_HandleEvent,\
			      RD_Open,\
			      RD_Close,\
			      RD_Read,\
			      RD_Write,\
			      RD_DoneMem,\
			      DrvRD_Ctrl >
; Driver control functions
DrvRD_Ctrl	DD	RD_GetInitStatStr
		DD	RD_GetParameters
		DD	RD_Cleanup

; Init status string piece
RDmsg		DB	" KB at ",0

ends


; --- Variables ---
segment KVARS
RDstart		DD	0				; RAM-disk address
RDnumSectors	DD	0				; Number of sectors
RDopenCount	DB	0				; Open counter
RDinitialized	DB	0				; Initialization status
ends


; --- Interface procedures ---
segment KCODE


		; RD_Init - initialize RAM-disk.
		; Input: ECX=size of RAM-disk (in KB),
		;	 ESI=pointer to buffer for init status string.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc RD_Init near
		push	ebx ecx edx esi
		mov	edx,ecx
		shl	ecx,10			; ECX=size in bytes
		call	EDRV_AllocData		; Allocate memory
		jc	short @@Exit
		mov	[RDstart],ebx

		mov	eax,ecx
                shr	eax,9			; EAX=number of sectors
		mov	[RDnumSectors],eax

		call	RD_Cleanup		; Clean disk space
		call	RD_GetInitStatStr	; Get init status string
		mov	[RDinitialized],1	; Mark driver as initialized

@@OK:		clc
@@Exit:		pop	esi edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; RD_DoneMem - release driver memory.
proc RD_DoneMem near
		ret
endp		;---------------------------------------------------------------


		; RD_HandleEvent - handle specific events.
proc RD_HandleEvent near
		ret
endp		;---------------------------------------------------------------


		; RD_Open - "open" device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Open near
		cmp	[RDopenCount],0
                jne	short @@Err

		inc	[RDopenCount]
		ret

@@Err:		mov	ax,ERR_DRV_AlreadyOpened
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Close - "close" device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Close near
		cmp	[RDopenCount],0
                je	short @@Err

		dec	[RDopenCount]
		ret

@@Err:		mov	ax,ERR_DRV_NotOpened
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Read - read sector(s).
		; Input: EBX=sector number,
		;	 ECX=number of sectors to read,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Read near
		push	ecx esi edi
		cmp	ebx,[RDnumSectors]		; Check sector number
		jae	short @@Err1
		mov	edi,ebx
		add	edi,ecx
		cmp	edi,[RDnumSectors]		; Check request size
		ja	short @@Err2

		shl	ecx,7				; ECX=number of dwords in disk
		mov	edi,esi				; EDI=buffer address
		mov	esi,ebx
		shl	esi,9
		add	esi,[RDstart]			; ESI=sector address
		cld
		rep	movsd
		clc
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_DISK_BadSectorNumber
		jmp	short @@Error
@@Err2:		mov	ax,ERR_DISK_BadNumOfSectors
@@Error:	stc
@@Exit:		pop	edi esi ecx
		ret
endp		;---------------------------------------------------------------


		; RD_Write - write sector(s).
		; Input: EBX=sector number,
		;	 ECX=number of sectors to write,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Write near
		push	ecx esi edi
		cmp	ebx,[RDnumSectors]		; Check sector number
		jae	short @@Err1
		mov	edi,ebx
		add	edi,ecx
		cmp	edi,[RDnumSectors]		; Check request size
		ja	short @@Err2

		shl	ecx,7				; ECX=number of dwords in disk
		mov	edi,ebx
		shl	edi,9
		add	edi,[RDstart]			; EDI=sector address
		cld
		rep	movsd
		clc
		jmp	short @@Exit

@@Err1:		mov	ax,ERR_DISK_BadSectorNumber
		jmp	short @@Error
@@Err2:		mov	ax,ERR_DISK_BadNumOfSectors
@@Error:	stc
@@Exit:		pop	edi esi ecx
		ret
endp		;---------------------------------------------------------------



		; RD_GetInitStatStr - get initialization status string.
		; Input: ESI=pointer to buffer for string.
		;	 Output: none.
proc RD_GetInitStatStr near
		push	eax esi edi
		mov	edi,esi
		mov	esi,offset DrvRD	; Copy "%ramdisk"
		call	StrCopy
		call	StrEnd
		mov	eax,203A0920h		; Tabs and ':'
		stosd
		mov	eax,[RDnumSectors]
		shr	eax,1
		xchg	esi,edi
		call	K_DecD2Str
		xchg	esi,edi
		mov	esi,offset RDmsg
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		mov	eax,[RDstart]
		call	K_HexD2Str
		mov	[dword esi],0A68h			; 'h' and NL
		pop	edi esi eax
		ret
endp		;---------------------------------------------------------------


		; RD_GetParameters - get device parameters.
		; Input: none.
		; Output: CF=0 - OK:
		;		    ECX=total number of sectors on disk,
		;		    AL=file system type or 0, if disk is empty.
		;	  CF=1 - error, AX=error code.
proc RD_GetParameters near
		cmp	[RDinitialized],0
		je	short @@Err
		mov	ecx,[RDnumSectors]

		push	edx				; Look of file system
		mov	edx,[DrvId_RD]			; Get RAM-disk driver ID
		or	edx,edx
		stc
		jz	short @@Exit

		mov	eax,[DrvId_RFS]			; RFS driver installed?
		or	eax,eax
		jz	short @@LookMDOS
		mCallDriverCtrl eax,FSF_LookFSysOnDev	; Look of RFS
		jc	short @@LookMDOS
		mov	al,CFS_ID_RFSNATIVE		; RFS found
		jmp	short @@OK

@@LookMDOS:	;mov	eax,[DrvId_MDOSFS]		; MDOSFS driver installed?
;		or	eax,eax
;		jz	short @@OK
;		mCallDriverCtrl eax,FSF_LookFSysOnDev	; Look of MDOSFS
;		jmp	short @@OK

		xor	al,al
@@OK:		clc
@@Exit:		pop	edx
		ret

@@Err:		mov	ax,ERR_DRV_NotInitialized
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Cleanup - clean disk space.
proc RD_Cleanup near
		push	eax ecx edi
		mov	ecx,[RDnumSectors]
		shl	ecx,7			; ECX=number of dwords in disk
		xor	eax,eax
		mov	edi,[RDstart]
		cld
		rep	stos [dword edi]	; Clear disk area
		pop	edi ecx eax
		ret
endp		;---------------------------------------------------------------

ends
