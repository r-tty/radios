;-------------------------------------------------------------------------------
; pmdata.nasm - protected mode initialization data (descriptors, etc).
;-------------------------------------------------------------------------------

publicdata GDTaddrLim

extern SysReboot

section .data

; Kernel TSS
KernTSS istruc tTSS
	 at tTSS.Link,		DD	0
	 at tTSS.ESP0,		DD	90000h
	 at tTSS.SS0,		DD	KERNELDATA
	 at tTSS.ESP1,		DD	0
	 at tTSS.SS1,		DD	0
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

; Global descriptor table
GDT	istruc tDesc					; NULL descriptor
	 			DD	0,0
	iend

	; Kernel code (08h) - low 2G, execute and read
	istruc tDesc
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_CS_XR+AR_DPL0
	 at tDesc.LimHiMode,	DB	7+AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	; Kernel data (10h) - entire 4G, read and write
	istruc tDesc
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_DS_RW+AR_DPL0
	 at tDesc.LimHiMode,	DB	0Fh+AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	0
	iend

	; User code (18h) - upper 2G, execute and read
	istruc tDesc
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_CS_XR+AR_DPL3
	 at tDesc.LimHiMode,	DB	7+AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	80h
	iend

	; User data (20h) - upper 2G, read and write
	istruc tDesc
	 at tDesc.LimitLo,	DW	0FFFFh
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	ARsegment+ARpresent+AR_DS_RW+AR_DPL3
	 at tDesc.LimHiMode,	DB	7+AR_DfltSz+AR_Granlr
	 at tDesc.BaseHHB,	DB	80h
	iend

	; Kernel TSS (28h)
	istruc tDesc
	 at tDesc.LimitLo,	DW	tTSS_size-1
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_AvlTSS+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	; Kernel LDT (30h)
	istruc tDesc
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_LDTdesc+ARpresent+AR_DPL0
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend

	; User LDT (38h)
	istruc tDesc
	 at tDesc.LimitLo,	DW	0
	 at tDesc.BaseLW,	DW	0
	 at tDesc.BaseHLB,	DB	0
	 at tDesc.AR,		DB	AR_LDTdesc+ARpresent+AR_DPL3
	 at tDesc.LimHiMode,	DB	0
	 at tDesc.BaseHHB,	DB	0
	iend


%macro mDefineOffset 2-3
		DD	%1%2%3
%endmacro


; --- Trap handlers ---

TrapHandlersArr:

%assign i 0
%rep 18							; Exception handlers
		mDefineOffset Exception,i,Handler
%assign i i+1
%endrep

		TIMES 14 DD K_ReservedException		; Reserved by Intel

%assign i 0
%rep 16							; IRQ handlers
		mDefineOffset K_ISR,i
%assign i i+1
%endrep

%assign i 48
%rep 16							; Service traps
		mDefineOffset ServTrap,i,Handler
%assign i i+1
%endrep

TrapHandlersArrEnd:


; --- Addresses and limits of descriptor tables ---
; GDT is fixed
GDTaddrLim	DW	GDT_size-1
		DD	GDT

; IDT is built dynamically
IDTaddrLim	DW	IDT_size-1
		DD	0
