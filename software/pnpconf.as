;*******************************************************************************
;  pnpconf.as - Plug and Play devices configuration utility.
;  Copyright (c) 1999 RET & COM research and SD Software.
;*******************************************************************************

; --- Definitions ---
bits 32


; --- Externals ---
library KERNEL
extern PNPGetConfig,PNPSetConfig,Exit

library KERNEL.MISC
extern WrString


; --- Globals ---
global ??PnPconfig


; --- Data ---
section .data
MsgVer		DB "pnpconf - ISA Plug & Play configuration utility, version 1.0",10
		DB "Copyright (c) 1999 RET & COM Research and SD Software",10,0


section .bss
stack		RESB	128


; --- Code ---
section .text

??PnPconfig:	mov	esi,MsgVer
		call	far WrString

		call	far Exit
end
