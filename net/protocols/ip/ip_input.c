/*     
 * $RCSfile: ip_input.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: ip_input.c,v $
 * Revision 1.2  1996/01/29 22:19:34  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:27:12  slm
 * Initial revision
 *
 * Revision 1.11.1.1.1.4  1994/12/02  18:15:59  hkaram
 * Changed to new mapResolve interface
 *
 * Revision 1.11.1.1.1.3  1994/11/22  21:01:19  hkaram
 * Added casts to mapResolve calls
 *
 * Revision 1.11.1.1.1.2  1994/10/27  01:25:02  hkaram
 * Merged in changes from Davids versoin
 *
 * Revision 1.11.1.1  1994/06/08  17:04:04  menze
 * bzero multicomponent keys before use
 */


#include "xkernel.h"
#include "ip.h"
#include "ip_i.h"
#include "route.h"

#ifdef __STDC__
static int		onLocalNet( Sessn, IPhost * );
static int		validateOpenEnable( Sessn );
#else
static int		onLocalNet();
static int		validateOpenEnable();
#endif /* __STDC__ */


/*
 * ipDemux
 */
XkReturn
ipDemux(self, transport_s, dg)
    Protl self;
    Sessn transport_s;
    Msg *dg;
{
    IPheader	hdr;
    Sessn        s;
    ActiveId	actKey;
    PState	*pstate = (PState *) self->state;
    int		dataLen;
    char	options[40];
    
    xTrace1(ipp, TR_EVENTS,
	    "IP demux called with datagram of len %d", msgLength(dg));
    if ( ipGetHdr(dg, &hdr, options) PREDICT_FALSE ) {
	xTrace0(ipp, TR_SOFT_ERRORS,
		"IP demux : getHdr problems, dropping message\n"); 
	return XK_SUCCESS;
    }
    xTrace3(ipp, TR_MORE_EVENTS,
	    "ipdemux: seq=%d,frag=%d, len=%d", hdr.ident, hdr.frag,
	    msgLength(dg));
    if (GET_HLEN(&hdr) > 5 PREDICT_FALSE) {
	xTrace0(ipp, TR_SOFT_ERRORS,
		"IP demux: I don't understand options!  Dropping msg");
	return XK_SUCCESS;
    }
    dataLen = hdr.dlen - IPHLEN;
    if ( dataLen < msgLength(dg) ) {
	xTrace1(ipp, TR_MORE_EVENTS,
		"IP demux : truncating right at byte %d", dataLen);
	msgTruncate(dg, dataLen);
    }
    bzero((char *)&actKey, sizeof(ActiveId));
    actKey.protNum = hdr.prot;
    *((int*)&actKey.remote) = *((int*)&hdr.source);
    actKey.local = hdr.dest;
    if (mapResolve(pstate->activeMap, &actKey, (void **)&s) !=
	XK_SUCCESS PREDICT_FALSE) {
	FwdId	fwdKey;
	IPhost	mask;

	netMaskFind(&mask, &hdr.dest);
	IP_AND(fwdKey, mask, hdr.dest);
	if (mapResolve(pstate->fwdMap, &fwdKey, (void **)&s) == XK_FAILURE) {
	    xTrace0(ipp, TR_EVENTS, "no active session found");
	    s = ipCreatePassiveSessn(self, transport_s, &actKey, &fwdKey);
	    if ( s == ERR_SESSN ) {
		xTrace0(ipp, TR_EVENTS, "...dropping the message");
		return XK_SUCCESS;
	    }
	}
    }
    return xPop(s, transport_s, dg, &hdr);
}


XkReturn
ipForwardPop( s, lls, msg, inHdr )
    Sessn	s, lls;
    Msg 	*msg;
    VOID	*inHdr;
{
    IPheader		*h = (IPheader *)inHdr;
    XkHandle	res;

    xTrace0(ipp, TR_EVENTS, "ip forward pop");
    xAssert(h);
    if ( --h->time == 0 ) {
	xTrace0(ipp, TR_EVENTS, "ttl == 0 -- dropping");
	return XK_SUCCESS;
    }
    /* 
     * We need to go through ipSend because the MTU on the outgoing
     * interface might be less than the packet size (and need
     * fragmentation.) 
     */
    res = ipSend(s, xGetSessnDown(s, 0), msg, h);
    return ( res == XMSG_ERR_HANDLE ) ? XK_FAILURE : XK_SUCCESS;
}


static int
onLocalNet( llo, h )
    Sessn	llo;
    IPhost	*h;
{
    int	res;

    res = xControlSessn(llo, VNET_HOSTONLOCALNET, (char *)h, sizeof(IPhost));
    if ( res < 0 ) {
	xTrace0(ipp, TR_ERRORS, "ipFwdBcst couldn't do HOSTONLOCALNET on llo");
	return 0;
    }
    return res > 0;
}


/* 
 * Used for ipFwdBcast sessions, sessions which receive network broadcasts
 * in a subnet  environment.  Depending on the incoming interface, the
 * message may  need to be forwarded on other interfaces and locally
 * accepted, or it may be dropped.  See RFC 922.
 *
 * This is not very efficient and is further complicated by the hiding
 * of interfaces in VNET.
 */
XkReturn
ipFwdBcastPop( s, llsIn, msg, inHdr )
    Sessn	s, llsIn;
    Msg 	*msg;
    VOID	*inHdr;
{
    IPheader		*h = (IPheader *)inHdr;
    XkHandle	res;
    route		rt;
    Msg			msgCopy;
    VOID		*ifcId;
    Sessn		lls;
    XkReturn	xkr;
    PState		*ps = (PState *)xMyProtl(s)->state;

    xTrace0(ipp, TR_EVENTS, "ip forward bcast pop");
    xAssert(h);
    if ( --h->time == 0 ) {
	xTrace0(ipp, TR_EVENTS, "ttl == 0 -- dropping");
	return XK_SUCCESS;
    }
    /* 
     * Did this packet come in on the interface we would use to reach
     * the source?  If not, drop the message
     */
    if ( ! onLocalNet(llsIn, &h->source) ) {
	if ( onLocalNet(xGetSessnDown((Sessn)xMyProtl(s), 0), &h->source ) ) {
	    xTrace0(ipp, TR_EVENTS,
	          "ipFwdBcast gets packet not on direct connection, dropping");
	    return XK_SUCCESS;
	}
	xkr = rt_get( &ps->rtTbl, &h->source, &rt );
	if ( xkr == XK_FAILURE ) {
	    xTrace0(ipp, TR_SOFT_ERRORS, "ipFwdBcast ... no gateway");
	    return XK_SUCCESS;
	}
	if ( ! onLocalNet(llsIn, &rt.gw) ) {
	    xTrace0(ipp, TR_EVENTS,
		    "ipFwdBcast receives packet from dup gw, dropping");
	    return XK_SUCCESS;
	}
    }
    /* 
     * If this is a session used for local delivery (i.e., if the
     * down[0] is valid), send up for local processing (reassemble first)
     */
    if (xIsSessn(xGetSessnDown(s, 0))) {
	msgConstructCopy(&msgCopy, msg);
	ipStdPop(s, llsIn, &msgCopy, h);
	msgDestroy(&msgCopy);
    }
    /* 
     * Send this message back out on all appropriate interfaces except
     * the one on which it was received.
     */
    lls = xGetSessnDown(s, 1);
    xAssert(xIsSessn(lls));
    xControlSessn(llsIn, VNET_GETINTERFACEID, (char *)&ifcId, sizeof(VOID *));
    if ( xControlSessn(lls, VNET_DISABLEINTERFACE, (char *)&ifcId, sizeof(VOID *))
		< 0 ) {
	xTrace0(ipp, TR_ERRORS,
		"ipFwdBcastPop could not disable lls interface");
	return XK_SUCCESS;
    }
    res = ipSend(s, lls, msg, h);
    xControlSessn(lls, VNET_ENABLEINTERFACE, (char *)&ifcId, sizeof(VOID *));
    return ( res == XMSG_ERR_HANDLE ) ? XK_FAILURE : XK_SUCCESS;
}


/* 
 * validateOpenEnable -- Checks to see if there is still an openEnable for
 * the session and, if so, calls openDone.
 * This is called right before a message is sent up through
 * a session with no external references.  This has to be done
 * because IP sessions
 * can survive beyond removal of all external references. 
 *
 * Returns 1 if an openenable exists, 0 if it doesn't.
 */
static int
validateOpenEnable( s )
    Sessn	s;
{
    SState	*ss = (SState *)s->state;
    Enable	*e;

    e = ipFindEnable(xMyProtl(s), ss->hdr.prot, &ss->hdr.source);
    if ( e == ERR_ENABLE ) {
	xTrace1(ipp, TR_MAJOR_EVENTS, "ipValidateOE -- no OE for hlp %d!",
		ss->hdr.prot);
	return 0;
    }
    xOpenDone(e->hlp, xMyProtl(s), s);
    return 1;
}

XkReturn
ipMsgComplete(s, lls, dg, inHdr)
    Sessn	s, lls;
    Msg 	*dg;
    VOID	*inHdr;
{
    IPheader *h = (IPheader *)inHdr;
    IPpseudoHdr ph;
    
    if ( s->rcnt == 1 && ! validateOpenEnable(s) ) {
	return XK_SUCCESS;
    }
    xAssert(h);
    ph.src = h->source;
    ph.dst = h->dest;
    ph.zero = 0;
    ph.prot = h->prot;
    ph.len = htons( msgLength(dg) );
    msgSetAttr(dg, 0, (VOID *)&ph, sizeof(IPpseudoHdr));
    xTrace1(ipp, TR_EVENTS, "IP pop, length = %d", msgLength(dg));
    xAssert(xIsSessn(s));
    return xDemux(xGetUp(s), s, dg);
}

XkReturn
ipStdPop( s, lls, dg, hdr )
    Sessn	s, lls;
    Msg		*dg;
    VOID	*hdr;
{
    s->idle = FALSE;
    if (COMPLETEPACKET(*(IPheader *)hdr)) {
	return ipMsgComplete(s, lls, dg, hdr);
    } else {
	return ipReassemble(s, lls, dg, hdr);
    }
}
