/*
 * tcpip.h
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
 *	@(#)tcpip.h	7.2 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:30:32 $
 */
#ifndef tcpip_h
#define tcpip_h

#include "xkernel.h"
#include "ip.h"

typedef	xk_u_int32 tcp_seq;

/*
 * TCP header.
 * Per RFC 793, September, 1981.
 */
struct tcphdr {
	u_short	th_sport;		/* source port */
	u_short	th_dport;		/* destination port */
	tcp_seq	th_seq;			/* sequence number */
	tcp_seq	th_ack;			/* acknowledgement number */
#if ENDIAN == LITTLE
	u_int	th_x2:4,		/* (unused) */
		th_off:4;		/* data offset */
#endif
#if ENDIAN == BIG
	u_int	th_off:4,		/* data offset */
		th_x2:4;		/* (unused) */
#endif
	u_char	th_flags;
#define	TH_FIN	0x01
#define	TH_SYN	0x02
#define	TH_RST	0x04
#define	TH_PUSH	0x08
#define	TH_ACK	0x10
#define	TH_URG	0x20
	u_short	th_win;			/* window */
	u_short	th_sum;			/* checksum */
	u_short	th_urp;			/* urgent pointer */
};


/*
 * TCP+IP header, after ip options removed.
 */
/*
 * Overlay for ip header used by other protocols (tcp, udp).
 */
struct ipovly {
    caddr_t ih_next, ih_prev;       /* for protocol sequence q's */
    u_char  ih_x1;                  /* (unused) */
    u_char  ih_pr;                  /* protocol */
    short   ih_len;                 /* protocol length */
    IPhost  ih_src;		    /* source internet address */
    IPhost  ih_dst;		    /* destination internet address */
};

struct tcpiphdr {
    struct 	ipovly 	ti_i;		/* overlaid ip structure */
    struct	tcphdr 	ti_t;		/* tcp header */
    IPpseudoHdr	ti_p;
};

#define	ti_next		ti_i.ih_next
#define	ti_prev		ti_i.ih_prev
#define	ti_x1		ti_i.ih_x1
#define	ti_pr		ti_i.ih_pr
#define	ti_len		ti_i.ih_len
#define	ti_src		ti_i.ih_src
#define	ti_dst		ti_i.ih_dst
#define	ti_sport	ti_t.th_sport
#define	ti_dport	ti_t.th_dport
#define	ti_seq		ti_t.th_seq
#define	ti_ack		ti_t.th_ack
#define	ti_x2		ti_t.th_x2
#define	ti_off		ti_t.th_off
#define	ti_flags	ti_t.th_flags
#define	ti_win		ti_t.th_win
#define	ti_sum		ti_t.th_sum
#define	ti_urp		ti_t.th_urp

#endif /* tcpip_h */
