;-------------------------------------------------------------------------------
;  scfg.as - RadiOS startup configuration table.
;-------------------------------------------------------------------------------

%define	SCFG_Signature	00435352h

StartupCfg	DD	SCFG_Signature
		DW	6				; Number of items
		DW	CfgItem0-StartupCfg		; Item addresses
		DW	CfgItem1-StartupCfg
		DW	CfgItem2-StartupCfg
		DW	CfgItem3-StartupCfg
		DW	CfgItem4-StartupCfg
		DW	CfgItem5-StartupCfg

CfgItem0	DB	"%ramdisk",0			; Root device
CfgItem1	DB	"F:",0				; Root linkpoint
CfgItem2	DW	1440				; RAM-disk size
CfgItem3	DW	512				; Buffers memory (KB)
CfgItem4	DB	0				; Swap device
CfgItem5	DD	0				; Swap size (KB)

