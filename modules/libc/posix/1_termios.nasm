;-------------------------------------------------------------------------------
; posix/1_termios.nasm - POSIX termios routines.
;-------------------------------------------------------------------------------

module libc.termios

%include "errors.ah"
%include "rm/devctl.ah"

exportproc _tcdrain, _tcdropline, _tcflow, _tcflush, _tcsendbreak
exportproc _tcgetattr, _tcsetattr, _tcgetprgp, _tcsetpgrp
exportproc _cfgetispeed, _cfsetispeed, _cfgetospeed, _cfsetospeed

externproc _devctl

section .text

		; int tcdrain(int fd)
proc _tcdrain
		arg	fd
		prologue
		Ccall	_devctl, dword [%$fd], DCMD_CHR_TCDRAIN, byte 0, \
			byte 0, DEVCTL_FLAG_NORETVAL | DEVCTL_FLAG_NOTTY
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int tcdropline(int fd, int duration);
proc _tcdropline
	duration = ((duration ? duration : 300) << 16) | _SERCTL_DTR_CHG | 0;
	return _devctl(fd, DCMD_CHR_SERCTL, &duration, sizeof duration, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; int tcflow(int fd, int action);
proc _tcflow
	return _devctl(fd, DCMD_CHR_TCFLOW, &action, sizeof action, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; int tcflush(int fd, int queue);
proc _tcflush
	return _devctl(fd, DCMD_CHR_TCFLUSH, &queue, sizeof queue, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; int tcgetattr(int fd, struct termios *termios_p);
proc _tcgetattr
	return _devctl(fd, DCMD_CHR_TCGETATTR, termios_p, sizeof *termios_p, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; int tcgetpgrp(int fd);
proc _tcgetpgrp
	pid_t			pgrp;

	if(_devctl(fd, DCMD_CHR_TCGETPGRP, &pgrp, sizeof pgrp, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY) == -1) {
		return -1;
	}
	return pgrp;
endp		;---------------------------------------------------------------


		; int tcsendbreak(int fd, int duration);
proc _tcsendbreak
	if(duration > USHRT_MAX) {
		errno = EINVAL;
		return -1;
	}

	duration = ((unsigned)(duration ? duration : 300) << 16) | _SERCTL_BRK_CHG | _SERCTL_BRK;
	return _devctl(fd, DCMD_CHR_SERCTL, &duration, sizeof duration, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; int tcsetattr(int fd, int optact, const struct termios *tp);
proc _tcsetattr
	int			dcmd;

	switch(optact) {
	case TCSANOW:
		dcmd = DCMD_CHR_TCSETATTR;
		 break;

	case TCSADRAIN:
		dcmd = DCMD_CHR_TCSETATTRD;
		break;

	case TCSAFLUSH:
		dcmd = DCMD_CHR_TCSETATTRF;
		break;

	default:
		errno = EINVAL;
		return -1;
	}

	return _devctl(fd, dcmd, (void *)termios_p, sizeof *termios_p, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; int tcsetpgrp(int fd, pid_t pgrp);
proc _tcsetpgrp
	return _devctl(fd, DCMD_CHR_TCSETPGRP, &pgrp, sizeof pgrp, _DEVCTL_FLAG_NORETVAL | _DEVCTL_FLAG_NOTTY);
endp		;---------------------------------------------------------------


		; speed_t cfgetispeed(const struct termios *tp);
proc _cfgetispeed
	return(termios_p->c_ispeed);
endp		;---------------------------------------------------------------


		; speed_t cfgetospeed(const struct termios *tp);
proc _cfgetospeed
	return(termios_p->c_ospeed);
endp		;---------------------------------------------------------------


		; int cfsetispeed(struct termios *tp, speed_t speed);
proc _cfsetispeed		
	termios_p->c_ispeed = (speed == 0) ? termios_p->c_ospeed : speed;
	return(0);
endp		;---------------------------------------------------------------


		; int cfsetospeed(struct termios *tp, speed_t speed);
proc _cfsetospeed
	termios_p->c_ospeed = speed;
	return(0);
endp		;---------------------------------------------------------------
