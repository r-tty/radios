/*
 * tcp_timer.c
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
 *	@(#)tcp_timer.c	7.11 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:32:07 $
 */

#include "xkernel.h"
#include "tcp_debug.h"
#include "tcp_internal.h"
#include "tcp_fsm.h"
#include "tcp_seq.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"

int tcpnodelack = 0;
int tcp_backoff[TCP_MAXRXTSHIFT + 1] = {
    1, 2, 4, 8, 16, 32, 64, 64, 64, 64, 64, 64, 64
};


static int
fasttimo(void *key, void *value, void *arg)
{
    Sessn so = (Sessn) value;
    SState *ss = sotoss(so);
#ifdef TCP_STATISTICS
    PState *ps = (PState*)arg;
#endif

    if (ss && (ss->t_flags & TF_DELACK)) {
	ss->t_flags &= ~TF_DELACK;
	ss->t_flags |= TF_ACKNOW;
	TCP_STAT(++ps->tcps_delack);
	/* 
	 * What if this blocks???
	 */
	tcp_output(so);
    } /* if */
    return MFE_CONTINUE;
} /* fasttimo */


/*
 * Fast timeout routine for processing delayed acks.
 */
void
tcp_fasttimo( ev, arg )
     Event ev;
     VOID *arg;
{
    PState *ps = (PState*) ((Protl)arg)->state;

    mapForEach(ps->activeMap, fasttimo, ps);
    evDetach(evSchedule(tcp_fasttimo, arg, TCP_FAST_INTERVAL));
} /* tcp_fasttimo */


/*
 * TCP timer processing.
 */
static int
tcp_timers(so, timer)
     Sessn so;
     int timer;
{
    int rexmt;
    Protl protl = xMyProtl(so);
    SState *ss = sotoss(so);
#ifdef TCP_STATISTICS
    PState *ps = (PState*)protl->state;
#endif

    switch (timer) {
      case TCPT_2MSL:
	/*
	 * 2 MSL timeout in shutdown went off.  If we're closed but
	 * still waiting for peer to close and connection has been idle
	 * too long, or if 2MSL time is up from TIME_WAIT, delete connection
	 * control block.  Otherwise, check again in a bit.
	 */
	xTraceS2(so, TR_GROSS_EVENTS,
		 "shutdown timer 2 MSL (so=%lx, state=%s)",
		 (u_long)so, tcpstates[ss->t_state]);
	if (ss->t_state != TCPS_TIME_WAIT && ss->t_idle <= TCPTV_MAXIDLE) {
	    ss->t_timer[TCPT_2MSL] = TCPTV_KEEP;
	} else {
	    /*
	     * There can be no external references to this session
	     * anymore (otherwise we wouldn't be in the TIME_WAIT
	     * state), so we can proceed and directly destroy the
	     * session:
	     */
	    so->binding = 0;	/* prevent tcpClose() from removing binding */
	    tcp_destroy(so);
	    return 0;
	} /* if */
	break;

      case TCPT_REXMT:
	/*
	 * Retransmission timer went off.  Message has not
	 * been acked within retransmit interval.  Back off
	 * to a longer retransmit interval and retransmit one segment.
	 */
	xTraceS2(so, TR_GROSS_EVENTS, "retransmission timeout on so=%lx (%d)",
		 (u_long)so, ss->t_rxtshift);
	if (++ss->t_rxtshift > TCP_MAXRXTSHIFT) {
	    xTrace0(tcpp, TR_GROSS_EVENTS,
		    "Too many rexmits, dropping");
	    ss->t_rxtshift = TCP_MAXRXTSHIFT;
	    TCP_STAT(++ps->tcps_timeoutdrop);
	    so->binding = 0;	/* prevent tcpClose() from removing binding */
	    tcp_drop(so, ETIMEDOUT);
	    return 0;
	} /* if */
	TCP_STAT(++ps->tcps_rexmttimeo);
	rexmt = ((ss->t_srtt >> 2) + ss->t_rttvar) >> 1;
	rexmt *= tcp_backoff[ss->t_rxtshift];
	TCPT_RANGESET(ss->t_rxtcur, rexmt, TCPTV_MIN, TCPTV_REXMTMAX);
	ss->t_timer[TCPT_REXMT] = ss->t_rxtcur;
	/*
	 * If losing, let the lower level know and try for
	 * a better route.  Also, if we backed off this far,
	 * our srtt estimate is probably bogus.  Clobber it
	 * so we'll take the next rtt measurement as our srtt;
	 * move the current srtt into rttvar to keep the current
	 * retransmit times until then.
	 */
	if (ss->t_rxtshift > TCP_MAXRXTSHIFT / 4) {
	    ss->t_rttvar += (ss->t_srtt >> 2);
	    ss->t_srtt = 0;
	}
	ss->snd_nxt = ss->snd_una;
	xTraceS2(so, TR_GROSS_EVENTS,
		 "retransmitting (starting seqno=%d, state=%s)",
		 ss->snd_una, tcpstates[ss->t_state]);
	/*
	 * If timing a segment in this window, stop the timer.
	 */
	ss->t_rtt = 0;
	/*
	 * Close the congestion window down to one segment
	 * (we'll open it by one segment for each ack we get).
	 * Since we probably have a window's worth of unacked
	 * data accumulated, this "slow start" keeps us from
	 * dumping all that data as back-to-back packets (which
	 * might overwhelm an intermediate gateway).
	 *
	 * There are two phases to the opening: Initially we
	 * open by one mss on each ack.  This makes the window
	 * size increase exponentially with time.  If the
	 * window is larger than the path can handle, this
	 * exponential growth results in dropped packet(s)
	 * almost immediately.  To get more time between 
	 * drops but still "push" the network to take advantage
	 * of improving conditions, we switch from exponential
	 * to linear window opening at some threshhold size.
	 * For a threshhold, we use half the current window
	 * size, truncated to a multiple of the mss.
	 *
	 * (the minimum cwnd that will give us exponential
	 * growth is 2 mss.  We don't allow the threshhold
	 * to go below this.)
	 */
	{
	    u_short win = MIN(ss->snd_wnd, ss->snd_cwnd) / 2 / ss->t_maxseg;
	    if (win < 2)
	      win = 2;
	    ss->snd_cwnd = ss->t_maxseg;
	    ss->snd_ssthresh = win * ss->t_maxseg;
	}
	tcp_output(so);
	break;

      case TCPT_PERSIST:
	/*
	 * Persistence timer into zero window.
	 * Force a byte to be output, if possible.
	 */
	xTraceS2(so, TR_GROSS_EVENTS, "persist timer (so=%lx, state=%s)",
		 (u_long)so, tcpstates[ss->t_state]);
	TCP_STAT(++ps->tcps_persisttimeo);
	tcp_setpersist(ss);
	ss->t_force = 1;
	tcp_output(so);
	ss->t_force = 0;
	break;

      case TCPT_KEEP:
	/*
	 * Keep-alive timer went off; send something
	 * or drop connection if idle for too long.
	 */
	xTraceS2(so, TR_GROSS_EVENTS, "keep-alive timer (so=%lx, state=%s)",
		 (u_long)so, tcpstates[ss->t_state]);
	TCP_STAT(++ps->tcps_keeptimeo);
	if (ss->t_state < TCPS_ESTABLISHED)
	  goto dropit;
	if ((ss->t_flags & TF_KEEP_ALIVE) && ss->t_state <= TCPS_CLOSE_WAIT) {
	    if (ss->t_idle >= TCPTV_MAXIDLE)
	      goto dropit;
	    /*
	     * Send a packet designed to force a response
	     * if the peer is up and reachable:
	     * either an ACK if the connection is still alive,
	     * or an RST if the peer has closed the connection
	     * due to timeout or reboot.
	     * Using sequence number ss->snd_una-1
	     * causes the transmitted zero-length segment
	     * to lie outside the receive window;
	     * by the protocol spec, this requires the
	     * correspondent TCP to respond.
	     */
	    TCP_STAT(++ps->tcps_keepprobe);
	    xTraceS0(so, TR_GROSS_EVENTS, "sending dummy segment");
#ifdef TCP_COMPAT_42
	    /*
	     * The keepalive packet must have nonzero length
	     * to get a 4.2 host to respond.
	     */
	    tcp_respond(so, &ss->t_template.ti_t, 
			&ss->t_template.ti_p,
			ss->rcv_nxt - 1, ss->snd_una - 1, 0,
			protl);
#else
	    tcp_respond(so, &ss->t_template.ti_t, 
			&ss->t_template.ti_p,
			ss->rcv_nxt, ss->snd_una - 1, 0,
			protl);
#endif
	} /* if */
	ss->t_timer[TCPT_KEEP] = TCPTV_KEEP;
	break;
      dropit:
	TCP_STAT(++ps->tcps_keepdrops);
	so->binding = 0;	/* prevent tcpClose() from removing binding */
	tcp_drop(so, ETIMEDOUT);
	return 0;
    } /* switch */
    return 1;
} /* tcp_timers */


static int
slowtimo(void *key, void *value, void *arg)
{
    Sessn so = (Sessn) value;
    SState *ss = sotoss(so);
    int i;
#ifdef TCP_STATISTICS
    PState *ps = (PState*) arg;
#endif

    if (!so) {
	return MFE_CONTINUE;
    } /* if */

    /*
     * Update active timers:
     */
    for (i = 0; i < TCPT_NTIMERS; i++) {
	if (ss->t_timer[i] && --ss->t_timer[i] == 0) {
	    /* 
	     * What if this blocks???
	     */
	    xIfTrace(tcpp, 3) {
		tcp_trace(TA_USER, ss->t_state, ss, 0, PRU_SLOWTIMO | i << 8);
	    } /* if */
	    if (!tcp_timers(so, i)) {
		return MFE_REMOVE | MFE_CONTINUE;
	    } /* if */
	} /* if */
    } /* for */
    ++ss->t_idle;
    if (ss->t_rtt) {
	++ss->t_rtt;
    } /* if */
    return MFE_CONTINUE;
} /* slowtimo */


/*
 * TCP protocol timeout routine called every 500 ms.
 * Updates the timers in all active tcb's and
 * causes finite state machine actions if timers expire.
 */
void
tcp_slowtimo(ev, arg)
     Event ev;
     VOID *arg;
{
    PState *ps;

    ps = ((Protl)arg)->state;
    mapForEach(ps->activeMap, slowtimo, ps);

    tcp_iss += TCP_ISSINCR/PR_SLOWHZ;		/* increment iss */
#ifdef TCP_COMPAT_42
    if ((int)tcp_iss < 0) {
	tcp_iss = 0;				/* XXX */
    } /* if */
#endif
    evDetach(evSchedule(tcp_slowtimo, arg, TCP_SLOW_INTERVAL));
} /* tcp_slowtimo */


/*
 * Cancel all timers in a TCP session.
 */
void
tcp_canceltimers(ss)
     SState *ss;
{
    int i;

    for (i = 0; i < TCPT_NTIMERS; i++) {
	ss->t_timer[i] = 0;
    } /* for */
} /* tcp_canceltimers */

			/*** end of tcp_timer.c ***/
