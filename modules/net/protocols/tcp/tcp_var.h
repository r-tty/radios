/*
 * tcp_var.h
 *
 * Derived from:
 *
 * Copyright (c) 1982, 1986 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that this notice is preserved and that due credit is given
 * to the University of California at Berkeley. The name of the University
 * may not be used to endorse or promote products derived from this
 * software without specific prior written permission. This software
 * is provided ``as is'' without express or implied warranty.
 *
 *	@(#)tcp_var.h	7.6 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:30:32 $
 */
#ifndef tcp_var_h
#define tcp_var_h

#include "tcp_timer.h"
#include "tcpip.h"

/*
 * xtcp configuration:  This is a half-assed attempt to make xtcp
 * self-configure for a few varieties of 4.2 and 4.3-based unixes.
 * If you don't have a) a 4.3bsd vax or b) a 3.x Sun (x<6), check
 * this carefully (it's probably not right).  Please send me mail
 * if you run into configuration problems.
 *  - Van Jacobson (van@lbl-csam.arpa)
 */

#ifndef BSD
#define BSD 42	/* if we're not 4.3, pretend we're 4.2 */
#endif

#if sun||BSD<43
#define TCP_COMPAT_42	/* set if we have to interop w/4.2 systems */
#endif

#define SB_MAX 65535	/* max socket buffer size */

/* --------------- end of xtcp config ---------------- */

#endif /* tcp_var_h */
