;-------------------------------------------------------------------------------
;  memdet.as - memory detection routines.
;-------------------------------------------------------------------------------

global K_InitMem, K_GetMemInitStr


		; K_InitMem - get memory size from CMOS and test
		;	      the extended memory.
		; Input: EAX=size of base memory (in KB).
		; Output: CF=0 - OK, ECX=size of extended memory in KB;
		;	  CF=1 - error, AX=error code.
proc K_InitMem
		mov	[?BaseMemSz],eax

		call	CMOS_ReadExtMemSz	; Get ext. mem. size
		movzx	eax,ax
		mov	[?ExtMemSz],eax		; Store (<=64 MB)

		xor	eax,eax			; Prepare to test
		mov	[?PhysMemPages],eax	; extended memory
		mov	esi,StartOfExtMem

.Loop2:		mov	ah,[esi]		; Get byte
		mov	byte [esi],0AAh		; Replace it with this
		cmp	byte [esi],0AAh		; Make sure it stuck
		mov	[esi],ah		; Restore byte
		jne	short .StopScan		; Quit if failed
		mov	byte [esi],055h		; Otherwise replace it with this
		cmp	byte [esi],055h		; Make sure it stuck
		mov	[esi],ah		; Restore original value
		jne	short .StopScan		; Quit if failed
		inc	dword [?PhysMemPages]	; Found a page
		add	esi,PAGESIZE		; Go to next page
		jmp	.Loop2

.StopScan:	mov	eax,[?PhysMemPages]
		shl	eax,2
		cmp	dword [?ExtMemSz],32768
		jae	short .SizeOK
		cmp	eax,[?ExtMemSz]
		jne	short .Err3
.SizeOK:	mov	[?ExtMemSz],eax
		mov	ecx,eax
		mov	eax,[?PhysMemPages]
		mov	[?TotalMemPages],eax
		clc
		
.Exit:		ret

.Err2:		mov	ax,ERR_MEM_ExtTestErr
		stc
		ret
.Err3:		mov	ax,ERR_MEM_InvCMOSExtMemSz
		stc
		ret
endp		;---------------------------------------------------------------


		; K_GetMemInitStr - get memory initialization status string.
		; Input: ESI=pointer to buffer for string.
		; Output: none.
proc K_GetMemInitStr
		mpush	esi,edi
		mov	edi,esi
		mov	esi,MemInitMsg
		call	StrCopy
		call	StrEnd
		mov	esi,edi
		mov	eax,[?BaseMemSz]
		call	DecD2Str
		mov	esi,MemDISSbase
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		mov	eax,[?ExtMemSz]
		call	DecD2Str
		mov	esi,MemDISSext
		call	StrAppend
		clc
		mpop	edi,esi
		ret
endp		;---------------------------------------------------------------
