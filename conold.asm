ConNames	DB "CONSOLE00       "		; Consoles with color screen
		DB "CONSOLE01       "
		DB "CONSOLE02       "
		DB "CONSOLE03       "
		DB "CONSOLE04       "
		DB "CONSOLE05       "
		DB "CONSOLE06       "
		DB "CONSOLE07       "
		DB "CONSOLE08       "		; Monochrome screen (reserved)
		DB "CONSOLE09       "
		DB "CONSOLE10       "
		DB "CONSOLE11       "
		DB "CONSOLE12       "
		DB "CONSOLE13       "
		DB "CONSOLE14       "
		DB "CONSOLE15       "

		; CON_InstallDrv - install console driver.
		; Input: AL=console number.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_InstallDrv near
		cmp	al,MAXCONNUM
		ja	InstDrv_Err
		push	eax
		push	ebx
		push	ecx
		push	edx

		pop	edx
		pop	edx
		pop	ebx
		pop	eax
		clc
		jmp	InstDrv_Exit
InstDrv_Err:	mov	ax,ERR_CON_BadConNum
		stc
InstDrv_Exit:	ret
endp		;---------------------------------------------------------------


		; CON_Init - initialize console.
		; Input: none.
		; Output: CF=0 - OK,
		;	  CF=1 - error, AX=error code.
proc CON_Init near
		clc
		ret
endp		;---------------------------------------------------------------