/*
 * $RCSfile: tcp_input.c,v $
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
 *    @(#)tcp_input.c 7.13+ (Berkeley) 11/13/87
 *
 * Modified for x-kernel v3.3	12/10/90
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: tcp_input.c,v $
 * Revision 1.2  1996/01/29 22:32:07  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.25.1.4.1.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.25.1.3  1994/05/02  01:09:13  davidm
 * (tcp_input): tcpSemSignal() changed into tcpVAll (with obvious
 * optimization).  Otherwise, semaphore count can reach unbounded
 * values.
 *
 * Also changed two tracing level 2 to TR_MAJOR_EVENTS---the idea being
 * that with TR_GROSS_EVENTS, you get messages only in the case of
 * retransmission etc (abnormal events).
 *
 * Revision 1.25.1.2  1994/04/26  17:31:20  menze
 * Added cast to bzero argument
 *
 * Revision 1.25.1.1  1994/04/25  21:13:24  menze
 * Removed gratuitous remnants from tcp_reass
 */

#include "xkernel.h"
#include "ip.h"
#include "tcp_internal.h"
#include "tcp_fsm.h"
#include "tcp_seq.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"
#include "tcp_debug.h"

typedef struct {
    IPpseudoHdr *pHdr;
    struct tcphdr tHdr;
    int tlen;
    char *options;
    int option_len;
    int try_again;
} Pop_State;

#define CANTRCVMORE(so) (sotoss(so)->t_flags & TF_NETCLOSED)

int	tcpprintfs = 0;
int	tcpcksum = 1;
int	tcprexmtthresh = 3;
extern int tcpnodelack;

#ifdef __STDC__

static int	tcp_reass( Sessn, struct tcphdr *, Msg *, Msg * );
static void	tcp_dooptions(Sessn so, char *, int, struct tcphdr *);
/* static bool	tcp_pulloobchar( char *ptr, long len, VOID *oobc); */
static void 	tcp_pulloutofband(SState *, struct tcphdr *, Msg *);

#else

static int	tcp_reass();
static void	tcp_dooptions();
/* static bool	tcp_pulloobchar(); */
static void 	tcp_pulloutofband();

#endif

/*
 * Insert segment ti into reassembly queue of tcp with
 * control block tp.  Return TH_FIN if reassembly now includes
 * a segment with FIN.  The macro form does the common case inline
 * (segment is the next to be received on an established connection,
 * and the queue is empty), avoiding linkage into and removal
 * from the queue and repetition of various conversions.
 *
 * Reassembled message, if one exists, is plaecd in demuxmsg
 */
#define	TCP_REASS(ss, th, so, m, dMsg, flags) { \
	if ((th)->th_seq == (ss)->rcv_nxt \
	    && (ss)->seg_next == (struct reass*)(&(ss)->seg_next) \
	    && (ss)->t_state == TCPS_ESTABLISHED \
	    PREDICT_TRUE) \
	{ \
		(ss)->rcv_nxt += msgLength(m); \
		flags = (th)->th_flags & TH_FIN; \
	        TCP_STAT(++ps->tcps_rcvpack; ps->tcps_rcvbyte += msgLength(m)); \
		msgAssign((dMsg), (m)); \
	} else \
		(flags) = tcp_reass((so), (th), (m), (dMsg)); \
}


static int
tcp_reass(so, th, m, demuxmsg)
     Sessn so;
     struct tcphdr *th;
     Msg *m, *demuxmsg;
{
    struct reass *q, *next;
    SState *ss = sotoss(so);
    int flags;
    xk_int32 i;
#ifdef TCP_STATISTICS
    PState *ps = (PState *)xMyProtl(so)->state;
#endif

    xIfTrace(tcpp, TR_GROSS_EVENTS) {
	if (th && so && th->th_seq != ss->rcv_nxt) {
	    xTraceS2(so, TR_ALWAYS,
		     "lost/out-of-order: expected seqno %d, got seqno %d",
		     ss->rcv_nxt, th->th_seq);
	} /* if */
    } /* if */

    xTraceS0(so, TR_FUNCTIONAL_TRACE, "tcp_reass()");
    /*
     * Call with th==0 after become established to
     * force pre-ESTABLISHED data up to user socket.
     */
    if (th) {
	/*
	 * Find a segment which begins after this one does.
	 */
	for (q = ss->seg_next; q != (struct reass *)&ss->seg_next;
	     q = (struct reass *)q->next)
	{
	    if (SEQ_GT(q->th.th_seq, th->th_seq)) {
		break;
	    } /* if */
	} /* for */

	/*
	 * If there is a preceding segment, it may provide some of
	 * our data already.  If so, drop the data from the incoming
	 * segment.  If it provides all of our data, drop us.
	 */
	if (q->prev != (struct reass *)&ss->seg_next) {
	    q = q->prev;
	    /* conversion to int (in i) handles seq wraparound */
	    i = q->th.th_seq + msgLength(&q->m) - th->th_seq;
	    if (i > 0) {
		if (i >= msgLength(m)) {
		    TCP_STAT(++ps->tcps_rcvduppack;
			     ps->tcps_rcvdupbyte += msgLength(m));
		    return 0;
		} /* if */
		msgDiscard(m, i);
		th->th_seq += i;
	    } /* if */
	    q = q->next;
	} /* if */
	TCP_STAT(++ps->tcps_rcvoopack; ps->tcps_rcvoobyte += msgLength(m));

	/*
	 * While we overlap succeeding segments trim them or,
	 * if they are completely covered, dequeue them.
	 */
	while (q != (struct reass *)&ss->seg_next) {
	    i = (th->th_seq + msgLength(m)) - q->th.th_seq;
	    if (i <= 0) {
		break;
	    } /* if */
	    if (i < msgLength(&q->m)) {
		q->th.th_seq += i;
		msgDiscard(&q->m, i);
		break;
	    } /* if */
	    next = q->next;
	    remque(q);
	    msgDestroy(&q->m);
	    xFree((char *) q);
	    q = next;
	} /* while */
	
	/*
	 * Stick new segment in its place.
	 */
	{
	    struct reass *new;

	    new = (struct reass *)xMalloc(sizeof *new);
	    new->th = *th;
	    msgConstructCopy(&new->m, m);
	    insque(new, q);
	}
    } /* if */
    /*
     * Present data to user, advancing rcv_nxt through
     * completed sequence space.
     */
    if (TCPS_HAVERCVDSYN(ss->t_state) == 0) {
	return 0;
    } /* if */
    q = ss->seg_next;
    th = &q->th;
    if (q == (struct reass *)&ss->seg_next || th->th_seq != ss->rcv_nxt) {
	return 0;
    } /* if */
    if (ss->t_state == TCPS_SYN_RECEIVED && msgLength(&q->m)) {
	return 0;
    } /* if */
    do {
	ss->rcv_nxt += msgLength(&q->m);
	flags = th->th_flags & TH_FIN;
	next = q->next;
	remque(q);
	if (!CANTRCVMORE(so)) {
	    msgJoin(demuxmsg, demuxmsg, &q->m);
	}
	msgDestroy(&q->m);
	xFree((char *)q);
	q = next;
	th = &q->th;
    } while (q != (struct reass *)&ss->seg_next && th->th_seq == ss->rcv_nxt);
    return flags;
} /* tcp_reass */


static XkReturn
drop(Msg *m)
{
    xTrace1(tcpp, TR_EVENTS, "drop: dropping message", (u_long)m);
    /*
     * Drop space held by incoming segment and return.
     */
    xIfTrace(tcpp, TR_MAJOR_EVENTS) {
	tcp_trace(TA_DROP, 0, 0, 0, 0);
    } /* if */
    if (m) {
	msgDestroy(m);
    } /* if */
    return XK_SUCCESS;
} /* drop */


/*
 * Attention: SO argument may be NULL.
 */
static XkReturn
dropwithreset(Sessn so, Msg *m, int tiflags,
	      IPpseudoHdr *pHdr, struct tcphdr tHdr, int tlen, Protl tcp)
{
    IPpseudoHdr tmpPhdr;

    xTrace1(tcpp, TR_EVENTS, "[tcp] dropwithreset(so=%lx)", (u_long)so);
    /*
     * Generate a RST, dropping incoming segment.
     * Make ACK acceptable to originator of segment.
     * Don't bother to respond if destination was broadcast.
     */
    if ((tiflags & TH_RST) || IP_ADS_BCAST(pHdr->dst)) {
	return drop(m);
    } /* if */

    tmpPhdr.src = pHdr->dst;
    tmpPhdr.dst = pHdr->src;
    tmpPhdr.zero = 0;
    tmpPhdr.prot = pHdr->prot;
    if (tiflags & TH_ACK) {
	tcp_respond(so, &tHdr, &tmpPhdr, tHdr.th_ack, (tcp_seq)0, TH_RST, tcp);
    } else {
	if (tiflags & TH_SYN) {
	    ++tlen;
	} /* if */
	tcp_respond(so, &tHdr, &tmpPhdr, tHdr.th_seq + tlen,
		    (tcp_seq)0, TH_RST|TH_ACK, tcp);
    } /* if */
    if (m) {
	msgDestroy(m);
    } /* if */
    return XK_SUCCESS;
} /* dropwithreset */


static XkReturn
dropafterack(Sessn so, int tiflags, Msg *m)
{
    SState *ss = sotoss(so);

    xTraceS1(so, TR_EVENTS, "dropafterack(so=%lx)", (u_long)so);
    /*
     * Generate an ACK dropping incoming segment if it occupies
     * sequence space, where the ACK reflects our state.
     */
    if (tiflags & TH_RST) {
	return drop(m);
    } /* if */
    ss->t_flags |= TF_ACKNOW;
    tcp_output(so);
    msgDestroy(m);

    return XK_SUCCESS;
} /* dropafterack */


XkReturn
tcpPop(so, lls, m, state)
    Sessn so;
    Sessn lls;
    Msg *m;
    VOID *state;
{
    int todrop, acked, ourfinisacked, needoutput = 0;
    bool invoke_cantrcvmore = FALSE;
    SState *ss = sotoss(so);
    struct tcphdr tHdr;
    IPpseudoHdr *pHdr;
    Msg demuxmsg;
    char *options;
    int option_len = 0;
    int tiflags, tlen, len;
    int iss = 0;
    int ostate = 0;
    int bad;
    Pop_State *pop_state = state;
    Protl tcp = xMyProtl(so);
#ifdef TCP_STATISTICS
    PState *ps = (PState *)xMyProtl(so)->state;
#endif

    pHdr = pop_state->pHdr;
    tHdr = pop_state->tHdr;
    tlen = pop_state->tlen;
    options = pop_state->options;
    option_len = pop_state->option_len;

    xIfTrace(tcpp, 1) {
	ostate = ss->t_state;
    } /* if */

    tiflags = tHdr.th_flags;

    msgConstructEmpty(&demuxmsg);

    /*
     * Segment received on connection.
     * Reset idle time and keep-alive timer.
     */
    ss->t_idle = 0;
    ss->t_timer[TCPT_KEEP] = TCPTV_KEEP;
    
    /*
     * Process options if not in LISTEN state,
     * else do it below (after getting remote address).
     */
    if (options PREDICT_FALSE) {
	if (ss->t_state != TCPS_LISTEN) {
	    tcp_dooptions(so, options, option_len, &tHdr);
	    options = 0;
	} /* if */
    } /* if */
    
    /*
     * Calculate amount of space in receive window,
     * and then do TCP input processing.
     * Receive window is amount of space in rcv queue,
     * but not less than advertised window.
     */
    {
	int win;
	win = ss->rcv_space;
	if (win < 0)
	  win = 0;
	ss->rcv_wnd = MAX(win, (int)(ss->rcv_adv - ss->rcv_nxt));
	xTraceS4(so, TR_MORE_EVENTS,
		 "New win (%x) = max(std (%x), adv (%x) - nxt (%x))",
		 ss->rcv_wnd, win, ss->rcv_adv, ss->rcv_nxt);
    }

    xTraceS2(so, TR_EVENTS, "tcpPop: so=%lx switch %s", (u_long)so,
	     tcpstates[ss->t_state]);
    
    if (ss->t_state == TCPS_LISTEN PREDICT_FALSE) {
	/*
	 * If the state is LISTEN then ignore segment if it
	 * contains an RST.
	 * If the segment contains an ACK then it is bad and send
	 * a RST.
	 * If it does not contain a SYN then it is not
	 * interesting; drop it.
	 * Don't bother responding if the destination was a
	 * broadcast.
	 * Otherwise initialize ss->rcv_nxt, and ss->irs, select
	 * an initial ss->iss, and send a segment:
	 *     <SEQ=ISS><ACK=RCV_NXT><CTL=SYN,ACK>
	 * Also initialize ss->snd_nxt to ss->iss+1 and
	 * ss->snd_una to ss->iss.
	 * Fill in remote peer address fields if not previously
	 * specified.  Enter SYN_RECEIVED state, and process any
	 * other fields of this segment in this state.
	 */
	if (tiflags & TH_RST)
	  return drop(&demuxmsg);
	if (tiflags & TH_ACK)
	  return dropwithreset(so, &demuxmsg, tiflags, pHdr, tHdr, tlen, tcp);
	if (((tiflags & TH_SYN) == 0) || IP_ADS_BCAST(pHdr->dst))
	  return drop(&demuxmsg);

	xTraceS0(so, TR_MAJOR_EVENTS, "tcpPop: LISTEN");
	tcp_template(so);
	if (options) {
	    tcp_dooptions(so, options, option_len, &tHdr);
	} /* if */
	if (iss)
	  ss->iss = iss;
	else
	  ss->iss = tcp_iss;
	tcp_iss += TCP_ISSINCR/2;
	ss->irs = tHdr.th_seq;
	tcp_sendseqinit(ss);
	tcp_rcvseqinit(ss);
	ss->t_flags |= TF_ACKNOW;
	ss->t_state = TCPS_SYN_RECEIVED;
	ss->t_timer[TCPT_KEEP] = TCPTV_KEEP;
	TCP_STAT(++ps->tcps_accepts);
	goto trimthenstep6;
    } else if (ss->t_state == TCPS_SYN_SENT PREDICT_FALSE) {
	/*
	 * If the state is SYN_SENT:
	 *	if seg contains an ACK, but not for our SYN, drop the input.
	 *	if seg contains a RST, then drop the connection.
	 *	if seg does not contain SYN, then drop it.
	 * Otherwise this is an acceptable SYN segment
	 *	initialize ss->rcv_nxt and ss->irs
	 *	if seg contains ack then advance ss->snd_una
	 *	if SYN has been acked change to ESTABLISHED else SYN_RCVD state
	 *	arrange for segment to be acked (eventually)
	 *	continue processing rest of data/controls, beginning with URG
	 */
	if ((tiflags & TH_ACK) &&
	    (SEQ_LEQ(tHdr.th_ack, ss->iss) ||
	     SEQ_GT(tHdr.th_ack, ss->snd_max))) {
	    xTraceS0(so, TR_SOFT_ERRORS,
		     "input state SYN_SENT -- dropping with reset");
	    xTraceS3(so, TR_SOFT_ERRORS, "   (ack==%d, iss==%d, snd_max==%d)",
		     tHdr.th_ack, ss->iss, ss->snd_max);
	    return dropwithreset(so, &demuxmsg, tiflags, pHdr, tHdr, tlen,
				 tcp);
	} /* if */
	if (tiflags & TH_RST) {
	    if (tiflags & TH_ACK) {
		tcp_drop(so, ECONNREFUSED);
	    } /* if */
	    xTraceS0(so, TR_SOFT_ERRORS, "peer sent reset (TH_RST)---dropping");
	    return drop(&demuxmsg);
	} /* if */
	if ((tiflags & TH_SYN) == 0) {
	    xTraceS1(so, TR_SOFT_ERRORS,
		     "peer did not send TH_SYN---dropping (tiflags=%x)",
		     tiflags);
	    return drop(&demuxmsg);
	} /* if */

	if (tiflags & TH_ACK) {
	    ss->snd_una = tHdr.th_ack;
	    if (SEQ_LT(ss->snd_nxt, ss->snd_una))
	      ss->snd_nxt = ss->snd_una;
	} /* if */
	ss->t_timer[TCPT_REXMT] = 0;
	ss->irs = tHdr.th_seq;
	tcp_rcvseqinit(ss);
	ss->t_flags |= TF_ACKNOW;
	if (tiflags & TH_ACK && SEQ_GT(ss->snd_una, ss->iss)) {
	    TCP_STAT(++ps->tcps_connects);
	    soisconnected(so);
	    ss->t_state = TCPS_ESTABLISHED;
	    ss->t_maxseg = MIN(ss->t_maxseg, tcp_mss(so));
	    tcp_reass(so, NULL, NULL, &demuxmsg);
	    /*
	     * if we didn't have to retransmit the SYN,
	     * use its rtt as our initial srtt & rtt var.
	     */
	    if (ss->t_rtt) {
		ss->t_srtt = ss->t_rtt << 3;
		ss->t_rttvar = ss->t_rtt << 1;
		TCPT_RANGESET(ss->t_rxtcur, 
			      ((ss->t_srtt >> 2) + ss->t_rttvar) >> 1,
			      TCPTV_MIN, TCPTV_REXMTMAX);
		ss->t_rtt = 0;
	    } /* if */
	} else {
	    ss->t_state = TCPS_SYN_RECEIVED;
	} /* if */
	
trimthenstep6:
	/*
	 * Advance ti->ti_seq to correspond to first data byte.
	 * If data, trim to stay within window,
	 * dropping FIN if necessary.
	 */
	tHdr.th_seq++;
	if (tlen > ss->rcv_wnd) {
	    todrop = tlen - ss->rcv_wnd;
	    xTraceS2(so, TR_MORE_EVENTS,
		     "tlen (%d) > rcv_wnd (%d) ... truncating",
		     tlen, ss->rcv_wnd);
	    msgTruncate(m, todrop);
	    tlen = ss->rcv_wnd;
	    tiflags &= ~TH_FIN;
	    TCP_STAT(ps->tcps_rcvpackafterwin++;
		     ps->tcps_rcvbyteafterwin += todrop);
	}
	ss->snd_wl1 = tHdr.th_seq - 1;
	ss->rcv_up = tHdr.th_seq;
	goto step6;
    } /* if */

    /*
     * States other than LISTEN or SYN_SENT.
     * First check that at least some bytes of segment are within 
     * receive window.  If segment begins before rcv_nxt,
     * drop leading data (and SYN); if nothing left, just ack.
     */
    todrop = ss->rcv_nxt - tHdr.th_seq;
    if (todrop > 0 PREDICT_FALSE) {
	if (tiflags & TH_SYN) {
	    tiflags &= ~TH_SYN;
	    tHdr.th_seq++;
	    if (tHdr.th_urp > 1) 
	      tHdr.th_urp--;
	    else
	      tiflags &= ~TH_URG;
	    todrop--;
	}
	if (todrop > tlen ||
	    todrop == tlen && (tiflags & TH_FIN) == 0)
	  {
#ifdef TCP_COMPAT_42
	      /*
	       * Don't toss RST in response to 4.2-style keepalive.
	       */
	      if (tHdr.th_seq == ss->rcv_nxt - 1 && tiflags & TH_RST)
		goto do_rst;
#endif
	      TCP_STAT(++ps->tcps_rcvduppack; ps->tcps_rcvdupbyte += tlen);
	      todrop = tlen;
	      tiflags &= ~TH_FIN;
	      ss->t_flags |= TF_ACKNOW;
	  } else {
	      TCP_STAT(++ps->tcps_rcvpartduppack;
		       ps->tcps_rcvpartdupbyte += todrop);
	  }
	xTraceS1(so, TR_MORE_EVENTS, "discarding %d bytes from front of msg",
		 todrop);
	msgDiscard(m, todrop);
	tHdr.th_seq += todrop;
	tlen -= todrop;
	if (tHdr.th_urp > todrop)
	  tHdr.th_urp -= todrop;
	else {
	    tiflags &= ~TH_URG;
	    tHdr.th_urp = 0;
	}
    }
    
    /*
     * If segment ends after window, drop trailing data
     * (and PUSH and FIN); if nothing left, just ACK.
     */
    todrop = (tHdr.th_seq + tlen) - (ss->rcv_nxt + ss->rcv_wnd);
    if (todrop > 0 PREDICT_FALSE) {
	TCP_STAT(++ps->tcps_rcvpackafterwin);
	if (todrop >= tlen) {
	    TCP_STAT(ps->tcps_rcvbyteafterwin += tlen);
	    /*
	     * If a new connection request is received
	     * while in TIME_WAIT, drop the old connection
	     * and start over if the sequence numbers
	     * are above the previous ones.
	     */
	    if (tiflags & TH_SYN &&
		ss->t_state == TCPS_TIME_WAIT &&
		SEQ_GT(tHdr.th_seq, ss->rcv_nxt))
	    {
		iss = ss->rcv_nxt + TCP_ISSINCR;
		/*
		 * There can be no external references to this session
		 * anymore (otherwise we wouldn't be in the TIME_WAIT
		 * state), so we can proceed and directly destroy the
		 * session:
		 */
		tcp_destroy(so);
		msgDestroy(&demuxmsg);
		pop_state->try_again = TRUE;
		return XK_SUCCESS;
	    } /* if */
	    /*
	     * If window is closed can only take segments at
	     * window edge, and have to drop data and PUSH from
	     * incoming segments.  Continue processing, but
	     * remember to ack.  Otherwise, drop segment
	     * and ack.
	     */
	    if (ss->rcv_wnd == 0 && tHdr.th_seq == ss->rcv_nxt) {
		ss->t_flags |= TF_ACKNOW;
		TCP_STAT(++ps->tcps_rcvwinprobe);
	    } else {
		return dropafterack(so, tiflags, &demuxmsg);
	    } /* if */
	} else {
	    TCP_STAT(ps->tcps_rcvbyteafterwin += todrop);
	} /* if */
	xTraceS1(so, TR_MORE_EVENTS,
		 "segment ends after window -- truncating to %d", todrop);
	msgTruncate(m, todrop);
	tlen -= todrop;
	tiflags &= ~(TH_PUSH|TH_FIN);
    }
    
#ifdef TCP_COMPAT_42
  do_rst:
#endif
    bad = (tiflags & (TH_RST | TH_SYN)) | (~tiflags & TH_ACK);
    if (bad PREDICT_FALSE) {
	/*
	 * If the RST bit is set examine the state:
	 *    SYN_RECEIVED STATE:
	 *	If passive open, return to LISTEN state.
	 *	If active open, inform user that connection was refused.
	 *    ESTABLISHED, FIN_WAIT_1, FIN_WAIT2, CLOSE_WAIT STATES:
	 *	Inform user that connection was reset, and close tcb.
	 *    CLOSING, LAST_ACK, TIME_WAIT STATES
	 *	Close the tcb.
	 */
	if (tiflags & TH_RST) {
	    switch (ss->t_state) {

	      case TCPS_SYN_RECEIVED:
		tcp_drop(so, ECONNREFUSED);
		return drop(&demuxmsg);

	      case TCPS_ESTABLISHED:
	      case TCPS_FIN_WAIT_1:
	      case TCPS_FIN_WAIT_2:
	      case TCPS_CLOSE_WAIT:
		tcp_drop(so, ECONNRESET);
		return drop(&demuxmsg);

	      case TCPS_CLOSING:
	      case TCPS_LAST_ACK:
	      case TCPS_TIME_WAIT:
		/*
		 * There can be no external references to this session
		 * anymore (otherwise we wouldn't be in one of the above
		 * states), so we can proceed and directly destroy the
		 * session:
		 */
		tcp_destroy(so);
		return drop(&demuxmsg);
	    } /* switch */
	} /* if */

	/*
	 * If a SYN is in the window, then this is an
	 * error and we send an RST and drop the connection.
	 */
	if (tiflags & TH_SYN) {
	    tcp_drop(so, ECONNRESET);
	    return dropwithreset(so, &demuxmsg, tiflags, pHdr, tHdr, tlen,
				 tcp);
	} /* if */
    
	/*
	 * If the ACK bit is off we drop the segment and return.
	 */
	if (!(tiflags & TH_ACK)) {
	    return drop(&demuxmsg);
	} /* if */
    } /* if */
    
    /*
     * Ack processing.
     */
    if (ss->t_state == TCPS_SYN_RECEIVED PREDICT_FALSE) {
	/*
	 * In SYN_RECEIVED state if the ack ACKs our SYN then enter
	 * ESTABLISHED state and continue processing, otherwise
	 * send an RST.
	 */
	if (SEQ_GT(ss->snd_una, tHdr.th_ack) ||
	    SEQ_GT(tHdr.th_ack, ss->snd_max))
	  return dropwithreset(so, &demuxmsg, tiflags, pHdr, tHdr, tlen, tcp);
	TCP_STAT(++ps->tcps_connects);
	soisconnected(so);
	ss->t_state = TCPS_ESTABLISHED;
	ss->t_maxseg = MIN(ss->t_maxseg, tcp_mss(so));
	tcp_reass(so, NULL, NULL, &demuxmsg);
	ss->snd_wl1 = tHdr.th_seq - 1;
	goto do_ack_processing;
    } else {
	switch (ss->t_state) {
	    /*
	     * In ESTABLISHED state: drop duplicate ACKs; ACK out of range
	     * ACKs.  If the ack is in the range
	     *	ss->snd_una < ti->ti_ack <= ss->snd_max
	     * then advance ss->snd_una to ti->ti_ack and drop
	     * data from the retransmission queue.  If this ACK
	     * reflects more up to date window information we
	     * update our window information.
	     */
	  case TCPS_ESTABLISHED:
	  case TCPS_FIN_WAIT_1:
	  case TCPS_FIN_WAIT_2:
	  case TCPS_CLOSE_WAIT:
	  case TCPS_CLOSING:
	  case TCPS_LAST_ACK:
	  case TCPS_TIME_WAIT:
	  do_ack_processing:
	    if (SEQ_LEQ(tHdr.th_ack, ss->snd_una)) {
		if (tlen == 0 && tHdr.th_win == ss->snd_wnd
		    PREDICT_FALSE)
		  {
		      TCP_STAT(++ps->tcps_rcvdupack);
		      /*
		       * If we have outstanding data (not a
		       * window probe), this is a completely
		       * duplicate ack (ie, window info didn't
		       * change), the ack is the biggest we've
		       * seen and we've seen exactly our rexmt
		       * threshhold of them, assume a packet
		       * has been dropped and retransmit it.
		       * Kludge snd_nxt & the congestion
		       * window so we send only this one
		       * packet.  
		       *
		       * We know we're losing at the current
		       * window size so do congestion avoidance
		       * (set ssthresh to half the current window
		       * and pull our congestion window back to
		       * the new ssthresh).
		       *
		       * Dup acks mean that packets have left the
		       * network (they're now cached at the receiver)
		       * so bump cwnd by the amount in the receiver
		       * to keep a constant cwnd packets in the
		       * network.
		       */

		      if (ss->t_timer[TCPT_REXMT] == 0 ||
			  tHdr.th_ack != ss->snd_una)
			ss->t_dupacks = 0;
		      else if (++ss->t_dupacks == tcprexmtthresh) {
			  tcp_seq onxt = ss->snd_nxt;
			  u_long win =
			    MIN(ss->snd_wnd,
				ss->snd_cwnd);

			  win /= ss->t_maxseg;
			  win >>= 1;
			  if (win < 2)
			    win = 2;
			  ss->snd_ssthresh = win * ss->t_maxseg;

			  ss->t_timer[TCPT_REXMT] = 0;
			  ss->t_rtt = 0;
			  ss->snd_nxt = tHdr.th_ack;
			  ss->snd_cwnd = ss->t_maxseg;
			  tcp_output(so);
			  ss->snd_cwnd = ss->snd_ssthresh +
			    ss->t_maxseg *
			      ss->t_dupacks;
			  if (SEQ_GT(onxt, ss->snd_nxt))
			    ss->snd_nxt = onxt;
			  return drop(&demuxmsg);
		      } else if (ss->t_dupacks > tcprexmtthresh) {
			  ss->snd_cwnd += ss->t_maxseg;
			  tcp_output(so);
			  return drop(&demuxmsg);
		      }
		  } else
		    ss->t_dupacks = 0;
		break;
	    } /* if */
	    ss->t_dupacks = 0;
	    if (SEQ_GT(tHdr.th_ack, ss->snd_max) PREDICT_FALSE) {
		TCP_STAT(++ps->tcps_rcvacktoomuch);
		return drop(&demuxmsg);
	    }
	    acked = tHdr.th_ack - ss->snd_una;
	    xTraceS2(so, TR_EVENTS,
		     "received ACK for byte %d (%d new bytes ACKED)",
		     tHdr.th_ack, acked);
	    TCP_STAT(++ps->tcps_rcvackpack; ps->tcps_rcvackbyte += acked);

	    /*
	     * If transmit timer is running and timed sequence
	     * number was acked, update smoothed round trip time.
	     * Since we now have an rtt measurement, cancel the
	     * timer backoff (cf., Phil Karn's retransmit alg.).
	     * Recompute the initial retransmit timer.
	     */
	    if (ss->t_rtt && SEQ_GT(tHdr.th_ack, ss->t_rtseq)) {
		TCP_STAT(++ps->tcps_rttupdated);
		if (ss->t_srtt != 0 PREDICT_TRUE) {
		    register short delta;

		    /*
		     * srtt is stored as fixed point with 3 bits
		     * after the binary point (i.e., scaled by 8).
		     * The following magic is equivalent
		     * to the smoothing algorithm in rfc793
		     * with an alpha of .875
		     * (srtt = rtt/8 + srtt*7/8 in fixed point).
		     * Adjust t_rtt to origin 0.
		     */
		    ss->t_rtt--;
		    delta = ss->t_rtt - (ss->t_srtt >> 3);
		    if ((ss->t_srtt += delta) <= 0)
		      ss->t_srtt = 1;
		    /*
		     * We accumulate a smoothed rtt variance
		     * (actually, a smoothed mean difference),
		     * then set the retransmit timer to smoothed
		     * rtt + 2 times the smoothed variance.
		     * rttvar is stored as fixed point
		     * with 2 bits after the binary point
		     * (scaled by 4).  The following is equivalent
		     * to rfc793 smoothing with an alpha of .75
		     * (rttvar = rttvar*3/4 + |delta| / 4).
		     * This replaces rfc793's wired-in beta.
		     */
		    if (delta < 0)
		      delta = -delta;
		    delta -= (ss->t_rttvar >> 2);
		    if ((ss->t_rttvar += delta) <= 0)
		      ss->t_rttvar = 1;
		} else {
		    /* 
		     * No rtt measurement yet - use the
		     * unsmoothed rtt.  Set the variance
		     * to half the rtt (so our first
		     * retransmit happens at 2*rtt)
		     */
		    ss->t_srtt = ss->t_rtt << 3;
		    ss->t_rttvar = ss->t_rtt << 1;
		}
		ss->t_rtt = 0;
		ss->t_rxtshift = 0;
		TCPT_RANGESET(ss->t_rxtcur, 
			      ((ss->t_srtt >> 2) + ss->t_rttvar) >> 1,
			      TCPTV_MIN, TCPTV_REXMTMAX);
	    }

	    /*
	     * If all outstanding data is acked, stop retransmit
	     * timer and remember to restart (more output or persist).
	     * If there is more data to be acked, restart retransmit
	     * timer, using current (possibly backed-off) value.
	     */
	    if (tHdr.th_ack == ss->snd_max) {
		ss->t_timer[TCPT_REXMT] = 0;
		needoutput = 1;
	    } else if (ss->t_timer[TCPT_PERSIST] == 0)
	      ss->t_timer[TCPT_REXMT] = ss->t_rxtcur;
	    /*
	     * When new data is acked, open the congestion window.
	     * If the window gives us less than ssthresh packets
	     * in flight, open exponentially (maxseg per packet).
	     * Otherwise open linearly (maxseg per window,
	     * or maxseg^2 / cwnd per packet).
	     */
#	    define MAX_CWND	65535
	    if (ss->snd_cwnd < MAX_CWND PREDICT_FALSE) {
		u_long incr = ss->t_maxseg;

		if (ss->snd_cwnd > ss->snd_ssthresh && incr != ss->snd_cwnd) {
		    incr = MAX(incr * incr / ss->snd_cwnd, 1);
		} /* if */
		
		xTraceS3(so, TR_MAJOR_EVENTS,
			 "tcpPop: congestion window=%x (MIN(%x+%x,ffff))",
			 ss->snd_cwnd + incr, ss->snd_cwnd, incr);
		ss->snd_cwnd = MIN(ss->snd_cwnd + incr, MAX_CWND);
	    } /* if */
	    if (acked > sblength(ss->snd) PREDICT_FALSE) {
		ss->snd_wnd -= sblength(ss->snd);
		sbdrop(ss->snd, sblength(ss->snd));
		ourfinisacked = 1;
	    } else {
		sbdrop(ss->snd, acked);
		ss->snd_wnd -= acked;
		ourfinisacked = 0;
	    }
	    if (ss->waiting.waitCount) {
		tcpSemVAll(&ss->waiting);
	    } /* if */
	    ss->snd_una = tHdr.th_ack;
	    if (SEQ_LT(ss->snd_nxt, ss->snd_una))
	      ss->snd_nxt = ss->snd_una;

	    if (ss->t_state == TCPS_FIN_WAIT_1 PREDICT_FALSE) {
		/*
		 * In FIN_WAIT_1 STATE in addition to the processing
		 * for the ESTABLISHED state if our FIN is now acknowledged
		 * then enter FIN_WAIT_2.
		 */
		if (ourfinisacked) {
		    /*
		     * If we can't receive any more
		     * data, then closing user can proceed.
		     * Starting the timer is contrary to the
		     * specification, but if we don't get a FIN
		     * we'll hang forever.
		     */
		    if (CANTRCVMORE(so)) {
			soisdisconnected(so);
			ss->t_timer[TCPT_2MSL] = TCPTV_MAXIDLE;
		    } /* if */
		    ss->t_state = TCPS_FIN_WAIT_2;
		} /* if */
	    } else if (ss->t_state == TCPS_CLOSING PREDICT_FALSE) {
		/*
		 * In CLOSING STATE in addition to the processing for
		 * the ESTABLISHED state if the ACK acknowledges our FIN
		 * then enter the TIME-WAIT state, otherwise ignore
		 * the segment.
		 */
		if (ourfinisacked) {
		    ss->t_state = TCPS_TIME_WAIT;
		    tcp_canceltimers(ss);
		    ss->t_timer[TCPT_2MSL] = 2 * TCPTV_MSL;
		    soisdisconnected(so);
		} /* if */
	    } else if (ss->t_state == TCPS_LAST_ACK PREDICT_FALSE) {
		/*
		 * In LAST_ACK, we may still be waiting for data
		 * to drain and/or to be acked, as well as for the
		 * ack of our FIN.  If our FIN is now
		 * acknowledged, delete the TCB, enter the closed
		 * state and return.
		 */
		if (ourfinisacked) {
		    /*
		     * There can be no external references to this session
		     * anymore (otherwise we wouldn't be in the LAST_ACK
		     * state), so we can proceed and directly destroy the
		     * session:
		     */
		    tcp_destroy(so);
		    return drop(&demuxmsg);
		} /* if */
	    } else if (ss->t_state == TCPS_TIME_WAIT PREDICT_FALSE) {
		/*
		 * In TIME_WAIT state the only thing that should
		 * arrive is a retransmission of the remote FIN.
		 * Acknowledge it and restart the finack timer.
		 */
		ss->t_timer[TCPT_2MSL] = 2 * TCPTV_MSL;
		return dropafterack(so, tiflags, &demuxmsg);
	    } /* if */
	} /* switch */
    } /* if */
    
step6:
    xTraceS1(so, TR_EVENTS, "tcpPop:  step6 on so=%lx", (u_long)so);
    /*
     * Update window information.
     * Don't look at window if no ACK: TAC's send garbage on first SYN.
     */
    if ((tiflags & TH_ACK) &&
	(SEQ_LT(ss->snd_wl1, tHdr.th_seq) || ss->snd_wl1 == tHdr.th_seq &&
	 (SEQ_LT(ss->snd_wl2, tHdr.th_ack) ||
	  ss->snd_wl2 == tHdr.th_ack && tHdr.th_win > ss->snd_wnd))) {
	/* keep track of pure window updates */
	if (tlen == 0
	    && ss->snd_wl2 == tHdr.th_ack && tHdr.th_win > ss->snd_wnd)
	{
	    TCP_STAT(++ps->tcps_rcvwinupd);
	} /* if */
	ss->snd_wnd = tHdr.th_win;
	ss->snd_wl1 = tHdr.th_seq;
	ss->snd_wl2 = tHdr.th_ack;
	if (ss->snd_wnd > ss->max_sndwnd)
	  ss->max_sndwnd = ss->snd_wnd;
	needoutput = 1;
    }
    
    /*
     * Process segments with URG.
     */
    if ((tiflags & TH_URG) && tHdr.th_urp && !TCPS_HAVERCVDFIN(ss->t_state)
	PREDICT_FALSE)
    {
	/*
	 * This is a kludge, but if we receive and accept
	 * random urgent pointers, we'll crash in
	   * soreceive.  It's hard to imagine someone
	   * actually wanting to send this much urgent data.
	   */
	if (tHdr.th_urp > SB_MAX) {
	    tHdr.th_urp = 0;	/* XXX */
	    tiflags &= ~TH_URG; /* XXX */
	    goto dodata;	/* XXX */
	}
	/*
	 * If this segment advances the known urgent pointer,
	 * then mark the data stream.  This should not happen
	 * in CLOSE_WAIT, CLOSING, LAST_ACK or TIME_WAIT STATES since
	 * a FIN has been received from the remote side. 
	 * In these states we ignore the URG.
	 *
	 * According to RFC961 (Assigned Protocols),
	 * the urgent pointer points to the last octet
	 * of urgent data.  We continue, however,
	 * to consider it to indicate the first octet
	 * of data past the urgent section
	 * as the original spec states.
	 */
	if (SEQ_GT(tHdr.th_seq+tHdr.th_urp, ss->rcv_up)) {
	    ss->rcv_up = tHdr.th_seq + tHdr.th_urp;
	    sohasoutofband(so,
			   (ss->rcv_hiwat - ss->rcv_space) +
			   (ss->rcv_up - ss->rcv_nxt) - 1);
	    ss->t_oobflags &= ~(TCPOOB_HAVEDATA | TCPOOB_HADDATA);
	}
	/*
	 * Remove out of band data so doesn't get presented to user.
	   * This can happen independent of advancing the URG pointer,
	   * but if two URG's are pending at once, some out-of-band
	   * data may creep in... ick.
	   */
	if (tHdr.th_urp <= tlen &&
	    (ss->t_flags & TF_OOBINLINE) == 0)
	  tcp_pulloutofband(ss, &tHdr, m);
    } else {
	/*
	 * If no out of band data is expected,
	 * pull receive urgent pointer along
	 * with the receive window.
	 */
	if (SEQ_GT(ss->rcv_nxt, ss->rcv_up))
	  ss->rcv_up = ss->rcv_nxt;
    } /* if */

dodata:							/* XXX */
    xTraceS1(so, TR_EVENTS, "tcpPop: do data on so=%lx", (u_long)so);
    /*
     * Process the segment text, merging it into the TCP sequencing queue,
     * and arranging for acknowledgment of receipt if necessary.
     * This process logically involves adjusting ss->rcv_wnd as data
     * is presented to the user (this happens in tcp_usrreq.c,
     * case PRU_RCVD).  If a FIN has already been received on this
     * connection then we just ignore the text.
     */
    if ((tlen || (tiflags & TH_FIN)) && TCPS_HAVERCVDFIN(ss->t_state) == 0) {
	xTrace1(tcpp, TR_EVENTS,
		"Calling macro reassemble with msg len %d",
		msgLength(m));
	TCP_REASS(ss, &tHdr, so, m, &demuxmsg, tiflags);
	xTraceS1(so, TR_MORE_EVENTS,
		 "after reassembly demux msg has length %d", msgLength(m));
	/*
	 * Pass received message to user:
	 */
	{
	    int mlen = msgLength(&demuxmsg);
	    if (mlen != 0) {
		if ( ! (ss->t_flags & TF_RCV_ACK_ALWAYS) ) {
		    ss->rcv_space -= mlen;
		}
		xDemux(xGetUp(so), so, &demuxmsg);
	    } /* if */
	}
	
	if (tcpnodelack == 0)
	  ss->t_flags |= TF_DELACK;
	else
	  ss->t_flags |= TF_ACKNOW;
	/*
	 * Note the amount of data that peer has sent into
	 * our window, in order to estimate the sender's
	 * buffer size.
	 */
	len = ss->rcv_hiwat - (ss->rcv_adv - ss->rcv_nxt);
	if (len > ss->max_rcvd)
	  ss->max_rcvd = len;
    } else {
	tiflags &= ~TH_FIN;
    }
    
    /*
     * If FIN is received ACK the FIN and let the user know
     * that the connection is closing.
     */
    if (tiflags & TH_FIN PREDICT_FALSE) {
	xTraceS1(so, TR_EVENTS, "tcpPop: got fin on so=%lx", (u_long)so);

	if (TCPS_HAVERCVDFIN(ss->t_state) == 0) {
	    /* delay socantrcvmore() until after data has been processed: */
	    invoke_cantrcvmore = TRUE;
	    ss->t_flags |= TF_ACKNOW;
	    ss->rcv_nxt++;
	}
	switch (ss->t_state) {

	    /*
	     * In SYN_RECEIVED and ESTABLISHED STATES
	     * enter the CLOSE_WAIT state.
	     */
	  case TCPS_SYN_RECEIVED:
	  case TCPS_ESTABLISHED:
	    ss->t_state = TCPS_CLOSE_WAIT;
	    break;

	    /*
	     * If still in FIN_WAIT_1 STATE FIN has not been acked so
	     * enter the CLOSING state.
	     */
	  case TCPS_FIN_WAIT_1:
	    ss->t_state = TCPS_CLOSING;
	    break;

	    /*
	     * In FIN_WAIT_2 state enter the TIME_WAIT state,
	     * starting the time-wait timer, turning off the other 
	     * standard timers.
	     */
	  case TCPS_FIN_WAIT_2:
	    ss->t_state = TCPS_TIME_WAIT;
	    tcp_canceltimers(ss);
	    ss->t_timer[TCPT_2MSL] = 2 * TCPTV_MSL;
	    soisdisconnected(so);
	    break;

	    /*
	     * In TIME_WAIT state restart the 2 MSL time_wait timer.
	     */
	  case TCPS_TIME_WAIT:
	    ss->t_timer[TCPT_2MSL] = 2 * TCPTV_MSL;
	    break;
	} /* switch */
    } /* if */

    msgDestroy(&demuxmsg);

    xIfTrace(tcpp, TR_MAJOR_EVENTS) {
	tcp_trace(TA_INPUT, ostate, ss, 0, 0);
    } /* if */
    
    /*
     * Return any desired output.
     */
    if (needoutput || (ss->t_flags & TF_ACKNOW)) {
	tcp_output(so);
    }
    
    if (invoke_cantrcvmore PREDICT_FALSE) {
	socantrcvmore(so);
    } /* if */

    return XK_SUCCESS;
} /* tcpPop */


/*
 * TCP input routine, follows pages 65-76 of the
 * protocol specification dated September, 1981 very closely.
 */
XkReturn
tcpDemux(self, lls, m)
     Protl self;
     Sessn lls;
     Msg *m;
{
    Sessn so = 0;
    Protl hlp = 0, hlpType = 0;
    PState *ps = (PState *)self->state;
    SState *ss = 0;
    struct tcphdr tHdr;
    IPpseudoHdr *pHdr = NULL;
    char *options = 0;
    int option_len = 0;
    int tlen, off;
    Pop_State pop_state;
    char *buf;
    u_short check_sum;

    TCP_STAT(++ps->tcps_rcvtotal);

    tlen = msgLength(m);
    pHdr = (IPpseudoHdr *)msgGetAttr(m, 0);
    xAssert(pHdr);
    /*
     * Get IP and TCP header together in stack part of message.
     * x-kernel Note:  IP attaches IP pseudoheader (in network byte
     * order) as the attribute of the message
     */
    check_sum = inCkSum(m, (u_short *)pHdr, sizeof(IPpseudoHdr));
    buf = msgPop(m, sizeof(tHdr));
    if (!buf PREDICT_FALSE ) {
	xTraceP0(self, TR_MAJOR_EVENTS,
		 "tcpDemux: msgPop of header failed -- dropping");
	return XK_FAILURE;
    } /* if */
    tcpHdrLoad(&tHdr, buf, sizeof(tHdr), m);
    msgSetAttr(m, 0, 0, 0);

    xTraceP4(self, TR_MAJOR_EVENTS,
	     "tcpDemux seq %d, dlen %d, f( %s ) to port (%d)",
	     tHdr.th_seq, msgLength(m), tcpFlagStr(tHdr.th_flags), tHdr.th_dport);
    /*
     * Check the checksum value (calculated in tcpHdrLoad):
     */
    if (tcpcksum) {
	if (check_sum != 0 PREDICT_FALSE) {
	    xTraceP1(self, TR_MAJOR_EVENTS,
		     "tcpDemux: bad checksum (%x)", check_sum);
	    TCP_STAT(++ps->tcps_rcvbadsum);
#if BSD<=43
	    TCP_STAT(++ps->tcps_badsum);
#endif
	    return XK_SUCCESS;
	} /* if */
    } /* if */

    xTraceP1(self, TR_EVENTS, "received msg with sequence number %d",
	     tHdr.th_seq);

    /*
     * Check that TCP offset makes sense, pull out TCP options and
     * adjust length.
     */
    off = tHdr.th_off << 2;
    if (off < sizeof(struct tcphdr) || off > tlen PREDICT_FALSE) {
	xTraceP2(self, TR_ERRORS, "bad tcp off: src %x off %d",
		 pHdr->src, off);
	TCP_STAT(++ps->tcps_rcvbadoff);
#if BSD<=43
	TCP_STAT(++ps->tcps_badoff);
#endif
	return XK_SUCCESS;
    } /* if */
    tlen -= off;
    option_len = off - sizeof (struct tcphdr);
    if (option_len > 0 PREDICT_FALSE) {
	xTraceP1(self, TR_MAJOR_EVENTS, "tcpDemux: %d bytes of options",
		 option_len);
	/*
	 * Re-check the length, cause option_len increases the size 
	 * of the tcp header
	 */
	if (tlen < 0) {
	    xTraceP2(self, TR_GROSS_EVENTS,
		     "tcpDemux: rcvd short optlen = %d, len = %d",
		     option_len, tlen);
	    TCP_STAT(++ps->tcps_rcvshort);
	    return XK_SUCCESS;
	} /* if */
	/*
	 * Put the options somewhere reasonable		
	 */
	options = xMalloc(option_len);
	buf = msgPop(m, option_len);
	xAssert(buf);
	tcpOptionsLoad(options, buf, option_len);
    } /* if */

    /*
     * Locate session for segment.
     */
    do {
	ActiveId activeId;
	PassiveId passiveId;

	bzero((char *)&activeId, sizeof(activeId));
	activeId.localport = tHdr.th_dport;
	activeId.remoteport = tHdr.th_sport;
	*((int*)&activeId.remoteaddr) = *((int*)&pHdr->src);
	xTraceP3(self, TR_EVENTS, "looking for %d->%s:%d", 
		 activeId.localport, ipHostStr(&activeId.remoteaddr),
		 activeId.remoteport);
	/* look in the active map */
	if (mapResolve(ps->activeMap, &activeId, (void **)&so) !=
	    XK_SUCCESS PREDICT_FALSE) {
	    /*
	     * Look in the passive map
	     */
	    Enable *e;

	    passiveId = activeId.localport;
	    xTraceP1(self, TR_SOFT_ERRORS,
		     "looking for passive open on %d", passiveId);
	    /* look in the map */
	    if (mapResolve(ps->passiveMap, &passiveId, (void **)&e) ==
		XK_FAILURE) {
		xTraceP0(self, TR_SOFT_ERRORS, "No passive open object exists");
		so = 0;
	    } else {
		hlp = e->hlp;
		hlpType = e->hlpType;
		xTraceP1(self, TR_EVENTS, "found openenable object: %lx",
			 (u_long)so);

		so = sonewconn(self, hlp, hlpType, &pHdr->src,
			       &pHdr->dst, tHdr.th_sport, tHdr.th_dport);
		if (!so) {
		    break;
		} /* if */
		/* keep this session around until xOpenDone() or error: */
		ss = sotoss(so);
		/*
		 * Let TCP own a reference until the user gets chance
                 * to take over:
		 */
		xDuplicate(so);
		ss->t_flags |= TF_EMBRYONIC;
		ss->t_template.ti_src = pHdr->dst;
		ss->t_template.ti_sport = tHdr.th_dport;
		ss->t_state = TCPS_LISTEN;
	    } /* if */
	} else {
	    ss = sotoss(so);
	} /* if */
	/*
	 * If the state is CLOSED (i.e., TCB does not exist) then
	 * all data in the incoming segment is discarded.
	 * If the TCB exists but is in CLOSED state, it is embryonic,
	 * but should either do a listen or a connect soon.
	 */
	if (!so PREDICT_FALSE) {
	    xTraceP0(self, TR_GROSS_EVENTS, "tcpDemux: no so");
	    dropwithreset(so, 0, tHdr.th_flags, pHdr, tHdr, tlen, self);
	    break;
	} /* if */
	if (ss->t_state == TCPS_CLOSED PREDICT_FALSE) {
	    xTraceP0(self, TR_GROSS_EVENTS, "tcpDemux: TCPS_CLOSED");
	    break;
	} /* if */

	pop_state.pHdr = pHdr;
	pop_state.tHdr = tHdr;
	pop_state.tlen = tlen;
	pop_state.options = options;
	pop_state.option_len = option_len;
	pop_state.try_again = FALSE;
	xPop(so, lls, m, &pop_state);

	if (options) {
	    xFree(options);
	    options = 0;
	} /* if */
    } while (pop_state.try_again);

    return XK_SUCCESS;
} /* tcpDemux */


static void
tcp_dooptions(so, options, option_len, tHdr)
     Sessn so;
     char *options;
     int option_len;
     struct tcphdr *tHdr;
{
    SState *ss = sotoss(so);
    int opt, optlen, cnt;
    u_char *cp;

    cp = (u_char *)options;
    cnt = option_len;
    for (; cnt > 0; cnt -= optlen, cp += optlen) {
	opt = cp[0];
	if (opt == TCPOPT_EOL)
	  break;
	if (opt == TCPOPT_NOP)
	  optlen = 1;
	else {
	    optlen = cp[1];
	    if (optlen <= 0)
	      break;
	}
	switch (opt) {

	  default:
	    break;

	  case TCPOPT_MAXSEG:
	    if (optlen != 4)
	      continue;
	    if (!(tHdr->th_flags & TH_SYN))
	      continue;
	    ss->t_maxseg = *(u_short *)(cp + 2);
	    ss->t_maxseg = ntohs((u_short)ss->t_maxseg);
	    ss->t_maxseg = MIN(ss->t_maxseg, tcp_mss(so));
	    break;
	} /* switch */
    } /* for */
} /* tcp_dooptions */

#if 0
static bool
tcp_pulloobchar( ptr, len, oobc )
    char	*ptr;
    VOID	*oobc;
    long	len;
{
    xAssert(len >= 1);
    *(char *)oobc = *ptr;
    return FALSE;
} /* tcp_pulloobchar */
#endif

/*
 * Pull out of band byte out of a segment so
 * it doesn't appear in the user's data queue.
 * It is still reflected in the segment length for
 * sequencing purposes.
 */
static void
tcp_pulloutofband(ss, th, m)
     SState *ss;
     struct tcphdr *th;
     Msg *m;
{
    Msg firstPart;
    int cnt = th->th_urp - 1;
    char *buf;
	
    ss->t_oobflags |= TCPOOB_HAVEDATA;

    msgConstructEmpty(&firstPart);
    msgBreak(m, &firstPart, cnt);

    buf = msgPop(m, 1);
    xAssert(buf);
    ss->t_iobc = buf[0];

    msgJoin(m, &firstPart, m);
    msgDestroy(&firstPart);
} /* tcp_pulloutofband */


/*
 *  Determine a reasonable value for maxseg size.
 *  If the route is known, use one that can be handled
 *  on the given interface without forcing IP to fragment.
 *  If bigger than an mbuf cluster (MCLBYTES), round down to nearest size
 *  to utilize large mbufs.
 *  If interface pointer is unavailable, or the destination isn't local,
 *  use a conservative size (512 or the default IP max size, but no more
 *  than the mtu of the interface through which we route),
 *  as we can't discover anything about intervening gateways or networks.
 *  We also initialize the congestion/slow start window to be a single
 *  segment if the destination isn't local; this information should
 *  probably all be saved with the routing entry at the transport level.
 *
 *  This is ugly, and doesn't belong at this level, but has to happen somehow.
 */
int
tcp_mss(so)
     Sessn so;
{
    SState *ss = sotoss(so);
    int mss;

    if (xControlSessn(xGetSessnDown(so, 0), GETOPTPACKET, (char *)&mss, sizeof(int))
	< sizeof(int))
    {
	xTraceS0(so, TR_SOFT_ERRORS,
		 "tcp_mss: GETOPTPACKET control of lls failed");
	mss = 512;
    } /* if */
    xTrace1(tcpp, 3, "tcp_mss: GETOPTPACKET control of lls returned %d", mss);
    mss -= sizeof(struct tcphdr);
    ss->snd_cwnd = mss;
    return mss;
} /* tcp_mss */

			/*** end of tcp_input.c ***/
