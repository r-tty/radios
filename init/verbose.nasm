;
; verbose.as - verbose intialization routines.
;

section .data

CPUinitMsg	DB	"CPU init: ",0
FPUinitMsg	DB	"FPU init: ",0

Msg_CPU386	DB	"i80386 compatible",0
Msg_CPU486	DB	"i486 compatible",0
Msg_CPUPENT	DB	"Intel Pentium",0
Msg_CPUPPRO	DB	"Intel Pentium Pro",0
Msg_CPUPMMX	DB	"Intel Pentium MMX",0
Msg_CPUP2	DB	"Intel Pentium II",0
Msg_CPUK5	DB	"AMD K5 (5k86)",0
Msg_CPUK6	DB	"AMD K6",0
Msg_CPUK62	DB	"AMD K6-2",0
Msg_CPUM1	DB	"Cyrix/IBM 6x86",0
Msg_CPUM2	DB	"Cyrix/IBM 6x86MX",0
Msg_CPUIDT	DB	"IDT C6",0
Msg_Unknown	DB	"Unknown",0

Msg_SpdInd	DB	", speed index=",0

FPUstr_Emul	DB	"floating-point emulation library, version 1.0",0
FPUstr_387	DB	"387, using IRQ13 error reporting",0
FPUstr_486	DB	"486+ (built-in), using exception 16 error reporting",0
FPUstr_none	DB	"not present or buggy",0

FPUtypeStrs	DD	FPUstr_none,FPUstr_Emul,FPUstr_Emul
		DD	FPUstr_387,FPUstr_486
		
Msg_InitDskDr	DB	NL,NL,"Initializing disk drivers"
Msg_Dots	DB	"...",NL,0
Msg_SearchPart	DB	NL,"Searching partitions on ",0
Msg_InitChDr	DB	NL,"Initializing character device drivers...",NL,0
Msg_InitErr	DB	": init error ",0
Msg_Bytes	DB " bytes.",NL,0


section .text

		; K_GetCPUtypeStr - get CPU type string.
		; Input: ESI=buffer pointer.
		; Output: none.
proc K_GetCPUtypeStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,CPUinitMsg
		call	StrCopy

		mov	al,[?CPUtype]
		cmp	al,3
		je	.386
		cmp	al,4
		je	.486
		cmp	al,5
		je	.586
		mov	esi,Msg_Unknown
		jmp	short .BldStr

.386:		mov	esi,Msg_CPU386
		jmp	short .BldStr
.486:		mov	esi,Msg_CPU486
		jmp	short .BldStr
.586:		mov	esi,Msg_CPUPENT
		jmp	short .BldStr


.BldStr:	call	StrAppend
		mov	esi,Msg_SpdInd
		call	StrAppend
		mov	esi,edi
		call	StrEnd
		mov	esi,edi
		mov	eax,[?CPUspeed]
		call	DecD2Str

		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; K_GetFPUtypeStr - get FPU type string.
		; Input: ESI=pointer to buffer.
		; Output: none.
proc K_GetFPUtypeStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,FPUinitMsg
		call	StrCopy
		call	StrEnd
		xor	eax,eax
		mov	al,[?FPUtype]
		mov	esi,[FPUtypeStrs+eax*4]
		call	StrCopy
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


		; INIT_ShowCPUFPU - show CPU & FPU type
proc INIT_ShowCPUFPU
		mov	esi,InitStringBuf
		call	K_GetCPUtypeStr
		mPrintChar ' '
		mPrintString
		mPrintChar NL

		call	K_GetFPUtypeStr
		mPrintChar ' '
		mPrintString
		mPrintChar NL
		ret
endp		;---------------------------------------------------------------


		; INIT_InitDiskDrvs - initialize disk drivers.
proc INIT_InitDiskDrvs
		; Print message
		mPrintString Msg_InitDskDr
		mov	esi,InitStringBuf

		; Initialize DIHD structures
		mov	al,16				; Max. 16 drives
		call	HD_Init

		; Initialize FDD driver
		mCallDriver byte DRVID_FDD, byte DRVF_Init
		jnc	short .FDinitOK
		mov	ebx,DRVID_FDD
		call	DrvInitErr
		jmp	near .InitIDE

.FDinitOK:	mPrintChar ' '
		mPrintString
		or	dl,dl
		jz	short .InitIDE

		; Print floppy drives information
		mov	ebx,DRVID_FDD			; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

.Loop:		push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		mPrintChar NL
		mPrintChar ' '
		mPrintString
		inc	cl
		cmp	cl,dl
		jbe	.Loop


		; Initialize HD IDE driver
.InitIDE:	mov	dl,2				; Max # of drives to search
		mCallDriver byte DRVID_HDIDE, byte DRVF_Init
		jnc	short .IDEinitOK
		mov	ebx,DRVID_HDIDE
		call	DrvInitErr
		jmp	.Exit

.IDEinitOK:	mPrintChar NL
		mPrintChar ' '
		mPrintString
		or	dl,dl
		jz	short .Exit

		; Print model of all hard disks found
		mov	dl,4
		mov	ebx,DRVID_HDIDE				; Major number
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr ; Function
		xor	cl,cl
		inc	cl

.Loop1:		push	ebx
		or	[esp+2],cl
		push	edi
		call	DRV_CallDriver
		jc	short .NoDrive
		mPrintChar NL
		mPrintChar ' '
		mPrintString
.NoDrive:	inc	cl
		cmp	cl,dl
		jbe	.Loop1

.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InitChDrv - initialize character device drivers.
proc INIT_InitChDrv
		mPrintString Msg_InitChDr
		mov	esi,InitStringBuf
		xor	al,al
		mCallDriver byte DRVID_Parallel, byte DRVF_Init
		jnc	short .PrintParSt
		mov	ebx,DRVID_Parallel
		call	DrvInitErr
		jmp	short .InitSerial

.PrintParSt:	mPrintChar ' '
		mPrintString
		mPrintChar NL

.InitSerial:	xor	al,al
		mov	ecx,(Init_SerOutBufSize << 16) + Init_SerInpBufSize
		mCallDriver byte DRVID_Serial, byte DRVF_Init
		jnc	short .PrintSerSt
		mov	ebx,DRVID_Serial
		call	DrvInitErr
		jmp	short .Continue

.PrintSerSt:	mPrintChar ' '
		mPrintString
		mPrintChar NL

.Continue:	ret
endp		;---------------------------------------------------------------


		; INIT_PrintPartTbl - open boot disk device and print its
		;		      partition table.
proc INIT_PrintPartTbl
		mov	al,SCFG_BootDev			; Get config item
		call	INIT_GetStCfgItem		; (boot device string)
		jc	near .Exit

		mov	esi,ebx				; Check for %hd or %sd
		mov	edi,BootDev_HD
		xor	ecx,ecx
		mov	cl,3
		call	StrLComp			; "%hd"?
		or	al,al
		jz	short .Do
		mov	edi,BootDev_SD
		call	StrLComp			; "%sd"?
		or	al,al
		jz	short .Do
		jmp	.OK				; Else don't print

.Do:		call	DRV_FindName			; Get device ID
		jc	near .Exit
		mov	ebx,eax				; and keep it

		and	eax,00FFFFFFh			; Mask subminor
		push	eax
		push	dword DRVF_Open
		call	DRV_CallDriver			; "Open" device
		jc	near .Exit

		mPrintString Msg_SearchPart		; Print message
		mov	eax,ebx				; Restore device ID
		and	eax,0000FFFFh
		call	DRV_GetName
		mPrintString
		mov	eax,ebx
		shr	eax,16
		add	al,30h
		call	PrintChar
		mPrintString Msg_Dots

		mov	dl,1
		mov	edi,DRVF_Control+256*DRVCTL_GetInitStatStr
		mov	esi,InitStringBuf
.Loop:		push	ebx
		mov	[esp+3],dl
		push	edi
		call	DRV_CallDriver
		jnc	short .Print
		cmp	dl,4
		ja	short .OK
		jmp	short .IncCnt
.Print:		mPrintChar ' '
		mPrintString
		mPrintChar NL
.IncCnt:	inc	dl
		jmp	.Loop
.OK:		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; INIT_InstallBinFmtDrvs - install and initialize binary
		;			   format drivers.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc INIT_InstallBinFmtDrvs
		xor	ecx,ecx
.Loop:		mov	ebx,[BinFmtDrivers+ecx*4]
		or	ebx,ebx
		jz	short .Exit
		xor	edx,edx
		call	DRV_InstallNew
		jc	short .Exit
		call	MOD_RegisterFormat
		jc	short .Exit
		inc	cl
		jmp	.Loop
.Exit:		ret
endp		;---------------------------------------------------------------
