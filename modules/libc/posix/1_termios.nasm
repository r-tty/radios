;-------------------------------------------------------------------------------
; posix/1_termios.nasm - POSIX termios routines.
;-------------------------------------------------------------------------------

module libc.termios

%include "errors.ah"
%include "locstor.ah"
%include "lib/termios.ah"
%include "rm/devctl.ah"
%include "rm/devctl_char.ah"

exportproc _tcdrain, _tcdropline, _tcflow, _tcflush, _tcsendbreak
exportproc _tcgetattr, _tcsetattr, _tcgetprgp, _tcsetpgrp
exportproc _cfgetispeed, _cfsetispeed, _cfgetospeed, _cfsetospeed

externproc DevControl

section .text

		; int tcdrain(int fd);
proc _tcdrain
		arg	fd
		prologue
		Ccall	DevControl, dword [%$fd], DCMD_CHR_TCDRAIN, byte 0, \
			byte 0, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcdropline(int fd, int duration);
proc _tcdropline
		arg	fd, dur
		prologue
		mov	eax,[%$dur]
		or	eax,eax
		jz	.1
		mov	eax,300
.1:		shl	eax,byte 16
		or	eax,SERCTL_DTR_CHG
		mov	[%$dur],eax
		lea	eax,[%$dur]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_SERCTL, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcflow(int fd, int action);
proc _tcflow
		arg	fd, action
		prologue
		lea	eax,[%$action]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_TCFLOW, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcflush(int fd, int queue);
proc _tcflush
		arg	fd, queue
		prologue
		lea	eax,[%$queue]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_TCFLUSH, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcgetattr(int fd, struct termios *tp);
proc _tcgetattr
		arg	fd, tp
		prologue
		lea	eax,[%$tp]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_TCGETATTR, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcgetpgrp(int fd);
proc _tcgetpgrp
		arg	fd
		locals	pgrp
		prologue
		lea	eax,[%$pgrp]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_TCGETPGRP, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		cmp	eax,-1
		je	.Exit
		mov	eax,[%$pgrp]
.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcsendbreak(int fd, int duration);
proc _tcsendbreak
		arg	fd, dur
		prologue
		mov	eax,[%$dur]
		cmp	eax,8000h
		jae	.Err
		or	eax,eax
		jz	.1
		mov	eax,300
.1:		shl	eax,byte 16
		or	eax,SERCTL_BRK_CHG | SERCTL_BRK
		mov	[%$dur],eax
		lea	eax,[%$dur]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_SERCTL, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
.Exit:		epilogue
		ret

.Err:		mSetErrno EINVAL, eax
		xor	eax,eax
		dec	eax
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int tcsetattr(int fd, int optact, const struct termios *tp);
proc _tcsetattr
		arg	fd, optact, tp
		locals	dcmd
		prologue
		savereg	edx

		mov	eax,[%$optact]
		mov	edx,DCMD_CHR_TCSETATTR
		cmp	eax,TCSANOW
		je	.1
		mov	edx,DCMD_CHR_TCSETATTRD
		cmp	eax,TCSADRAIN
		je	.1
		mov	edx,DCMD_CHR_TCSETATTRF
		cmp	eax,TCSAFLUSH
		je	.1
		mSetErrno EINVAL, eax
		xor	eax,eax
		dec	eax
		jmp	.Exit

.1:		lea	eax,[%$dcmd]
		mov	[eax],edx
		Ccall	DevControl, dword [%$fd], eax, dword [%$tp], \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY

.Exit:		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcsetpgrp(int fd, pid_t pgrp);
proc _tcsetpgrp
		arg	fd, pgrp
		prologue
		lea	eax,[%$pgrp]
		Ccall	DevControl, dword [%$fd], DCMD_CHR_TCSETPGRP, eax, \
			byte Dword_size, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; speed_t cfgetispeed(const struct termios *tp);
proc _cfgetispeed
		mov	eax,[esp+4]
		mov	eax,[eax+tTermIOs.ISpeed]
		ret
endp		;---------------------------------------------------------------


		; speed_t cfgetospeed(const struct termios *tp);
proc _cfgetospeed
		mov	eax,[esp+4]
		mov	eax,[eax+tTermIOs.OSpeed]
		ret
endp		;---------------------------------------------------------------


		; int cfsetispeed(struct termios *tp, speed_t speed);
proc _cfsetispeed
		arg	tp, speed
		prologue
		savereg	ebx
		mov	ebx,[%$tp]
		mov	eax,[%$speed]
		or	eax,eax
		jnz	.Set
		mov	eax,[ebx+tTermIOs.OSpeed]
.Set:		mov	[ebx+tTermIOs.ISpeed],eax
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int cfsetospeed(struct termios *tp, speed_t speed);
proc _cfsetospeed
		arg	tp,speed
		prologue
		savereg	ebx
		mov	ebx,[%$tp]
		Mov32	ebx+tTermIOs.OSpeed,%$speed
		xor	eax,eax
		epilogue
		ret
endp		;---------------------------------------------------------------
