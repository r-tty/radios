;*******************************************************************************
;  ramdisk.as - RAM disk driver.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

module ramdisk

%define	extcall near

%include "sys.ah"
%include "errors.ah"
%include "driver.ah"
%include "commonfs.ah"
%include "hw/partids.ah"


; --- Exports ---

global DrvRD


; --- Imports ---

library kernel
extern DrvId_RD, DrvId_RFS

library kernel.driver
extern DRV_CallDriver:extcall, EDRV_AllocData:extcall

library kernel.misc
extern StrCopy:extcall, StrEnd:extcall, StrAppend:extcall
extern K_HexD2Str:extcall, K_DecD2Str:extcall


; --- Data ---

section .data

; RAM-disk driver main structure
DrvRD		DB	"%ramdisk"
		TIMES	16-$+DrvRD DB 0
		DD	DrvRDET
		DW	DRVFL_Block

; Driver entry points table
DrvRDET		DD	RD_Init
		DD	RD_HandleEvent
		DD	RD_Open
		DD	RD_Close
		DD	RD_Read
		DD	RD_Write
		DD	RD_DoneMem
		DD	DrvRD_Ctrl

; Driver control functions
DrvRD_Ctrl	DD	RD_GetInitStatStr
		DD	RD_GetParameters
		DD	RD_Cleanup

; Init status string piece
RDmsg		DB	" KB at ",0


; --- Variables ---

section .bss

RDstart		RESD	1				; RAM-disk address
RDnumSectors	RESD	1				; Number of sectors
RDopenCount	RESB	1				; Open counter
RDinitialized	RESB	1				; Initialization status



; --- Interface procedures ---

section .text

		; RD_Init - initialize RAM-disk.
		; Input: ECX=size of RAM-disk (in KB),
		;	 ESI=pointer to buffer for init status string.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc RD_Init
		mpush	ebx,ecx,edx,esi
		mov	edx,ecx
		shl	ecx,10			; ECX=size in bytes
		call	EDRV_AllocData		; Allocate memory
		jc	short .Exit
		mov	[RDstart],ebx

		mov	eax,ecx
                shr	eax,9			; EAX=number of sectors
		mov	[RDnumSectors],eax

		call	RD_Cleanup		; Clean disk space
		call	RD_GetInitStatStr	; Get init status string
		mov	byte [RDinitialized],1	; Mark driver as initialized

.OK:		clc
.Exit:		mpop	esi,edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; RD_DoneMem - release driver memory.
proc RD_DoneMem
		ret
endp		;---------------------------------------------------------------


		; RD_HandleEvent - handle specific events.
proc RD_HandleEvent
		ret
endp		;---------------------------------------------------------------


		; RD_Open - "open" device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Open
		cmp	byte [RDopenCount],0
                jne	short .Err

		inc	byte [RDopenCount]
		ret

.Err:		mov	ax,ERR_DRV_AlreadyOpened
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Close - "close" device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Close
		cmp	byte [RDopenCount],0
                je	short .Err

		dec	byte [RDopenCount]
		ret

.Err:		mov	ax,ERR_DRV_NotOpened
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Read - read sector(s).
		; Input: EBX=sector number,
		;	 ECX=number of sectors to read,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Read
		mpush	ecx,esi,edi
		cmp	ebx,[RDnumSectors]		; Check sector number
		jae	short .Err1
		mov	edi,ebx
		add	edi,ecx
		cmp	edi,[RDnumSectors]		; Check request size
		ja	short .Err2

		shl	ecx,7				; ECX=number of dwords in disk
		mov	edi,esi				; EDI=buffer address
		mov	esi,ebx
		shl	esi,9
		add	esi,[RDstart]			; ESI=sector address
		cld
		rep	movsd
		clc
		jmp	short .Exit

.Err1:		mov	ax,ERR_DISK_BadSectorNumber
		jmp	short .Error
.Err2:		mov	ax,ERR_DISK_BadNumOfSectors
.Error:		stc
.Exit:		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RD_Write - write sector(s).
		; Input: EBX=sector number,
		;	 ECX=number of sectors to write,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Write
		mpush	ecx,esi,edi
		cmp	ebx,[RDnumSectors]		; Check sector number
		jae	short .Err1
		mov	edi,ebx
		add	edi,ecx
		cmp	edi,[RDnumSectors]		; Check request size
		ja	short .Err2

		shl	ecx,7				; ECX=number of dwords in disk
		mov	edi,ebx
		shl	edi,9
		add	edi,[RDstart]			; EDI=sector address
		cld
		rep	movsd
		clc
		jmp	short .Exit

.Err1:		mov	ax,ERR_DISK_BadSectorNumber
		jmp	short .Error
.Err2:		mov	ax,ERR_DISK_BadNumOfSectors
.Error:		stc
.Exit:		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RD_GetInitStatStr - get initialization status string.
		; Input: ESI=pointer to buffer for string.
		;	 Output: none.
proc RD_GetInitStatStr
		mpush	eax,esi,edi
		mov	edi,esi
		mov	esi,DrvRD		; Copy "%ramdisk"
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
		mov	dword [esi],0A68h	; 'h' and NL
		mpop	edi,esi,eax
		ret
endp		;---------------------------------------------------------------


		; RD_GetParameters - get device parameters.
		; Input: none.
		; Output: CF=0 - OK:
		;		    ECX=total number of sectors on disk,
		;		    AL=file system type or 0, if disk is empty.
		;	  CF=1 - error, AX=error code.
proc RD_GetParameters
		cmp	byte [RDinitialized],0
		je	short .Err
		mov	ecx,[RDnumSectors]

		push	edx				; Look of file system
		mov	edx,[DrvId_RD]			; Get RAM-disk driver ID
		or	edx,edx
		stc
		jz	short .Exit

		mov	eax,[DrvId_RFS]			; RFS driver installed?
		or	eax,eax
		jz	short .LookMDOS
		mCallDriverCtrl eax,FSF_LookFSysOnDev	; Look for RFS
		jc	short .LookMDOS
		mov	al,FS_ID_RFSNATIVE		; RFS found
		jmp	short .OK

.LookMDOS:	;mov	eax,[DrvId_MDOSFS]		; MDOSFS driver installed?
;		or	eax,eax
;		jz	short .OK
;		mCallDriverCtrl eax,FSF_LookFSysOnDev	; Look of MDOSFS
;		jmp	short .OK

		xor	al,al
.OK:		clc
.Exit:		pop	edx
		ret

.Err:		mov	ax,ERR_DRV_NotInitialized
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Cleanup - clean disk space.
proc RD_Cleanup
		mpush	eax,ecx,edi
		mov	ecx,[RDnumSectors]
		shl	ecx,7			; ECX=number of dwords in disk
		xor	eax,eax
		mov	edi,[RDstart]
		cld
		rep	stosd			; Clear disk area
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------

