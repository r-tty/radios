;*******************************************************************************
; ramdisk.nasm - RAM disk driver module
; Copyright (c) 2002 RET & COM Research.
;*******************************************************************************

module ramdisk

%include "sys.ah"
%include "errors.ah"

%macro mSysenter 0-1
%if %0 != 0
	mov	eax,%1			; Syscall number
%endif
	mov	ecx,esp			; Our stack pointer
	mov	edx,%1			; Return address
	sysenter
%%1:
%endmacro

library kernel
extern AllocPhysMem


section .data

RDmsg		DB	" KB at ",0


section .bss

?RDstart	RESD	1				; RAM-disk address
?RDnumSectors	RESD	1				; Number of sectors
?RDopenCount	RESB	1				; Open counter
?RDinitialized	RESB	1				; Initialization status



; --- Interface procedures ---

section .text

		; RD_Init - initialize RAM-disk.
		; Input: ECX=size of RAM-disk (in KB).
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc RD_Init
		push	ecx

		shl	ecx,10			; ECX=size in bytes
		mov	dl,1			; Allocate memory
		call	AllocPhysMem		; above 1M
		jc	short .Exit
		mov	[?RDstart],ebx

		mov	eax,ecx
                shr	eax,9			; EAX=number of sectors
		mov	[?RDnumSectors],eax

		call	RD_Cleanup		; Clean disk space
		mov	byte [?RDinitialized],1	; Mark driver as initialized
		clc
		
.Exit:		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; RD_Open - "open" device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Open
		cmp	byte [?RDopenCount],0
                jne	short .Err

		inc	byte [?RDopenCount]
		ret

.Err:		mov	ax,-1
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Close - "close" device.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Close
		cmp	byte [?RDopenCount],0
                je	short .Err

		dec	byte [?RDopenCount]
		ret

.Err:		mov	ax,-1
		stc
		ret
endp		;---------------------------------------------------------------


		; RD_Read - read sector(s).
		; Input: EBX=sector number,
		;	 ECX=number of sectors to read,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Read
		mpush	ecx,esi,edi
		cmp	ebx,[?RDnumSectors]		; Check sector number
		jae	short .Err1
		mov	edi,ebx
		add	edi,ecx
		cmp	edi,[?RDnumSectors]		; Check request size
		ja	short .Err2

		shl	ecx,7				; ECX=number of dwords in disk
		mov	edi,esi				; EDI=buffer address
		mov	esi,ebx
		shl	esi,9
		add	esi,[?RDstart]			; ESI=sector address
		cld
		rep	movsd
		clc
		jmp	short .Exit

.Err1:		mov	ax,-1
		jmp	short .Error
.Err2:		mov	ax,-1
.Error:		stc
.Exit:		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RD_Write - write sector(s).
		; Input: EBX=sector number,
		;	 ECX=number of sectors to write,
		;	 ESI=buffer address.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc RD_Write
		mpush	ecx,esi,edi
		cmp	ebx,[?RDnumSectors]		; Check sector number
		jae	short .Err1
		mov	edi,ebx
		add	edi,ecx
		cmp	edi,[?RDnumSectors]		; Check request size
		ja	short .Err2

		shl	ecx,7				; ECX=number of dwords in disk
		mov	edi,ebx
		shl	edi,9
		add	edi,[?RDstart]			; EDI=sector address
		cld
		rep	movsd
		clc
		jmp	short .Exit

.Err1:		mov	ax,-1
		jmp	short .Error
.Err2:		mov	ax,-1
.Error:		stc
.Exit:		mpop	edi,esi,ecx
		ret
endp		;---------------------------------------------------------------


		; RD_Cleanup - clean disk space.
		; Input: none.
		; Output: none.
proc RD_Cleanup
		mpush	eax,ecx,edi
		mov	ecx,[?RDnumSectors]
		shl	ecx,7			; ECX=number of dwords in disk
		xor	eax,eax
		mov	edi,[?RDstart]
		cld
		rep	stosd			; Clear disk area
		mpop	edi,ecx,eax
		ret
endp		;---------------------------------------------------------------

