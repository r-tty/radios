;-------------------------------------------------------------------------------
;  fstest.as - file system test routines for RKDT.
;-------------------------------------------------------------------------------

library kernel.fs
extern CFS_MakeFS, CFS_LinkFS, CFS_UnlinkFS
extern CFS_SetCurrentLP
extern CFS_Open, CFS_Close, CFS_Read, CFS_Write
extern CFS_CreateFile, CFS_RemoveFile
extern CFS_MoveFile, CFS_Truncate
extern CFS_ChangeDir, CFS_CreateDir, CFS_RemoveDir
extern BUF_FlushAll

section .data

msg_FScreated	DB "File system created on %ramdisk",NL,0
msg_CfgCreated	DB "Config file created",NL,0

CfgName		DB "radios.config",0
ConfigFile	DB "#-----------------------------------------------------",NL
		DB "# radios.config - RadiOS configuration file",NL
		DB "#-----------------------------------------------------",NL,NL
		DB 0
SizeOfCfgFile	EQU	$-ConfigFile


section .text

proc TEST_CreateTextFile
%define	.handle		ebp-4
%define	.size		ebp-8
%define	.buffer		ebp-8-520

		prologue 528
		mpush	ecx,esi
		add	esi,ecx
		inc	esi

		; Open file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Begin
		call	RKDT_ErrorHandler
		jmp	short .Exit

.Begin:		mov	[.handle],ebx

		; Read file from console
		lea	esi,[.buffer]
		mov	dword [.size],0
.Loop:		mPrintChar NL
		mov	cl,77
		call	ReadString
		or	cl,cl
		jz	.EmptyLn
		cmp	byte [esi],'`'
		je	short .EndInput
.EmptyLn:	and	ecx,0FFh
		add	esi,ecx
		mov	byte [esi],NL
		inc	esi
		add	[.size],ecx
		inc	dword [.size]
		jmp	.Loop

.EndInput:

		; Write to file
		lea	esi,[.buffer]
		mov	ebx,[.handle]
		mov	ecx,[.size]
		xor	eax,eax
		call	CFS_Write
		jnc	short .Close
		call	RKDT_ErrorHandler

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc TEST_ViewFile
%define	.handle	ebp-4
%define	.buffer	ebp-516

		prologue 516
		mpush	ecx,esi
		add	esi,ecx
		inc	esi

		mPrintChar NL
		call	PrintChar

		xor	edx,edx
		xor	eax,eax
		call	CFS_Open
		jnc	short .Loop
		call	RKDT_ErrorHandler
		jmp	short .Exit

.Loop:		lea	esi,[.buffer]
		mov	ecx,512
		xor	eax,eax
		call	CFS_Read
		jc	short .Exit
		or	eax,eax
		jz	short .OK			; Nothing to view
		mov	ecx,eax

		push	ecx
.Print:		lodsb
		mPrintChar
		dec	ecx
		jz	short .EndPrint
		jmp	.Print
.EndPrint:	pop	ecx

		cmp	ecx,512
		jb	short .OK
		jmp	.Loop

.OK:		xor	ax,ax
		call	CFS_Close
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc TEST_RemoveFile
		mpush	ecx,esi
		add	esi,ecx
		inc	esi
		xor	eax,eax
		call	CFS_RemoveFile
		jnc	short .Exit
		call	RKDT_ErrorHandler
.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_MoveFile
		mpush	ecx,esi
		add	esi,ecx
		inc	esi				; ESI=old name
		mov	edi,esi
		mov	al, ' '
		call	StrScan
		or	edi,edi
		jz	short .Exit
		xor	al,al
		stosb					; EDI=new name

		xor	eax,eax
		call	CFS_MoveFile
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_Ls
		mpush	ecx,esi
	extern rfs_ls
	call rfs_ls

		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_MkDir
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

 		xor	eax,eax
		call	CFS_CreateDir
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_ChDir
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	CFS_ChangeDir
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_RmDir
		mpush	ecx,esi

		add	esi,ecx
		inc	esi

		xor	eax,eax
		call	CFS_RemoveDir
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


proc TEST_CreateManyFiles
%define	.count		ebp-4
%define	.buf		ebp-16

		prologue 16
		mpush	ecx,esi

		mov	dword [.count],0
.Loop:		lea	esi,[.buf]
		mov	eax,[.count]
		call	DecD2Str

		; Create file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Close
		call	RKDT_ErrorHandler
		jmp	short .Exit

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Cont
		call	RKDT_ErrorHandler
		jmp	short .Exit

.Cont:		inc	dword [.count]
		cmp	dword [.count],31
		je	short .Exit
		jmp	.Loop


.Exit:		mpop	esi,ecx
		epilogue
		ret
endp		;---------------------------------------------------------------


proc TEST_CreateLargeFile
		mpush	ecx,esi
		add	esi,ecx
		inc	esi

		; Open file
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Begin
		call	RKDT_ErrorHandler
		jmp	short .Exit

		; Write to file
.Begin:		mov	esi,0B8000h
		mov	ecx,211931
		xor	eax,eax
		call	CFS_Write
		jnc	short .Close
		call	RKDT_ErrorHandler

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------


		; TEST_GrabFile - grab file from 90002h.
		; Note: file length (<64K) is at 90000h.
proc TEST_GrabFile
		mpush	ecx,esi
		or	ecx,ecx
		jz	short .Exit
		add	esi,ecx
		inc	esi

		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .Write
		call	RKDT_ErrorHandler
		jmp	short .Exit

		; Write file
.Write:		mov	esi,90002h
		movzx	ecx,word [90000h]
		xor	eax,eax
		call	CFS_Write
		jnc	short .Close
		call	RKDT_ErrorHandler
		jmp	short .Exit

		; Close file
.Close:		xor	eax,eax
		call	CFS_Close
		jnc	short .Exit
		call	RKDT_ErrorHandler

.Exit:		mpop	esi,ecx
		ret
endp		;---------------------------------------------------------------
