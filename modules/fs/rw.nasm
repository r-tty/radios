;*******************************************************************************
;  rw.as - read/write routines.
;  Copyright (c) 1999-2001 RET & COM Research.
;  This file is based on the Linux Kernel (c) 1991-2001 Linus Torvalds.
;*******************************************************************************

module cfs.rw

%include "sys.ah"
%include "errors.ah"
%include "thread.ah"
%include "process.ah"


; --- Exports ---

global CFS_ReadDir, CFS_Lseek, CFS_Read, CFS_Write


; --- Imports ---
library cfs.open
extern ?MaxOpenFiles

library kernel.mt
extern ?CurrThread

; --- Code ---

section .text

		; CFS_ReadDir - read a directory.
		; Input: EBX=address of a tDirEntry structure,
		;	 EDX=file descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ReadDir
%define .fd		ebp-4

		prologue 4
		push	esi
		mov	esi,ebx
		mov	[.fd],edx
		
		; Check whether a file descriptor is valid
		cmp	edx,[?MaxOpenFiles]
		jae	short .Error1
		mov	eax,[?CurrThread]
		mov	eax,[eax+tTCB.PCB]
		mov	eax,[eax+tProcDesc.Files]
		mov	ebx,[eax+tFile.FDptr]
		cmp	dword [ebx+edx*4],0
		je	short .Error1

.Exit:		pop	esi
		epilogue
		ret

.Error1:	mov	ax,ERR_FS_InvFileDesc
		stc
		jmp	.Exit
endp		;---------------------------------------------------------------


		; CFS_Seek - seek to a specified position.
		; Input: EBX=origin (begin/current/end),
		;	 ECX=new offset (in bytes),
		;	 EDX=file descriptor.
		; Output: CF=0 - OK, EDI=new position;
		;	  CF=1 - error, AX=error code.
proc CFS_Seek
		ret
endp		;---------------------------------------------------------------


		; CFS_Read - read a file.
		; Input: EBX=buffer address,
		;	 ECX=number of bytes to read,
		;	 EDX=file descriptor.
		; Output: CF=0 - OK, EAX=number of read bytes;
		;	  CF=1 - error, AX=error code.
proc CFS_Read
		ret
endp		;---------------------------------------------------------------


		; CFS_Write - write a file.
		; Input: EBX=buffer address,
		;	 ECX=number of bytes to write,
		;	 EDX=file descriptor.
		; Output: CF=0 - OK, EAX=number of written bytes;
		;	  CF=1 - error, AX=error code.
proc CFS_Write
		ret
endp		;---------------------------------------------------------------

