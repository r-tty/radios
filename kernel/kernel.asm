;*******************************************************************************
;  kernel.asm - RadiOS head kernel file.
;  Copyright (c) 1998,99 RET & COM research. 
;*******************************************************************************

.386p
Ideal

include "macros.ah"
include "errdefs.ah"
include "gdt.ah"
include "strings.ah"
include "misc.ah"
include "kernel.ah"
include "signal.ah"
include "drivers.ah"
include "hardware.ah"
include "biosdata.ah"
include "segments.ah"

segment KCODE
org 1000h

include "pmdata.asm"

include "ints.asm"
include "driver.asm"
include "misc.asm"
include "kheap.asm"
include "channel.asm"
include "module.asm"
include "paging.asm"
include "remaps.asm"

include "MEMMAN\memman.asm"
include "MTASK\mt.asm"
include "API\api.asm"

; ------------------------- Additional kernel part -----------------------------

		; K_DescriptorAddress - get address of descriptor.
		; Input: DX=descriptor.
		; Output: EBX=descriptor address.
proc K_DescriptorAddress near
		push	edi
		movzx	edx,dx
		test	dx,SELECTOR_LDT		; See if in LDT
		jz	@@GetGDT
		xor	ebx,ebx			; If so get LDT selector
		sldt	bx
		and	ebx,not SELECTOR_STATUS	; Strip off RPL and TI
		add	ebx,offset GDT		; Find position in GDT
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
		push	eax
		and	[ebx+tDescriptor.Lim19GDXU],not AR_Granlr
		test	eax,0FFF00000h
		jz	@@LowGrn
		or	[ebx+tDescriptor.Lim19GDXU],AR_Granlr
		shr	eax,12
@@LowGrn:	mov	[ebx+tDescriptor.Limit15],ax
		shr	eax,16
		and	[ebx+tDescriptor.Lim19GDXU],0F0h
		or	[ebx+tDescriptor.Lim19GDXU],al
		pop	eax
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
		mov	dx,[ebx+tGateDesc.Selector]
		ret
endp		;---------------------------------------------------------------


		; K_SetGateSelector - set selector field of gate descriptor.
		; Input: EBX=descriptor address,
		;	 DX=selector.
proc K_SetGateSelector near
		mov	[ebx+tGateDesc.Selector],dx
		ret
endp		;---------------------------------------------------------------


		; K_GetGateOffset - get offset field of gate descriptor.
		; Input: EBX=descriptor address,
		; Output: EAX=offset.
proc K_GetGateOffset near
		mov	ax,[ebx+tGateDesc.OffsetHi]
		shl	eax,16
		mov	ax,[ebx+tGateDesc.OffsetLo]
		ret
endp		;---------------------------------------------------------------


		; K_SetGateOffset - set offset field of gate descriptor.
		; Input: EBX=descriptor address,
		;	 EAX=offset.
proc K_SetGateOffset near
		mov	[ebx+tGateDesc.OffsetLo],ax
		shr	ax,16
		mov	[ebx+tGateDesc.OffsetHi],ax
		ret
endp		;---------------------------------------------------------------


		; K_SetGateCount - set gate descriptor count field.
		; Input: EBX=descriptor address,
		;	 AL=count.
proc K_SetGateCount near
		mov	[ebx+tGateDesc.Count],al
		ret
endp		;---------------------------------------------------------------


		; K_GetExceptionVec - get exception handler selector
		;		      and offset.
		; Input: AL=vector number.
		; Output: DX=handler selector,
		;	  EBX=handler offset.
proc K_GetExceptionVec near
		push	eax
		movzx	ebx,al
		shl	ebx,3				; Count gate address
		add	ebx,offset IDT
		call	K_GetGateOffset
		call	K_GetGateSelector
		mov	ebx,eax
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_SetExceptionVec - set exception vector.
		; Input: DX=handler selector,
		;	 EBX=handler offset,
		;	 AL=vector number.
proc K_SetExceptionVec near
		push	eax
		push	ebx
		movzx	eax,al
		shl	eax,3				; Count gate address
		add	eax,offset IDT
                xchg	eax,ebx
		call	K_SetGateOffset
		call	K_SetGateSelector
		pop	ebx
		pop	eax
		ret
endp		;---------------------------------------------------------------


		; K_SendMessage - send message to process (without buffering).
		; Input: EDX=PID,
		;	 EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - return.
proc K_SendMessage near
@@selector	EQU	ebp-4				; Gate selector (far)
@@evhandler	EQU	ebp-8				; Handler address (near)

		push	ebp
		mov	ebp,esp
		sub	esp,8
		push	ebx

		xchg	eax,edx
		call	K_GetProcDescAddr		; Get process descriptor
		jc	short @@Exit			; address in EBX
		mov	eax,[ebx+tProcDesc.EventHandler]
		cmp	[ebx+tProcDesc.Seg],0		; Another segment?
		je	short @@Kernel			; No, near call
		mov	[@@selector],eax		; Else far call
		mov	[dword @@evhandler],0

		mov	eax,edx
		call	[fword @@evhandler]
		jmp	short @@Exit

@@Kernel:	xchg	eax,edx
		call	edx

@@Exit:		pop	ebx
		mov	esp,ebp
		pop	ebp
		ret
endp		;---------------------------------------------------------------


;-------------------------------------------------------------------------------


; === Drivers managed by kernel ===

segment KDATA
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
CPUcontrol	DD	CPU_GetInitStatStr

DrvFPUET	tDrvEntries < FPU_Init,\
			      FPU_HandleEvents,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      FPUcontrol >
FPUcontrol	DD	FPU_GetInitStatStr

DrvMemET 	tDrvEntries < MemDrv_Init,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      DrvNULL,\
			      MEMcontrol >
MEMcontrol	DD	MEM_GetInitStatStr
ends


; --- CPU driver ---

		; CPUdrv_Init - determine CPU type and speed index.
		; Input: none.
		; Output: none.
proc CPUDrv_Init near
		push	ecx
		call	CPU_GetType
		mov	[CPUtype],al
		call	TMR_CountCPUspeed
		mov	[CPUspeed],ecx
		pop	ecx
		ret
endp		;---------------------------------------------------------------


		; CPU_GetInitStatStr - get driver init status string.
		; Input: ESI=init status string buffer.
		; Output: none.
proc CPU_GetInitStatStr near
		push	esi edi
		mov	edi,esi
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
		mov	esi,edi
		mov	eax,[CPUspeed]
		call	K_DecD2Str

		pop	edi esi
		ret
endp		;---------------------------------------------------------------


; --- FPU driver ---
segment KDATA
FPUtest_X	DQ	4195835
FPUtest_Y	DQ	3145727
FPUstr_Emul	DB	"floating-point emulation library, version 1.0",0
FPUstr_387	DB	"387, using IRQ13 error reporting",0
FPUstr_486	DB	"486+ (built-in), using exception 16 error reporting",0
FPUstr_none	DB	"not present or buggy",0

FPUtypeStrs	DD	FPUstr_none,FPUstr_Emul,FPUstr_Emul
		DD	FPUstr_387,FPUstr_486
ends

segment KVARS
FPU_ExcFlags	DB	0
ends

		; FPU_Init - initialize FPU.
		; Input: AL=1 - use emulation library if 387 not installed.
		; Output: none.
proc FPU_Init near
@@fcw		EQU	ebp-4
@@fdiv_bug	EQU	ebp-8

		enter	8,0
		push	ecx

		mov	[FPUtype],al
		test	[BIOSDA_Begin+tBIOSDA.Hardware],2	; FPU installed?
		jnz	short @@Test387
		cmp	al,1				; Use emulation lib?
		jne	@@Exit
		call	FPU_InitEmuLib
		jmp	@@Exit

@@Test387:	cli
		mov	ecx,cr0
		or	ecx,CR0_NE			; Enable exception 16
		mov	cr0,ecx
		mov	al,13				; Enable 387 IRQ
		call	PIC_EnbIRQ
		sti

		clts					; Clear TS in CR0
		fninit
		fnstcw	[@@fcw]
		fwait
		and	[word @@fcw],0FFC0h
		fldcw	[@@fcw]
		fwait
		mov	[FPU_ExcFlags],0
		fldz
		fld1
		fdiv	st,st(1)

		mov	ecx,100				; Delay 0.1 sec
		call	K_LDelayMs
		test	[FPU_ExcFlags],1		; IRQ13 happened?
		jz	short @@Test487
		mov	[FPUtype],3
		jmp	short @@Exit

@@Test487:	fninit
		fld	[FPUtest_X]
		fdiv	[FPUtest_Y]
		fmul	[FPUtest_Y]
		fld	[FPUtest_X]
		fsubp	st(1),st
		fistp	[dword @@fdiv_bug]
		fwait
		fninit

		cmp	[dword @@fdiv_bug],0
		jne	short @@FdivBug
		mov	[FPUtype],4
		jmp	short @@Exit

@@FdivBug:	mov	[FPUtype],0

@@Exit:		pop	ecx
		leave
		ret
endp		;---------------------------------------------------------------


		; FPU_HandleEvents - handle IRQ13 on a 387.
		; Input: none.
		; Output: none.
proc FPU_HandleEvents near
	call SPK_Tick
		or	[FPU_ExcFlags],1
		ret
endp		;---------------------------------------------------------------


		; FPU_GetInitStatStr - get driver init status string.
		; Input: ESI=init status string buffer.
		; Output: none.
proc FPU_GetInitStatStr near
		push	esi edi
		mov	edi,esi
		mov	esi,offset DrvFPU.DrvName
		call	StrCopy
		call	StrEnd
		mov	[dword edi]," :		"
		add	edi,4
		xor	eax,eax
		mov	al,[FPUtype]
		mov	esi,[FPUtypeStrs+eax*4]
		call	StrCopy
		pop	edi esi
		ret
endp		;---------------------------------------------------------------


		; FPU_InitEmuLib - initialize floating point emulation library.
		; Input: none.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc FPU_InitEmuLib near
		ret
endp		;---------------------------------------------------------------


; --- Memory driver ---

segment KVARS
; Initialization status string
MemDISSbase	DB " KB base, ",0
MemDISSext	DB " KB extended",0
ends

; Procedures
		; MemDrv_Init - read memory size from CMOS
		;		and test extended memory.
		; Input: ESI=buffer for init status string.
		; Output: CF=0 - OK:
		;		 EAX=0;
		;		 ECX=size of extended memory in KB;
		;	  CF=1 - error, AX=error code.
proc MemDrv_Init near
		push	edi
		mov	edi,esi
		xor	ecx,ecx
		mov	cl,5				; Read from CMOS
@@Loop1:	call	CMOS_ReadBaseMemSz		; 5 times
		cmp	ax,640
		je	short @@BaseOK
		loop	@@Loop1
		jmp	@@Err1

@@BaseOK:	movzx	eax,ax
		mov	[BaseMemSz],eax

		call	CMOS_ReadExtMemSz		; Get ext. mem. size
		movzx	eax,ax
		mov	[ExtMemSz],eax			; Store (<=64 MB)

		xor	eax,eax				; Prepare to test
		mov	[ExtMemPages],eax		; extended memory
		mov	esi,StartOfExtMem

@@Loop2:	mov	ah,[esi]		; Get byte
		mov	[byte esi],0AAh		; Replace it with this
		cmp	[byte esi],0AAh		; Make sure it stuck
		mov	[esi],ah		; Restore byte
		jne	short @@StopScan	; Quit if failed
		mov	[byte esi],055h		; Otherwise replace it with this
		cmp	[byte esi],055h		; Make sure it stuck
		mov	[esi],ah		; Restore original value
		jne	short @@StopScan	; Quit if failed
		inc	[ExtMemPages]		; Found a page
		add	esi,PageSize		; Go to next page
		jmp	@@Loop2

@@StopScan:	mov	eax,[ExtMemPages]
		shl	eax,2
		cmp	[ExtMemSz],32768
		jae	short @@SizeOK
		cmp	eax,[ExtMemSz]
		jne	short @@Err3
@@SizeOK:	mov	[ExtMemSz],eax
		mov	ecx,eax

@@CrStr:	mov	esi,edi
		call	MEM_GetInitStatStr
		clc
@@Exit:		pop	edi
		ret

@@Err1:		mov	ax,ERR_MEM_InvBaseSz
		jmp	short @@Err
@@Err2:		mov	ax,ERR_MEM_ExtTestErr
		jmp	short @@Err
@@Err3:		mov	ax,ERR_MEM_InvCMOSExtMemSz
@@Err:		stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; MEM_GetInitStatStr - get driver init status string.
		; Input: ESI=buffer for string.
		; Output: none.
proc MEM_GetInitStatStr near
		push	esi edi
		mov	edi,esi
		mov	esi,offset DrvMemory.DrvName
		call	StrCopy
		call	StrEnd
		mov	[dword edi]," :	"
		lea	esi,[edi+3]
		mov	eax,[BaseMemSz]
		call	K_DecD2Str
		mov	esi,offset MemDISSbase
		call	StrAppend
		call	StrEnd
		mov	esi,edi
		mov	eax,[ExtMemSz]
		call	K_DecD2Str
		mov	esi,offset MemDISSext
		call	StrAppend
		clc
		pop	edi esi
		ret
endp		;---------------------------------------------------------------


; --- Kernel event handler ---

		; KernelEventHandler - handle kernel events.
		; Input: EAX=event code.
		; Output: CF=0 - OK;
		;	  CF=1 - error.
proc KernelEventHandler near
		push	eax
		ror	eax,16
		cmp	ax,EV_SIGNAL shr 16
		je	short @@Signal
		pop	eax
		stc
		ret

@@Signal:	pop	eax
		cmp	ax,SIG_CTRLALTDEL
		je	short @@Reboot
		ret

@@Reboot:	push	esi
		mWrString INFO_Reboot
		pop	esi
		mPICACK 0
		sti
		jmp	SysReset
endp		;---------------------------------------------------------------


; --- Another common routines ---

		; K_TableSearch - search in table.
		; Input: EBX=table address,
		;	 ECX=number of elements in table,
		;	 EAX=searching mask,
		;	 DL=size of table element,
		;	 DH=offset to target field in table element.
		; Output: CF=0 - OK:
		;	   EDX=element number,
		;	   EBX=element address;
		;	  CF=1 - not found.
proc K_TableSearch near
		push	edx esi edi
		movzx	esi,dl
		movzx	edi,dh
		xor	edx,edx
@@Loop:		test	[ebx+edi],eax
		jz	short @@Found
		add	ebx,esi
		inc	edx
		cmp	edx,ecx
		je	short @@NotFound
		jmp	@@Loop
@@Found:	clc
@@Exit:		pop	edi esi edx
		ret
@@NotFound:	stc
		jmp	@@Exit
endp		;---------------------------------------------------------------


		; DrvNULL - NULL device driver.
		; Action: simply does RET.
proc DrvNULL near
		ret
endp		;---------------------------------------------------------------

ends

segment KDATA
include "kmsgs.asm"
ends

segment KVARS
include "kvars.asm"
ends

end
