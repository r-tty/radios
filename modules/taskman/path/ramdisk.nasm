;-------------------------------------------------------------------------------
; ramdisk.nasm - routines for RAM-disk initialization.
;-------------------------------------------------------------------------------

module tm.pathman.ramdisk

%include "errors.ah"
%include "parameters.ah"
%include "serventry.ah"
%include "module.ah"
%include "tm/rfs.ah"

publicproc RD_Init

externproc RFS_CheckFSid, RFS_MakeFS
externproc TM_GetModIdByName
externproc MM_AllocBlock
externdata ?ProcListPtr

section .data

string RDmodName, {"!ramdisk.rfs.gz", 0}
string RDdevName, {"%rd", 0}

TxtAt		DB	" at ",0
TxtFSfound	DB	"File system found on RAM-disk",10,0
TxtCreatingFS	DB	"Creating new RAM file system...",10,0


section .bss

?RDstart	RESD	1				; RAM-disk address
?RDsize		RESD	1				; and size


section .text

		; RD_Init - initialize RAM-disk.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Init
		; Is ramdisk image loaded?
		mov	esi,RDmodName
		call	TM_GetModIdByName
		jc	.AllocRD
		mov	ecx,[edi+tModule.Size]
		cmp	ecx,RFS_BLOCKSIZE*128
		jb	.Err1

		; It seems so. Check if it contains a valid file system
		mov	edx,[edi+tModule.DataStart]
		call	RFS_CheckFSid
		jc	.MakeFS
		call	.PrintInfo
		jmp	.OK

.AllocRD:	mov	ecx,INITRDSIZE * 1024
		mov	esi,[?ProcListPtr]
		mov	ah,PG_WRITABLE
		call	MM_AllocBlock
		jc	.Err2
		mov	edx,ebx

		; Create a file system on the RAM disk
.MakeFS:	call	.PrintInfo
		mServPrintStr TxtCreatingFS
		call	RFS_MakeFS
		jc	.Exit

.OK:		mov	[?RDsize],ecx
		mov	[?RDstart],edx
		clc
.Exit:		ret

.Err1:		mov	ax,ERR_PTM_InvalidRAMdisk
		stc
		jmp	.Exit
.Err2:		mov	ax,ERR_PTM_UnableAllocRD
		stc
		jmp	.Exit

		; Subroutine: print information about the RAM-disk
.PrintInfo:	mServPrintStr RDdevName
		mServPrintStr TxtAt
		mServPrint32h edx
		mServPrintChar 'h'
		mServPrintChar 10
		ret
endp		;---------------------------------------------------------------
