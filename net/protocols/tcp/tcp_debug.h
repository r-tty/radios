/*
 * $RCSfile: tcp_debug.h,v $
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
 *	@(#)tcp_debug.h	7.2 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: tcp_debug.h,v $
 * Revision 1.2  1996/01/29 22:30:32  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.3.1.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.3  1993/12/16  01:40:08  menze
 * Strict ANSI compilers weren't combining multiple tentative definitions
 * of external variables into a single definition at link time.
 *
 */
#ifndef tcp_debug_h
#define tcp_debug_h

#include "tcpip.h"
#include "tcp_internal.h"
#include "tcp_var.h"

struct tcp_debug {
    n_time	td_time;
    short	td_act;
    short	td_ostate;
    caddr_t	td_tcb;
    struct	tcpiphdr td_ti;
    short	td_req;
    SState	td_cb;
};

#define	TA_INPUT 	0
#define	TA_OUTPUT	1
#define	TA_USER		2
#define	TA_RESPOND	3
#define	TA_DROP		4

#define	TCP_NDEBUG 100
extern struct	tcp_debug tcp_debug[TCP_NDEBUG];
extern int	tcp_debx;

#endif /* tcp_debug_h */
