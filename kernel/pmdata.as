;-------------------------------------------------------------------------------
;  pmdata.as - descriptor tables.
;-------------------------------------------------------------------------------

global GDTaddrLim, IntHandlersArr

; Kernel TSS
KernTSS	istruc tTSS
	 at tTSS.Link,		DD	0
	 at tTSS.ESP0,		DD	90000h
	 at tTSS.SS0,		DD	KERNELDATA
	 at tTSS.ESP1,		DD	0
	 at tTSS.SS1,		DD	KERNELDATA
	 at tTSS.ESP2,		DD	0
	 at tTSS.SS2,		DD	0
	 at tTSS.CR3,		DD	0
	 at tTSS.EIP,		DD	SysReboot
	 at tTSS.EFLAGS,	DD	202h
	 at tTSS.EAX,		DD	0
	 at tTSS.ECX,		DD	0
	 at tTSS.EDX,		DD	0
	 at tTSS.EBX,		DD	0
	 at tTSS.ESP,		DD	0
	 at tTSS.EBP,		DD	0
	 at tTSS.ESI,		DD	0
	 at tTSS.EDI,		DD	0
	 at tTSS.ES,		DD	KERNELDATA
	 at tTSS.CS,		DD	KERNELCODE
	 at tTSS.SS,		DD	KERNELDATA
	 at tTSS.DS,		DD	KERNELDATA
	 at tTSS.FS,		DD	KERNELDATA
	 at tTSS.GS,		DD	KERNELDATA
	 at tTSS.LDT,		DD	KLDT
	 at tTSS.Trap,		DW	0
	 at tTSS.IOBM,		DW	0FFh
	iend

; Drivers' TSS
DrvTSS	istruc tTSS
		TIMES 18	DD	0
	 at tTSS.ES,		DD	DRVDATA
	 at tTSS.CS,		DD	DRVCODE
	 at tTSS.SS,		DD	DRVDATA
	 at tTSS.DS,		DD	DRVDATA
	 at tTSS.FS,		DD	DRVDATA
	 at tTSS.GS,		DD	DRVDATA
	 at tTSS.LDT,		DD	DLDT
	 at tTSS.Trap,		DW	0
	 at tTSS.IOBM,		DW	0FFh
	iend

; Global descriptor table
GDT	istruc tDesc					; NULL descriptor
	 			DD	0,0
	iend

	istruc tDesc					; Kernel code
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_CS_XR+AR_DPL0
	 at tDesc.LimHiMode,	DB	0Fh+AR_DfltSz
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Kernel data
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_DS_RW+AR_DPL0
	 at tDesc.LimHiMode,	DB	0Fh+AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Absolute data
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_DS_RW+AR_DPL0
	 at tDesc.LimHiMode,	DB	0Fh+AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; HMA
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	10h
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_DS_RW+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Drivers code
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	11h
	 at tDesc.AR,		DB	ARsegment+AR_CS_X+AR_DPL1
	 at tDesc.LimHiMode,	DB	AR_DfltSz
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Drivers data
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	11h
	 at tDesc.AR,		DB	ARsegment+AR_DS_RW+AR_DPL1
	 at tDesc.LimHiMode,	DB	AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; User code
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+AR_CS_X+AR_DPL3
	 at tDesc.LimHiMode,	DB	AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; User data
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+AR_DS_RW+AR_DPL3
	 at tDesc.LimHiMode,	DB	AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Kernel TSS
	 at tDesc.LimitLo,	DW	tTSS_size-1
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_AvlTSS+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Drivers TSS
	 at tDesc.LimitLo,	DW	tTSS_size-1
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_AvlTSS+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Kernel LDT
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_LDTdesc+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; Driver LDT
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_LDTdesc+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	istruc tDesc					; User LDT
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_LDTdesc+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend


%macro mDefineOffset 2
		DD	%1%2Handler
%endmacro


; --- Interrupt handlers address array ---

IntHandlersArr:

%assign i 0
%rep 18							; Exception handlers
		mDefineOffset Int,i
%assign i i+1
%endrep

		TIMES	14 DD IntReservedHandler	; Reserved by Intel

%assign i 0
%rep 16							; IRQ handlers
		mDefineOffset IRQ,i
%assign i i+1
%endrep


GDTaddrLim	DW	GDT_size-1
		DD	GDT
