;-------------------------------------------------------------------------------
;  api.asm - API procedures and kernel module exports.
;-------------------------------------------------------------------------------

include "rmod.ah"

include "API/fs.asm"
include "API/memman.asm"
include "API/mt.asm"


; --- Exports ---

API_NumFSfunctions	EQU	5
API_NumMMfunctions	EQU	4
API_NumMTfunctions	EQU	5

segment KDATA

UserAPIsTable:
G_FS_Open:	DD	API_FS_Open
G_FS_Close:	DD	API_FS_Close
G_FS_Read:	DD	API_FS_Read
G_FS_Write:	DD	API_FS_Write
G_FS_Seek:	DD	API_FS_Seek

G_MM_Alloc:	DD	API_MM_Alloc
G_MM_Free:	DD	API_MM_Free

G_MT_Exec:	DD	API_MT_Exec
G_MT_Exit:	DD	API_MT_Exit

		DD	0


DrvAPIsTable:
		DD	0


KRModNamesTbl	DD	0
		DW	SECT_NONE
		DB	OBJTYPE_SUBMODULE,3,".FS"

		DD	0
		DW	(G_FS_Open-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,4,"Open"

		DD	0
		DW	(G_FS_Close-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,5,"Close"

		DD	0
		DW	(G_FS_Read-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,4,"Read"

		DD	0
		DW	(G_FS_Write-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,5,"Write"

		DD	0
		DW	(G_FS_Seek-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,4,"Seek"


		DD	0
		DW	SECT_NONE
		DB	OBJTYPE_SUBMODULE,3,".MM"

		DD	0
		DW	(G_MM_Alloc-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,5,"Alloc"

		DD	0
		DW	(G_MM_Free-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,4,"Free"


		DD	0
		DW	SECT_NONE
		DB	OBJTYPE_SUBMODULE,3,".MT"

		DD	0
		DW	(G_MT_Exec-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,4,"Exec"

		DD	0
		DW	(G_MT_Exit-UserAPIsTable)/4
		DB	OBJTYPE_FARPROC,4,"Exit"

ends
