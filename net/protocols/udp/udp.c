/*
 * $RCSfile: udp.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: udp.c,v $
 * Revision 1.2  1996/01/29 22:38:16  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:19:18  slm
 * Initial revision
 *
 * Revision 1.87.1.5  1994/12/06  03:30:26  davidm
 * Fixed bug that prevented checksumming from working.
 *
 * Revision 1.87.1.4  1994/12/02  18:30:06  hkaram
 * Changed to new mapResolve interface
 *
 * Revision 1.87.1.3  1994/11/22  21:04:15  hkaram
 * Added mapResolve casts
 *
 * Revision 1.87.1.2  1994/10/27  01:58:07  hkaram
 * Merged changes from Davids version.
 *
 * Revision 1.87  1994/09/20  18:40:18  gkim
 * added port range support (ANY_LOW_PORT, ANY_HIGH_PORT)
 *
 * Revision 1.86  1994/04/21  04:09:08  ho
 * Zero activemap keys before using them; these are structures.
 * Passive maps keys are not structures, don't need zeroing.
 *
 * Revision 1.85  1994/01/08  21:26:18  menze
 *   [ 1994/01/05          menze ]
 *   PROTNUM changed to PORTNUM
 *
 * Revision 1.84  1993/12/13  23:32:10  menze
 * Modifications from UMass:
 *
 *   [ 93/11/04          nahum ]
 *   Some UDP cleanup to appease GCC -wall
 *
 * Revision 1.83  1993/12/11  00:25:16  menze
 * fixed #endif comments
 *
 * Revision 1.82  1993/12/07  17:38:02  menze
 * Improved validity checks on incoming participants
 *
 * Revision 1.81  1993/12/07  00:59:00  menze
 * Now uses IP_GETPSEUDOHDR to determine protocol number relative to IP.
 */

#include "xkernel.h"
#include "ip.h"
#include "udp.h"
#include "udp_internal.h"
#include "gc.h"

int traceudpp;

/* #define UDP_USE_GC */

/*
 * Check port range
 */
#define portCheck(_port, name, retval) {                     \
    if ((_port) < 0 || (_port) > MAX_PORT) {                 \
	xTrace2(udpp, TR_SOFT_ERRORS,                        \
		"%s port %d out of range", (name), (_port)); \
	return (retval);                                     \
    }                                                        \
}

#ifdef __STDC__

static void     callUnlockPort(void *, Enable *);
static void     dispPseudoHdr(IPpseudoHdr *);
static int      getPorts(PSTATE *, Part *, UDPport *, UDPport *, char *);
static void     getproc_sessn(Sessn);
static void     getproc_protl(Protl);
/* static XkReturn udpCloseProtl(Protl); */
static XkReturn udpCloseSessn(Sessn);
static int      udpControlProtl(Protl, int, char *, int) ;
static int      udpControlSessn(Sessn, int, char *, int) ;
static Part     *udpGetParticipants(Sessn);
static Sessn    udpCreateSessn(Protl, Protl, Protl, ActiveId *);
static XkReturn udpDemux(Protl, Sessn, Msg *);
static long     udpHdrLoad(void *, char *, long, Msg *);
static void     udpHdrStore(void *, char *, long, Msg *, Sessn);
static Sessn    udpOpen(Protl, Protl, Protl, Part *);
static XkReturn udpOpenDisable(Protl, Protl, Protl, Part *);
static XkReturn udpOpenEnable(Protl, Protl, Protl, Part *);
static XkReturn udpOpenDisableAll(Protl, Protl);
static XkReturn udpPop(Sessn, Sessn, Msg *, void *);
static XkHandle udpPush(Sessn, Msg *);
#ifdef UDP_USE_GC
static void     udpDestroySessn(Sessn);
#endif

#else

static void     callUnlockPort();
static void     dispPseudoHdr();
static int      getPorts();
static void     getproc_sessn();
static void     getproc_protl();
/* static XkReturn udpCloseProtl(); */
static XkReturn udpCloseSessn();
static int      udpControlProtl() ;
static int      udpControlSessn() ;
static Part     *udpGetParticipants();
static Sessn    udpCreateSessn();
static XkReturn udpDemux();
static long     udpHdrLoad();
static void     udpHdrStore();
static Sessn    udpOpen();
static XkReturn udpOpenDisable();
static XkReturn udpOpenEnable();
static XkReturn udpOpenDisableAll();
static XkReturn udpPop();
static XkHandle udpPush();
#ifdef UDP_USE_GC
static void     udpDestroySessn();
#endif

#endif /* __STDC__ */

#define SESSN_COLLECT_INTERVAL 30 * 1000 * 1000    /* 30 seconds */
#define ACTIVE_MAP_SIZE        101
#define PASSIVE_MAP_SIZE       23

static void
dispPseudoHdr(h)
IPpseudoHdr *h;
{
    xTrace2(udpp, TR_ALWAYS, "   IP pseudo header: src: %s  dst: %s",
	    ipHostStr(&h->src), ipHostStr(&h->dst));
    xTrace3(udpp, TR_ALWAYS, "      z:  %d  p: %d len: %d",
	    h->zero, h->prot, ntohs(h->len));
}

/*
 * udpHdrStore -- write header to potentially unaligned msg buffer.
 * Note:  *hdr will be modified
 */
static
#if defined(__GNUC__)
inline
#endif
void udpHdrStore(hdr, dst, len, m, s)
VOID  *hdr;
char  *dst;
long  int len;
Msg   *m;
Sessn s;
{
    SSTATE *sstate;

    xAssert(len == sizeof(HDR));

    ((HDR *)hdr)->ulen = htons(((HDR *)hdr)->ulen);
    ((HDR *)hdr)->sport = htons(((HDR *)hdr)->sport);
    ((HDR *)hdr)->dport = htons(((HDR *)hdr)->dport);
    ((HDR *)hdr)->sum = 0;
    bcopy((char *)hdr, dst, sizeof(HDR));
    sstate = (SSTATE *)s->state;
    if (sstate->useCkSum) {
	u_short sum = 0;

	xTrace0(udpp, TR_FUNCTIONAL_TRACE, "Using UDP checksum");
	sstate->pHdr.len = ((HDR *)hdr)->ulen;	/* already in net byte order */
	xIfTrace(udpp, TR_FUNCTIONAL_TRACE)
	    dispPseudoHdr(&sstate->pHdr);
	sum = inCkSum(m, (u_short *)&sstate->pHdr, sizeof(IPpseudoHdr));
	bcopy((char *)&sum, (char *)&((HDR *)dst)->sum, sizeof(u_short));
	xAssert(!inCkSum(m, (u_short *)&sstate->pHdr, sizeof(IPpseudoHdr)));
    }
}

/*
 * udpHdrLoad -- load header from potentially unaligned msg buffer.
 * Result of checksum calculation will be in hdr->sum.
 */
static
#if defined(__GNUC__)
inline
#endif
long udpHdrLoad(hdr, src, len, m)
VOID *hdr;
char *src;
long int len;
Msg  *m;
{
    xAssert(len == sizeof(HDR));

    bcopy(src, (char *)hdr, sizeof(HDR));

    ((HDR *)hdr)->ulen = ntohs(((HDR *)hdr)->ulen);
    ((HDR *)hdr)->sport = ntohs(((HDR *)hdr)->sport);
    ((HDR *)hdr)->dport = ntohs(((HDR *)hdr)->dport);
    return sizeof(HDR);
}

/* udp_init */
void
udp_init(self)
Protl self;
{
    Part   part;
    PSTATE *pstate;
    Protl  llp;

    xTrace0(udpp, TR_GROSS_EVENTS, "UDP init");
    xAssert(xIsProtl(self));

    getproc_protl(self);
    pstate = X_NEW(PSTATE);
    bzero((char *)pstate, sizeof(PSTATE));
    self->state = (VOID *)pstate;
    pstate->activemap = mapCreate(ACTIVE_MAP_SIZE, sizeof(ActiveId));
    pstate->passivemap = mapCreate(PASSIVE_MAP_SIZE, sizeof(PassiveId));
    if (!xIsProtl(llp = xGetProtlDown(self, 0)))
	Kabort("UDP could not get lower protocol");
    /* Notify any protocols between UDP & IP to turn on length-fixup for the
       IP pseudoheader. */
    xControlProtl(llp,IP_PSEUDOHDR,(char *)0,0);
    partInit(&part, 1);
    partPush(part, ANY_HOST, 0);
    if (xOpenEnable(self, self, llp, &part) == XK_FAILURE) {
	xTrace0(udpp, TR_ALWAYS,
		"udp_init: can't openenable transport protocol");
	xFree((char *) pstate);
	return;
    }
#ifdef UDP_USE_GC
    initSessionCollector(pstate->activemap, SESSN_COLLECT_INTERVAL,
			 udpDestroySessn, "udp");
#endif
    udpPortMapInit(&pstate->portstate);
    xTrace0(udpp, TR_GROSS_EVENTS, "UDP init done");
}

/*
 * getPorts -- extract ports from the participant, checking for validity.
 * If lPort is 0, no attempt to read a local port is made.
 * Returns 0 if the port extraction succeeded, -1 if there were problems.
 */
static int
getPorts(pstate, p, rPort, lPort, str)
PSTATE  *pstate;
Part    *p;
UDPport *lPort, *rPort;
char    *str;
{
    long *port = NULL;
    long freePort;

    xAssert(rPort);
    if (!p || partLength(p) < 1 || partStackTopByteLen(p[0]) < sizeof(long) ||
	partLength(p) > 1 && (partStackTopByteLen(p[1]) < sizeof(long))) {
	xTrace1(udpp, TR_SOFT_ERRORS, "%s -- bad participants", str);
	return -1;
    }
    if ((port = (long *)partPop(p[0])) == 0) {
	xTrace1(udpp, TR_SOFT_ERRORS, "%s -- no remote port", str);
	return -1;
    }
    if (*port != ANY_PORT)
	portCheck(*port, str, -1);
    *rPort = *port;
    if (lPort) {
 	if ((partLength(p) < 2)  ||
 	    (((port = (long *)partPop(p[1])) != 0) && (*port == ANY_PORT))) {
	    /* no port specified -- find a free one */
	    if (udpGetFreePort(pstate->portstate, &freePort)) {
		sprintf(errBuf, "%s -- no free ports!", str);
		xError(errBuf);
		return -1;
	    }
	    *lPort = freePort;
	}
	else if ((port != 0) &&
		(*port == ANY_LOW_PORT || *port == ANY_HIGH_PORT)) {
	    /* a range of ports was specified */
	    long lowbound = (*port == ANY_LOW_PORT) ?
				LOW_PORT_FLOOR : HIGH_PORT_FLOOR;
	    long highbound = (*port == ANY_LOW_PORT) ?
	    			LOW_PORT_CEILING : HIGH_PORT_CEILING;

	    if (udpGetFreePortRange(pstate->portstate,
				lowbound, highbound, &freePort)) {
		sprintf(errBuf, "%s -- no free ports!", str);
		xError(errBuf);
		return -1;
	    }
	    *lPort = freePort;
	}
	else {
	    /* a specific local port was requested */
	    if (port == 0) {
		xTrace1(udpp, TR_SOFT_ERRORS,
			"%s -- local participant, but no local port", str);
		return -1;
	    }
	    portCheck(*port, str, -1);
	    *lPort = *port;
	    udpDuplicatePort(pstate->portstate, *lPort);
	}
    }
    return 0;
}

/* udpOpen */
static Sessn
udpOpen(self, hlp, hlpType, p)
Protl self, hlp, hlpType;
Part  *p;
{
    Sessn    udp_s;
    Sessn    lls;
    ActiveId key;
    PSTATE   *pstate = (PSTATE *)self->state;

    xTrace0(udpp, TR_MAJOR_EVENTS, "UDP open");
    bzero((char *)&key, sizeof(key));
    if (getPorts(pstate, p, &key.remoteport, &key.localport, "udpOpen"))
	return ERR_SESSN;
    xTrace2(udpp, TR_MAJOR_EVENTS, "UDP open: from port %d to port %d",
	    key.localport, key.remoteport);
    udp_s = ERR_SESSN;
    lls = xOpen(self, self, xGetProtlDown(self, 0), p);
    if (lls != ERR_SESSN) {
	key.lls = lls;
	if (mapResolve(pstate->activemap, &key, (void **)&udp_s) == XK_FAILURE){
	    xTrace0(udpp, TR_MAJOR_EVENTS, "udpOpen creates new session");
	    udp_s = udpCreateSessn(self, hlp, hlpType, &key);
	    if (udp_s != ERR_SESSN) {
		/* a successful open! */
		xTrace1(udpp, TR_MAJOR_EVENTS, "UDP open returns %x", udp_s);
		return udp_s;
	    }
	}
	else {
	    /*
	     * We don't allow multiple opens of the same UDP session.  If
	     * the refcount is zero, the session is just being idle
	     * awaiting garbage collection
	     */
	    if (udp_s->rcnt > 0) {
		xTrace0(udpp, TR_MAJOR_EVENTS,
			"udpOpen ERROR -- found existing session!");
		udp_s = ERR_SESSN;
	    }
	    else
		udp_s->idle = FALSE;
	}
	xClose(lls);
    }
    return udp_s;
}

static Sessn
udpCreateSessn(self, hlp, hlpType, key)
Protl self, hlp, hlpType;
ActiveId *key;
{
    Sessn  s;
    SSTATE *sstate;
    PSTATE *pstate;
    HDR    *udph;

    pstate = (PSTATE *)self->state;
    s = xCreateSessn(getproc_sessn, hlp, hlpType, self, 1, &key->lls);
    s->binding = mapBind(pstate->activemap, key, s);
    sstate = (SSTATE *)xMalloc(sizeof(SSTATE));
    if (xControlSessn(key->lls, IP_GETPSEUDOHDR, (char *)&sstate->pHdr,
		      sizeof(IPpseudoHdr)) == -1) {
	xTrace0(udpp, TR_MAJOR_EVENTS,
		"UDP create sessn could not get pseudo-hdr from lls");
    }
    sstate->useCkSum = USE_CHECKSUM_DEF;
    s->state = (char *)sstate;
    udph = &(sstate->hdr);
    udph->sport = key->localport;
    udph->dport = key->remoteport;
    udph->ulen = 0;
    udph->sum = 0;
    /* Notify any protocols between UDP & IP to turn on length-fixup for the
       IP pseudoheader. */
    /* xControlSessn(xGetSessnDown(s,0),IP_PSEUDOHDR,(char *)0,0); redundant
       for now, since we're doing this at the protocol level instead of session
       level for UDP.  Might change back to sessions if UDP were to use
       opendone. */

    return s;
}

/* udpControlSessn */
static int
udpControlSessn(s, opcode, buf, len)
Sessn s;
int opcode;
char *buf;
int len;
{
    SSTATE *sstate;
    PSTATE *pstate;
    HDR    *hdr;

    xAssert(xIsSessn(s));

    sstate = (SSTATE *) s->state;
    pstate = (PSTATE *) s->myprotl->state;

    hdr = &(sstate->hdr);
    switch (opcode) {
        case UDP_DISABLE_CHECKSUM:
            sstate->useCkSum = 0;
            return 0;

        case UDP_ENABLE_CHECKSUM:
            sstate->useCkSum = 1;
            return 0;

        case GETMYPROTO:
            checkLen(len, sizeof(long));
            *(long *)buf = sstate->hdr.sport;
            return sizeof(long);

        case GETPEERPROTO:
            checkLen(len, sizeof(long));
            *(long *)buf = sstate->hdr.dport;
            return sizeof(long);

        case GETMAXPACKET:
        case GETOPTPACKET:
	    checkLen(len, sizeof(int));
	    if (xControlSessn(xGetSessnDown(s, 0), opcode, buf, len) <
		    sizeof(int))
	        return -1;
	    *(int *)buf -= sizeof(HDR);
	    return sizeof(int);

        default:
            return xControlSessn(xGetSessnDown(s, 0), opcode, buf, len);;
    }
}

static Part *
udpGetParticipants(s)
Sessn s;
{
    Part   *p;
    int	   numParts;
    SSTATE *sstate = (SSTATE *)s->state;
    long   localPort, remotePort;

    p = xGetParticipants(xGetSessnDown(s, 0));
    if (!p)
	return NULL;
    numParts = partLength(p);
    if (numParts > 0 && numParts <= 2) {
	if (numParts == 2) {
	    localPort = sstate->hdr.sport;
	    partPush(p[1], &localPort, sizeof(long));
	}
	remotePort = sstate->hdr.dport;
	partPush(p[0], &remotePort, sizeof(long));
	return p;
    }
    else {
	xTrace1(udpp, TR_SOFT_ERRORS,
	"UDP -- Bad number of participants (%d) returned from xGetParticipants",
		partLength(p));
	return NULL;
    }
}

/* udpControlProtl */
static int
udpControlProtl(self, opcode, buf, len)
Protl self;
int opcode;
char *buf;
int len;
{
    long port;

    xAssert(xIsProtl(self));

    switch (opcode) {
        case GETMAXPACKET:
        case GETOPTPACKET:
	    checkLen(len, sizeof(int));
	    if (xControlProtl(xGetProtlDown(self, 0), opcode, buf, len) <
		    sizeof(int))
	        return -1;
	    *(int *)buf -= sizeof(HDR);
	    return sizeof(int);

        case UDP_GETFREEPORTNUM:
	    checkLen(len, sizeof(long));
	    port = *(long *)buf;
	    if (udpGetFreePort(((PSTATE *)(self->state))->portstate, &port))
	        return -1;
	    *(long *)buf = port;
	    return 0;

        case UDP_RELEASEPORTNUM:
	    checkLen(len, sizeof(long));
	    port = *(long *)buf;
	    udpReleasePort(((PSTATE *)(self->state))->portstate, port);
	    return 0;

        default:
	    return xControlProtl(xGetProtlDown(self, 0), opcode, buf, len);
    }
}

/* udpOpenEnable */
static XkReturn
udpOpenEnable(self, hlp, hlpType, p)
Protl self, hlp, hlpType;
Part *p;
{
    PSTATE    *pstate = (PSTATE *)self->state;
    Enable    *e;
    PassiveId key;

    xTrace0(udpp, TR_MAJOR_EVENTS, "UDP open enable");
    if (getPorts(pstate, p, &key, 0, "udpOpenEnable"))
	return XK_FAILURE;
    xTrace1(udpp, TR_MAJOR_EVENTS, "Port number %d", key);
    if (mapResolve(pstate->passivemap, &key, (void **)&e) != XK_FAILURE) {
	if (e->hlp == hlp) {
	    e->rcnt++;
	    return XK_SUCCESS;
	}
	return XK_FAILURE;
    }
    udpDuplicatePort(pstate->portstate, key);
    e = (Enable *)xMalloc(sizeof(Enable));
    e->hlp = hlp;
    e->hlpType = hlpType;
    e->rcnt = 1;
    e->binding = mapBind(pstate->passivemap, &key, e);
    if (e->binding == ERR_BIND) {
      xFree((char *)e);
      return XK_FAILURE;
    }
    return XK_SUCCESS;
}

#ifdef UDP_USE_GC

/* udpCloseSessn */
static XkReturn
udpCloseSessn(s)
Sessn s;
{
    SSTATE *sstate;

    sstate = (SSTATE *)s->state;

    xAssert(xIsSessn(s));
    xTrace1(udpp, TR_MAJOR_EVENTS, "UDP close of session %x", s);
    xAssert(s->rcnt == 0);
    udpReleasePort(((PSTATE *)(xMyProtl(s)->state))->portstate,
		   sstate->hdr.sport);
    return XK_SUCCESS;
}

/*
 * This function is udpDestroySessn if we are using garbage
 * collection, udpCloseSessn if we are not.
 */
static void
udpDestroySessn(s)

#else

static XkReturn
udpCloseSessn(s)

#endif
Sessn s;
{
    PSTATE *pstate;
    SSTATE *sstate;

    xAssert(xIsSessn(s));
    xTrace1(udpp, TR_MAJOR_EVENTS, "UDP destroy session %x", s);
    xAssert(s->rcnt == 0);
    pstate = (PSTATE *)s->myprotl->state;
    sstate = (SSTATE *)s->state;
    mapRemoveBinding(pstate->activemap, s->binding);
    xClose(xGetSessnDown(s, 0));
#ifndef UDP_USE_GC
    udpReleasePort(pstate->portstate, sstate->hdr.sport);
#endif
    xDestroySessn(s);
#ifndef UDP_USE_GC
    return XK_SUCCESS;
#endif
}

/* udpPush */
/*ARGSUSED*/
static XkHandle
udpPush(s, msg)
Sessn s;
Msg *msg;
{
    SSTATE *sstate;
    HDR    hdr;
    VOID   *buf;

    xTrace0(udpp, TR_EVENTS, "in udp push");
    xAssert(xIsSessn(s));
    sstate = (SSTATE *) s->state;
    hdr = sstate->hdr;
    hdr.ulen = msgLength(msg) + HLEN;
    xTrace2(udpp, TR_EVENTS, "sending msg len %d from port %d",
	    msgLength(msg), hdr.sport);
    xTrace5(udpp, TR_EVENTS, "  to port %d @ %d.%d.%d.%d", hdr.dport,
	    sstate->pHdr.dst.a, sstate->pHdr.dst.b, sstate->pHdr.dst.c,
	    sstate->pHdr.dst.d);

    buf = msgPush(msg, HLEN);
    xAssert(buf);
    udpHdrStore(&hdr, buf, HLEN, msg, s);
    return xPush(xGetSessnDown(s, 0), msg);
}

/* udpDemux */
static XkReturn
udpDemux(self, lls, dg)
Protl self;
Sessn lls;
Msg *dg;
{
    HDR       h;
    Sessn     s;
    ActiveId  activeid;
    PassiveId passiveid;
    PSTATE    *pstate;
    Enable    *e;
    VOID      *buf;
    long      checksum = 0;

    pstate = (PSTATE *)self->state;
    xTrace0(udpp, TR_EVENTS, "UDP Demux");

    buf = msgPeek(dg, HLEN);
    if (!buf PREDICT_FALSE) {
	xTraceP0(self, TR_MAJOR_EVENTS,
		 "udpDemux: msgPop of header failed -- dropping");
	return XK_FAILURE;
    } /* if */

    /* 0 in the checksum field indicates checksum disabled */
    if (((HDR *)buf)->sum) {
	IPpseudoHdr *pHdr = (IPpseudoHdr *)msgGetAttr(dg, 0);

	xTraceP1(self, TR_FUNCTIONAL_TRACE,
		 "UDP header checksum was used (%x)", ((HDR*)buf)->sum);
	xAssert(pHdr);
	xIfTrace(udpp, TR_FUNCTIONAL_TRACE) {
	    dispPseudoHdr(pHdr);
	} /* if */
	checksum = inCkSum(dg, (u_short *)pHdr, sizeof(*pHdr));
    }
    else
	xTraceP0(self, TR_FUNCTIONAL_TRACE, "No UDP header checksum was used");

    /* now that we have checksum, pop header off: */
    msgDiscard(dg, HLEN);

    udpHdrLoad(&h, buf, HLEN, dg);

    xTrace1(udpp, TR_FUNCTIONAL_TRACE, "Sending host: %s",
	    ipHostStr(&((IPpseudoHdr *)msgGetAttr(dg, 0))->src));
    xTrace1(udpp, TR_FUNCTIONAL_TRACE, "Destination host: %s",
	    ipHostStr(&((IPpseudoHdr *)msgGetAttr(dg, 0))->dst));
    xTrace2(udpp, TR_EVENTS, "sport = %d, dport = %d", h.sport, h.dport);

    if (checksum) {
	xTraceP1(self, TR_MAJOR_EVENTS,
		 "udpDemux: bad hdr checksum (%x)---dropping msg!",
		 checksum);
	return XK_SUCCESS;
    }
    if ((h.ulen - HLEN) < msgLength(dg))
	msgTruncate(dg, (int) h.ulen);
    xTrace2(udpp, TR_FUNCTIONAL_TRACE, " h->ulen = %d, msg_len = %d", h.ulen,
	    msgLength(dg));
    bzero((char *)&activeid, sizeof(activeid));
    activeid.localport = h.dport;
    activeid.remoteport = h.sport;
    activeid.lls = lls;
    if (mapResolve(pstate->activemap, &activeid, (void **)&s) == XK_FAILURE) {
	passiveid = h.dport;
	if (mapResolve(pstate->passivemap, &passiveid, (void **)&e) ==
	    XK_FAILURE) {
	    xTrace0(udpp, TR_MAJOR_EVENTS, "udpDemux dropping the message");
	    return XK_SUCCESS;
	}
	xTrace1(udpp, TR_MAJOR_EVENTS, "Found an open enable for prot %d",
		e->hlp);
	s = udpCreateSessn(self, e->hlp, e->hlpType, &activeid);
	if (s == ERR_SESSN) {
	    xTrace0(udpp, TR_ERRORS, "udpDemux could not create session");
	    return XK_SUCCESS;
	}
	xDuplicate(lls);
	udpDuplicatePort(pstate->portstate, activeid.localport);
#ifndef UDP_USE_GC
	xOpenDone(e->hlp, self, s);
#endif /* ! UDP_USE_GC */
    }
    else
	xTrace1(udpp, TR_EVENTS, "Popping to existing session %x", s);
#ifdef UDP_USE_GC
    /*
     * Since UDP sessions don't go away when the external ref count is
     * zero, we need to check for openEnables when rcnt == 0.
     */
    if (s->rcnt == 0) {
	passiveid = h.dport;
	if (mapResolve(pstate->passivemap, &passiveid, (void **)&e) ==
	    XK_FAILURE) {
	    xTrace0(udpp, TR_MAJOR_EVENTS, "udpDemux dropping the message");
	    return XK_SUCCESS;
	}
	xOpenDone(e->hlp, self, s);
    }
#endif /* UDP_USE_GC */
    xAssert(xIsSessn(s));
    return xPop(s, lls, dg, 0);
}

/* udpPop */
/*ARGSUSED*/
static XkReturn
udpPop(s, ds, dg, arg)
Sessn s;
Sessn ds;
Msg *dg;
VOID *arg;
{
    xTrace1(udpp, TR_EVENTS, "UDP pop, length = %d", msgLength(dg));
    xAssert(xIsSessn(s));
    return xDemux(xGetUp(s), s, dg);
}

static XkReturn
udpOpenDisable(self, hlp, hlpType, p)
Protl self, hlp, hlpType;
Part  *p;
{
    PassiveId key;
    PSTATE    *pstate = (PSTATE *)self->state;
    Enable    *e;

    xTrace0(udpp, TR_MAJOR_EVENTS, "UDP open disable");
    if (getPorts(pstate, p, &key, 0, "udpOpenDisable"))
	return XK_FAILURE;
    xTrace1(udpp, TR_MAJOR_EVENTS, "port %d", key);
    if (mapResolve(pstate->passivemap, &key, (void **)&e) == XK_FAILURE ||
	e->hlp == hlp && e->hlpType == hlpType) {
	if (--(e->rcnt) == 0) {
	    mapRemoveBinding(pstate->passivemap, e->binding);
	    xFree((char *)e);
	    udpReleasePort(pstate->portstate, key);
	}
	return XK_SUCCESS;
    }
    else
	return XK_FAILURE;
}

static VOID *portstatekludge; /* no, it's not instantiated separately for each
				 instance, but because it won't be used with
				 blocking, we escape disaster */

static void
callUnlockPort(key, e)
VOID   *key;
Enable *e;
{
    xTrace1(udpp, TR_FUNCTIONAL_TRACE,
	    "UDP callUnlockPort called with key %d", (int)*(PassiveId *)key);
    udpReleasePort(portstatekludge, *(PassiveId *)key);
}

static XkReturn
udpOpenDisableAll(self, hlp)
Protl self, hlp;
{
    xTrace0(udpp, TR_MAJOR_EVENTS, "udpOpenDisableAll");
    portstatekludge = (void *)(((PSTATE *)(self->state))->portstate);
    return defaultOpenDisableAll(((PSTATE *)self->state)->passivemap,
				 hlp, callUnlockPort);
}

static void
getproc_protl(s)
Protl s;
{
    xAssert(xIsProtl(s));
    /* s->close         = udpCloseProtl; */
    s->controlprotl   = udpControlProtl;
    s->open           = udpOpen;
    s->openenable     = udpOpenEnable;
    s->opendisable    = udpOpenDisable;
    s->demux          = udpDemux;
    s->opendisableall = udpOpenDisableAll;
}

static void
getproc_sessn(s)
Sessn s;
{
    xAssert(xIsSessn(s));
    s->push            = udpPush;
    s->pop             = udpPop;
    s->controlsessn    = udpControlSessn;
    s->getparticipants = udpGetParticipants;
    s->close           = udpCloseSessn;
}
