;-------------------------------------------------------------------------------
;  pmdata.asm - data for protected mode (descriptor tables, etc.)
;-------------------------------------------------------------------------------

; --- GDT definitions ---
GDT		tRGDT <>


; --- IDT definitions ---
IDT		tDescriptor <offset small Int0Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int1Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int2Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int4Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int6Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int8Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int9Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int10Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int11Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int12Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int13Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int14Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int15Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int16Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int17Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor 30 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>)

		tDescriptor <offset small Int30Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int31Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int32Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int33Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL2+ARpresent,0,0>
		tDescriptor <offset small Int34Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int35Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int36Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int37Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int38Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int39Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3AHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3BHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3CHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3DHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3EHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
Int3Fgate	tDescriptor <offset small Int3FHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>

		tDescriptor 16 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset small Int50Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int51Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int52Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int53Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int54Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int55Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int56Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int57Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int58Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int59Handler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5AHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5BHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5CHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5DHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5EHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5FHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 16 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset small Int70Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int71Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int72Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int73Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int74Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int75Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int76Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int77Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int78Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int79Handler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7AHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7BHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7CHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7DHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7EHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7FHandler,(tRGDT).KernelCode,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 128 dup (<offset small IntReservedHandler,(tRGDT).KernelCode,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>)
