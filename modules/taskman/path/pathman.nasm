;*******************************************************************************
; pathman.nasm - head code of the path manager.
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module tm.pathman

%include "errors.ah"
%include "parameters.ah"
%include "rm/iomsg.ah"
%include "tm/pathmsg.ah"

publicproc TM_InitPathman

externproc RD_Init, RFS_InitOCBpool, TM_SetMHfromTable

section .data

PathMsgHandlers:
mMHTabEnt MH_ResolvePath, PATH_RESOLVE
mMHTabEnt MH_ChDir, PATH_CHDIR
mMHTabEnt MH_ChRoot, PATH_CHROOT
mMHTabEnt 0

section .text

		; PTM_Init - initialize path manager.
		; Input:
		; Output:
proc TM_InitPathman
		call	RD_Init
		jc	.Exit
		mov	eax,MAXOCBS
		call	RFS_InitOCBpool
		jc	.Exit
		mov	esi,PathMsgHandlers
		call	TM_SetMHfromTable
.Exit:		ret
endp		;---------------------------------------------------------------


		; PATH_RESOLVE handler
proc MH_ResolvePath
		ret
endp		;---------------------------------------------------------------


		; PATH_CHDIR handler
proc MH_ChDir
		ret
endp		;---------------------------------------------------------------


		; PATH_CHROOT handler
proc MH_ChRoot
		ret
endp		;---------------------------------------------------------------
