;*******************************************************************************
;  cfs_init.asm - initialization of the CFS.
;  Copyright (c) 1999-2001 RET & COM Research.
;*******************************************************************************

module cfs.init

; --- Exports ---

global CFS_Init


; --- Imports ---

library cfs.inode
extern IND_Init:near


; --- Code ---

section .text

		; CFS_Init - initialize CFS.
		; Input:
		; Output:
proc CFS_Init
		call	IND_Init
		ret
endp		;---------------------------------------------------------------
