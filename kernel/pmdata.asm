;-------------------------------------------------------------------------------
;  pmdata.asm - data for protected mode (descriptor tables, etc.)
;-------------------------------------------------------------------------------


include "KERNEL\pmdata.ah"

; --- GDT definitions ---

struc	tZGDT
 NullDesc	tDescriptor <>
 KernelCode	tDescriptor <0FFFFh,0,0,ARsegment+ARpresent+AR_CS_X+AR_DPL0,\
 			     0Fh+AR_DfltSz,0>
 KernelData	tDescriptor <0FFFFh,0,0,ARsegment+ARpresent+AR_DS_RW+AR_DPL0,\
			     0Fh+AR_DfltSz,0>
 HMAdata	tDescriptor <0FFFFh,0,10h,ARsegment+ARpresent+AR_DS_RW+AR_DPL1,\
			     0,0>
 DrvCode	tDescriptor <0,0,11h,ARsegment+AR_CS_X+AR_DPL2,AR_DfltSz,0>
 DrvData	tDescriptor <0,0,11h,ARsegment+AR_DS_RW+AR_DPL2,AR_DfltSz,0>
 HeapCode	tDescriptor <0FFFFh,0,11h,ARsegment+AR_CS_X+AR_DPL3,\
			     0Fh+AR_Granlr+AR_DfltSz,0>
 HeapData	tDescriptor <0FFFFh,0,11h,ARsegment+AR_DS_RW+AR_DPL3,\
			     0Fh+AR_Granlr+AR_DfltSz,0>
 Reserved	tDescriptor 2 dup (<>)
ends

GDT		tZGDT <>


; --- IDT definitions ---
IDT		tDescriptor <offset Int00handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int01handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int02handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int03handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int04handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int05handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int06handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int07handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int08handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int09handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int0Ahandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int0Bhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int0Chandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int0Dhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int0Ehandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int12_1Fhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int10handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int11handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor 30 dup (<offset Int12_1Fhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>)

		tDescriptor <offset Int30handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int31handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset Int32handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset Int33handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL2+ARpresent,0,0>
		tDescriptor <offset Int34handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int35handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset Int36handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int37handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int38handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int39handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int3Ahandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int3Bhandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset Int3Chandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset Int3Dhandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset Int3Ehandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
Int3Fgate	tDescriptor <offset Int3Fhandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>

		tDescriptor 16 dup (<offset IntReservedHandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset Int50handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int51handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int52handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int53handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int54handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int55handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int56handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int57handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int58handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int59handler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int5Ahandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int5Bhandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int5Chandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int5Dhandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int5Ehandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int5Fhandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 16 dup (<offset IntReservedHandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset Int70handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int71handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int72handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int73handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int74handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int75handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int76handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int77handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int78handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int79handler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int7Ahandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int7Bhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int7Chandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int7Dhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int7Ehandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset Int7Fhandler,(tZGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 128 dup (<offset IntReservedHandler,(tZGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>)