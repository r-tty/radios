/*
 * $RCSfile: tcp_seq.h,v $
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
 *	@(#)tcp_seq.h	7.2 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: tcp_seq.h,v $
 * Revision 1.2  1996/01/29 22:30:32  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.3.1.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.3  1993/12/16  01:42:37  menze
 * Strict ANSI compilers weren't combining multiple tentative definitions
 * of external variables into a single definition at link time.
 */
#ifndef tcp_seq_h
#define tcp_seq_h

/*
 * TCP sequence numbers are 32 bit integers operated
 * on with modular arithmetic.  These macros can be
 * used to compare such integers.
 */
#define	SEQ_LT(a,b)	((xk_int32)((a)-(b)) < 0)
#define	SEQ_LEQ(a,b)	((xk_int32)((a)-(b)) <= 0)
#define	SEQ_GT(a,b)	((xk_int32)((a)-(b)) > 0)
#define	SEQ_GEQ(a,b)	((xk_int32)((a)-(b)) >= 0)

/*
 * Macros to initialize tcp sequence numbers for
 * send and receive from initial send and receive
 * sequence numbers.
 */
#define	tcp_rcvseqinit(tp) \
	(tp)->rcv_adv = (tp)->rcv_nxt = (tp)->irs + 1

#define	tcp_sendseqinit(tp) \
	(tp)->snd_una = (tp)->snd_nxt = (tp)->snd_max = (tp)->snd_up = \
	    (tp)->iss

#define	TCP_ISSINCR	(125*1024)	/* increment for tcp_iss each second */


extern tcp_seq	tcp_iss;		/* tcp initial send seq # */

#endif /* tcp_seq_h */
