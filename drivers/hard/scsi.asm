;*******************************************************************************
;  scsi.asm - SCSI controller and drives control module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --- Publics ---
		public DrvHDSCSI


; --- Data ---

; HD driver main structure
DrvHDSCSI	tDriver <"%hd             ",offset DrvSCSIET,0>

; Driver entry points table
DrvSCSIET	tDrvEntries < SCSI_Init,\
			      SCSI_HandleEvent,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL >

; --- Procedures ---

		; SCSI_Init
proc SCSI_Init near
		ret
endp		;---------------------------------------------------------------


		; SCSI_HandleEvent
proc SCSI_HandleEvent near
		ret
endp		;---------------------------------------------------------------
