;-------------------------------------------------------------------------------
;  misc.asm - Miscelaneous hardware routines (speaker, CPU determination, etc.)
;-------------------------------------------------------------------------------

; --- CPU types ---
CPU_386SX		EQU	3
CPU_386DX		EQU	3
CPU_486			EQU	4
CPU_586			EQU	5

		; GetCPUtype - determine type of CPU
		; Input: none
		; Output: FC=1 - can't determine CPU type
		;	  FC=0 - All OK, CPU type in AL:
		;		  3 - i386 compatible,
		;		  4 - i486 compatible,
		;		  5 - Pentium compatible.
proc GetCPUtype	near
		push	ebx
                mov	eax,cr0
                mov	ebx,eax			;Original CR0 into EBX
                or	al,10h			;Set bit
                mov	cr0,eax			;Store it
                mov	eax,cr0			;Read it back
                mov	cr0,ebx			;Restore CR0
                test	al,10h			;Did it set?
                jnz	Test386DX		;Go if not 386SX

                mov	al,CPU_386SX
                jmp	GetCPU_OK

Test386DX:	mov	ecx,esp			;Original ESP in ECX
		pushfd				;Original EFLAGS in EBX
		pop	ebx
		and	esp,not 3		;Align stack to prevent 486
						;  fault when AC is flipped
		mov	eax,ebx			;EFLAGS => EAX
		xor	eax,40000h		;Flip AC flag
		push	eax			;Store it
		popfd
		pushfd				;Read it back
		pop	eax
		push	ebx			;Restore EFLAGS
		popfd
		mov	esp,ecx			;Restore ESP
		cmp	eax,ebx			;Compare old/new AC bits
		jne	Test486			;If AC changes, not 386

		mov	al,CPU_386DX
		jmp	short GetCPU_OK

Test486:	mov	al,CPU_486		;Until the Pentium appears...

GetCPU_OK:	clc
		pop	ebx
		ret
endp		;---------------------------------------------------------------