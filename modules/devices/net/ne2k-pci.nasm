;*******************************************************************************
;  ne2k-pci.as - NE2000 compatible PCI card driver.
;  (c) 1999 RET & COM Research.
;*******************************************************************************

module hw.net.ne2k-pci

%include "sys.ah"
%include "driver.ah"


global DrvNE2K_PCI


section .data

DrvNE2K_PCI	DB	"%ne2k-pci"
		TIMES	16-$+DrvNE2K_PCI DB 0
		DD	DrvNE2KP_ET
		DW	0

DrvNE2KP_ET	DD	0


section .text
