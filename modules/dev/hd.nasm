;-------------------------------------------------------------------------------
;  hd.nasm - device independend part of any hard disk driver.
;-------------------------------------------------------------------------------

module hw.genhd

%include "sys.ah"
%include "errors.ah"
%include "hd.ah"
%include "hw/partids.ah"
%include "mbr.ah"
%include "hw/ddb.ah"
%include "driver.ah"
%include "drvctrl.ah"

%define	SECTORSHIFT	9

; --- Exports ---

global HD_Init, HD_Open, HD_Close, HD_Read, HD_Write
global HD_GetPartParams, HD_GetPartInfoStr
global HD_LBA2CHS


; --- Imports ---

library kernel.driver
extern DRV_CallDriver:near

library kernel.misc
extern StrEnd:near, StrCopy:near, StrAppend:near
extern HexB2Str:near, DecD2Str:near


; --- Data ---

section .data

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


; --- Variables ---

section .bss

HDtable		RESB	tDIHD_size*HD_MaxDrives
HD_MaxNumDisks	RESB	1


; --- Procedures ---

section .text

		; HD_Init - initialize DIHD memory structures.
		; Input: AL=maximum number of physical HD drives.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc HD_Init
		cmp	al,HD_MaxDrives
		ja	short .Err
		mov	[HD_MaxNumDisks],al
		clc
		ret
.Err:		mov	ax,ERR_HD_InitTooManyDrv
		stc
		ret
endp		;---------------------------------------------------------------


		; HD_Open - "open" device.
		; Input: EDX=full device driver ID,
		;	 EDI=address of "Disk operation" procedure.
		; Output: CF=0 - OK, EAX=common hard disk descriptor.
		;	  CF=1 - error, AX=error code.
		; Note: this procedure is called by each hard disk driver
		;	"open" procedure.
proc HD_Open
%define	.buffer		ebp-512
%define	.buffer2	ebp-528
%define	.cmnhddesc	ebp-532
%define	.drvnumcnt	ebp-536
%define	.diskopproc	ebp-540

		prologue 540
		mpush	ebx,ecx,edx,esi
		test	edx,0FF000000h			; Subminor present?
		jz	short .NoMinor			; No, partition drive
		jmp	.Exit

		; Form disk descriptor (address of disk structure)
.NoMinor:	call	HD_FindFreeDesc
		jc	near .Exit
		mov	[.cmnhddesc],eax

		; Read main MBR
		mov	[.diskopproc],edi
		mov	ebx,edx
		shr	ebx,8
		dec	bh				; BH=hard disk number
		mov	bl,1				; BL=1 sector
		mov	[.drvnumcnt],ebx		; Store them
		xor	ecx,ecx				; Sector 0 (main MBR)
		lea	esi,[.buffer]			; MBR buffer address
		mov	ah,HD_opREADSEC			; Disk operation code
		call	edi				; Read one sector
		jc	near .Exit

		; Check MBR signature
		cmp	word [esi+tMBR.MBRdata+tMBRdata.Signature],MBR_SIGNATURE
		jne	near .Err2

		; Store device ID
		mov	eax,[.cmnhddesc]
		mov	[eax+tDIHD.DevID],edx

		; Get drive parameters
		push	edx
		push	dword DRVF_Control+10000h*DRVCTL_GetParams
		call	DRV_CallDriver
		jc	near .Exit

		; Fill primary partitions descriptors
		xor	eax,eax
		mov	edi,[.cmnhddesc]
		add	edi,tDIHD.PartDesc		; First partition
		add	esi,tMBR.MBRdata
		mov	cl,4				; 4 primary partitions
.LoopFill:	call	HD_MBR2PartDesc			; Fill it
		cmp	byte [edi+tPartDesc.SysCode],FS_ID_EXTENDED ; Extended partition?
		je	short .Ext
		cmp	byte [edi+tPartDesc.SysCode],FS_ID_LINUXEXT
		je	short .Ext
		cmp	byte [edi+tPartDesc.SysCode],FS_ID_WINLBAEXT
		jne	short .1
.Ext:		mov	eax,edi
.1:		add	esi,tPartitionEntry_size
		add	edi,tPartDesc_size		; Next partition
		dec	cl
		jnz	.LoopFill

		; Extended partition found?
		or	eax,eax
		jz	short .OK

		; Search extended MBRs
.ExtLoop:	mov	ecx,[eax+tPartDesc.BegSec]
		mov	ebx,[.drvnumcnt]
		lea	esi,[.buffer]
		mov	ah,HD_opREADSEC
		call	dword [.diskopproc]		; Read one sector
		jc	short .Exit

		add	esi,tMBR.MBRdata
		cmp	word [esi+tMBRdata.Signature],MBR_SIGNATURE
		jne	short .OK

                mov	cl,4
.ExtLoop2:	mov	al,[esi+tPartitionEntry.SystemCode]
		or	al,al
		jz	short .OK
		cmp	al,FS_ID_EXTENDED		; Extended?
		je	short .SubExt
		cmp	al,FS_ID_LINUXEXT
		je	short .SubExt
		cmp	al,FS_ID_WINLBAEXT
		jne	short .NotSubExt
		
.SubExt:	push	edi
		lea	edi,[.buffer2]
		call	HD_MBR2PartDesc
		mov	eax,edi
		pop	edi
		jmp	short .ExtLoop
		
.NotSubExt:	call	HD_MBR2PartDesc
		add	esi,byte tPartitionEntry_size
		add	edi,byte tPartDesc_size		; Next partition
		dec	cl
		jnz	.ExtLoop2

.OK:		mov	eax,[.cmnhddesc]		; EAX=disk descriptor
		clc
		jmp	short .Exit
.Err2:		mov	ax,ERR_HD_BadMBRsig
.Error:		stc
.Exit:		mpop	esi,edx,ecx,ebx
		epilogue
		ret
endp		;---------------------------------------------------------------


		; HD_Close - "close" device.
		; Input: EAX=common hard disk descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc HD_Close
		mov	dword [eax+tDIHD.DevID],0
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
proc HD_Read
%define	.count		ebp-4				; Sectors counter

		prologue 4
		mpush	ebx,ecx,edx,esi

		shr	edx,16				; DX=full minor number
		or	dh,dh				; Subminor given?
		jz	short .Exit
		and	ecx,0FFFFh
		or	ecx,ecx
		jz	short .Exit
		mov	[.count],ecx
		mov	ecx,ebx				; ECX=relative sector
		mov	bh,dl
		dec	bh				; BH=drive
		dec	dh
		xor	dl,dl
		shr	edx,4
		add	edx,tDIHD.PartDesc
		add	ecx,[eax+edx+tPartDesc.BegSec]

		mov	bl,HD_MaxSecPerOp
.Loop:		cmp	dword [.count],HD_MaxSecPerOp
		ja	short .Read
		mov	bl,[.count]
.Read:		mov	ah,HD_opREADSEC
		call	edi
		jc	short .Exit
		xor	eax,eax
		mov	al,bl
		sub	[.count],eax			; Decrease counter
		jz	short .OK
		add	ecx,eax				; Increase sector number
		shl	eax,SECTORSHIFT
		add	esi,eax				; and buffer pointer
		jmp	.Loop
.OK:		xor	eax,eax
.Exit:		mpop	esi,edx,ecx,ebx
		epilogue
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
proc HD_Write
		ret
endp		;---------------------------------------------------------------


		; HD_GetPartParams - get partition parameters.
		; Input: EAX=common disk descriptor,
		;	 BL=partition number (1..MAXPARTITION).
		; Output: CF=0 - OK:
		;		  AL=system code,
		;		  ECX=number of sectors in partition;
		;	  CF=1 - error.
proc HD_GetPartParams
		or	bl,bl
		stc
		jz	short .Exit
		push	ebx
		and	ebx,0FFh
		dec	bl
		shl	ebx,4			; Size of tPartDesc must be=16
		add	ebx,eax
		add	ebx,tDIHD.PartDesc
		mov	al,[ebx+tPartDesc.SysCode]
		mov	ecx,[ebx+tPartDesc.NumSectors]
		pop	ebx
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; HD_GetPartInfoStr - build string with partition information.
		; Input: EAX=common disk descriptor,
		;	 BL=partition number (1..MAXPARTITION),
		;	 ESI=pointer to string buffer.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc HD_GetPartInfoStr
		mpush	eax,ecx,esi,edi
		call	HD_GetPartParams		; Get partition params
		jc	short .Exit
		or	al,al				; Empty partition?
		stc
		jz	short .Exit

		mov	edi,esi
		mov	esi,HDstr_Type
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		call	HexB2Str
		mov	edi,esi
		mov	dword [edi],202C68h		; Paste "h, "
		mov	esi,HDstr_Size
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		mov	eax,ecx
		shr	eax,11
		call	DecD2Str
		mov	esi,HDstr_MB
		call	StrAppend

.OK:		clc
.Exit:		mpop	edi,esi,ecx,eax
		ret
endp		;---------------------------------------------------------------



; --- Miscellaneous procedures ---

		; HD_FindFreeDesc - find free disk descriptor.
		; Input: none.
		; Output: CF=0 - OK, EAX=descriptor found;
		;	  CF=1 - error, AX=error code.
proc HD_FindFreeDesc
		push	ecx
		mov	eax,HDtable
		mov	cl,[HD_MaxNumDisks]
.Loop:		cmp	dword [eax+tDIHD.DevID],0
		je	short .OK
		add	eax,tDIHD_size
		dec	cl
		jnz	.Loop
		jmp	short .Err
.OK:		clc
		jmp	short .Exit
.Err:		mov	ax,ERR_HD_NoDescriptors
		stc
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------

		; HD_MBR2PartDesc - convert partition information from MBR to
		;		    partition descriptor.
		; Input: ESI=pointer to begin of MBR partition entry,
		;	 EDI=address of partition descriptor structure,
		;	 DH=humber of heads in drive,
		;	 DL=number of sectors per track.
		; Output: none.
proc HD_MBR2PartDesc
		mpush	ebx,ecx
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
		mpop	ecx,ebx
		ret
endp		;---------------------------------------------------------------


		; HD_CHS2LBA - convert cylinder, head and sector into LBA.
		; Input: CX=cylinder,
		;	 BH=head number,
		;	 BL=sector number,
		;	 DH=number of heads,
		;	 DL=number of sectors per track.
		; Output: EBX=relative sector number.
proc HD_CHS2LBA
		mpush	eax,ecx,edx,esi
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
		mpop	esi,edx,ecx,eax
		ret
endp		;---------------------------------------------------------------


		; HD_LBA2CHS - convert LBA into cylinder, head and sector.
		; Input: EBX=relative sector number,
		;	 DH=number of heads,
		;	 DL=number of sectors per track.
		; Output:ECX=cylinder,
		;	 BH=head,
		;	 BL=sector.
proc HD_LBA2CHS
		mpush	eax,edx,esi
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
		mpop	esi,edx,eax
		ret
endp		;---------------------------------------------------------------
