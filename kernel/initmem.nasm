;*******************************************************************************
;  initmem.nasm - routines for memory initialization.
;  Copyright (c) 2001 RET & COM Research.
;*******************************************************************************

module kernel.initmem

;%define VERBOSE

%include "sys.ah"
%include "errors.ah"
%include "x86/paging.ah"
%include "boot/mb_info.ah"
%include "boot/bootdefs.ah"
%include "asciictl.ah"

%define DRIVERAREASTART	1000000h
%define USERAREASTART	80000000h


; --- Exports ---

global K_InitMem:proc
global ?BaseMemSz:data, ?ExtMemSz:data
global ?PhysMemPages:data, ?VirtMemPages:data, ?TotalMemPages:data
global ?DrvrAreaStart:data, ?UserAreaStart:data

; --- Imports ---

library kernel.x86.basedev
extern CMOS_ReadBaseMemSz, CMOS_ReadExtMemSz


; --- Data ---

section .data

%ifdef VERBOSE
MsgDumpHdr	DB	NL,"BIOS memory map dump:"
		DB	NL," Base address",ASC_HT,"Size (bytes)",ASC_HT
		DB	"Pages",NL,0
%endif

; --- Variables ---
section .bss

; Memory sizes (in kilobytes)
?BaseMemSz	RESD	1
?ExtMemSz	RESD	1

; Number of extended memory pages
?PhysMemPages	RESD	1			; Number of upper memory pages
?VirtMemPages	RESD	1			; Virtual memory pages
?TotalMemPages	RESD	1			; Total pages (upper+virtual)

; Driver and user area start addresses
?DrvrAreaStart	RESD	1
?UserAreaStart	RESD	1

; --- Code ---

section .text

		; K_InitMem - find out how much memory we have, and if
		;	      there is a BIOS memory map - arrange it.
		; Input: EAX=size of lower memory.
		; Output: CF=1 - error;
		;	  CF=0 - OK.
proc K_InitMem
		mov	[?BaseMemSz],eax
		mov	ecx,[UpperMemSizeKB]		; Memory map present?
		or	ecx,ecx
		jnz	short .MemSizOK
		call	K_ProbeMem			; If no map - probe mem
		jc	short .Exit
.MemSizOK:	mov	[?ExtMemSz],ecx
		shr	ecx,2
		mov	[?PhysMemPages],ecx
		mov	[?TotalMemPages],ecx

	%ifdef VERBOSE
		; Dump enhanced memory map, if presents
		cmp	dword [BIOSMemMapSize],0
		jz	short .OK
		call	K_DumpBMM
	%endif
	
.OK:		mov	dword [?DrvrAreaStart],DRIVERAREASTART
		mov	dword [?UserAreaStart],USERAREASTART
		clc
.Exit:		ret
endp		;---------------------------------------------------------------


		; K_ProbeMem - get memory size from CMOS and test upper memory.
		;	       This routine is called if there's no BIOS memmap.
		; Input: none.
		; Output: CF=0 - OK, ECX=size of extended memory in KB;
		;	  CF=1 - error, AX=error code.
proc K_ProbeMem
		call	CMOS_ReadExtMemSz	; Get upper memory size
		movzx	eax,ax
		mov	[?ExtMemSz],eax		; Store (<=64 MB)

		xor	eax,eax			; Prepare to test
		mov	[?PhysMemPages],eax	; extended memory
		mov	esi,StartOfExtMem

.Loop2:		mov	ah,[esi]		; Get byte
		mov	byte [esi],0AAh		; Replace it with this
		cmp	byte [esi],0AAh		; Make sure it stuck
		mov	[esi],ah		; Restore byte
		jne	.StopScan		; Quit if failed
		mov	byte [esi],055h		; Otherwise replace it with this
		cmp	byte [esi],055h		; Make sure it stuck
		mov	[esi],ah		; Restore original value
		jne	.StopScan		; Quit if failed
		inc	dword [?PhysMemPages]	; Found a page
		add	esi,PAGESIZE		; Go to next page
		jmp	.Loop2

.StopScan:	mov	eax,[?PhysMemPages]
		shl	eax,2
		cmp	dword [?ExtMemSz],32768
		jae	short .SizeOK
		cmp	eax,[?ExtMemSz]
		jne	short .Err3
.SizeOK:	mov	ecx,eax
		clc
.Exit:		ret

.Err2:		mov	ax,ERR_MEM_ExtTestErr
		stc
		ret
.Err3:		mov	ax,ERR_MEM_InvCMOSExtMemSz
		stc
		ret
endp		;---------------------------------------------------------------


%ifdef VERBOSE

		; K_DumpBMM - Dump BIOS memory map.
		; Input: none.
		; Output: none.
proc K_DumpBMM
		mpush	ebx,ecx,esi
		mServPrintStr MsgDumpHdr
		mov	ecx,[BIOSMemMapSize]
		or	ecx,ecx
		jz	near .Exit
		mov	ebx,[BIOSMemMapAddr]
.Loop:		mServPrintChar ' '
		mov	eax,[ebx+tAddrRangeDesc.BaseAddrLow]
		mServPrint32h
		mServPrintChar 9
		mov	eax,[ebx+tAddrRangeDesc.LengthLow]
		push	eax
		mServPrint32h
		mServPrintChar 9
		pop	eax
		shr	eax,PAGESHIFT
		mServPrintDec
		mServPrintChar 10
		mov	eax,[ebx+tAddrRangeDesc.Size]
		add	eax,byte 4
		sub	ecx,eax
		jz	short .OK
		add	ebx,eax
		jmp	.Loop
.OK:		mServPrintChar 10
.Exit:		mpop	esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------

%endif

