;-------------------------------------------------------------------------------
;  scfg.as - RadiOS startup configuration table.
;-------------------------------------------------------------------------------

StartupCfg	DD	SCFG_Signature
		DW	6				; Number of items
		DW	sRootDev-StartupCfg		; Item addresses
		DW	sRDsize-StartupCfg
		DW	sBufMem-StartupCfg
		DW	sSwapDev-StartupCfg
		DW	sSwapSize-StartupCfg

sRootDev	DB	"%hd1.1",0		; Root device
sRDsize		DW	1440			; RAM-disk size
sBufMem		DW	512			; Buffers memory (KB)
sSwapDev	DD	0			; Swap device
sSwapSize	DD	0			; Swap size (KB)
