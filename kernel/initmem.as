;*******************************************************************************
;  initmem.as - routines for memory initialization.
;  Copyright (c) 2001 RET & COM Research.
;  BIOS memory map routines are based on the sources by Alexey Frounze.
;*******************************************************************************

module kernel.initmem

%define VERBOSE

%include "sys.ah"
%include "errors.ah"
%include "x86/paging.ah"
%include "boot/mb_info.ah"
%include "boot/bootdefs.ah"
%include "kconio.ah"
%include "asciictl.ah"


; --- Exports ---

global K_InitMem, K_GetMemInitStr

; --- Imports ---

library kernel
extern ?BaseMemSz, ?ExtMemSz
extern ?PhysMemPages, ?TotalMemPages

library kernel.misc
extern StrEnd:near, StrCopy:near, StrAppend:near
extern DecD2Str:near

library hw.onboard
extern CMOS_ReadBaseMemSz:near, CMOS_ReadExtMemSz:near

library kernel.kconio
extern PrintChar: near, PrintString:near
extern PrintDwordDec:near, PrintDwordHex:near


; --- Data ---

section .data

MsgMemInit	DB	"Memory init: ",0
MsgLowerMemKB	DB	" KB lower, ",0
MsgUpperMemKB	DB	" KB upper",0

%ifdef VERBOSE
MsgDumpHdr	DB	NL,"BIOS memory map dump:"
		DB	NL," Base address",ASC_HT,"Size (bytes)",ASC_HT
		DB	"Pages",NL,0
%endif


; --- Code ---

section .text

		; K_InitMem - find out how much memory we have, and if
		;	      there is a BIOS memory map - arrange it.
		; Input: EAX=size of lower memory.
		; Output: CF=1 - error;
		;	  CF=0 - OK, ECX=upper memory size in kilobytes.
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

		mov	ecx,[BIOSMemMapSize]		
		or	ecx,ecx
		jz	short .OK
		
	%ifdef VERBOSE
		call	K_DumpBMM
	%endif
	
.OK:		clc
		
.Exit:		ret
endp		;---------------------------------------------------------------


		; K_ArrangeBMM - arrange BIOS memory map blocks.
		; Input: none.
		; Output: none.
proc K_ArrangeBMM
		ret
endp		;---------------------------------------------------------------


		; K_ProbeMem - get memory size from CMOS and test upper memory.
		;	      This routine is called if there's no BIOS memmap.
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
		jne	short .StopScan		; Quit if failed
		mov	byte [esi],055h		; Otherwise replace it with this
		cmp	byte [esi],055h		; Make sure it stuck
		mov	[esi],ah		; Restore original value
		jne	short .StopScan		; Quit if failed
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


		; K_GetMemInitStr - get memory initialization status string.
		; Input: ESI=pointer to buffer for string.
		; Output: none.
proc K_GetMemInitStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,MsgMemInit
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	eax,[?BaseMemSz]
		call	DecD2Str
		mov	esi,MsgLowerMemKB
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		mov	eax,[?ExtMemSz]
		call	DecD2Str
		mov	esi,MsgUpperMemKB
		call	StrAppend
		clc
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------


%ifdef VERBOSE

		; K_DumpBMM - Dump BIOS memory map.
		; Input: none.
		; Output: none.
proc K_DumpBMM
		mpush	ebx,ecx,esi
		mPrintString MsgDumpHdr
		mov	ecx,[BIOSMemMapSize]
		or	ecx,ecx
		jz	short .Exit
		mov	ebx,[BIOSMemMapAddr]
.Loop:		mPrintChar ' '
		mov	eax,[ebx+tAddrRangeDesc.BaseAddrLow]
		call	PrintDwordHex
		mPrintChar 'h'
		mPrintChar ASC_HT
		mov	eax,[ebx+tAddrRangeDesc.LengthLow]
		push	eax
		call	PrintDwordHex
		mPrintChar 'h'
		mPrintChar ASC_HT
		pop	eax
		shr	eax,PAGESHIFT
		call	PrintDwordDec
		mPrintChar NL
		mov	eax,[ebx+tAddrRangeDesc.Size]
		add	eax,byte 4
		sub	ecx,eax
		jz	short .OK
		add	ebx,eax
		jmp	.Loop
.OK:		mPrintChar NL
.Exit:		mpop	esi,ecx,ebx
		ret
endp		;---------------------------------------------------------------

%endif


;--- Debugging stuff -----------------------------------------------------------

%ifdef DEBUG

%endif
