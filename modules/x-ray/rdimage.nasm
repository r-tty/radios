;-------------------------------------------------------------------------------
;  rdimage.as - create RAM-disk image.
;-------------------------------------------------------------------------------

		; Create RAM-disk image
proc RKDT_CreateRDimage
		; Link %ramdisk with %rfs at F:
		mov	esi,[DrvId_RFS]
		mov	edi,[DrvId_RD]
		mov	dl,5
		mov	dh,flFSL_NoInitFS
		call	CFS_LinkFS
		jc	near .Err

		; Make filesystem on %ramdisk
		mov	dl,5			; "F:"
		xor	esi,esi
		call	CFS_MakeFS
		jc	near .Err
		call	CFS_SetCurrentLP

		; Unlink filesystem from %ramdisk
		mov	dl,5
		call	CFS_UnlinkFS
		jc	near .Err
		mPrintMsg msg_FScreated

		; Link filesystem again
		mov	esi,[DrvId_RFS]
		mov	edi,[DrvId_RD]
		mov	dx,5
		call	CFS_LinkFS
		jc	near .Err

		; Create config file
		mov	esi,CfgName
		xor	edx,edx
		xor	eax,eax
		call	CFS_CreateFile
		jnc	short .WrConf
		call	RKDT_ErrorHandler
		jmp	.Err

		; Write config file
.WrConf:	mov	esi,ConfigFile
		mov	ecx,SizeOfCfgFile
		xor	eax,eax
		call	CFS_Write
		jnc	short .CloseCfg
		call	RKDT_ErrorHandler
		jmp	short .Err

		; Close config file
.CloseCfg:	xor	eax,eax
		call	CFS_Close
		jc	short .Err

		; Unlink filesystem from %ramdisk
		mov	dl,5
		call	CFS_UnlinkFS
		jc	short .Err

		mPrintMsg msg_CfgCreated
		ret

.Err:		int3
		ret
endp		;---------------------------------------------------------------