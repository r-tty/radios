;-------------------------------------------------------------------------------
; conio.nasm - some DOS-like terminal I/O functions.
;-------------------------------------------------------------------------------

module libc.conio

%include "lib/termios.ah"
%include "lib/defs.ah"

exportproc _getch, _putch, _kbhit

externproc _tcgetattr, _tcsetattr
externproc _read, _write, _poll

section .text

		; int getch(void);
proc _getch
		locals	buf
		locauto	torig, tTermIOs_size
		locauto	ttmp, tTermIOs_size
		prologue
		savereg	esi,edi,ecx

		lea	esi,[%$torig]
		Ccall	_tcgetattr, STDIN_FILENO, ebx
		lea	edi,[%$ttmp]
		mov	ecx,tTermIOs_size
		cld
		rep	movsb
		lea	edi,[%$ttmp]
		and	dword [edi+tTermIOs.IFlag],~(IXOFF | IXON)
		and	dword [edi+tTermIOs.LFlag],~(ECHO | ICANON | NOFLSH)
		or	dword [edi+tTermIOs.LFlag],ISIG
		mov	byte [edi+tTermIOs.CC+VMIN],1
		mov	byte [edi+tTermIOs.CC+VTIME],0
		Ccall	_tcsetattr, STDIN_FILENO, TCSADRAIN, edi
		lea	eax,[%$buf]
		Ccall	_read, STDIN_FILENO, byte 1
		lea	esi,[%$torig]
		Ccall	_tcsetattr, STDIN_FILENO, TCSADRAIN, esi
		movzx	eax,byte [%$buf]
    		epilogue
		ret
endp		;---------------------------------------------------------------


		; int putch(int c);
proc _putch
		arg	ch
		locals	buf
		prologue
		Mov8	%$buf,%$ch
		lea	eax,[%$buf]
		Ccall	_write, STDOUT_FILENO, eax, byte 1
		movzx	eax,byte [%$ch]
    		epilogue
		ret
endp		;---------------------------------------------------------------


		; int kbhit(void);
proc _kbhit
		ret
endp		;---------------------------------------------------------------
