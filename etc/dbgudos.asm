		jmp	ENBLA20
include "ETC\a20at.asm"
ENBLA20:	mov	ax,1				; Activating A20
		call	AT_A20Handler
		mov	ax,PMSTARTSEG			; Move PM start code
		mov	ds,ax				; to HMA
		mov	ax,0FFFFh
		mov	es,ax
		mov	si,offset DBG_MOVEKRNL
		mov	di,si
		mov	cx,100h
		cld
		rep	movsb
		DB	0EAh				; Far jump in HMA
		DW	offset DBG_MOVEKRNL
		DW	0FFFFh

DBG_MOVEKRNL:	mov	ax,RADIOSKRNLSEG		; Move kernel code
		mov	ds,ax				; to 0:1000h
		xor	ax,ax
		mov	es,ax
		mov	si,1000h
		mov	di,si
		mov	cx,0F000h
		cld
		rep	movsb