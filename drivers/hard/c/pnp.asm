IDEAL
model tiny

	public	c	pin
	public	c	pout
	public	c	PnP_wait
	public	c	PnP_reset

codeseg
P386

	proc		pin C
		arg	port:word
		mov	dx,[port]
		in	al,dx
		ret
	endp		pin

	proc		pout C
		arg	port:word,value:byte
		mov	al,[value]
		mov	dx,[port]
		out	dx,al
		ret
	endp		pout


	proc		PnP_wait C
		mov	cx,0ffH;1FFFh

	@@again:
		loop	@@again
		ret
	endp		PnP_wait

	proc		PnP_reset C
		mov	dx,279h
		xor	al,al
		out	dx,al
		call	PnP_wait
		out	dx,al
		call	PnP_wait
		mov	al,6Ah
		mov	cx,20h
	@@next:
		out	dx,al
		mov	ah,al
		shr	al,1
		xor	ah,al
		shl	ah,7
		or	al,ah
		loop	@@next
		ret
	endp		PnP_reset
	
	ends
	end
