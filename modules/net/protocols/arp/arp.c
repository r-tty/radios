/* 
 * $RCSfile: arp.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: arp.c,v $
 * Revision 1.2  1996/01/29 21:58:34  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:58:36  slm
 * Initial revision
 *
 * Revision 1.75.1.1.1.2  1994/10/27  01:29:31  hkaram
 * Merged in changes from Davids version
 *
 * Revision 1.75.1.1  1994/03/14  23:11:12  umass
 * Uses MAC48BitHosts instead of ETHhosts
 *
 * Revision 1.75  1993/12/11  00:23:52  menze
 * fixed #endif comments
 *
 * Revision 1.74  1993/11/12  20:47:04  menze
 * SendRarpReply was rewriting arp_tha address from the address of the
 * requesting host (which isn't necessarily the target host.)
 */


#include "xkernel.h"
#include "mac.h"
#include "eth.h"
#include "ip.h"
#include "arp.h"
#include "arp_i.h"
#include "arp_table.h"

int tracearpp;


#ifdef XK_DEBUG

static char *codenames[] = {
  "impossible",
  "req",
  "rply",
  "rreq",
  "rrply"
};

#endif /* XK_DEBUG */


/* global data of arp protocol */

static MAC48bithost   genericBroadcastHost = BCAST_MAC48BIT_ADDRESS;
static IPhost	      ipLocalBcastHost = { 255, 255, 255, 255 };


#ifdef __STDC__

static void		arp_print( char *, ArpHdr * );
static int		arpControlProtl( Protl, int, char *, int );
static XkReturn 	arpDemux( Protl, Sessn, Msg * );
static void		arpFuncs( Protl );
static void		arpHdrStore(void *, char *, long, void *);
static long		arpHdrLoad(void *, char *, long, void *);
static XkReturn	arpInterfaceInit( Protl, Protl );
static void		arpTimeout( Event, VOID * );
static void		newWait( ArpWait *, Protl );
static int		noopControl( Protl, int, char *, int );
static XkReturn	noopDemux( Protl, Sessn, Msg * );
static void 		sendArpReply( Protl, Sessn, ArpHdr * );
#ifdef ANSWER_RARPS 
static void 		sendRarpReply( Protl, Sessn, ArpHdr * );
#endif

#else

static int	arpControlProtl();
static XkReturn arpDemux();
static void	arpHdrStore();
static long	arpHdrLoad();
static XkReturn 	arpInterfaceInit();
static void	arpTimeout();
static void 	sendArpReply();
#ifdef ANSWER_RARPS 
static void 	sendRarpReply();
#endif

#endif /* __STDC__ */


static void
arp_print(s, m)
    char *s;
    ArpHdr *m;
{
    xTrace3(arpp, TR_ALWAYS, "%s arp %s (%d) message:", s,
	    (m->arp_op > ARP_MAXOP) ? "unknown" : codenames[m->arp_op],
	    m->arp_op); 
    xTrace2(arpp, TR_ALWAYS, "  source %s @ %s",
	    mac48bitHostStr(&m->arp_sha), ipHostStr(&m->arp_spa));
    xTrace2(arpp, TR_ALWAYS, "  target %s @ %s",
	    mac48bitHostStr(&m->arp_tha), ipHostStr(&m->arp_tpa));
}


static void
arpFuncs(self)
    Protl self;
{
    self->controlprotl = arpControlProtl;
    self->demux = arpDemux;
}


static XkReturn
noopDemux( self, s, msg )
    Protl self;
    Sessn s;
    Msg *msg;
{
    return XK_FAILURE;
}


static int
noopControl( self, op, buf, len )
    Protl self;
    int op;
    char *buf;
    int len;
{
    return -1;
}


void
arp_init(self)
    Protl self;
{
    PSTATE	*ps;
    Protl	llp;
    
    xTrace0(arpp, 1, "ARP init");
    ps = X_NEW(PSTATE);
    self->state = (VOID *)ps;
    ps->tbl = arpTableInit();
    arpPlatformInit(self);
    /* 
     * We create a rarp protocol for each arp protocol, mainly to be
     * able to find the protocol number of rarp relative to the llp
     */
    llp = xGetProtlDown(self, 0);
    if (!xIsProtl(llp)) {
	xError("ARP -- could not get llp");
	return;
    }
    ps->rarp = xCreateProtl(arpFuncs, "rarp", "", self->traceVar, 1, &llp);
    if ( ps->rarp == ERR_PROTL ) {
	xError("ARP could not create RARP protocol");
	return;
    }
    ps->rarp->state = self->state;
    arpFuncs(self);
    if ( arpInterfaceInit(self, llp) == XK_FAILURE ) {
 	xError("ARP -- error in initialization");
	self->controlprotl = noopControl;
	self->demux = noopDemux;
    }
}


static XkReturn
arpInterfaceInit( self, llp )
    Protl self;
    Protl llp;
{
    MAC48bithost localHost;
    PSTATE	 *ps = (PSTATE *)self->state;
    Part	 part;

    if ( xControlProtl(llp, GETMYHOST, (char *)&ps->hdr.arp_sha, 
                  sizeof(MAC48bithost)) < (int)sizeof(MAC48bithost) ) {
	xError("ARP could not get host from llp");
	return XK_FAILURE;
    }
    localHost = ps->hdr.arp_sha;
    /*
     * Openenable lower protocol for arps and rarps
     */
    partInit(&part, 1);
    partPush(part, ANY_HOST, 0);
    xOpenEnable(self, self, llp, &part);
    partPush(part, ANY_HOST, 0);
    xOpenEnable(self, ps->rarp, llp, &part);
    /*
     * Open broadcast sessions for this interface
     */
    partInit(&part, 1);
    partPush(part, &genericBroadcastHost, sizeof(genericBroadcastHost));
    if ( (ps->rarpSessn = xOpen(self, ps->rarp, llp, &part)) == ERR_SESSN) {
	xError("ARP init failure (rarp)");
	return XK_FAILURE;
    }
    partInit(&part, 1);
    partPush(part, &genericBroadcastHost, sizeof(genericBroadcastHost));
    if ((ps->arpSessn = xOpen(self, self, llp, &part)) == ERR_SESSN) {
	xError("ARP init failure (arp)");
	return XK_FAILURE;
    }
#ifdef X_IRIX
    /* 
     * Register ourselves with the lower (Ethernet or FDDI) protocol
     */
    xControlProtl(llp, MAC_REGISTER_ARP, (char *)&self, sizeof(Protl));
#else
    /* 
     * Register ourselves with the lower protocol
     */
    xControlProtl(llp, ETH_REGISTER_ARP, (char *)&self, sizeof(Protl));
#endif
    /*
     * Create a default header for requests sent on this interface
     */
    ps->hdr.arp_hrd=1;
    ps->hdr.arp_prot=ARP_PROT;
    ps->hdr.arp_hlen=6;
    ps->hdr.arp_plen=4;
    /*
     * Get my IP address for this interface
     */
    xTrace1(arpp, 3, "My phy addr = %s", mac48bitHostStr(&ps->hdr.arp_sha));
    while ( arpRevLookup(self, &ps->hdr.arp_spa, &ps->hdr.arp_sha) != 0 ) {
	sprintf(errBuf, 
	"ARP: Could not get my ip address for interface %s (still trying)",
		llp->name);
	xError(errBuf);
	/*
	 * Most protocols aren't going to be very useful if we can't
	 * find out our own IP address.  Keep trying.
	 */
	Delay( INIT_RARP_DELAY );
    }
    /* 
     * Lock my binding in the table so it doesn't leave the cache.
     */
    arpLock( ps->tbl, &ps->hdr.arp_spa );
    arpTblPurge( ps->tbl, &ps->hdr.arp_spa );
    return XK_SUCCESS;
}


/*
 * sendArpReply -- send an ARP reply to the sender of 'srcHdr'
 * with my ip and physical addresses on the interface 'ifs'
 */
static void
sendArpReply( self, lls, srcHdr )
    Protl 	self;
    Sessn	lls;
    ArpHdr	*srcHdr;
{
    ArpHdr reply;
    Msg repMsg;
    VOID *buf;

    reply = ((PSTATE *)self->state)->hdr;
    reply.arp_tha = srcHdr->arp_sha;
    reply.arp_tpa = srcHdr->arp_spa;
    reply.arp_op = ARP_RPLY;
    msgConstructEmpty(&repMsg);

    buf = msgPush(&repMsg, ARP_HLEN);
    xAssert(buf);
    arpHdrStore(&reply, buf, ARP_HLEN, 0);

    xTrace2(arpp, 3, "replying with arp message with op %d (%s)", 
	    reply.arp_op, codenames[reply.arp_op]);
    xPush(lls, &repMsg);
    msgDestroy(&repMsg);
}


#ifdef ANSWER_RARPS 

/*
 * sendRarpReply -- send a RARP reply to the sender of 'srcHdr'
 * if we know the answer
 */
static void
sendRarpReply( self, lls, srcHdr )
    Protl 	self;
    Sessn	lls;
    ArpHdr	*srcHdr;
{
    ArpHdr reply;
    Msg repMsg;
    IPhost ipHost;
    VOID *buf;
    
    if ( arpRevLookupTable( self, &ipHost, &srcHdr->arp_tha ) != 0 ) {
	/*
	 * We don't have this value in our table
	 */
	xTrace1(arpp, 3, "Don't know address of %s, can't send RARP reply",
		mac48bitHostStr(&srcHdr->arp_tha));
	return;
    }
    reply = ((PSTATE *)self->state)->hdr;
    reply.arp_op = ARP_RRPLY;
    reply.arp_tha = srcHdr->arp_tha;
    reply.arp_tpa = ipHost;
    msgConstructEmpty(&repMsg);

    buf = msgPush(&repMsg, ARP_HLEN);
    xAssert(buf);
    arpHdrStore(&reply, buf, ARP_HLEN, 0);

    xTrace1(arpp, 3, "replying with arp message with op %d", reply.arp_op);
    xPush(lls, &repMsg);
    msgDestroy(&repMsg);
}

#endif /* ANSWER_RARPS */


static XkReturn
arpDemux(self, s, msg)
    Protl self;
    Sessn s;
    Msg *msg;
{
    ArpHdr hdr;
    PSTATE *ps = (PSTATE *)self->state;
    VOID *buf;
    
    xAssert(xIsSessn(s));
    xAssert(xIsProtl(self));
    buf = msgPop(msg, ARP_HLEN);
    xAssert(buf);
    arpHdrLoad(&hdr, buf, ARP_HLEN, 0);

    xIfTrace(arpp, 3) arp_print("received", &hdr);
    switch(hdr.arp_op) {
      case ARP_REQ:
	if ( IP_EQUAL(ps->hdr.arp_spa, hdr.arp_tpa) ) {
	    arpSaveBinding(ps->tbl, &hdr.arp_spa, &hdr.arp_sha);    
	    sendArpReply(self, s, &hdr);
	}
	break;
	
      case ARP_RPLY:
	arpSaveBinding(ps->tbl, &hdr.arp_spa, &hdr.arp_sha);
	break;
	
      case ARP_RREQ:
#ifdef ANSWER_RARPS 
	sendRarpReply(self, s, &hdr);
#endif
	break;
	
      case ARP_RRPLY:
	arpSaveBinding(ps->tbl, &hdr.arp_spa, &hdr.arp_sha);
	arpSaveBinding(ps->tbl, &hdr.arp_tpa, &hdr.arp_tha);
	break;
	
      default:
	{/*do nothing*/}
	break;
    }
    return XK_SUCCESS;
}


static void
arpTimeout(ev, arg)
    Event	ev;
    VOID 	*arg;
{
    arpSendRequest( (ArpWait *)arg );
}

/*
 * arpSendRequest -- this is called both for initial requests and
 * as the timeout event
 */ 
void
arpSendRequest(w)
    ArpWait *w;
{
    Msg msg;
    VOID *buf;
    PSTATE *ps = (PSTATE *)w->self->state;
    
    xTrace1(arpp, 3, "Arp timeout, state = %x", w);
    if (*w->status == ARP_RSLVD) {
	xTrace0(arpp, 5, "Request already resolved, timeout exiting");
	return;
    }
    if (w->reqMsg.arp_op == ARP_REQ && w->tries++ > ARP_RTRY) {
	xTrace0(arpp, 1, "arp timeout: giving up");
	arpSaveBinding( ps->tbl, &w->reqMsg.arp_tpa, 0 );
	return;
    } else if (w->reqMsg.arp_op == ARP_RREQ && w->tries++ > ARP_RRTRY) {
	xTrace0(arpp, 1, "arp timeout: giving up");
	arpSaveBinding( ps->tbl, 0, &w->reqMsg.arp_tha );
	return;
    }
    xTrace0(arpp, 3, "arp timeout: trying again");
    /*
     *  start a new event, detaching old one if it existed.
     */
    if ( w->event ) {
	evDetach(w->event);
    }
    w->event = evSchedule( arpTimeout, w, ARP_TIME * 1000 );
    msgConstructEmpty(&msg);

    buf = msgPush(&msg, ARP_HLEN);
    xAssert(buf);
    arpHdrStore(&w->reqMsg, buf, ARP_HLEN, 0);

    xIfTrace(arpp, 3) arp_print("sending", &w->reqMsg);
    xPush((w->reqMsg.arp_op == ARP_RREQ) ? ps->rarpSessn : ps->arpSessn, &msg);
    msgDestroy(&msg);
}


static int
arpControlProtl(self, op, buf, len)
    Protl self;
    int op;
    char *buf;
    int len;
{
    PSTATE	*ps = (PSTATE *)self->state;
    int 	reply;
    ArpBinding	*b = (ArpBinding *)buf;
    
    xAssert(xIsProtl(self));
    switch (op) {
        case RESOLVE:
	    checkLen(len, sizeof(ArpBinding));
	    if ( ( netMaskNetsEqual(&b->ip, &ps->hdr.arp_spa) && 
	    	 	netMaskIsBroadcast(&b->ip) ) ||
		 IP_EQUAL(b->ip, ipLocalBcastHost) ) {

		xTrace0(arpp, 3, "returning MAC layer broadcast address");
		b->hw = genericBroadcastHost;
		reply = sizeof(ArpBinding);
	    } else if ( netMaskSubnetsEqual(&b->ip, &ps->hdr.arp_spa) ) {
		reply = (arpLookup(self, &b->ip, &b->hw) == 0) ? 
		  		sizeof(ArpBinding) : -1;
		if ( reply == -1 ) {
		    xTrace1(arpp, TR_SOFT_ERRORS,
			    "ARP lookup for host %s returns error",
			    ipHostStr(&b->ip));
		}
	    } else {
		xTrace1(arpp, TR_SOFT_ERRORS,
			"arp Resolve -- requested address %s is not local",
			ipHostStr(&b->ip));
		reply = -1;
	    }
	    break;
	
        case RRESOLVE:
	    checkLen(len, sizeof(ArpBinding));
	    if ( MAC48BIT_ADDRS_EQUAL(b->hw, genericBroadcastHost) ) {
		b->ip = ipLocalBcastHost;
		reply = sizeof(ArpBinding);
	    } else {
		reply = (arpRevLookup(self, &b->ip, &b->hw) == 0) ? 
	      			sizeof(ArpBinding) : -1;
	    }
	    break;
	
        case ARP_INSTALL:
	    checkLen(len, sizeof(ArpBinding));
	    arpSaveBinding(ps->tbl, &b->ip, &b->hw);
	    reply = 0;
	    break;
	
        case ARP_GETMYBINDING:
	    checkLen(len, sizeof(ArpBinding));
	    b->ip = ps->hdr.arp_spa;
	    b->hw = ps->hdr.arp_sha;
	    reply = sizeof(ArpBinding);
	    break;
	
        case ARP_FOR_EACH:
	    checkLen(len, sizeof(ArpForEach));
	    arpForEach(ps->tbl, (ArpForEach *)buf);
	    reply = 0;
	    break;

        default:
	    reply = -1;
    }
    xTrace2(arpp, 3, "Arp control %s returns %d", 
	    op == (int)RESOLVE ? "resolve":
	    op == (int)ARP_GETMYBINDING ? "getmybinding" :
	    op == (int)RRESOLVE ? "rresolve" :
	    op == (int)ARP_FOR_EACH ? "forEach" :
	    "UNKNOWN", reply);
    return(reply);
}



static void
arpHdrStore(hdr, netHdr, len, arg)
    VOID *hdr;
    char *netHdr;
    long int len;
    VOID *arg;
{
    /*
     * Need a temporary header structure to avoid alignment problems
     */
    ArpHdr tmpHdr;
    
    xTrace0(arpp, 5, "Entering arpHdrStore");
    xAssert( len == sizeof(ArpHdr) );
    bcopy( hdr, (char *)&tmpHdr, sizeof(ArpHdr) );
    tmpHdr.arp_hrd = htons(tmpHdr.arp_hrd);
    tmpHdr.arp_prot = htons(tmpHdr.arp_prot);
    tmpHdr.arp_op = htons(tmpHdr.arp_op);
    bcopy( (char *)&tmpHdr, netHdr, sizeof(ArpHdr) );
    xTrace0(arpp, 7, "leaving arpHdrStore");
}


static long
arpHdrLoad(hdr, netHdr, len, arg)
    VOID *hdr;
    char *netHdr;
    long int len;
    VOID *arg;
{
    xAssert( len == sizeof(ArpHdr) );

    xTrace0(arpp, 5, "Entering arpHdrLoad");
    bcopy( netHdr, hdr, sizeof(ArpHdr) );
    ((ArpHdr *)hdr)->arp_hrd = ntohs(((ArpHdr *)hdr)->arp_hrd);
    ((ArpHdr *)hdr)->arp_prot = ntohs(((ArpHdr *)hdr)->arp_prot);
    ((ArpHdr *)hdr)->arp_op = ntohs(((ArpHdr *)hdr)->arp_op);
    xTrace0(arpp, 7, "leaving arpHdrLoad");
    return len;
}


static void
newWait(w, self)
    ArpWait 	*w;
    Protl	self;
{
    bzero((char *)w, sizeof(ArpWait));
    semInit(&w->s, 0);
    w->self = self;
}


void
newArpWait(w, self, h, status)
    ArpWait 	*w;
    Protl	self;
    IPhost 	*h;
    ArpStatus 	*status;
{
    newWait(w, self);
    w->reqMsg = ((PSTATE *)self->state)->hdr;
    w->reqMsg.arp_tpa = *h;
    w->reqMsg.arp_op = ARP_REQ;
    w->status = status;
}


void
newRarpWait(w, self, h, status)
    ArpWait 	 *w;
    Protl	 self;
    MAC48bithost *h;
    ArpStatus 	 *status;
{
    newWait(w, self);
    w->reqMsg = ((PSTATE *)self->state)->hdr;
    w->reqMsg.arp_tha = *h;
    w->reqMsg.arp_op = ARP_RREQ;
    w->status = status;
}
