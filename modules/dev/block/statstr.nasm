
		; IDE_GetInitStatStr - get initialization status string.
		; Input: ESI=buffer for string.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
		; Note: if the minor number is given, forms string with
		;	hard disk model, else forms string with controller
		;	information and number of drives found.
proc IDE_GetInitStatStr
		mpush	eax,ebx,esi,edi
		
		mov	edi,esi		
		mov	esi,DrvIDE			; Copy "%hd"
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		
		test	edx,0FF0000h			; Minor present?
		jz	short .NoMinor

		; Check whether the device is initialized
		call	IDE_Minor2HDN
		jc	near .Exit
		cmp	word [edi+tIDEdev.BasePort],0
		jne	short .ChkSubMinor
		stc
		jmp	.Exit

.NoMinor:	mov	esi,IDE_InitStatStr
		call	StrCopy
		mov	ah,[IDE_NumChannels]
		mov	al,[IDE_NumInstDevs]
		add	ax,3030h
		mov	[edi+13],ah
		mov	[edi+27],al
                jmp	.Exit

.ChkSubMinor:	mov	edi,esi
		cld
		or	bl,bl
		jz	short .DriveModel
		mov	ebx,edx
		shr	ebx,16
		mov	eax,ebx
		add	ax,3030h
		stosb					; Store minor number,
		mov	al,'.'				; dot and
		stosw					; subminor number
		mov	eax," 	: "
		stosd
		xchg	bh,bl				; BL=partition number
		dec	bh				; BH=disk number
		push	edi				; Keep buffer address
		call	IDE_GetDPSaddr
		mov	eax,[edi+tIDEdev.CommonDesc]
		pop	edi
		jc	near .Exit
		mov	esi,edi
		call	HD_GetPartInfoStr
		jmp	.Exit

.DriveModel:	mov	ebx,edx
		shr	ebx,8
		mov	al,bh
		add	al,30h
		cld
		stosb					; Store minor number
		dec	bh
		push	edi				; Keep buffer address
		call	IDE_GetDPSaddr
		mov	ebx,edi
		pop	edi
		jc	near .Exit
		lea	esi,[ebx+tIDEdev.ModelStr]	; ESI=pointer to model
		mov	eax,"		: "
		stosd
		call	StrCopy

		call	StrEnd				; Store size string
		mov	ax,", "
		stosw
		mov	esi,edi
		mov	eax,[ebx+tIDEdev.TotalSectors]
		shr	eax,11
		call	DecD2Str
		mov	esi,IDE_MBstr
		call	StrAppend

		test	byte [ebx+tIDEdev.LDHpref],LDH_LBA	; LBA?
		jz	short .CHS
		mov	esi,IDE_LBAstr
		call	StrAppend
.CHS:		mov	esi,IDE_CHSstr
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		movzx	eax,word [ebx+tIDEdev.LCyls]
		call	DecD2Str
		call	StrEnd
		mov	byte [edi],'/'
		lea	esi,[edi+1]
		mov	ax,[ebx+tIDEdev.LHeads]
		call	DecD2Str
		call	StrEnd
		mov	byte [edi],'/'
		lea	esi,[edi+1]
		mov	ax,[ebx+tIDEdev.LSectors]
		call	DecD2Str

		mov	al,[ebx+tIDEdev.SecPerInt]
		cmp	al,1
		je	short .Exit
		mov	esi,IDE_MaxMultStr
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		call	DecD2Str
.OK:		clc
.Exit:		mpop	edi,esi,ebx,eax
		ret
endp		;---------------------------------------------------------------
