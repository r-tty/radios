;-------------------------------------------------------------------------------
;  hd.asm - device independend part of any hard disk driver.
;-------------------------------------------------------------------------------

include "hd.ah"
include "mbr.ah"
include "ddb.ah"


; --- Data ---
segment KDATA
PTstr_EMPTY	DB	"Empty",0
PTstr_FAT12	DB	"DOS FAT12",0
PTstr_XENIXroot	DB	"XENIX root",0
PTstr_XENIXusr	DB	"XENIX usr",0
PTstr_FAT16	DB	"DOS FAT16 <32MB",0
PTstr_EXT	DB	"Extended",0
PTstr_BIGDOS	DB	"DOS FAT16 >=32MB",0
PTstr_LinuxN	DB	"Linux native",0
PTstr_LinuxS	DB	"Linux swap",0
PTstr_RFSn	DB	"RFS native",0
PTstr_RFSs	DB	"RFS swap",0

HDstr_Type	DB	"type ",0
HDstr_Size	DB	"size=",0
HDstr_MB	DB	" MB",0
ends


; --- Variables ---
segment KVARS
HD_TableHnd	DW	?
HD_TableAddr	DD	?
HD_MaxNumDisks	DB	?
ends


; --- Procedures ---

		; HD_Init - initialize DIHD memory structures.
		; Input: AL=maximum number of physical HD drives.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc HD_Init near
		cmp	al,HD_MaxDrives
		jbe	short @@Do
		mov	ax,ERR_HD_InitTooManyDrv
		stc
		ret
@@Do:		push	ebx ecx edx
		movzx	eax,al
		mov	[HD_MaxNumDisks],al
		mov	ecx,size tDIHD
		mul	ecx			; Allocate memory
		mov	ecx,eax
		call	KH_Alloc		; for table
		jc	short @@Exit
		mov	[HD_TableHnd],ax	; Store block handle
		mov	[HD_TableAddr],ebx	; Store block address
		call	KH_FillZero		; Clear table entries
@@Exit:		pop	edx ecx ebx
		ret
endp		;---------------------------------------------------------------


		; HD_Done - release all DIHD memory.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc HD_Done near
		mov	ax,[HD_TableHnd]
		call	KH_Free
		ret
endp		;---------------------------------------------------------------


		; HD_Open - "open" device.
		; Input: EDX=full device driver ID,
		;	 EDI=address of "Disk operation" procedure.
		; Output: CF=0 - OK, EAX=common hard disk descriptor.
		;	  CF=1 - error, AX=error code.
		; Note: this procedure is called by each hard disk driver
		;	"open" procedure.
proc HD_Open near
@@buffer	EQU	[ebp-512]
@@buffer2	EQU	[ebp-528]
@@cmnhddesc	EQU	[ebp-532]
@@drvnumcnt	EQU	[ebp-536]
@@diskopproc	EQU	[dword ebp-540]

		push	ebp
		mov	ebp,esp
		sub	esp,540
		push	ebx ecx edx esi
		test	edx,0FF000000h			; Subminor present?
		jz	short @@NoMinor			; No, partition drive
		jmp	@@Exit

		; Form disk descriptor (address of disk structure)
@@NoMinor:	call	HD_FindFreeDesc
		jc	@@Exit
		mov	@@cmnhddesc,eax

		; Read main MBR
		mov	@@diskopproc,edi
		mov	ebx,edx
		shr	ebx,8
		dec	bh				; BH=hard disk number
		mov	bl,1				; BL=1 sector
		mov	@@drvnumcnt,ebx			; Store them
		xor	ecx,ecx				; Sector 0 (main MBR)
		lea	esi,@@buffer			; MBR buffer address
		mov	ah,HD_opREADSEC			; Disk operation code
		call	edi				; Read one sector
		jc	@@Exit

		; Check MBR signature
		cmp	[esi+tMBR.MBRdata.Signature],MBR_SIGNATURE
		jne	@@Err2

		; Store device ID
		mov	eax,@@cmnhddesc
		mov	[eax+tDIHD.DevID],edx

		; Get drive parameters
		push	edx
		push	DRVF_Control+10000h*DRVCTL_GetParams
		call	DRV_CallDriver
		jc	@@Exit

		; Fill primary partitions descriptors
		xor	eax,eax
		mov	edi,@@cmnhddesc
		add	edi,offset (tDIHD).PartDesc	; First partition
		add	esi,offset (tMBR).MBRdata
		mov	cl,4				; 4 primary partitions
@@LoopFill:	call	HD_MBR2PartDesc			; Fill it
		cmp	[edi+tPartDesc.SysCode],FS_Ext	; Extended partition?
		jne	short @@NoExt
		mov	eax,edi
@@NoExt:	add	esi,size tPartitionEntry
		add	edi,size tPartDesc		; Next partition
		dec	cl
		jnz	@@LoopFill

		; Extended partition found?
		or	eax,eax
		jz	short @@OK

		; Search extended MBRs
@@ExtLoop:	mov	ecx,[eax+tPartDesc.BegSec]
		mov	ebx,@@drvnumcnt
		lea	esi,@@buffer
		mov	ah,HD_opREADSEC
		call	@@diskopproc			; Read one sector
		jc	short @@Exit

		add	esi,offset (tMBR).MBRdata
		cmp	[esi+tMBRdata.Signature],MBR_SIGNATURE
		jne	short @@OK

                mov	cl,4
@@ExtLoop2:	mov	al,[esi+tPartitionEntry.SystemCode]
		or	al,al
		jz	short @@OK
		cmp	al,FS_Ext			; Extended?
		jne	short @@NotSubExt
		push	edi
		lea	edi,@@buffer2
		call	HD_MBR2PartDesc
		mov	eax,edi
		pop	edi
		jmp	short @@ExtLoop

@@NotSubExt:	call	HD_MBR2PartDesc
		add	esi,size tPartitionEntry
		add	edi,size tPartDesc		; Next partition
		dec	cl
		jnz	@@ExtLoop2

@@OK:		mov	eax,@@cmnhddesc			; EAX=disk descriptor
		clc
		jmp	short @@Exit
@@Err2:		mov	ax,ERR_HD_BadMBRsig
@@Error:	stc
@@Exit:		pop	esi edx ecx ebx
		leave
		ret
endp		;---------------------------------------------------------------


		; HD_Close - "close" device.
		; Input: EAX=common hard disk descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc HD_Close near
		mov	[eax+tDIHD.DevID],0
		clc
		ret
endp		;---------------------------------------------------------------


		; HD_Read - read sectors from device.
		; Input: EAX=common hard disk descriptor,
		;	 EDX (high word) = full minor device number,
		;	 EBX=relative sector number,
		;	 CX=quantity of sectors to read,
		;	 ESI=buffer address,
		;	 EDI=address of "Disk operation" procedure.
		; Output: CF=0 - OK, AX=0;
		;	  CF=1 - error, AX=error code.
proc HD_Read near
@@count		EQU	ebp-4				; Sectors counter

		push	ebp
		mov	ebp,esp
		sub	esp,4

		push	ebx ecx edx esi
		shr	edx,16				; DX=full minor number
		or	dh,dh				; Subminor given?
		jz	short @@Exit
		and	ecx,0FFFFh
		or	ecx,ecx
		jz	short @@Exit
		mov	[@@count],ecx
		mov	ecx,ebx				; ECX=relative sector
		mov	bh,dl
		dec	bh				; BH=drive
		dec	dh
		xor	dl,dl
		shr	edx,4
		add	edx,offset (tDIHD).PartDesc
		add	ecx,[eax+edx+tPartDesc.BegSec]

		mov	bl,HD_MaxSecPerOp
@@Loop:		cmp	[dword @@count],HD_MaxSecPerOp
		ja	short @@Read
		mov	bl,[byte @@count]
@@Read:		mov	ah,HD_opREADSEC
		call	edi
		jc	short @@Exit
		xor	eax,eax
		mov	al,bl
		sub	[@@count],eax			; Decrease counter
		jz	short @@OK
		add	ecx,eax				; Increase sector number
		shl	eax,SECTORSHIFT
		add	esi,eax				; and buffer pointer
		jmp	@@Loop
@@OK:		xor	eax,eax
@@Exit:		pop	esi edx ecx ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


		; HD_Write - write sectors to device.
		; Input: EAX=common hard disk descriptor,
		;	 EDX (high word) = full minor device number,
		;	 EBX=relative sector number,
		;	 CX=quantity of sectors to write,
		;	 ESI=buffer address,
		;	 EDI=address of "Disk operation" procedure.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc HD_Write near
		ret
endp		;---------------------------------------------------------------


		; HD_GetPartParams - get partition parameters.
		; Input: EAX=common disk descriptor,
		;	 BL=partition number (1..MAXPARTITION).
		; Output: CF=0 - OK:
		;		  AL=system code,
		;		  ECX=number of sectors in partition;
		;	  CF=1 - error.
proc HD_GetPartParams near
		or	bl,bl
		stc
		jz	short @@Exit
		push	ebx
		and	ebx,0FFh
		dec	bl
		shl	ebx,4			; Size of tPartDesc must be=16
		add	ebx,eax
		add	ebx,offset (tDIHD).PartDesc
		mov	al,[ebx+tPartDesc.SysCode]
		mov	ecx,[ebx+tPartDesc.NumSectors]
		pop	ebx
		clc
@@Exit:		ret
endp		;---------------------------------------------------------------


		; HD_GetPartInfoStr - build string with partition information.
		; Input: EAX=common disk descriptor,
		;	 BL=partition number (1..MAXPARTITION),
		;	 ESI=pointer to string buffer.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc HD_GetPartInfoStr near
		push	eax ecx esi edi
		call	HD_GetPartParams		; Get partition params
		jc	short @@Exit
		or	al,al				; Empty partition?
		stc
		jz	short @@Exit

		mov	edi,esi
		mov	esi,offset HDstr_Type
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		call	K_HexB2Str
		mov	edi,esi
		mov	[dword edi],202C68h		; Paste "h, "
		mov	esi,offset HDstr_Size
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		mov	eax,ecx
		shr	eax,11
		call	K_DecD2Str
		mov	esi,offset HDstr_MB
		call	StrAppend

@@OK:		clc
@@Exit:		pop	edi esi ecx eax
		ret
endp		;---------------------------------------------------------------



; --- Miscellaneous procedures ---

		; HD_FindFreeDesc - find free disk descriptor.
		; Input: none.
		; Output: CF=0 - OK, EAX=descriptor found;
		;	  CF=1 - error, AX=error code.
proc HD_FindFreeDesc near
		push	ecx
		mov	eax,[HD_TableAddr]
		mov	cl,[HD_MaxNumDisks]
@@Loop:		cmp	[eax+tDIHD.DevID],0
		je	short @@OK
		add	eax,size tDIHD
		dec	cl
		jnz	@@Loop
		jmp	short @@Err
@@OK:		clc
		jmp	short @@Exit
@@Err:		mov	ax,ERR_HD_NoDescriptors
		stc
@@Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------

		; HD_MBR2PartDesc - convert partition information from MBR to
		;		    partition descriptor.
		; Input: ESI=pointer to begin of MBR partition entry,
		;	 EDI=address of partition descriptor structure,
		;	 DH=humber of heads in drive,
		;	 DL=number of sectors per track.
		; Output: none.
proc HD_MBR2PartDesc near
		push	ebx ecx
		mov	cx,[esi+tPartitionEntry.BeginSecCyl]
		mov	bl,cl
		and	bl,3Fh
		xchg	cl,ch
		shr	ch,6
		mov	bh,[esi+tPartitionEntry.BeginHead]
		call	HD_CHS2LBA
		mov	[edi+tPartDesc.BegSec],ebx
		mov	ecx,[esi+tPartitionEntry.NumSectors]
		mov	[edi+tPartDesc.NumSectors],ecx
		mov	ebx,[esi+tPartitionEntry.RelStartSecNum]
		mov	[edi+tPartDesc.RelSec],ebx
		mov	bl,[esi+tPartitionEntry.SystemCode]
		mov	[edi+tPartDesc.SysCode],bl
		pop	ecx ebx
		ret
endp		;---------------------------------------------------------------


		; HD_CHS2LBA - convert cylinder, head and sector into LBA.
		; Input: CX=cylinder,
		;	 BH=head number,
		;	 BL=sector number,
		;	 DH=number of heads,
		;	 DL=number of sectors per track.
		; Output: EBX=relative sector number.
proc HD_CHS2LBA near
		push	eax ecx edx esi
		mov	esi,edx
		xor	eax,eax
		mov	ax,cx
		xor	ecx,ecx
		mov	cl,dh
		mul	ecx
		mov	edx,esi
		mov	cl,bh
		add	eax,ecx
		mov	cl,dl
		mul	ecx
		mov	cl,bl
		dec	cl
		add	eax,ecx
		mov	ebx,eax
		pop	esi edx ecx eax
		ret
endp		;---------------------------------------------------------------


		; HD_LBA2CHS - convert LBA into cylinder, head and sector.
		; Input: EBX=relative sector number,
		;	 DH=number of heads,
		;	 DL=number of sectors per track.
		; Output:ECX=cylinder,
		;	 BH=head,
		;	 BL=sector.
proc HD_LBA2CHS near
		push	eax edx esi
		mov	esi,edx
		xor	eax,eax
		mov	al,dl
		mul	dh
		mov	ecx,eax

		mov	eax,ebx
		xor	edx,edx
		div	ecx
		mov	ecx,eax

		mov	eax,edx
		mov	edx,esi
		div	dl
		mov	bh,al
		mov	bl,ah
		inc	bl
		pop	esi edx eax
		ret
endp		;---------------------------------------------------------------
