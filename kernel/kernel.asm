;*******************************************************************************
;  kernel.asm - RadiOS head kernel module.
;  Copyright (c) 1998 RET & COM research. All rights reserved.
;*******************************************************************************

; --------------- External procedures and data, used by kernel -----------------

extrn PIC_EOI1:	near
extrn PIC_EOI2:	near

; --------------------------- Kernel modules -----------------------------------

include "errdefs.ah"
include "sysdata.ah"

include "KERNEL\pmdata.asm"

include "KERNEL\int00-1f.asm"
include "KERNEL\int30-4f.asm"
include "KERNEL\int50-6f.asm"
include "KERNEL\int70-7f.asm"

include "KERNEL\MEMMAN\memman.asm"
include "KERNEL\PROCESS\process.asm"
include "KERNEL\misc.asm"
include "KERNEL\driver.asm"
include "KERNEL\api.asm"

include "KERNEL\sysdata.asm"


; -------------------------- Additional kernel part ----------------------------

		; K_DescriptorAddress - get address of descriptor.
		; Input: DX=descriptor.
		; Output: EBX=descriptor address.
proc K_DescriptorAddress near
		push	edi
		movzx	edx,dx
		test	dx,SELECTOR_LDT		; See if in LDT
		jz	@@GetGDT
		xor	edi,edi			; If so get LDT selector
		sldt	di
		and	edi,not SELECTOR_STATUS	; Strip off RPL and TI
		add	edi,offset GDT		; Find position in GDT
		call	K_GetDescriptorBase	; Load up the LDT base address
		mov	ebx,edi
		jmp	short @@GotLDT
@@GetGDT:	mov	ebx,offset GDT		; Otherwise just get the GDT table
@@GotLDT:	and	edx,not SELECTOR_STATUS	; Strip off RPL and TI of descriptor
		add	ebx,edx			; Add in to table base
		pop	edi
		ret
endp		;---------------------------------------------------------------


		; K_GetDescriptorBase - get base fields of descriptor.
		; Input: EBX=descriptor address.
		; Output: EDI=base address.
proc K_GetDescriptorBase near
		push	eax
		mov	al,[ebx+tDescriptor.Base23]
		mov	ah,[ebx+tDescriptor.Base31]
		shl	eax,16
		mov	ax,[ebx+tDescriptor.Base15]
		mov	edi,eax
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_SetDescriptorBase - set base fields of descriptor.
		; Input: EBX=descriptor address,
		;	 EDI=base address.
		; Output: none.
proc K_SetDescriptorBase near
		push	eax
		mov	eax,edi
		mov	[ebx+tDescriptor.Base15],ax
		shr	eax,16
		mov	[ebx+tDescriptor.Base23],al
		mov	[ebx+tDescriptor.Base31],ah
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_GetDescriptorLimit - get limit fields of descriptor.
		; Input: EBX=descriptor address.
		; Output: EAX=limit.
proc K_GetDescriptorLimit near
		mov	al,[ebx+tDescriptor.Lim19GDXU]
		and	ax,15
		shl	eax,16
		mov	ax,[ebx+tDescriptor.Limit15]
		test	[ebx+tDescriptor.Lim19GDXU],AR_Granlr
		jz	@@Exit
		shl	eax,12
		or	eax,PageSize-1
@@Exit:		ret
endp		;---------------------------------------------------------------


		; K_SetDescriptorLimit - set limit fields of descriptor.
		; Input: EBX=descriptor address,
		;	 EAX=limit.
		; Output: none.
proc K_SetDescriptorLimit near
		and	[ebx+tDescriptor.Lim19GDXU],not AR_Granlr
		test	eax,0FFF00000h
		jz	@@LowGrn
		or	[ebx+tDescriptor.Lim19GDXU],AR_Granlr
		shr	eax,12
@@LowGrn:	mov	[ebx+tDescriptor.Limit15],ax
		shr	eax,16
		and	[ebx+tDescriptor.Lim19GDXU],15
		or	[ebx+tDescriptor.Lim19GDXU],al
		ret
endp		;---------------------------------------------------------------


		; K_GetDescriptorAR - get access rights fields of descriptor.
		; Input: EBX=descriptor address.
		; Output: AX=ARs.
proc K_GetDescriptorAR near
		mov	al,[ebx+tDescriptor.AR]
		mov	ah,[ebx+tDescriptor.Lim19GDXU]
		and	ah,15
		ret
endp		;---------------------------------------------------------------


		; K_SetDescriptorAR - get access rights fields of descriptor.
		; Input: EBX=descriptor address,
		;	 AX=ARs.
		; Output: none.
proc K_SetDescriptorAR near
		mov	[ebx+tDescriptor.AR],al
		and	ah,15
		or	[ebx+tDescriptor.Lim19GDXU],ah
		ret
endp		;---------------------------------------------------------------


		; K_GetGateSelector - get selector field of gate descriptor.
		; Input: EBX=descriptor address.
		; Output: DX=selector.
proc K_GetGateSelector near
		mov	dx,[ebx+tGateDescriptor.Selector]
		ret
endp		;---------------------------------------------------------------


		; K_SetGateSelector - set selector field of gate descriptor.
		; Input: EBX=descriptor address,
		;	 DX=selector.
proc K_SetGateSelector near
		mov	[ebx+tGateDescriptor.Selector],dx
		ret
endp		;---------------------------------------------------------------


		; K_GetGateOffset - get offset field of gate descriptor.
		; Input: EBX=descriptor address,
		; Output: EAX=selector.
proc K_GetGateOffset near
		mov	ax,[ebx+tGateDescriptor.OffsetHi]
		shl	eax,16
		mov	ax,[ebx+tGateDescriptor.OffsetLo]
		ret
endp		;---------------------------------------------------------------


		; K_SetGateOffset - set offset field of gate descriptor.
		; Input: EBX=descriptor address,
		;	 EAX=offset.
proc K_SetGateOffset near
		mov	[ebx+tGateDescriptor.OffsetLo],ax
		shr	ax,16
		mov	[ebx+tGateDescriptor.OffsetHi],ax
		ret
endp		;---------------------------------------------------------------


		; K_SetGateCount - set gate descriptor count field.
		; Input: EBX=descriptor address,
		;	 AL=count.
proc K_SetGateCount near
		mov	[ebx+tGateDescriptor.Count],al
		ret
endp		;---------------------------------------------------------------




; === Miscellaneous procedures ===

		; WriteChar - write character to active console.
		; Input: AL=character code.
		;
proc WriteChar near
		mCallDriver [DrvId_Con],DRVF_Write
		ret
endp		;---------------------------------------------------------------



; === Drivers managed by kernel ===


; --- Driver main structures ---
DrvCPU		tDriver <"%CPU            ",offset DrvCPUET,DRVFL_Kernel>
DrvFPU		tDriver <"%FPU            ",offset DrvFPUET,0>
DrvMemory	tDriver <"%memory         ",offset DrvMemET,DRVFL_Kernel>


; --- Driver entry point tables ---
DrvCPUET	tDrvEntries < CPUDrv_Init,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      CPUcontrol >

DrvFPUET	tDrvEntries < FPUDrv_Init,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      FPUcontrol >

DrvMemET 	tDrvEntries < MemDrv_Init,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL >


; --- CPU driver ---

; Control functions table
CPUcontrol	DD	CPU_GetInitStatStr

; Initialization status string
CPUinitStatStr	DB 80 dup (0)

; Procedures
		; CPUdrv_Init - determine CPU type and speed index.
		; Input: none.
		; Output: ESI=pointer to driver information string.
proc CPUDrv_Init near
		push	eax
		push	ecx
		push	edi
		call	CPU_GetType
		mov	[CPUtype],al
		mov	cx,1024
		call	TMR_CountCPUspeed
		mov	[CPUspeed],ecx

		mov	edi,offset CPUinitStatStr
		mov	esi,offset DrvCPU.DrvName
		call	StrCopy
		mov	esi,edi
		call	StrEnd
		mov	[word edi],909h
		mov	[word edi+2]," :"
		mov	[byte edi+4],0
		mov	edi,esi

		mov	al,[CPUtype]
		cmp	al,3
		je	@@386
		cmp	al,4
		je	@@486
		cmp	al,5
		je	@@586
		mov	esi,offset INFO_Unknown
		jmp	short @@BldStr

@@386:		mov	esi,offset INFO_CPU386
		jmp	short @@BldStr
@@486:		mov	esi,offset INFO_CPU486
		jmp	short @@BldStr
@@586:		mov	esi,offset INFO_CPUPENT
		jmp	short @@BldStr


@@BldStr:	call	StrAppend
		mov	esi,offset INFO_SpdInd
		call	StrAppend
		mov	esi,edi
		call	StrEnd
		mov	eax,[CPUspeed]
		call	K_DecD2Str

		mov	esi,offset CPUinitStatStr
		call    StrEnd
		mov	[word edi],NL

		pop	edi
		pop	ecx
		pop	eax
		ret
endp		;---------------------------------------------------------------

		; CPU_GetInitStatStr - get pointer to driver initialization
		;		       status string.
		; Input: none.
		; Output: ESI=pointer to string.
proc CPU_GetInitStatStr near
		mov	esi,offset CPUinitStatStr
		ret
endp		;---------------------------------------------------------------


; --- FPU driver ---

; Control functions table
FPUcontrol	DD	FPU_GetInitStatStr

; Initialization status string
FPUinitStatStr	DB 80 dup (?)

; Procedures
		; FPU_Init
proc FPUDrv_Init near
		ret
endp		;---------------------------------------------------------------

		; FPU_GetInitStatStr - get pointer to driver initialization
		;		       status string.
		; Input: none.
		; Output: ESI=pointer to string.
proc FPU_GetInitStatStr near
		mov	esi,offset FPUinitStatStr
		ret
endp		;---------------------------------------------------------------

; --- Memory driver ---

; Initialization status string
MemDrvInitStr	DB 80 dup (?)
MemDISSbase	DB " KB base, ",0
MemDISSext	DB " KB extended",0

; Externals
extrn CMOS_ReadBaseMemSz:	near
extrn CMOS_ReadExtMemSz:	near

; Procedures
		; MemDrv_Init - read memory size from CMOS
		;		and test extended memory.
		; Input: none.
		; Output: CF=0 - OK:
		;		 ECX=size of extended memory in KB,
		;		 ESI=pointer to driver information string.
		;	  CF=1 - error, AX=error code.
proc MemDrv_Init near
		push	eax
		push	edi
		xor	ecx,ecx
		mov	cl,5				; Read from CMOS
@@Loop1:	call	CMOS_ReadBaseMemSz		; 5 times
		cmp	ax,640
		je	@@BaseOK
		loop	@@Loop1
		jmp	@@Err1

@@BaseOK:	movzx	eax,ax

		mov	edi,offset MemDrvInitStr
		mov	esi,offset DrvMemory.DrvName
		call	StrCopy
		mov	esi,edi
		call	StrEnd
		mov	[byte edi],9
		mov	[word edi+1]," :"
		lea	edi,[edi+3]
		call	K_DecD2Str
		mov	edi,offset MemDrvInitStr
		mov	esi,offset MemDISSbase
		call	StrAppend

		call	CMOS_ReadExtMemSz
		 movzx	eax,ax					; 64 MB limit

                call	StrEnd
		call	K_DecD2Str
		mov	edi,offset MemDrvInitStr
		mov	esi,offset MemDISSext
		call	StrAppend

		mov	ecx,eax

		mov	esi,offset MemDrvInitStr
		call    StrEnd
		mov	[word edi],NL
		clc
		jmp	short @@Exit

@@Err1:		mov	[word esp],ERR_MEM_InvBaseSz
		jmp	short @@Err
@@Err2:		mov	[word esp],ERR_MEM_ExtTestErr
@@Err:		stc
@@Exit:         pop	edi
		pop	eax
		ret
endp		;---------------------------------------------------------------
