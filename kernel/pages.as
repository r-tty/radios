;*******************************************************************************
;  pages.as - routines for allocating/deallocating memory pages.
;  This code is based on Alexey Frounze's operating system kernel.
;*******************************************************************************

module kernel.pages

%include "sys.ah"
%include "errors.ah"
%include "i386/paging.ah"


; --- Exports ---

global PG_Init, PG_Alloc, PG_Dealloc, PG_FaultHanldler


; --- Code ---

section .text

		; PG_Init - initialize the memory paging.
		; Input:
		; Output:
proc PG_Init
		ret
endp		;---------------------------------------------------------------


		; PG_Alloc - allocate one page.
		; Input:
		; Output: CF=0 - OK, EAX=page address;
		;	  CF=1 - error, AX=error code.
proc PG_Alloc
		ret
endp		;---------------------------------------------------------------


		; PG_Dealloc - deallocate a page.
		; Input: EAX=page address.
		; Output:
proc PG_Dealloc
		ret
endp		;---------------------------------------------------------------


		; PG_FaultHandler - handle page faults.
		; Input: none.
		; Output: none.
proc PG_FaultHandler
		mov	ebp,esp
		mov	eax,cr2				; EAX=faulty address
		and	eax,PG_ATTRIBUTES

		test	eax,PG_PRESENT			; Protection violation?
		jnz	short .Violation

		; Add a page table and a page
		mov	ebx,eax
		mov	esi,eax
		shr	esi,PAGEDIRSHIFT

.Violation:
		ret
endp		;---------------------------------------------------------------

