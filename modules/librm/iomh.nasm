;------------------------------------------------------------------------------
; iomh.nasm - message handlers.
;------------------------------------------------------------------------------

module librm.iofunc

%include "rm/resmgr.ah"
%include "rm/iomsg.ah"

exportproc RM_InitHandlers, RM_InitAttributes

section .data

ConnHandlers:	DD	RESMGR_CONNECT_NFUNCS
		DD	IOMH_Open
		DD	0				; unlink
		DD	0				; rename
		DD	0				; mknod
		DD	0				; readlink
		DD	0				; link
		DD	0				; unblock
		DD	0				; mount

IOhandlers:	DD	RESMGR_IO_NFUNCS
		DD	IOMH_Connect			; 100h
		DD	IOMH_Read			; 101h
		DD	IOMH_Write			; 102h
		DD	0				; 103h
		DD	IOMH_Stat			; 104h
		DD	IOMH_Notify			; 105h
		DD	IOMH_Devctl			; 106h
		DD	0				; 107h
		DD	IOMH_PathConf			; 108h
		DD	IOMH_lseek			; 109h
		DD	IOMH_chmod			; 10Ah
		DD	IOMH_chown			; 10Bh
		DD	IOMH_utime			; 10Ch
		DD	IOMH_OpenFD			; 10Dh
		DD	IOMH_FDinfo			; 10Eh
		DD	IOMH_Lock			; 10Fh
		DD	IOMH_Space			; 110h
		DD	IOMH_Shutdown			; 111h
		DD	IOMH_mmap			; 112h
		DD	IOMH_Msg			; 113h
		DD	0				; 114h
		DD	IOMH_Dup			; 115h
		DD	IOMH_Close			; 116h
		DD	0				; 117h
		DD	0				; 118h
		DD	IOMH_Sync			; 119h


section .text

; --- IO message handlers ------------------------------------------------------

proc IOMH_Connect
		ret
endp		;---------------------------------------------------------------


proc IOMH_Read
		ret
endp		;---------------------------------------------------------------


proc IOMH_Write
		ret
endp		;---------------------------------------------------------------


proc IOMH_Stat
		ret
endp		;---------------------------------------------------------------


proc IOMH_Notify
		ret
endp		;---------------------------------------------------------------


proc IOMH_Devctl
		ret
endp		;---------------------------------------------------------------


proc IOMH_PathConf
		ret
endp		;---------------------------------------------------------------


proc IOMH_lseek
		ret
endp		;---------------------------------------------------------------


proc IOMH_chmod
		ret
endp		;---------------------------------------------------------------


proc IOMH_chown
		ret
endp		;---------------------------------------------------------------


proc IOMH_utime
		ret
endp		;---------------------------------------------------------------


proc IOMH_OpenFD
		ret
endp		;---------------------------------------------------------------


proc IOMH_FDinfo
		ret
endp		;---------------------------------------------------------------


proc IOMH_Lock
		ret
endp		;---------------------------------------------------------------


proc IOMH_Space
		ret
endp		;---------------------------------------------------------------


proc IOMH_Shutdown
		ret
endp		;---------------------------------------------------------------


proc IOMH_mmap
		ret
endp		;---------------------------------------------------------------


proc IOMH_Msg
		ret
endp		;---------------------------------------------------------------


proc IOMH_Dup
		ret
endp		;---------------------------------------------------------------


proc IOMH_Close
		ret
endp		;---------------------------------------------------------------


proc IOMH_Sync
		ret
endp		;---------------------------------------------------------------


; --- Connect functions --------------------------------------------------------

                ; int IOMH_open(resmgr_context_t *ctp, io_open_t *msg,
                ;      IOMH_attr_t *attr, IOMH_attr_t *dattr,
                ;      struct _client_info *info);
proc IOMH_Open
		ret
endp		;---------------------------------------------------------------


; --- Other functions ----------------------------------------------------------


		; void IOMH_func_init(uint nconn, resmgr_connect_funcs_t *connect,
		;		 uint nio, resmgr_io_funcs_t *io);
proc RM_InitHandlers
		ret
endp		;---------------------------------------------------------------


		; void IOMH_attr_init(IOMH_attr_t *attr, mode_t mode,
		;		IOMH_attr_t *dattr, struct _client_info *info);
proc RM_InitAttributes
		ret
endp		;---------------------------------------------------------------
