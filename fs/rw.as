;-------------------------------------------------------------------------------
;  rw.as - read/write routines.
;-------------------------------------------------------------------------------

module cfs.rw

%include "sys.ah"
%include "errors.ah"


; --- Exports ---

global CFS_ReadDir, CFS_Lseek, CFS_Read, CFS_Write


; --- Imports ---
library cfs.open
extern ?MaxOpenFiles


; --- Code ---

section .text

		; CFS_ReadDir - read a directory.
		; Input: EBX=address of a tDirEntry structure,
		;	 EDX=file descriptor.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc CFS_ReadDir
		cmp	edx,[?MaxOpenFiles]
		jae	short .Error1

.Exit:		ret

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

