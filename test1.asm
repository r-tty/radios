.286

data		segment 'data'
s	struc
 A	DW ?
 B	DD ?
 C	DW ?
 Str	DB 18 dup (?)
s	ends

StrS	s <0,0,0,'---$'>
data		ends

		org	100h
code		segment 'code'
		assume cs:code;ds:data

start:		jmp	begin

demo		proc	far
		ret	2
demo		endp

begin:		mov	ax,data
		mov	ds,ax
		lea	dx,StrS.Str
		mov	ah,9
		int	21h

		push	ax
		call	demo

		mov	ah,4Ch
		int	21h

code		ends
		end start