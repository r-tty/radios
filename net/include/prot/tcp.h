/* 
 * $RCSfile: tcp.h,v $
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
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: tcp.h,v $
 * Revision 1.2  1996/01/29 20:13:09  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:32:09  slm
 * Initial revision
 *
 * Revision 1.8.3.1  1994/10/27  20:49:54  hkaram
 * New branch
 *
 * Revision 1.8  1994/01/27  21:51:36  menze
 *   [ 1994/01/05          menze ]
 *   PROTNUM changed to PORTNUM
 */

#ifndef tcp_h
#define tcp_h


#define TCP_PUSH		(TCP_CTL*MAXOPS + 0)
#define TCP_GETSTATEINFO	(TCP_CTL*MAXOPS + 1)
#define TCP_DUMPSTATEINFO	(TCP_CTL*MAXOPS + 2)
#define TCP_GETFREEPORTNUM	(TCP_CTL*MAXOPS + 3)
#define TCP_RELEASEPORTNUM	(TCP_CTL*MAXOPS + 4)
#define TCP_SETRCVBUFSPACE	(TCP_CTL*MAXOPS + 5)	/* set rx buf space */
#define TCP_GETSNDBUFSPACE	(TCP_CTL*MAXOPS + 6)	/* get tx buf space */
#define TCP_SETRCVBUFSIZE	(TCP_CTL*MAXOPS + 7)	/* set rx buf size */
#define TCP_SETSNDBUFSIZE	(TCP_CTL*MAXOPS + 8)	/* set tx buf size */
#define TCP_SETOOBINLINE	(TCP_CTL*MAXOPS + 9)	/* set oob inlining */
#define TCP_GETOOBDATA		(TCP_CTL*MAXOPS + 10)	/* read the oob data */
#define TCP_OOBPUSH		(TCP_CTL*MAXOPS + 11)	/* send oob message */
#define TCP_OOBMODE		(TCP_CTL*MAXOPS + 12)	/* this is an upcall */
#define TCP_SETPUSHALWAYS	(TCP_CTL*MAXOPS + 13)	/* always push */
#define TCP_SETRCVACKALWAYS	(TCP_CTL*MAXOPS + 14)	
	/* Implicitly does a SETRCVBUFSPACE on each xPop */

#  ifdef __STDC__

void	tcp_init(Protl);

#  endif


#endif
