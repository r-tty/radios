;*******************************************************************************
;  svgavbe2.asm - SVGA LFB driver.
;  Copyright (c) 1999 RET & COM research.
;*******************************************************************************

; --- Definitions ---

struc	tVESAinfo
 Signature	DB	4 dup (0)
 VESAversion	DW	0
 OEMnamePtr	DD	0
 Capabilities	DD	0
 ModeListPtr	DD	0
 Memory		DW	0
 OEMversion	DW	0
 VendorName	DD	0
 ProductName	DD	0
 ProductRev	DD	0
 Reserved	DB	222 dup (0)
 ScratchPad	DB	256 dup (0)
ends

struc	tVESA_ModeInfo
 Attr		DW	0
 WindowAttr	DW	0
 Granularity	DW	0
 WindowSize	DW	0
 WinSegs	DD	0
 WinPosFun	DD	0
 BPL		DW	0
 Width		DW	0
 Height		DW	0
 CharWidth	DB	0
 CharHeight	DB	0
 Planes		DB	0
 BPP		DB	0
 Banks		DB	0
 MemoryModel	DB	0
 BankSize	DB	0
 Pages		DB	0
 Reserved1	DB	0
 RedMaskSize	DB	0
 RedMaskPos	DB	0
 GreenMaskSize	DB	0
 GreenMaskPos	DB	0
 BlueMaskSize	DB	0
 BlueMaskPos	DB	0
 RsrvdMaskSize	DB	0
 RsrvdMaskPos	DB	0
 DirScrModeInfo	DB	0
 LFBAddress	DD	0
 OffScrMemAddr	DD	0
 OffScrMemSize	DD	0
 Reserved	DB	206 dup (0)
ends

