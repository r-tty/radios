;-------------------------------------------------------------------------------
;  fsinit.as - file systems initialization routines.
;-------------------------------------------------------------------------------

library kernel.fs
extern BUF_InitMem:near, CFS_Init:near
extern CFS_LinkFS:near
extern CFS_GetLPbyName:near, CFS_SetCurrentLP:near


; --- Data ---

section .data

Msg_DiskBuf	DB " KB allocated for disk buffers",NL,0
Msg_InitFSDRV	DB NL,"Initializing file system drivers...",NL,0
Msg_LinkPrimFS	DB NL,"Linking primary file system: ",0
Msg_Arrow	DB " <-> ",0
Msg_At		DB " at ",0
Msg_UnknFS	DB "failed, unknown file system on ",0
Msg_TryCrFS	DB NL,"Try to create file system manually :)",NL,0


; --- Code ---

section .text
		; INIT_GetFSdrvIDfromCode - get file system driver ID from
		;			    partition system code.
		; Input: AL=partition system code.
		; Output: CF=0 - OK, EDX=driver ID;
		;	  CF=1 - error (unknown code).
proc INIT_GetFSdrvIDfromCode
		mov	edx,[DrvId_RFS]
		cmp	al,FS_ID_RFSNATIVE
		je	short .OK
;		mov	edx,[DrvId_MDOSFS]
;		cmp	al,CFS_ID_DOSFAT16SMALL
;		je	short .OK
;		cmp	al,CFS_ID_DOSFAT16LARGE
;		je	short .OK
;		mov	edx,[DrvId_HPFS]
;		cmp	al,CFS_ID_OS2HPFS
;		je	short .OK

		stc
		ret

.OK:		clc
		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskBuffers - initialize disk buffers
proc INIT_InitDiskBuffers
		mov	al,SCFG_BuffersMem		; Read config item
		call	INIT_GetStCfgItem		; (buffers memory in KB)
		xor	ecx,ecx
		mov	cx,[ebx]			; ECX=buffers memory
		cmp	cx,8192
		cmc
		jb	short .Exit
		call	BUF_InitMem
		jc	short .Exit
		mPrintChar NL
		mov	eax,ecx				; Print message
		call	PrintDwordDec
		mPrintString Msg_DiskBuf
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitFileSystems - install and initialize all
		;			 file system drivers.
proc INIT_InitFileSystems

		; RFS driver
		mov	ebx,DrvRFS
		xor	edx,edx
		call	DRV_InstallNew
		jc	short .Exit
		mov	[DrvId_RFS],eax

		mov	al,26				; Max. number of LPs
		mov	cl,48				; Max. number of FCBs
		mov	esi,InitStringBuf		; Buffer for status string
		mCallDriver dword [DrvId_RFS], byte DRVF_Init
		jc	short .Exit
		mPrintChar ' '
		mPrintString

		; MDOSFS driver

		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_LinkPrimFS - link primary file system.
proc INIT_LinkPrimFS
%define	.devicestr	ebp-4
%define	.fsdrvstr	ebp-8
%define	.fslpstr	ebp-12

		prologue 12				; Save space
		mPrintString Msg_LinkPrimFS

		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	near .Exit
		mov	[.devicestr],ebx		; Keep it

		mov	esi,ebx
		call	DRV_FindName			; Get boot device ID
		jc	near .Exit
		mov	edi,eax				; Keep it in EDI
		mCallDriverCtrl edi,DRVCTL_GetParams	; Get partition type
		or	al,al				; Known file system?
		jnz	short .KnownFS			; Yes, continue
		mPrintString Msg_UnknFS			; Else print error msg
		mov	esi,ebx
		mPrintString
		mPrintString Msg_TryCrFS
		stc					; and exit with error
		jmp	.Exit

.KnownFS:	call	INIT_GetFSdrvIDfromCode		; Get FS driver ID in EDX
		jc	near .Exit

		mov	al,SCFG_PrimFS_LP		; Get config item
		call	INIT_GetStCfgItem		; (primary FSLP string)
		jc	near .Exit
		mov	[.fslpstr],ebx			; Keep it

		mov	eax,edx				; Keep FS driver ID
		call	DRV_GetName			; Get name of FS driver
		mov	[.fsdrvstr],esi
		mov	esi,ebx				; ESI=pointer to LP string
		call	CFS_GetLPbyName			; Get FSLP in DL
		jc	near .Exit
		mov	esi,eax				; ESI=FS driver ID

		mov	dh,0				; Linking mode
		call	CFS_LinkFS			; Do link
		jc	near .Exit
		call	CFS_SetCurrentLP		; Set current FSLP

		mov	esi,[.devicestr]		; Print linking status
		mPrintString
		mPrintString Msg_Arrow
		mov	esi,[.fsdrvstr]
		mPrintString
		mPrintString Msg_At
		mov	esi,[.fslpstr]
		mPrintString
		mPrintChar NL
		clc

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------
