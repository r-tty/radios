;-------------------------------------------------------------------------------
;  pmdata.asm - data for protected mode (descriptor tables, etc.)
;-------------------------------------------------------------------------------

; --- GDT ---
GDT		tRGDT <>


; --- IDT ---
IDT		tDescriptor <offset small Int0Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int1Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int2Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int4Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int6Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int8Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int9Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int10Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int11Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int12Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int13Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int14Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int15Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int16Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int17Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor 30 dup (<offset small IntReservedHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>)

		tDescriptor <offset small Int30Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int31Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int32Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int33Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL2+ARpresent,0,0>
		tDescriptor <offset small Int34Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int35Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int36Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int37Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int38Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int39Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3AHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int3BHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3CHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3DHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
		tDescriptor <offset small Int3EHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>
Int3Fgate	tDescriptor <offset small Int3FHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>

		tDescriptor 16 dup (<offset small IntReservedHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset small Int50Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int51Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int52Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int53Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int54Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int55Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int56Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int57Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int58Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int59Handler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5AHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5BHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5CHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5DHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5EHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int5FHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 16 dup (<offset small IntReservedHandler,KERNELCODE,0,\
		 AR_TrapGate+AR_DPL0+ARpresent,0,0>)

		tDescriptor <offset small Int70Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int71Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int72Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int73Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int74Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int75Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int76Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int77Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int78Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int79Handler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7AHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7BHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7CHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7DHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7EHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>
		tDescriptor <offset small Int7FHandler,KERNELCODE,0,\
		 AR_IntGate+AR_DPL3+ARpresent,0,0>

		tDescriptor 128 dup (<offset small IntReservedHandler,\
		 KERNELCODE,0,AR_TrapGate+AR_DPL0+ARpresent,0,0>)
