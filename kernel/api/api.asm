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
API_FS		DD	0
		 DB	 SECT_NONE,OBJTYPE_SUBMODULE,3,".FS"
		DD	offset API_FS_Open
		 DB	 SECT_CODE,OBJTYPE_FARPROC,4,"Open"
		DD	offset API_FS_Close
		 DB	 SECT_CODE,OBJTYPE_FARPROC,5,"Close"
		DD	offset API_FS_Read
		 DB	 SECT_CODE,OBJTYPE_FARPROC,4,"Read"
		DD	offset API_FS_Write
		 DB	 SECT_CODE,OBJTYPE_FARPROC,5,"Write"
		DD	offset API_FS_Seek
		 DB	 SECT_CODE,OBJTYPE_FARPROC,4,"Seek"

API_MM		DD	0
		 DB	 SECT_NONE,OBJTYPE_SUBMODULE,3,".MM"
		DD	offset API_MM_Alloc
		 DB	 SECT_CODE,OBJTYPE_FARPROC,5,"Alloc"
		DD	offset API_MM_Free
		 DB	 SECT_CODE,OBJTYPE_FARPROC,4,"Free"
		DD	offset API_MM_AllocPg
		 DB	 SECT_CODE,OBJTYPE_FARPROC,9,"AllocPage"
		DD	offset API_MM_FreePg
		 DB	 SECT_CODE,OBJTYPE_FARPROC,8,"FreePage"

API_MT		DD 0
		;DD <>
		;DD <>
		;DD <>
		;DD <>
		;DD <>

ends
