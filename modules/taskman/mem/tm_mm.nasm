
module tm.memman

publicproc tm_memman_init

library $libc
extern strcmp

section .data

str1	DB "str1",0
str2	DB "str2",0

section .text

proc tm_memman_init
		push str1
		push str2
	mov eax,strcmp
		call strcmp
		add esp,byte 8
		ret
	call strcmp
	ret
endp
