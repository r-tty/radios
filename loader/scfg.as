;-------------------------------------------------------------------------------
;  scfg.as - RadiOS startup configuration table.
;-------------------------------------------------------------------------------

%define	SCFG_Signature	00435352h

StartupCfg	DD	SCFG_Signature
		DW	6				; Number of items
		DW	sRootDev-StartupCfg		; Item addresses
		DW	sRootLP-StartupCfg
		DW	sRDsize-StartupCfg
		DW	sBufMem-StartupCfg
		DW	sSwapDev-StartupCfg
		DW	sSwapSize-StartupCfg
		DW	sNumMods-StartupCfg

sRootDev	DB	"%ramdisk",0		; Root device
sRootLP		DB	"F:",0			; Root linkpoint
sRDsize		DW	1440			; RAM-disk size
sBufMem		DW	512			; Buffers memory (KB)
sSwapDev	DD	0			; Swap device
sSwapSize	DD	0			; Swap size (KB)
sNumMods	DD	0			; Number of modules loaded
