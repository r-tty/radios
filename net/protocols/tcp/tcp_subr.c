/*
 * tcp_subr.c
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
 *	@(#)tcp_subr.c	7.13 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:32:07 $
 */

#include "xkernel.h"
#include "ip.h"
#include "icmp.h"
#include "tcp_internal.h"
#include "tcp_fsm.h"
#include "tcp_seq.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"

int	tcp_ttl = TCP_TTL;

/*
 * Create template to be used to send tcp packets on a connection.
 * Call after host entry created, allocates an mbuf and fills
 * in a skeletal tcp/ip header, minimizing the amount of work
 * necessary when the connection is used.
 */
void
tcp_template(so)
     Sessn so;
{
    struct tcpiphdr *n;
    Sessn lls;
    IPpseudoHdr	pHdr;
    SState *ss = sotoss(so);

    lls = xGetSessnDown(so,0);

    if ( xControlSessn(lls, IP_GETPSEUDOHDR, (char *)&pHdr, sizeof(pHdr)) < 0 ) {
	xTraceS0(so, TR_ERRORS,
		 "tcp_template could not get pseudo-hdr from lls");
	pHdr.prot = 0;
    } /* if */

    n = &ss->t_template;
    n->ti_next = n->ti_prev = 0;
    n->ti_x1 = 0;
    n->ti_pr = pHdr.prot;
    n->ti_len = sizeof (struct tcpiphdr) - sizeof (struct ipovly);

    n->ti_seq = 0;
    n->ti_ack = 0;
    n->ti_x2 = 0;
    n->ti_off = 5;
    n->ti_flags = 0;
    n->ti_win = 0;
    n->ti_sum = 0;
    n->ti_urp = 0;
    /*
     * IP pseudo-header:
     */
    n->ti_p.src = *(IPhost *)&n->ti_src;
    n->ti_p.dst = *(IPhost *)&n->ti_dst;
    n->ti_p.zero = 0;
    n->ti_p.prot = n->ti_pr;
} /* tcp_template */


/*
 * Send a single message to the TCP at address specified by
 * the given TCP/IP header.  If flags==0, then we make a copy
 * of the tcpiphdr at ti and send directly to the addressed host.
 * This is used to force keep alive messages out using the TCP
 * template for a connection tp->t_template.  If flags are given
 * then we send a message back to the TCP which originated the
 * segment ti, and discard the mbuf containing it and any other
 * attached mbufs.
 *
 * In any case the ack and sequence number of the transmitted
 * segment are as specified by the parameters.
 */
void
tcp_respond(so, th, pHdr, ack, seq, flags, tcp)
     Sessn so;
     struct tcphdr *th;
     IPpseudoHdr *pHdr;
     tcp_seq ack, seq;
     int flags;
     Protl tcp;
{
    int win = 0, tlen;
    Msg m;
    struct tcphdr tHdr;
    Sessn lls = 0;
    char *buf;

    if (so) {
	win = sotoss(so)->rcv_space;
	lls = xGetSessnDown(so, 0);
    } /* if */

#ifdef TCP_COMPAT_42
    tlen = flags == 0;
#else
    tlen = 0;
#endif
    tHdr = *th;
    if (flags == 0) {
	flags = TH_ACK;
    } else {
	u_short tmp;

	tmp = tHdr.th_sport;
	tHdr.th_sport = tHdr.th_dport;
	tHdr.th_dport = tmp;
    } /* if */
    tHdr.th_seq = seq;
    tHdr.th_ack = ack;
    tHdr.th_x2 = 0;
    tHdr.th_off = sizeof (struct tcphdr) >> 2;
    tHdr.th_flags = flags;
    tHdr.th_win = win;
    tHdr.th_urp = 0;

    msgConstructEmpty(&m);
    buf = msgPush(&m, sizeof(tHdr));
    xAssert(buf);
    tcpHdrStore(&tHdr, buf, sizeof(tHdr), &m, pHdr);
    if (lls) {
	xPush(lls, &m);
    } else {
	Part p[2];

	partInit(p, 2);
	partPush(p[0], &pHdr->dst, sizeof(IPhost));
	partPush(p[1], &pHdr->src, sizeof(IPhost));
	lls = xOpen(tcp, tcp, xGetProtlDown(tcp, 0), p);
	if (xIsSessn(lls)) {
	    xPush(lls, &m);
	    xClose(lls);
	} else {
	    xError("tcp_respond could not open lower session!");
	} /* if */
    } /* if */
    msgDestroy(&m);
} /* tcp_respond */


/*
 * Drop a TCP connection, reporting the specified error.  If
 * connection is synchronized, then send a RST to peer.
 *
 * There may still be external references to this session.  We get rid
 * of them by (a) waking up all sleepers, so they get a chance to
 * react to the closing and (b) by performing an xCloseDone(), so any
 * other external references can be freed.  Eventually, all references
 * will be gone and at that point tcpClose() will be invoked and
 * all the state will be freed.  We don't have much control over
 * what the user is doing in response to an xCloseDone(), so as a
 * saftey measure we ensure that it gets invoked only once per
 * session (by setting the flag TF_NETCLOSED).
 *
 * If the user has requested a close already or if we get a drop on an
 * embryonic session (i.e., during a passive open) there is no point
 * trying to be formal and we go ahead and destroy the session right
 * away.  In either case we are guaranteed that there are no external
 * references, so this is a fine thing to do.
 */
void
tcp_drop(so, errnum)
     Sessn so;
     int errnum;
{
    SState *ss = sotoss(so);
#ifdef TCP_STATISTICS
    PState *ps = (PState *)xMyProtl(so)->state;
#endif

    xTraceS2(so, TR_GROSS_EVENTS, "tcp_drop(so=%lx,errnum=%d)",
	     (u_long)so, errnum);

    if (TCPS_HAVERCVDSYN(ss->t_state)) {
	tcp_output(so);
	TCP_STAT(++ps->tcps_drops);
    } else {
	TCP_STAT(++ps->tcps_conndrops);
    } /* if */
    ss->t_state = TCPS_CLOSED;

    if (ss->t_flags & (TF_USRCLOSED | TF_EMBRYONIC)) {
	if (ss->t_flags & TF_USRCLOSED) {
	    /*
	     * A user-requested close was initiated already.  This
	     * implies that there are no external reference left and
	     * it is therefore safe to destroy the session.  But before
	     * doing so, first wakeup the potential sleeper in
	     * tcpClose():
	     */
	    soisdisconnected(so);
	} /* if */
	tcp_destroy(so);
    } else {
	/*
	 * The close is a surprise to the user.  Wake up any sleepers
	 * and also make sure user gets notified via xCloseDone():
	 */
	tcpSemVAll(&ss->waiting);
	socantrcvmore(so);
    } /* if */
} /* tcp_drop */


/*
 * Destroy a TCP control block:
 *	discard all space held by the tcp
 *	discard internet protocol block
 *
 * We get here only after an orderly shutdown or, if there was some
 * error, through tcp_drop().
 */
void
tcp_destroy(so)
     Sessn so;
{
    struct reass *this, *next;
    PState *ps = (PState *)xMyProtl(so)->state;
    SState *ss;
    int i;

    ss = sotoss(so);

    xTraceS1(so, TR_GROSS_EVENTS, "tcp_destroy(so=%lx)", (u_long)so);

    /* remove session from activeMap if it is still there: */
    if (so->binding) {
	mapRemoveBinding(ps->activeMap, so->binding);
    } /* if */

    /* destroy reassembly queue: */
    this = ss->seg_next;
    while (this != (struct reass *)&ss->seg_next) {
	next = this->next;
	msgDestroy(&this->m);
	remque(this);
	xFree((char *)this);
	this = next;
    } /* while */
    tcpReleasePort(ps->portstate, ss->t_template.ti_sport);

    /* destroy send queue: */
    sbdelete(ss->snd);

    /* close lower sessions: */
    for (i=0; i < so->numdown; i++) {
	xClose(xGetSessnDown(so, i));
    } /* for */

    /* deallocate session-object and session-state: */
    xDestroySessn(so);

    TCP_STAT(++ps->tcps_closed);
} /* tcp_destroy */


/*
 * When a source quench is received, close congestion window
 * to one segment.  We will gradually open it again as we proceed.
 */
void
tcp_quench(ss)
     SState *ss;
{
    if (ss) {
	ss->snd_cwnd = ss->t_maxseg;
    } /* if */
} /* tcp_quench */

			/*** end of tcp_subr.c ***/
