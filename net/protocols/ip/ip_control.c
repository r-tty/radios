/*     
 * ip_control.c
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: ip_control.c,v $
 * Revision 1.2  1996/01/29 22:19:34  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:27:12  slm
 * Initial revision
 *
 * Revision 1.27.1.1.1.1  1994/10/27  01:20:51  hkaram
 * New branch
 *
 * Revision 1.27.1.1  1994/10/11  19:36:22  menze
 * Cleaner separation of local outgoing address and incoming address,
 * reporting the latter as result in GETMYHOST
 */

#include "xkernel.h"
#include "ip.h"
#include "route.h"
#include "ip_i.h"

#define IPHOSTLEN	sizeof(IPhost)

/* ip_controlsessn */
int
ipControlSessn(s, opcode, buf, len)
Sessn s;
int   opcode;
char  *buf;
int   len;
{
    SState   *sstate;
    PState   *pstate;
    IPheader *hdr;
    
    xAssert(xIsSessn(s));
    sstate = (SState *)s->state;
    pstate = (PState *)s->myprotl->state;
    
    hdr = &(sstate->hdr);
    switch (opcode) {
        case GETMYHOST:
	    checkLen(len, IPHOSTLEN);
	    *(IPhost *)buf = sstate->rcvAddr;
	    return IPHOSTLEN;
	
        case GETPEERHOST:
	    checkLen(len, IPHOSTLEN);
	    *(IPhost *)buf = sstate->hdr.dest;  
	    return IPHOSTLEN;
	
        case GETMYHOSTCOUNT:
        case GETPEERHOSTCOUNT:
	    checkLen(len, sizeof(int));
	    *(int *)buf = 1;
	    return sizeof(int);

        case GETMYPROTO:
        case GETPEERPROTO:
	    checkLen(len, sizeof(long));
	    *(long *)buf = sstate->hdr.prot;
	    return sizeof(long);
	
        case GETMAXPACKET:
	    checkLen(len, sizeof(int));
	    *(int *)buf = IPMAXPACKET;
	    return sizeof(int);
	
        case GETOPTPACKET:
	    checkLen(len, sizeof(int));
	    *(int *)buf = sstate->mtu - IPHLEN;
	    return sizeof(int);
	
        case IP_REDIRECT:
	    return ipControlProtl(s->myprotl, opcode, buf, len);

        case IP_CHANGEROUTE:
	    return ipControlProtl(s->myprotl, opcode, buf, len);

        case IP_PSEUDOHDR:
	    return 0;

        case IP_SETSOURCEADDR:
        {
	    SState *ss;

	    checkLen(len, sizeof(IPhost));
	    ss = s->state;
	    ss->hdr.source = *(IPhost *)buf;
	    return 0;
        }
	
        case IP_GETPSEUDOHDR:
	{
	    IPpseudoHdr	*phdr = (IPpseudoHdr *)buf;

	    checkLen(len, sizeof(IPpseudoHdr));
	    phdr->src = sstate->hdr.source;
	    phdr->dst = sstate->hdr.dest;
	    phdr->zero = 0;
	    phdr->len = 0;
	    phdr->prot = sstate->hdr.prot;
	    return sizeof(IPpseudoHdr);
	}

        default: 
	    xTrace0(ipp,3,"Unhandled opcode -- forwarding");
	    return xControlSessn(xGetSessnDown(s, 0), opcode, buf, len);
    }
}

Part *
ipGetParticipants(s)
Sessn s;
{
    Part   *p;
    SState *sstate = (SState *)s->state;

    p = xGetParticipants(xGetSessnDown(s, 0));
    if (p && partLength(p) > 0 && partLength(p) <= 2) {
	/* 
	 * We may have rewritten the remote participant to be a gateway, so
	 * we'll replace it with the ultimate destination address.  The local
	 * participant (if it's there) should be OK.
	 */
	if (partPop(p[0]) == 0)
	    return NULL;
	partPush(p[0], &sstate->hdr.dest, sizeof(IPhost));
	return p;
    }
    else
	return NULL;
}

/* ip_controlprotl */
int
ipControlProtl(self, opcode, buf, len)
Protl self;
int   opcode;
char  *buf;
int   len;
{
    PState *pstate;
    IPhost net, mask, gw, dest;
    
    xAssert(xIsProtl(self));
    pstate = (PState *)self->state;
    
    switch (opcode) {
        case IP_REDIRECT:
	    checkLen(len, 2*IPHOSTLEN);
	    net = *(IPhost *)buf;
	    netMaskFind(&mask, &net);
	    gw = *(IPhost *)(buf + IPHOSTLEN);
	    xTrace3(ipp, 4, "IP_REDIRECT : net = %s, mask = %s, gw = %s",
		    ipHostStr(&net), ipHostStr(&mask), ipHostStr(&gw));
	    /*
	     * find which interface reaches the gateway
	     */
	    rt_add(pstate, &net, &mask, &gw, -1, RTDEFAULTTTL);
	    return 0;

        case IP_CHANGEROUTE:
        {
	    IProuteInfo *ri;

            checkLen(len, sizeof(IProuteInfo));
	    ri = (IProuteInfo *)buf;
            xTrace5(ipp, TR_EVENTS, "IP_CHANGEROUTE : "
		    "net = %s, mask = %s, gw = %s metric = %d, ttl = %d",
                    ipHostStr(&ri->net), ipHostStr(&ri->mask),
		    ipHostStr(&ri->gw), ri->metric, ri->ttl);
            /* find which interface reaches the gateway */
            rt_add(pstate, &ri->net, &ri->mask, &ri->gw, ri->metric, ri->ttl);
            return 0;
        }

        case GETMAXPACKET:
	    checkLen(len, sizeof(int));
	    *(int *)buf = IPMAXPACKET;
	    return sizeof(int);
	
        case GETOPTPACKET:
	    /* 
	     * A somewhat meaningless question to be asking the protocol.
	     * It makes more sense to ask an individual session that knows
	     * about the MTU.
	     */
	    checkLen(len, sizeof(int));
	    *(int *)buf = IPOPTPACKET - IPHLEN;
	    return sizeof(int);
	
	    /* test control ops - remove later */

        case IP_GETRTINFO:
	/* get route info for a given dest address :
	 * in : IP host address 
	 * out : route structure for this address
	 */
	{
	    XkReturn xkr;
	    
	    checkLen(len, sizeof(route));
	    dest = *(IPhost *)buf;
	    xkr = rt_get(&pstate->rtTbl, &dest, (route *)buf);
	    return (xkr == XK_SUCCESS) ? sizeof(route) : -1;
	}

        case IP_PSEUDOHDR:
	    return 0;

        default:
	    xTrace0(ipp,3,"Unrecognized opcode");
	    return xControlProtl(xGetProtlDown(self, 0), opcode, buf, len);
    }
}
