/*
 * tcp_output.c
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
 *	@(#)tcp_output.c	7.12 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:32:07 $
 */
#include "xkernel.h"
#include "tcp_internal.h"
#include "tcp_fsm.h"
#include "tcp_seq.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"
#include "tcp_debug.h"

/*
 * Flags used when sending segments in tcp_output.
 * Basic flags (TH_RST,TH_ACK,TH_SYN,TH_FIN) are totally
 * determined by state, with the proviso that TH_FIN is sent only
 * if all data queued for output is included in the segment.
 */
static u_char tcp_outflags[TCP_NSTATES] = {
    TH_RST|TH_ACK, 0, TH_SYN, TH_SYN|TH_ACK,
    TH_ACK, TH_ACK,
    TH_FIN|TH_ACK, TH_FIN|TH_ACK, TH_FIN|TH_ACK, TH_ACK, TH_ACK,
};

/*
 * Initial options.
 */
static u_char tcp_initopt[4] = {
    TCPOPT_MAXSEG, 4, 0x0, 0x0
};


void
tcp_setpersist(SState *ss)
{
    register t = ((ss->t_srtt >> 2) + ss->t_rttvar) >> 1;

    if (ss->t_timer[TCPT_REXMT])
      Kabort("tcp_output REXMT");
    /*
     * Start/restart persistance timer.
     */
    TCPT_RANGESET(ss->t_timer[TCPT_PERSIST],
		  t * tcp_backoff[ss->t_rxtshift],
		  TCPTV_PERSMIN, TCPTV_PERSMAX);
    if (ss->t_rxtshift < TCP_MAXRXTSHIFT)
      ss->t_rxtshift++;
} /* tcp_setpersist */


/*
 * TCP output routine: send what tcp_output() determined is ready to send.
 */
/*static*/ int
tcp_send(Sessn so, int off, int len, int win, int flags)
{
    SState *ss;
    struct tcphdr tHdr;
    unsigned optlen;
#ifdef TCP_STATISTICS
    PState *ps = (PState *)xMyProtl(so)->state;
#endif
    u_char *opt;
    VOID *buf;
    int error;
    Msg m;

    ss = sotoss(so);
    /*
     * Grab LEN bytes from xmit queue, attaching a copy of data to be
     * transmitted, and initialize the header from the template for
     * sends on this connection.
     */
    sbcollect(ss->snd, &m, off, len, 0);
    TCP_STAT(
	     if (len) {
		 if (ss->t_force && len == 1) {
		     ++ps->tcps_sndprobe;
		 } else if (SEQ_LT(ss->snd_nxt, ss->snd_max)) {
		     ++ps->tcps_sndrexmitpack;
		     ps->tcps_sndrexmitbyte += len;
		 } else {
		     ++ps->tcps_sndpack;
		     ps->tcps_sndbyte += len;
		 } /* if */
	     } else if (ss->t_flags & TF_ACKNOW) {
		 ++ps->tcps_sndacks;
	     } else if (flags & (TH_SYN|TH_FIN|TH_RST)) {
		 ++ps->tcps_sndctrl;
	     } else if (SEQ_GT(ss->snd_up, ss->snd_una)) {
		 ++ps->tcps_sndurg;
	     } else {
		 ++ps->tcps_sndwinup;
	     } /* if */);
    
    tHdr = ss->t_template.ti_t;
    /*
     * Fill in fields, remembering maximum advertised
     * window for use in delaying messages about window sizes.
     * If resending a FIN, be sure not to use a new sequence number.
     */
    if (flags & TH_FIN PREDICT_FALSE) {
	if (ss->t_flags & TF_SENTFIN && ss->snd_nxt == ss->snd_max) {
	    --ss->snd_nxt;
	} /* if */
    } /* if */

    tHdr.th_seq = ss->snd_nxt;
    tHdr.th_ack = ss->rcv_nxt;
    xTraceS2(so, TR_EVENTS, "sending seq %d, ack %d",
	     tHdr.th_seq, tHdr.th_ack);
    /*
     * Before ESTABLISHED, force sending of initial options
     * unless TCP set to not do any options.
     */
    if (flags & TH_SYN PREDICT_FALSE) {
	if ((ss->t_flags & TF_NOOPT) == 0) {
	    u_short mss;
	    int padOptLen;

	    mss = MIN(ss->rcv_hiwat / 2, tcp_mss(so));
	    if (mss > IP_MSS - sizeof(struct tcpiphdr)) {
		mss = htons(mss);
		opt = tcp_initopt;
		optlen = sizeof (tcp_initopt);
		bcopy((char *)&mss, (char *)opt+2, sizeof(short));
		padOptLen = (optlen + 3) & ~0x3;
		buf = msgPush(&m, padOptLen);

		xAssert(buf);
		tcpOptionsStore(opt, buf, padOptLen, optlen);
		tHdr.th_off = (sizeof (struct tcphdr) + padOptLen) >> 2;
	    } /* if */
	} /* if */
    } /* if */
    tHdr.th_flags = flags;
    /*
     * Calculate receive window.  Don't shrink window,
     * but avoid silly window syndrome.
     */
    if (win < (long)(ss->rcv_hiwat / 4) && win < (long)ss->t_maxseg) {
	win = 0;
    } /* if */
    if (win < (int)(ss->rcv_adv - ss->rcv_nxt) PREDICT_FALSE) {
	win = (int)(ss->rcv_adv - ss->rcv_nxt);
    } /* if */
    tHdr.th_win = (u_short)win;
    if (SEQ_GT(ss->snd_up, ss->snd_nxt) PREDICT_FALSE) {
	tHdr.th_urp = (u_short)(ss->snd_up - ss->snd_nxt);
	tHdr.th_flags |= TH_URG;
    } else {
	/*
	 * If no urgent pointer to send, then we pull
	 * the urgent pointer to the left edge of the send window
	 * so that it doesn't drift into the send window on sequence
	 * number wraparound.
	 */
	ss->snd_up = ss->snd_una;		/* drag it along */
    } /* if */
    /*
     * If anything to send and we can send it all, set PUSH.  (This
     * will keep happy those implementations which only give data to
     * the user when a buffer fills or a PUSH comes in.)
     */
    if (len && off+len == sblength(ss->snd)) {
	tHdr.th_flags |= TH_PUSH;
    } /* if */
    
    xTraceS2(so, TR_EVENTS, "sending %d bytes with flags (%s)",
	     msgLength(&m), tcpFlagStr(tHdr.th_flags));
    
    buf = msgPush(&m, sizeof(struct tcphdr));
    tcpHdrStore(&tHdr, buf, sizeof(struct tcphdr),
		&m, &ss->t_template.ti_p);
    /*
     * In transmit state, time the transmission and arrange for
     * the retransmit.  In persist state, just set snd_max.
     */
    if (ss->t_force == 0 || ss->t_timer[TCPT_PERSIST] == 0
	PREDICT_TRUE)
    {
	tcp_seq startseq = ss->snd_nxt;

	/*
	 * Advance snd_nxt over sequence space of this segment.
	 */
	if (flags & (TH_SYN | TH_FIN) PREDICT_FALSE) {
	    ++ss->snd_nxt;
	    if (flags & TH_FIN) {
		ss->t_flags |= TF_SENTFIN;
	    } /* if */
	} /* if */
	ss->snd_nxt += len;
	if (SEQ_GT(ss->snd_nxt, ss->snd_max)) {
	    ss->snd_max = ss->snd_nxt;
	    /*
	     * Time this transmission if not a retransmission and
	     * not currently timing anything.
	     */
	    if (ss->t_rtt == 0) {
		ss->t_rtt = 1;
		ss->t_rtseq = startseq;
		TCP_STAT(++ps->tcps_segstimed);
	    } /* if */
	} /* if */

	/*
	 * Set retransmit timer if not currently set,
	 * and not doing an ack or a keep-alive probe.
	 * Initial value for retransmit timer is smoothed
	 * round-trip time + 2 * round-trip time variance.
	 * Initialize shift counter which is used for backoff
	 * of retransmit time.
	 */
	if (ss->t_timer[TCPT_REXMT] == 0 &&
	    ss->snd_nxt != ss->snd_una)
	{
	    ss->t_timer[TCPT_REXMT] = ss->t_rxtcur;
	    if (ss->t_timer[TCPT_PERSIST] PREDICT_FALSE) {
		ss->t_timer[TCPT_PERSIST] = 0;
		ss->t_rxtshift = 0;
	    } /* if */
	} /* if */
    } else {
	if (SEQ_GT(ss->snd_nxt + len, ss->snd_max)) {
	    ss->snd_max = ss->snd_nxt + len;
	} /* if */
    } /* if */
    /*
     * Send it out.
     */
    error = xPush(xGetSessnDown(so, 0), &m) < 0;
    msgDestroy(&m);
    if (error PREDICT_FALSE) {
	if (error == ENOBUFS) {
	    tcp_quench(ss);
	} /* if */
	return error;
    } /* if */
    TCP_STAT(++ps->tcps_sndtotal);
    /*
     * Data sent (as far as we can tell).
     * If this advertises a larger window than any other segment,
     * then remember the size of the advertised window.
     * Any pending ACK has now been sent.
     */
    if (win > 0 && SEQ_GT(ss->rcv_nxt+win, ss->rcv_adv)) {
	ss->rcv_adv = ss->rcv_nxt + win;
	xTraceS3(so, TR_MORE_EVENTS,
		 "rcv_adv = rcv_nxt (%x) + win (%x) = %x",
		 ss->rcv_nxt, win, ss->rcv_adv);
    } /* if */
    ss->t_flags &= ~(TF_ACKNOW|TF_DELACK);
    return 0;
} /* tcp_send */


/*
 * Check whether there is anything to send.  If so, pass it along
 * to tcp_send().
 */
int
tcp_output(Sessn so)
{
    SState *ss;
    int len, win, off, flags, error = 0;
    int idle, sendalot;

    if (!so PREDICT_FALSE) {
	/*
	 * Oops, looks like the socket closed on us.  Well, no
	 * need to do anymore output so... -mjk 8/16/90
	 */
	xTrace0(tcpp, TR_EVENTS, "so is 0 -- tcp output exiting");
	return 0;
    } /* if */

    xTraceS1(so, TR_EVENTS, "tcp_output(so=%lx)", (u_long)so);
    ss = sotoss(so);
    /*
     * Determine length of data that should be transmitted,
     * and flags that will be used.
     * If there is some data or critical controls (SYN, RST)
     * to send, then transmit; otherwise, investigate further.
     */
    idle = (ss->snd_max == ss->snd_una);
    do {
	sendalot = 0;
	off = ss->snd_nxt - ss->snd_una;
	
	xTraceS2(so, TR_MAJOR_EVENTS,
		 "tcp_output: ss->snd_wnd=%x, ss->snd_cwnd=%x",
		 ss->snd_wnd, ss->snd_cwnd);
	
	win = MIN(ss->snd_wnd, ss->snd_cwnd);
	
	/*
	 * If in persist timeout with window of 0, send 1 byte.
	 * Otherwise, if window is small but nonzero
	 * and timer expired, we will send what we can
	 * and go to transmit state.
	 */
	if (ss->t_force) {
	    if (win == 0 PREDICT_FALSE) {
	      win = 1;
	    } else {
		ss->t_timer[TCPT_PERSIST] = 0;
		ss->t_rxtshift = 0;
	    } /* if */
	} /* if */
	
	len = MIN(sblength(ss->snd), win) - off;
	xTraceS4(so, TR_EVENTS,
		 "tcp_output: sbLen: %d, win: %d, off: %d, len == %d",
		 sblength(ss->snd), win, off, len);
	flags = tcp_outflags[ss->t_state];
	
	if (len < 0 PREDICT_FALSE) {
	    /*
	     * If FIN has been sent but not acked,
	     * but we haven't been called to retransmit,
	     * len will be -1.  Otherwise, window shrank
	     * after we sent into it.  If window shrank to 0,
	     * cancel pending retransmit and pull snd_nxt
	     * back to (closed) window.  We will enter persist
	     * state below.  If the window didn't close completely,
	     * just wait for an ACK.
	     */
	    len = 0;
	    if (win == 0) {
		ss->t_timer[TCPT_REXMT] = 0;
		ss->snd_nxt = ss->snd_una;
	    } /* if */
	} /* if */
	if (len > ss->t_maxseg PREDICT_FALSE) {
	    len = ss->t_maxseg;
	    sendalot = 1;
	}
	if (SEQ_LT(ss->snd_nxt + len, ss->snd_una + sblength(ss->snd))
	    PREDICT_FALSE)
	{
	    flags &= ~TH_FIN;
	} /* if */
	win = ss->rcv_space;
	
	if (/*
	     * Send if we owe peer an ACK.
	     */
	    (ss->t_flags & TF_ACKNOW)
	    || (SEQ_GT(ss->snd_up, ss->snd_una))
	    /*
	     * If our state indicates that FIN should be
	     * sent and we have not yet done so, or we're
	     * retransmitting the FIN, then we need to send.
	     */
	    || (flags & TH_FIN && ((ss->t_flags & TF_SENTFIN) == 0
				   || ss->snd_nxt == ss->snd_una))
	    || (flags & (TH_SYN|TH_RST)))
	{
	    error = tcp_send(so, off, len, win, flags);
	    continue;
	} /* if */

	/*
	 * Sender silly window avoidance.  If connection is idle
	 * and can send all data, a maximum segment,
	 * at least a maximum default-size segment do it,
	 * or are forced, do it; otherwise don't bother.
	 * If peer's buffer is tiny, then send
	 * when window is at least half open.
	 * If retransmitting (possibly after persist timer forced us
	 * to send into a small window), then must resend.
	 */
	if ((len > 0) && ((len == ss->t_maxseg)
			  || ((idle || ss->t_flags & TF_NODELAY) &&
			      len + off >= sblength(ss->snd))
			  || (ss->t_force)
			  || (len >= ss->max_sndwnd / 2)
			  || (SEQ_LT(ss->snd_nxt, ss->snd_max))))
	{
	    error = tcp_send(so, off, len, win, flags);
	    continue;
	} /* if */

	/*
	 * Compare available window to amount of window
	 * known to peer (as advertised window less
	 * next expected input).  If the difference is at least two
	 * max size segments or more than 33% of the maximum possible
	 * window, then want to send a window update to peer.
	 */
	if (win > 0) {
	    int adv = win - (ss->rcv_adv - ss->rcv_nxt);

	    if (((win == ss->rcv_hiwat) && (adv >= 2 * ss->t_maxseg))
		|| (3 * adv > ss->rcv_hiwat))
	    {
		error = tcp_send(so, off, len, win, flags);
		continue;
	    } /* if */
	} /* if */
	/*
	 * TCP window updates are not reliable, rather a polling protocol
	 * using ``persist'' packets is used to insure receipt of window
	 * updates.  The three ``states'' for the output side are:
	 *	idle			not doing retransmits or persists
	 *	persisting		to move a small or zero window
	 *	(re)transmitting	and thereby not persisting
	 *
	 * ss->t_timer[TCPT_PERSIST]
	 *	is set when we are in persist state.
	 * ss->t_force
	 *	is set when we are called to send a persist packet.
	 * ss->t_timer[TCPT_REXMT]
	 *	is set when we are retransmitting
	 * The output side is idle when both timers are zero.
	 *
	 * If send window is too small, there is data to transmit, and no
	 * retransmit or persist is pending, then go to persist state.
	 * If nothing happens soon, send when timer expires:
	 * if window is nonzero, transmit what we can,
	 * otherwise force out a byte.
	 */
	if (sblength(ss->snd) && ss->t_timer[TCPT_REXMT] == 0 &&
	    ss->t_timer[TCPT_PERSIST] == 0
	    PREDICT_FALSE)
	{
	    ss->t_rxtshift = 0;
	    tcp_setpersist(ss);
	} /* if */
	
	/*
	 * No reason to send a segment, just return.
	 */
	xTraceS0(so, TR_EVENTS, "tcp_output: no reason to send");
    } while (sendalot && error == 0);
    return error;
} /* tcp_output */

			/*** end of tcp_output.c ***/
