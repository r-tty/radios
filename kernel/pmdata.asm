;-------------------------------------------------------------------------------
;  pmdata.asm - data for protected mode (descriptor tables, etc.)
;-------------------------------------------------------------------------------


include "KERNEL\pmdata.ah"

; --- GDT definitions ---

struc	tRGDT
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

GDT		tRGDT <>


; --- IDT definitions ---
IDT		tDescriptor <offset small Int00handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int01handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int02handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int03handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int04handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int05handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int06handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int07handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int08handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int09handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int0Ahandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int0Bhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int0Chandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int0Dhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int0Ehandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int12_1Fhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int10handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int11handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor 30 dup (<offset small Int12_1Fhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>)

		tDescriptor <offset small Int30handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int31handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int32handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int33handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL2+ARpresent,0,0>
		tDescriptor <offset small Int34handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int35handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int36handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int37handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int38handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int39handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3Ahandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3Bhandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3Chandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3Dhandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3Ehandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>
Int3Fgate	tDescriptor <offset small Int3Fhandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>

		tDescriptor 16 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset small Int50handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int51handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int52handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int53handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int54handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int55handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int56handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int57handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int58handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int59handler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Ahandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Bhandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Chandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Dhandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Ehandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Fhandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 16 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset small Int70handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int71handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int72handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int73handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int74handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int75handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int76handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int77handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int78handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int79handler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Ahandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Bhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Chandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Dhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Ehandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Fhandler,(tRGDT).KernelCode,0,\
		AR_IntGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 128 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		AR_TrapGate+AR_DPL0+ARpresent,0,0>)