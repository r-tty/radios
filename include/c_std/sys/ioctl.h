/*
 * ioctl.h - definitions for IOCTL numbers, mainly for tty I/O
 */

#ifndef _sys_ioctl_h
#define _sys_ioctl_h

#include <sys/types.h>

struct ttysize {
    ushort	ts_lines;
    ushort	ts_cols;
    ushort	ts_xxx;
    ushort	ts_yyy;
};

#define TIOCGSIZE       TIOCGWINSZ
#define TIOCSSIZE       TIOCSWINSZ

#define FREAD		0x0001			/* For TIOCFLUSH */			
#define FWRITE		0x0002

#define TIOCM_DTR       0x0001			/* data terminal ready */
#define TIOCM_RTS       0x0002			/* request to send */
#define TIOCM_CTS       0x1000			/* clear to send */
#define TIOCM_DSR       0x2000			/* data set ready */
#define TIOCM_RI        0x4000			/* ring */
#define TIOCM_RNG       TIOCM_RI
#define TIOCM_CD        0x8000			/* carrier detect */
#define TIOCM_CAR       TIOCM_CD
#define TIOCM_LE        0x0100			/* line enable */
#define TIOCM_ST        0x0200			/* secondary transmit */
#define TIOCM_SR        0x0400			/* secondary receive */

/*
 * Ioctl's have the command encoded in the lower word, and the size of
 * any in or out parameters in the upper word.  The high 2 bits of the
 * upper word are used to encode the in/out status of the parameter.
 */
#define IOCPARM_MASK    0x3fff          /* parameter length, at most 14 bits */
#define IOCPARM_LEN(x)  (((x) >> 16) & IOCPARM_MASK)
#define IOCBASECMD(x)   ((x) & ~(IOCPARM_MASK << 16))
#define IOCGROUP(x)     (((x) >> 8) & 0xff)

#define IOCPARM_MAX     NBPG            /* max size of ioctl, mult. of NBPG */
#define IOC_VOID        0x00000000      /* no parameters */
#define IOC_OUT         0x40000000      /* copy out parameters */
#define IOC_IN          0x80000000      /* copy in parameters */
#define IOC_INOUT       (IOC_IN|IOC_OUT)
#define IOC_DIRMASK     0xc0000000      /* mask for IN/OUT/VOID */

#define _IOC(inout,group,num,len) \
        (inout | ((len & IOCPARM_MASK) << 16) | ((group) << 8) | (num))
#define _IO(g,n)        _IOC(IOC_VOID,  (g), (n), 0)
#define _IOR(g,n,t)     _IOC(IOC_OUT,   (g), (n), sizeof(t))
#define _IOW(g,n,t)     _IOC(IOC_IN,    (g), (n), sizeof(t))
#define _IOWR(g,n,t)    _IOC(IOC_INOUT, (g), (n), sizeof(t))

#define TCGETA          _IOR('T', 1, struct termio)
#define TCSETA          _IOW('T', 2, struct termio)
#define TCSETAW         _IOW('T', 3, struct termio)
#define TCSETAF         _IOW('T', 4, struct termio)
#define TCSBRK          _IOW('T',  5, int)
#define TCXONC          _IOW('T',  6, int)
#define TCFLSH          _IOW('T',  7, int)
#define TCGETS          _IOR('T', 13, struct termios)
#define TCSETS          _IOW('T', 14, struct termios)
#define TCSETSW         _IOW('T', 15, struct termios)
#define TCSETSF         _IOW('T', 16, struct termios)

#define TIOCHPCL        _IO('t',  2)                    /* hang up on last close */
#define TIOCGETP        _IOR('t', 8, struct sgttyb)     /* get parameters -- gtty */
#define TIOCSETP        _IOW('t', 9, struct sgttyb)     /* set parameters -- stty */
#define TIOCSETN        _IOW('t',10, struct sgttyb)     /* as above, but no flushtty*/

#define TIOCSINUSE      TIOCEXCL

#define TIOCEXCL        _IO('t', 13)                    /* set exclusive use of tty */
#define TIOCNXCL        _IO('t', 14)                    /* reset exclusive use of tty */
                                                        /* 15 unused */
#define TIOCFLUSH       _IOW('t', 16, int)              /* flush buffers */
#define TIOCSETC        _IOW('t', 17, struct tchars)    /* set special characters */
#define TIOCGETC        _IOR('t', 18, struct tchars)    /* get special characters */
#define TIOCGETA        _IOR('t', 19, struct termios)   /* get termios struct */
#define TIOCSETA        _IOW('t', 20, struct termios)   /* set termios struct */
#define TIOCSETAW       _IOW('t', 21, struct termios)   /* drain output, set */
#define TIOCSETAF       _IOW('t', 22, struct termios)   /* drn out, fls in, set */
#define TIOCDRAIN       _IO('t',  94)                   /* wait till output drained */
#define TIOCSCTTY       _IO('t',  97)                   /* become controlling tty */
#define TIOCSWINSZ      _IOW('t', 103, struct winsize)  /* set window size */
#define TIOCGWINSZ      _IOR('t', 104, struct winsize)  /* get window size */
#define TIOCMGET        _IOR('t', 106, int)             /* get all modem bits */
#define TIOCMBIC        _IOW('t', 107, int)             /* bic modem bits */
#define TIOCMBIS        _IOW('t', 108, int)             /* bis modem bits */
#define TIOCMSET        _IOW('t', 109, int)             /* set all modem bits */
#define TIOCSTART       _IO('t',  110)                  /* start output, like ^Q */
#define TIOCSTOP        _IO('t',  111)                  /* stop output, like ^S */
#define TIOCNOTTY       _IO('t', 113)                   /* void tty association */
#define TIOCSTI         _IOW('t', 114, char)            /* simulate terminal input */
#define TIOCOUTQ        _IOR('t', 115, int)             /* output queue size */
#define TIOCGLTC        _IOR('t', 116, struct ltchars)  /* get local special chars*/
#define TIOCSLTC        _IOW('t', 117, struct ltchars)  /* set local special chars*/
#define TIOCSPGRP       _IOW('t', 118, int)             /* set pgrp of tty */
#define TIOCGPGRP       _IOR('t', 119, int)             /* get pgrp of tty */
#define TIOCCDTR        _IO('t', 120)                   /* clear data terminal ready */
#define TIOCSDTR        _IO('t', 121)                   /* set data terminal ready */
#define TIOCCBRK        _IO('t', 122)                   /* clear break bit */
#define TIOCSBRK        _IO('t', 123)                   /* set break bit */
#define TIOCLGET        _IOR('t', 124, int)             /* get local modes */
#define TIOCLSET        _IOW('t', 125, int)             /* set entire local mode word */

#define UIOCCMD(n)      _IO('u', n)			/* usr cntl op "n" */

#define FIOCLEX         _IO('f', 1)                     /* set close on exec on fd */
#define FIONCLEX        _IO('f', 2)                     /* remove close on exec */
#define FIOGETOWN       _IOR('f', 123, int)		/* get owner */
#define FIOSETOWN       _IOW('f', 124, int)		/* set owner */
#define FIOASYNC        _IOW('f', 125, int)		/* set/clear async i/o */
#define FIONBIO         _IOW('f', 126, int)		/* set/clear non-blocking i/o */
#define FIONREAD        _IOR('f', 127, int)		/* get # bytes to read */

/* socket i/o controls */
#define SIOCSHIWAT      _IOW('s',  0, int)		/* set high watermark */
#define SIOCGHIWAT      _IOR('s',  1, int)		/* get high watermark */
#define SIOCSLOWAT      _IOW('s',  2, int)		/* set low watermark */
#define SIOCGLOWAT      _IOR('s',  3, int)		/* get low watermark */
#define SIOCATMARK      _IOR('s',  7, int)		/* at oob mark? */
#define SIOCSPGRP       _IOW('s',  8, int)		/* set process group */
#define SIOCGPGRP       _IOR('s',  9, int)		/* get process group */

#define SIOCADDRT       _IOW('r', 10, struct ortentry)  /* add route */
#define SIOCDELRT       _IOW('r', 11, struct ortentry)  /* delete route */

#define SIOCSIFADDR     _IOW('i', 12, struct ifreq)     /* set ifnet address */
#define SIOCGIFADDR     _IOWR('i',33, struct ifreq)     /* get ifnet address */
#define SIOCSIFDSTADDR  _IOW('i', 14, struct ifreq)     /* set p-p address */
#define SIOCGIFDSTADDR  _IOWR('i',34, struct ifreq)     /* get p-p address */
#define SIOCSIFFLAGS    _IOW('i', 16, struct ifreq)     /* set ifnet flags */
#define SIOCGIFFLAGS    _IOWR('i',17, struct ifreq)     /* get ifnet flags */
#define SIOCGIFBRDADDR  _IOWR('i',35, struct ifreq)     /* get broadcast addr */
#define SIOCSIFBRDADDR  _IOW('i',19, struct ifreq)      /* set broadcast addr */
#define SIOCGIFCONF     _IOWR('i',36, struct ifconf)    /* get ifnet list */
#define SIOCGIFNETMASK  _IOWR('i',37, struct ifreq)     /* get net addr mask */
#define SIOCSIFNETMASK  _IOW('i',22, struct ifreq)      /* set net addr mask */
#define SIOCGIFMETRIC   _IOWR('i',23, struct ifreq)     /* get IF metric */
#define SIOCSIFMETRIC   _IOW('i',24, struct ifreq)      /* set IF metric */
#define SIOCDIFADDR     _IOW('i',25, struct ifreq)      /* delete IF addr */
#define SIOCAIFADDR     _IOW('i',26, struct ifaliasreq) /* add/chg IF alias */
#define SIOCGIFALIAS    _IOWR('i',27, struct ifaliasreq)/* get IF alias */

#define SIOCGARP        _IOWR('i',38, struct arpreq)    /* get arp entry */
#define SIOCSIFMTU      _IOW('i', 41, struct ifreq)
#define SIOCGIFMTU      _IOWR('i', 41, struct ifreq)

int ioctl(int fd, int cmd, ...);

#endif
