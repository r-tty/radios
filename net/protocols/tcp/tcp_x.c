/*
 * $RCSfile: tcp_x.c,v $
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
 * $Log: tcp_x.c,v $
 * Revision 1.3  1996/01/29 22:32:07  slm
 * Updated copyright and version.
 *
 * Revision 1.2  1995/09/26  21:23:19  davidm
 * Got rid of bogus myHost global variable.  Host is now determined based
 * on lower-level session at tcp_establishopen time.  This works even in
 * the case of multi-homed hosts.
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.55.1.5.1.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.55.1.1  1994/04/26  17:25:34  menze
 * Added cast to bzero argument
 *
 * Revision 1.55  1994/04/21  21:09:58  davidm
 * (tcp_establishopen): use ERR_BIND instead of -1 and bzero() ex_id before
 * filling in individual fields.
 *
 * Revision 1.54  1994/01/08  21:23:50  menze
 *   [ 1994/01/05          menze ]
 *   PROTNUM changed to PORTNUM
 *
 * Revision 1.53  1993/12/16  01:45:15  menze
 * Strict ANSI compilers weren't combining multiple tentative definitions
 * of external variables into a single definition at link time.
 *
 * Revision 1.52  1993/12/13  23:26:33  menze
 * Modifications from UMass:
 *
 *   [ 93/08/20          nahum ]
 *   Fixed #undef problem.
 *
 * Revision 1.51  1993/12/11  00:25:08  menze
 * fixed #endif comments
 *
 * Revision 1.50  1993/12/07  18:15:56  menze
 * Improved validity checks on incoming participants
 *
 */

#include "xkernel.h"
#include "ip.h"
#include "tcp_debug.h"
#include "tcp_internal.h"
#include "tcp_fsm.h"
#include "tcp_seq.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"


tcp_seq	tcp_iss;		/* tcp initial send seq # */


#ifdef __STDC__

static int	extractPart( Part *, long *, IPhost **, char * );
static void	tcpSessnInit( Sessn );
static Sessn	tcp_establishopen( Protl, Protl, Protl, IPhost *, IPhost *,
				   int, int );
static void	tcp_dumpstats( PState * );
static XkReturn	tcpClose( Sessn );
static int	tcpControlProtl( Protl, int, char *, int );
/*static*/ int	tcpControlSessn( Sessn, int, char *, int );
static Part     *tcpGetParticipants(Sessn);
static Sessn	tcpOpen( Protl, Protl, Protl, Part * );
static XkReturn	tcpOpenEnable( Protl, Protl, Protl, Part * );
static XkReturn	tcpOpenDisable( Protl, Protl, Protl, Part * );
/*static*/ XkHandle	tcpPush( Sessn, Msg * );


#else

static int	extractPart();
static void	tcpSessnInit();
static Sessn	tcp_establishopen();
static void	tcp_dumpstats();
static int	tcpControlProtl();
/*static*/ int  tcpControlSessn();
static Part     *tcpGetParticipants();
static Sessn	tcpOpen();
static XkReturn	tcpOpenEnable();
static XkReturn	tcpOpenDisable();

#endif /* __STDC__ */



/* 
 * Check for a valid participant list
 */
#define partCheck(p, name, max, retval)					\
	{								\
	  if ( ! (p) || partLength(p) < 1 || partLength(p) > (max)) { 	\
		xTrace1(tcpp, TR_ERRORS,				\
			"%s -- bad participants",			\
			(name));  					\
		return (retval);					\
	  }								\
	}


void
tcpSemWait( ts )
     TcpSem *ts;
{
    ts->waitCount++;
    semWait(&ts->s);
    ts->waitCount--;
} /* tcpSemWait */


#if defined(__GNUC__)
inline
#endif
void
tcpSemSignal( ts )
     TcpSem *ts;
{
    semSignal(&ts->s);
} /* tcpSemSignal */


void
tcpSemVAll( ts )
     TcpSem *ts;
{
    int i, n;

    n=ts->waitCount;
    for ( i=0; i < n; i++ ) {
	semSignal(&ts->s);
    }
} /* tcpSemVAll */


void
tcpSemInit( ts, n )
     TcpSem *ts;
     int n;
{
    semInit(&ts->s, n);
    ts->waitCount = 0;
} /* tcpSemInit */


void
tcp_init(self)
    Protl self;
{
    Part p;
    PState *ps;

    xTraceP0(self, TR_GROSS_EVENTS, "TCP init");
    xTraceP1(self, TR_GROSS_EVENTS, "ENDIAN = %d", ENDIAN);

    xAssert(xIsProtl(self));
    ps = (PState *)xMalloc(sizeof(PState));
    bzero((char *)ps, sizeof(PState));
    self->state = (char *)ps;

    self->controlprotl = tcpControlProtl;
    self->open = tcpOpen;
    self->openenable = tcpOpenEnable;
    self->opendisable = tcpOpenDisable;
    self->demux = tcpDemux;

    ps->passiveMap = mapCreate(37, sizeof(PassiveId));
    ps->activeMap = mapCreate(101, sizeof(ActiveId));
    tcp_iss = 1;

    /* turn on IP pseudoheader length-fixup kludge in lower protocols: */
    xControlProtl(xGetProtlDown(self, 0),IP_PSEUDOHDR,(char *)0,0);

    partInit(&p, 1);
    partPush(p, ANY_HOST, 0);
    xOpenEnable(self, self, xGetProtlDown(self, 0), &p);
    evDetach(evSchedule(tcp_fasttimo, self, TCP_FAST_INTERVAL));
    evDetach(evSchedule(tcp_slowtimo, self, TCP_SLOW_INTERVAL));
    tcpPortMapInit( &ps->portstate );
} /* tcp_init */


static
#if defined(__GNUC__)
inline
#endif
SState*
new_session_state()
{
    SState *ss;

    ss = (SState*) xMalloc(sizeof(SState));
    bzero((char *)ss, sizeof(SState));
    tcpSemInit(&ss->waiting, 0);
    ss->snd = (struct sb *)xMalloc(sizeof(struct sb));
    /* initialize buffer size to TCPRCVWIN to get things started: */
    ss->rcv_space = TCPRCVWIN;
    ss->rcv_hiwat = TCPRCVWIN;
    return ss;
} /* new_session_state */


static Sessn
tcp_establishopen(self, hlp, hlpType, raddr, laddr, rport, lport)
     Protl self, hlp, hlpType;
     IPhost *raddr, *laddr;
     int rport, lport;
{
    Part p[2];
    Sessn new;
    SState *ss;
    ActiveId ex_id;
    Sessn lls;
    PState *ps = (PState *)self->state;

    xTraceP1(self, TR_MAJOR_EVENTS, "tcp_establishopen(hlp=%lx)",
	     (u_long) hlp);

    xAssert(xIsProtl(hlp));
    bzero((char *)&ex_id, sizeof(ex_id));
    ex_id.localport = lport;
    ex_id.remoteport = rport;
    ex_id.remoteaddr = *raddr;
    if (mapResolve(ps->activeMap, &ex_id, (void **)&new) == XK_SUCCESS) {
	xTraceP3(self, TR_GROSS_EVENTS,
		 "tcp_establish: (%d->%s:%d) already open",
		 ex_id.localport, ipHostStr(raddr), ex_id.remoteport);
	return 0;
    }

    partInit(p, laddr ? 2 : 1);
    partPush(p[0], raddr, sizeof(IPhost));
    if ( laddr ) {
	partPush(p[1], laddr, sizeof(IPhost));
    } /* if */
    xTraceP0(self, TR_EVENTS, "tcp_establishopen: opening IP");
    lls = xOpen(self, self, xGetProtlDown(self,0), p);
    if ( lls == ERR_SESSN ) {
	xTraceP0(self, TR_ERRORS, "tcp_establishopen: cannot open IP session");
	return 0;
    } /* if */

    new = xCreateSessn(tcpSessnInit, hlp, hlpType, self, 1, &lls);
    xTraceP3(self, TR_GROSS_EVENTS, "mapping %d->%s:%d",
	     lport, ipHostStr(raddr), rport);
    new->binding = mapBind(ps->activeMap,  &ex_id, new);
    if (new->binding == ERR_BIND) {
	xTraceP3(self, TR_GROSS_EVENTS,
		 "tcp_establish: bind of %d->%s:%d failed",
		 lport, ipHostStr(raddr), rport);
	return 0;
    } /* if */

    ss = new_session_state();
    ss->hlpType = hlpType;
    new->state = (char *)ss;

    /*
     * Attach TCP protocol to socket, allocating buffer space, and
     * entering LISTEN state if to accept connections.
     */
    xTraceP0(self, TR_EVENTS, "tcp_establishopen: attaching...");

    /*
     * Initialize send queue:
     */
    sbinit(ss->snd);

    /*
     * Create an empty reassembly queue.
     */
    ss->seg_next = ss->seg_prev = (struct reass *)&ss->seg_next;
    ss->t_maxseg = TCP_MSS;
    ss->t_flags = 0;		/* sends options! */
    /*
     * Init srtt to TCPTV_SRTTBASE (0), so we can tell that we have no
     * rtt estimate.  Set rttvar so that srtt + 2 * rttvar gives
     * reasonable initial retransmit time.
     */
    ss->t_srtt = TCPTV_SRTTBASE;
    ss->t_rttvar = TCPTV_SRTTDFLT << 2;
    TCPT_RANGESET(ss->t_rxtcur, 
		  ((TCPTV_SRTTBASE >> 2) + (TCPTV_SRTTDFLT << 2)) >> 1,
		  TCPTV_MIN, TCPTV_REXMTMAX);
    ss->snd_cwnd = sbspace(ss->snd);
    ss->snd_ssthresh = 65535;		/* XXX */

    ss->t_state = TCPS_CLOSED;

    xControlSessn(lls, GETMYHOST, (char *)&ss->t_template.ti_src, sizeof(IPhost));
    ss->t_template.ti_dst = ex_id.remoteaddr;
    ss->t_template.ti_sport = ex_id.localport;
    ss->t_template.ti_dport = ex_id.remoteport;

    return new;
} /* tcp_establishopen */


static int
extractPart( p, port, host, s )
    Part	*p;
    long	*port;
    IPhost	**host;
    char	*s;
{
    long	*portPtr;
    IPhost	*hostPtr;

    xAssert(port);
    if ( ! p || partStackTopByteLen(*p) < sizeof(long) ||
	 (portPtr = (long *)partPop(*p)) == 0 ) {
	xTrace1(tcpp, TR_SOFT_ERRORS, "bad participant in %s -- no port", s);
	return -1;
    }
    *port = *portPtr;
    if ( *port > MAX_PORT ) {
	xTrace2(tcpp, TR_SOFT_ERRORS,
		"Bad participant in %s -- port %d out of range", s, *port);
	return -1;
    }
    if ( host ) {
	if ( partStackTopByteLen(*p) < sizeof(IPhost) ||
	     (hostPtr = (IPhost *)partPop(*p)) == 0 ) {
	    xTrace1(tcpp, TR_SOFT_ERRORS,
		    "bad participant in %s -- no host", s);
	    return -1;
	}
	*host = hostPtr;
    }
    return 0;
} /* extractPart */


static Sessn
tcpOpen(self, hlp, hlpType, p)
    Protl            self, hlp, hlpType;
    Part           *p;
{
    Sessn so;
    PState *ps;
    SState *ss;
    long remotePort, localPort = ANY_PORT;
    IPhost *remoteHost, *localHost = 0;
    
    ps = (PState *)self->state;

    xTraceP0(self, TR_GROSS_EVENTS, "tcpOpen()");
    partCheck(p, "tcpOpen", 2, ERR_SESSN);
    if ( extractPart(p, &remotePort, &remoteHost, "tcpOpen (remote)") ) {
	return ERR_SESSN;
    }
    if ( partLength(p) > 1 ) {
	if ( extractPart(p+1, &localPort, &localHost, "tcpOpen (local)") ) {
	    return ERR_SESSN;
	}
	if ( localHost == (IPhost *)ANY_HOST ) {
	    localHost = 0;
	}
    }
    if ( localPort == ANY_PORT ) {
	/* 
	 * We need to find a free local port
	 */
	long	freePort;
	if (tcpGetFreePort(ps->portstate, &freePort)) {
	    xError("tcpOpen -- no free ports!");
	    return ERR_SESSN;
	}
	localPort = freePort;
    } else {
	/* 
	 * A specific local port was requested
	 */
	if (tcpDuplicatePort(ps->portstate, localPort)) {
	    xTraceP1(self, TR_MAJOR_EVENTS,
		     "tcpOpen: requested port %d is already in use",
		     localPort);
	    return ERR_SESSN;
	}
    } /* if */
    so = tcp_establishopen(self, hlp, hlpType, remoteHost, localHost,
			   remotePort, localPort);

    if (!so) {
	tcpReleasePort(ps->portstate, localPort);
	so = ERR_SESSN;
    } else {
	xTraceP0(self, TR_EVENTS, "tcpOpen: connecting...");

	tcp_template(so);
	TCP_STAT(++ps->tcps_connattempt);

	ss = sotoss(so);
	ss->t_state = TCPS_SYN_SENT;
	ss->t_timer[TCPT_KEEP] = TCPTV_KEEP;
	ss->iss = tcp_iss;
	tcp_iss += TCP_ISSINCR/2;

	tcp_sendseqinit(ss);
	tcp_output(so);
	xIfTrace(tcpp, 3) {
	    tcp_trace(TA_USER, ss->t_state, ss, 0, PRU_CONNECT);
	}
	
	xTraceP0(self, TR_EVENTS, "tcpOpen: waiting...");

	/* make sure we don't loose session while waiting: */
	xDuplicate(so);
	tcpSemWait(&ss->waiting);
	if (ss->t_state == TCPS_ESTABLISHED) {
	    /*
	     * Hack: reference count will be incremented by xOpen()
	     * when returning from this function, so pass our reference
	     * along to xOpen().  We cannot use xClose() here because
	     * our reference is likely to be the only one outstanding
	     * (so xClose() would destroy the object).
	     */
	    --so->rcnt;
	} else {
	    xTraceP3(self, TR_EVENTS,
		     "tcpOpen: open (%d->%s:%d) connect failed",
		     localPort,  ipHostStr(remoteHost), remotePort);
	    tcpReleasePort(ps->portstate, localPort);
	    xClose(so);
	    so = ERR_SESSN;
	} /* if */
    } /* if */
    xTraceP1(self, TR_GROSS_EVENTS, "return from tcpOpen, session = %lx",
	     (u_long)so);
    return so;
} /* tcpOpen */


static XkReturn
tcpOpenEnable(self, hlp, hlpType, p)
    Protl	self, hlp, hlpType;
    Part	*p;
{
    PassiveId	key;
    long	protNum;
    PState	*ps = (PState *)self->state;
    Enable	*e;
    
    partCheck(p, "tcpOpenEnable", 1, XK_FAILURE);
    if ( extractPart(p, &protNum, 0, "tcpOpenEnable") ) {
	return XK_FAILURE;
    }
    key = protNum;
    xTraceP2(self, TR_MAJOR_EVENTS, "tcpOpenEnable mapping %d->%lx", key,
	     (u_long)hlp);
    if (mapResolve(ps->passiveMap, &key, (void **)&e) == XK_SUCCESS) {
	if ( e->hlp == hlp && e->hlpType == hlpType ) {
	    e->rcnt++;
	    return XK_SUCCESS;
	}
	return XK_FAILURE;
    }
    tcpDuplicatePort(ps->portstate, key);
    e = (Enable *)xMalloc(sizeof(Enable));
    e->hlp = hlp;
    e->hlpType = hlpType;
    e->rcnt = 1;
    e->binding = mapBind(ps->passiveMap, &key, e);
    if ( e->binding == ERR_BIND ) {
	xFree((char *)e);
	return XK_FAILURE;
    }
    return XK_SUCCESS;
} /* tcpOpenEnable */


static XkReturn
tcpOpenDisable(self, hlp, hlpType, p)
    Protl	self, hlp, hlpType;
    Part        *p;
{
    PassiveId	key;
    long	protNum;
    Enable	*e;
    PState	*ps;

    ps = (PState *)self->state;
    partCheck(p, "tcpOpenDisable", 1, XK_FAILURE);
    if ( extractPart(p, &protNum, 0, "tcpOpenEnable") ) {
	return XK_FAILURE;
    }
    key = protNum;
    xTraceP1(self, TR_MAJOR_EVENTS, "tcp_disable removing %d", key);
    if (mapResolve(ps->passiveMap, &key, (void **)&e) == XK_FAILURE ||
		e->hlp != hlp || e->hlpType != hlpType) {
	return XK_FAILURE;
    }
    if (--(e->rcnt) == 0) {
	mapRemoveBinding(ps->passiveMap, e->binding);
	xFree((char *)e);
	tcpReleasePort(ps->portstate, key);
    }
    return XK_SUCCESS;
} /* tcpOpenDisable */


/*
 * User issued close, and wishes to trail through shutdown states:
 * if never received SYN, just forget it.  If got a SYN from peer,
 * but haven't sent FIN, then go to FIN_WAIT_1 state to send peer a FIN.
 * If already got a FIN from peer, then almost done; go to LAST_ACK
 * state.  In all other cases, have already sent FIN to peer (e.g.
 * after PRU_SHUTDOWN), and just have to play tedious game waiting
 * for peer to send FIN or not respond to keep-alives, etc.
 * We can let the user exit from the close as soon as the FIN is acked.
 */
static XkReturn
tcpClose(so)
     Sessn so;
{
    SState *ss;
    
    xTraceS1(so, TR_FUNCTIONAL_TRACE, "tcpClose(so=%lx)", so);

    ss = sotoss(so);
    ss->t_flags |= TF_USRCLOSED;
    
    switch (ss->t_state) {
      case TCPS_CLOSED:
      case TCPS_LISTEN:
      case TCPS_SYN_SENT:
	ss->t_state = TCPS_CLOSED;
	tcp_destroy(so);
	return XK_SUCCESS;

      case TCPS_SYN_RECEIVED:
      case TCPS_ESTABLISHED:
	ss->t_state = TCPS_FIN_WAIT_1;
	break;

      case TCPS_CLOSE_WAIT:
	ss->t_state = TCPS_LAST_ACK;
	break;
    } /* switch */

    /*
     * We need to keep the session around until we're really done.
     * Without bumping up the reference count, we would get a
     * tcpClose() invocation for each incoming message.
     */
    xDuplicate(so);

    if (ss->t_state >= TCPS_FIN_WAIT_2) {
	soisdisconnected(so);
    } /* if */
    tcp_output(so);

    xTraceS2(so, TR_MAJOR_EVENTS, "tcpClose: so=%lx, ss->t_flags=%x",
	     (u_long) so, ss->t_flags);

    if (!(ss->t_flags & TF_NETCLOSED)) {
	/*
	 * Wait until connection-teardown has completed:
	 */
	xTraceS0(so, TR_EVENTS, "tcpClose: waiting...");
	tcpSemWait(&ss->waiting);
	/* at this point, session may be gone already */
	xTraceS0(so, TR_EVENTS, "tcpClose: done");
    } /* if */
    return XK_SUCCESS;
} /* tcpClose */


/*static*/ XkHandle
tcpPush(so, msg)
     Sessn so;
     Msg *msg;
{
    int error, space;
    Msg pushMsg;
    register SState *ss = sotoss(so);

    xTraceS2(so, TR_MAJOR_EVENTS, "tcpPush: session %lx, msg %d bytes",
	     (u_long)so, msgLength(msg));

    xAssert(so->rcnt >= 1);

#undef CHUNKSIZE
#define CHUNKSIZE (ss->t_maxseg)

    if (ss->t_flags & TF_NBIO PREDICT_FALSE) {
	if (sbspace(ss->snd) < MIN(msgLength(msg), CHUNKSIZE)) {
	    return XMSG_ERR_WOULDBLOCK;
	} /* if */
    } /* if */

    msgConstructEmpty(&pushMsg);
    while ( msgLength(msg) != 0 ) {
	xTraceS1(so, TR_FUNCTIONAL_TRACE,
		 "tcpPush: msgLength = <%d>", msgLength(msg));
	msgBreak(msg, &pushMsg, CHUNKSIZE);
	xTraceS2(so, TR_FUNCTIONAL_TRACE,
		 "tcpPush: after break pushMsg = <%d> msg = <%d>",
		 msgLength(&pushMsg), msgLength(msg));
	space = sbspace(ss->snd);
	if (space < msgLength(&pushMsg) PREDICT_FALSE) {
	    /*
	     * This may not be that uncommon.  But in the latency
	     * sensitive case (small message) it should be uncommon.
	     * Also, compared to blocking, the extra jump shouldn't
	     * hurt much.
	     */
	    do {
		xTraceS1(so, TR_MAJOR_EVENTS,
			 "tcpPush: waiting for space (%d available)", space);
		xTraceS1(so, TR_FUNCTIONAL_TRACE,
			 "tcpPush: msgLength == %d before blocking",
			 msgLength(msg));
		tcpSemWait(&ss->waiting);
		if (ss->t_state != TCPS_ESTABLISHED PREDICT_FALSE) {
		    xTraceS1(so, TR_FUNCTIONAL_TRACE,
			    "tcpPush: session already closed %d", ss->t_flags);
		    msgDestroy(&pushMsg);
		    return XMSG_ERR_HANDLE;
		} /* if */
		space = sbspace(ss->snd);
	    } while (space < msgLength(&pushMsg));
	} /* if */
	xTraceS1(so, TR_FUNCTIONAL_TRACE,
		 "tcppush about to append to sb.  orig msgLength == %d",
		 msgLength(msg));
	sbappend(ss->snd, &pushMsg);
	error = tcp_output(so);
	if (error PREDICT_FALSE) {
	    xTraceS1(so, TR_ERRORS, "tcpPush failed with code %d", error);
	    msgDestroy(&pushMsg);
	    return XMSG_ERR_HANDLE;
	}
    }
    msgDestroy(&pushMsg);
    return XMSG_NULL_HANDLE;
} /* tcpPush */


/*static*/ int
tcpControlSessn(so, opcode, buf, len)
     Sessn so;
     char *buf;
     int opcode;
     int len;
{
    SState *ss;
    u_short size;

    ss = sotoss(so);

    if (opcode == TCP_SETRCVBUFSPACE PREDICT_TRUE) {
	/*
	 * Yes, my friend, this *is* on the critical path.  Only
	 * God knows why this is a control-op.
	 */
	checkLen(len, sizeof(u_short));
	size = *(u_short *)buf;
	ss->rcv_space = size;
	/* after receiving message possibly send window update: */
	tcp_output(so);
	return 0;
    } else {
	switch (opcode) {

	  case GETMYPROTO:
	    checkLen(len, sizeof(long));
	    *(long *)buf = ss->t_template.ti_sport;
	    return sizeof(long);

	  case GETPEERPROTO:
	    checkLen(len, sizeof(long));
	    *(long *)buf = ss->t_template.ti_dport;
	    return sizeof(long);

	  case TCP_PUSH:
	    ss->t_force = 1;
	    tcp_output(so);
	    ss->t_force = 0;
	    return 0;

	  case TCP_GETSTATEINFO:
	    *(int *) buf = ss->t_state;
	    return (sizeof(int));

	  case GETOPTPACKET:
	  case GETMAXPACKET:
	    if ( xControlSessn(xGetSessnDown(so, 0), opcode, buf, len) < sizeof(int) ) {
		return -1;
	    } /* if */
	    *(int *)buf -= sizeof(struct tcphdr);
	    return sizeof(int);

	  case SETNONBLOCKINGIO:
	    xControlSessn(xGetSessnDown(so, 0), opcode, buf, len);
	    if (*(int*)buf) {
		ss->t_flags |= TF_NBIO;
	    } else {
		ss->t_flags &= ~TF_NBIO;
	    } /* if */
	    return 0;

#define SETKEEPALIVE	14	/* XXX fixme!! should be in upi.h */
	  case SETKEEPALIVE:
	    xControlSessn(xGetSessnDown(so, 0), opcode, buf, len);
	    if (*(int*)buf) {
		ss->t_flags |= TF_KEEP_ALIVE;
	    } else {
		ss->t_flags &= ~TF_KEEP_ALIVE;
	    } /* if */
	    return 0;

	  case TCP_SETPUSHALWAYS:
	    checkLen(len, sizeof(int));
	    if (*(int*)buf) {
		ss->t_flags |= TF_NODELAY;
	    } else {
		ss->t_flags &= ~TF_NODELAY;
	    } /* if */
	    return 0;

	  case TCP_SETRCVACKALWAYS:
	    checkLen(len, sizeof(int));
	    if (*(int*)buf) {
		ss->t_flags |= TF_RCV_ACK_ALWAYS;
	    } else {
		ss->t_flags &= ~TF_RCV_ACK_ALWAYS;
	    } /* if */
	    return 0;

	  case TCP_GETSNDBUFSPACE:
	    checkLen(len, sizeof(u_short));
	    *(u_short*)buf = sbspace(ss->snd);
	    return sizeof(u_short);

	  case TCP_SETRCVBUFSIZE:
	    checkLen(len, sizeof(u_short));
	    size = *(u_short *)buf;
	    ss->rcv_hiwat = size;
	    return 0;

	  case TCP_SETSNDBUFSIZE:
	    checkLen(len, sizeof(u_short));
	    sbhiwat(ss->snd) = *(u_short *)buf;
	    return 0;

	  case TCP_SETOOBINLINE:
	    checkLen(len, sizeof(int));
	    if (*(int*)buf) {
		ss->t_flags |= TF_OOBINLINE;
	    } else {
		ss->t_flags &= ~TF_OOBINLINE;
	    } /* if */
	    return 0;

	  case TCP_GETOOBDATA:
	    {     
		char peek;

		checkLen(len, sizeof(char));

		peek = *(char*)buf;
		if ((ss->t_oobflags & TCPOOB_HADDATA) ||
		    !(ss->t_oobflags & TCPOOB_HAVEDATA))
		{
		    return 0;
		} /* if */
		*(char*)buf = ss->t_iobc;
		if (!peek) {
		    ss->t_oobflags ^= TCPOOB_HAVEDATA | TCPOOB_HADDATA;
		} /* if */
		return 1;
	    }

	  case TCP_OOBPUSH:
	    {
		Msg *m;

		checkLen(len, sizeof(Msg *));

		m = (Msg *)buf;
		sbappend(ss->snd, m);
		ss->snd_up = ss->snd_una + sblength(ss->snd);
		ss->t_force = 1;
		tcp_output(so);
		ss->t_force = 0;
		return 0;
	    }

	  default:
	    return xControlSessn(xGetSessnDown(so, 0), opcode, buf, len);
	} /* switch */
    } /* if */
} /* tcpControlSessn */

static Part *
tcpGetParticipants(so)
Sessn so;
{
    Part   *p;
    int    numParts;
    SState *ss;
    long   localPort, remotePort;

    p = xGetParticipants(xGetSessnDown(so, 0));
    if (!p)
	return NULL;
    numParts = partLength(p);
    if (numParts > 0 && numParts <= 2) {
        ss = sotoss(so);
	if (numParts == 2) {
	    localPort = ss->t_template.ti_sport;
	    partPush(p[1], &localPort, sizeof(long));
	}
	remotePort = ss->t_template.ti_dport;
	partPush(p[0], &remotePort, sizeof(long));
	return p;
    }
    else {
	xTraceS1(so, TR_SOFT_ERRORS,
	       "bad number of participants (%d) returned from xGetParticipants",
		 partLength(p));
	return NULL;
    }
}

static int
tcpControlProtl(self, opcode, buf, len)
     Protl self;
     int opcode, len;
     char *buf;
{
    long port;

    switch (opcode) {

      case TCP_DUMPSTATEINFO:
	{
	    PState	*ps = (PState *)self->state;

	    tcp_dumpstats(ps);
	    return 0;
	}

      case TCP_GETFREEPORTNUM:
	checkLen(len, sizeof(long));
	port = *(long *)buf;
	if (tcpGetFreePort(((PState *)(self->state))->portstate, &port)) {
	    return -1;
	} /* if */
	*(long *)buf = port;
	return 0;

      case TCP_RELEASEPORTNUM:
	checkLen(len, sizeof(long));
	port = *(long *)buf;
	tcpReleasePort(((PState *)(self->state))->portstate, port);
	return 0;

      default:
	return xControlProtl(xGetProtlDown(self,0), opcode, buf, len);
    }
} /* tcpControlProtl */

static void
tcpSessnInit(s)
Sessn s;
{
    xAssert(xIsSessn(s));
    s->push            = tcpPush;
    s->close           = tcpClose;
    s->controlsessn    = tcpControlSessn;
    s->getparticipants = tcpGetParticipants;
    s->pop             = tcpPop;
} /* tcpSessnInit */

/*
 * This is invoked in response to a user-requested close (tcpClose)
 * once it is guaranteed that the connection tear-down has proceeded
 * far enough to guarantee that there won't be any new data on the
 * connection anymore (this may be satisified in response to an error).
 */
void
soisdisconnected(so)
     Sessn so;
{
    SState *ss = sotoss(so);

    xTraceS1(so, TR_MAJOR_EVENTS, "soisdisconnected(so=%lx)", (u_long)so);

    xAssert(ss->t_flags & TF_USRCLOSED);

    /* wake up the thread that initiated the close: */
    tcpSemSignal(&ss->waiting);
} /* soisdisconnected */


/*
 * This is invoked when we receive an unsolicited FIN.
 */
void
socantrcvmore(so)
    Sessn so;
{
    xTraceS1(so, TR_MAJOR_EVENTS, "socantrcvmore on %lx", (u_long)so);

    sotoss(so)->t_flags |= TF_NETCLOSED;
    if (!(sotoss(so)->t_flags & TF_USRCLOSED)) {
	/*
	 * Let user know that peer requested a close unless user has
	 * requested close already.
	 */
	xCloseDone(so);
    } /* if */
} /* socantrcvmore */


void
soisconnected(so)
     Sessn so;
{
    SState *ss = sotoss(so);
    TcpSem *sem = &ss->waiting;

    xTraceS1(so, TR_MAJOR_EVENTS, "soisconnected on %lx", (u_long)so);
    if (sem->waitCount) {
	xTraceS1(so, TR_EVENTS, "waking up opener on %lx", (u_long)so);
	tcpSemSignal(sem);
    } else {
	/*
	 * Give up temporary reference created in tcpDemux().  It is
	 * OK to do this via an xClose() because we came through
	 * tcpPop, so there is a reference outstanding and the
	 * close here won't make the reference count drop to zero.
	 * The user can then do an xDuplicate() in the xOpenDone()
	 * at his or her discretion.
	 */
	xClose(so);
	ss->t_flags &= ~TF_EMBRYONIC;
	xOpenDone(xGetUp(so), xMyProtl(so), so);
    } /* if */
} /* soisconnected */


/* 
 * sonewconn is called by the input routine to establish a passive open
 */
Sessn
sonewconn(self, so, hlpType, src, dst, sport, dport)
     Protl self, so, hlpType;
     IPhost *src, *dst;
     int sport, dport;
{
    Sessn new;

    xAssert(xIsProtl(so));
    xTraceP1(self, TR_MAJOR_EVENTS, "sonewconn(so=%lx)", (u_long)so);
    new = tcp_establishopen(self, so, hlpType, src, dst, sport, dport);
    if ( new ) {
	tcpDuplicatePort(((PState *)self->state)->portstate, dport);
    }
    return new;
} /* sonewconn */


/* 
 * sohasoutofband is called by the input routine to signal the presence
 * of urgent (out-of-band) data
 */
void
sohasoutofband(so, oobmark)
     Sessn so;
     u_int oobmark;
{
    void *buf[2];

    buf[0] = so;
    buf[1] = (void*) oobmark;
    xControlProtl(xGetUp(so), TCP_OOBMODE, (char*) buf, sizeof(buf));
} /* sohasoutofband */


void
tcp_dumpstats( ps )
     PState *ps;
{
#ifdef TCP_STATISTICS
    printf("tcps_badsum %d\n", ps->tcps_badsum);
    printf("tcps_badoff %d\n", ps->tcps_badoff);
    printf("tcps_hdrops %d\n", ps->tcps_hdrops);
    printf("tcps_badsegs %d\n", ps->tcps_badsegs);
    printf("tcps_unack %d\n", ps->tcps_unack);
    printf("connections initiated %d\n", ps->tcps_connattempt);
    printf("connections accepted %d\n", ps->tcps_accepts);
    printf("connections established %d\n", ps->tcps_connects);
    printf("connections dropped %d\n", ps->tcps_drops);
    printf("embryonic connections dropped %d\n", ps->tcps_conndrops);
    printf("conn. closed (includes drops) %d\n", ps->tcps_closed);
    printf("segs where we tried to get rtt %d\n", ps->tcps_segstimed);
    printf("times we succeeded %d\n", ps->tcps_rttupdated);
    printf("delayed acks sent %d\n", ps->tcps_delack);
    printf("conn. dropped in rxmt timeout %d\n", ps->tcps_timeoutdrop);
    printf("retransmit timeouts %d\n", ps->tcps_rexmttimeo);
    printf("persist timeouts %d\n", ps->tcps_persisttimeo);
    printf("keepalive timeouts %d\n", ps->tcps_keeptimeo);
    printf("keepalive probes sent %d\n", ps->tcps_keepprobe);
    printf("connections dropped in keepalive %d\n", ps->tcps_keepdrops);
    printf("total packets sent %d\n", ps->tcps_sndtotal);
    printf("data packets sent %d\n", ps->tcps_sndpack);
    printf("data bytes sent %d\n", ps->tcps_sndbyte);
    printf("data packets retransmitted %d\n", ps->tcps_sndrexmitpack);
    printf("data bytes retransmitted %d\n", ps->tcps_sndrexmitbyte);
    printf("ack-only packets sent %d\n", ps->tcps_sndacks);
    printf("window probes sent %d\n", ps->tcps_sndprobe);
    printf("packets sent with URG only %d\n", ps->tcps_sndurg);
    printf("window update-only packets sent %d\n", ps->tcps_sndwinup);
    printf("control (SYN|FIN|RST) packets sent %d\n", ps->tcps_sndctrl);
    printf("total packets received %d\n", ps->tcps_rcvtotal);
    printf("packets received in sequence %d\n", ps->tcps_rcvpack);
    printf("bytes received in sequence %d\n", ps->tcps_rcvbyte);
    printf("packets received with ccksum errs %d\n", ps->tcps_rcvbadsum);
    printf("packets received with bad offset %d\n", ps->tcps_rcvbadoff);
    printf("packets received too short %d\n", ps->tcps_rcvshort);
    printf("duplicate-only packets received %d\n", ps->tcps_rcvduppack);
    printf("duplicate-only bytes received %d\n", ps->tcps_rcvdupbyte);
    printf("packets with some duplicate data %d\n", ps->tcps_rcvpartduppack);
    printf("dup. bytes in part-dup. packets %d\n", ps->tcps_rcvpartdupbyte);
    printf("out-of-order packets received %d\n", ps->tcps_rcvoopack);
    printf("out-of-order bytes received %d\n", ps->tcps_rcvoobyte);
    printf("packets with data after window %d\n", ps->tcps_rcvpackafterwin);
    printf("bytes rcvd after window %d\n", ps->tcps_rcvbyteafterwin);
    printf("packets rcvd after \"close\" %d\n", ps->tcps_rcvafterclose);
    printf("rcvd window probe packets %d\n", ps->tcps_rcvwinprobe);
    printf("rcvd duplicate acks %d\n", ps->tcps_rcvdupack);
    printf("rcvd acks for unsent data %d\n", ps->tcps_rcvacktoomuch);
    printf("rcvd ack packets %d\n", ps->tcps_rcvackpack);
    printf("bytes acked by rcvd acks %d\n", ps->tcps_rcvackbyte);
    printf("rcvd window update packets %d\n", ps->tcps_rcvwinupd);

    ps->tcps_badsum = 0;
    ps->tcps_badoff = 0;
    ps->tcps_hdrops = 0;
    ps->tcps_badsegs = 0;
    ps->tcps_unack = 0;
    ps->tcps_connattempt = 0;
    ps->tcps_accepts = 0;
    ps->tcps_connects = 0;
    ps->tcps_drops = 0;
    ps->tcps_conndrops = 0;
    ps->tcps_closed = 0;
    ps->tcps_segstimed = 0;
    ps->tcps_rttupdated = 0;
    ps->tcps_delack = 0;
    ps->tcps_timeoutdrop = 0;
    ps->tcps_rexmttimeo = 0;
    ps->tcps_persisttimeo = 0;
    ps->tcps_keeptimeo = 0;
    ps->tcps_keepprobe = 0;
    ps->tcps_keepdrops = 0;
    ps->tcps_sndtotal = 0;
    ps->tcps_sndpack = 0;
    ps->tcps_sndbyte = 0;
    ps->tcps_sndrexmitpack = 0;
    ps->tcps_sndrexmitbyte = 0;
    ps->tcps_sndacks = 0;
    ps->tcps_sndprobe = 0;
    ps->tcps_sndurg = 0;
    ps->tcps_sndwinup = 0;
    ps->tcps_sndctrl = 0;
    ps->tcps_rcvtotal = 0;
    ps->tcps_rcvpack = 0;
    ps->tcps_rcvbyte = 0;
    ps->tcps_rcvbadsum = 0;
    ps->tcps_rcvbadoff = 0;
    ps->tcps_rcvshort = 0;
    ps->tcps_rcvduppack = 0;
    ps->tcps_rcvdupbyte = 0;
    ps->tcps_rcvpartduppack = 0;
    ps->tcps_rcvpartdupbyte = 0;
    ps->tcps_rcvoopack = 0;
    ps->tcps_rcvoobyte = 0;
    ps->tcps_rcvpackafterwin = 0;
    ps->tcps_rcvbyteafterwin = 0;
    ps->tcps_rcvafterclose = 0;
    ps->tcps_rcvwinprobe = 0;
    ps->tcps_rcvdupack = 0;
    ps->tcps_rcvacktoomuch = 0;
    ps->tcps_rcvackpack = 0;
    ps->tcps_rcvackbyte = 0;
    ps->tcps_rcvwinupd = 0;
#endif /* TCP_STATISTICS */
} /* tcp_dumpstats */

			/*** end of tcp_x.c ***/
