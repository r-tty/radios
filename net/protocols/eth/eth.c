/*
 * $RCSfile: eth.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: eth.c,v $
 * Revision 1.2  1996/01/29 22:13:22  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:12:14  slm
 * Initial revision
 *
 * Revision 1.61.1.6  1994/12/02  18:12:42  hkaram
 * Changed to new mapResolve interface
 *
 * Revision 1.61.1.5  1994/11/26  01:24:46  hkaram
 * msgDestroy added for the promiscous case
 *
 * Revision 1.61.1.4  1994/11/22  20:57:43  hkaram
 * Added casts to mapResolve and bcopy calls
 *
 * Revision 1.61.1.3  1994/11/02  23:49:27  hkaram
 * Simple syntax error fix
 *
 * Revision 1.61.1.2  1994/10/27  01:48:35  hkaram
 * Merged changes from Davids version.
 *
 * Revision 1.61.1.1  1994/10/27  01:35:34  hkaram
 * New branch
 *
 * Revision 1.61  1994/06/16  20:50:12  xk
 * Added cast to use of bzero - IRIX build complained.
 *
 * Revision 1.60  1994/06/15  23:48:10  davidm
 * (ethDemux): zero out actKey before filling in elements.
 *
 * Revision 1.59  1994/03/13  03:40:22  davidm
 * Pointers are now printed as "%lx" and cast to (u_long).
 *
 * Revision 1.58  1993/12/13  22:46:46  menze
 * Modifications from UMass:
 *
 *   [ 93/11/12          yates ]
 *   Changed casting of Map manager calls so that the header file does it all.
 */

/*
 * The xkernel ethernet driver is structured in two layers.
 *
 * The ethernet protocol layer (this file) is independent of any particular
 * ethernet controller hardware.  It comprises the usual xkernel protocol
 * functions, e.g. eth_open, eth_push, etc.).  It knows about ethernet
 * addresses and "types," but nothing about any particular ethernet controller.
 *
 * The device driver, which exports an xkernel interface, sits below this
 * protocol.
 */

#include "xkernel.h"
#include "romopt.h"
#include "eth.h"
#include "eth_i.h"

typedef struct {
    ETHhdr hdr;
    int    hlp_num;	/* HLP number in host byte order */
} SState;

typedef struct {
    ETHhost host;
    ETHtype type;
} ActiveId;

typedef struct {
    Sessn   prmSessn;
    ETHhost myHost;
    Map     actMap;
    Map     pasMap;
    int     mtu;
} PState;

typedef ETHtype  PassiveId;

typedef struct {
    Msg    msg;
    Protl  self;
    Protl  llp;
    ETHhdr hdr;
} RetBlock;

#define ETH_ACTIVE_MAP_SZ  257
#define ETH_PASSIVE_MAP_SZ 13

int  traceethp;

#ifdef XK_DEBUG

static ETHhost ethBcastHost = BCAST_ETH_AD;

#endif

#ifdef __STDC__

static void     demuxStub(Event, VOID *);
static int      dispActiveMap(void *, void *, void *);
static int      dispPassiveMap(void *, void *, void *);
static Sessn    ethCreateSessn(Protl, Protl, Protl, ActiveId *);
static void     ethSessnInit(Sessn);
static int      ethControlProtl(Protl, int, char *, int);
static XkReturn ethDemux(Protl, Sessn, Msg *);
static Sessn    ethOpen(Protl, Protl, Protl, Part *);
static XkReturn ethOpenEnable(Protl, Protl, Protl, Part *);
static XkReturn ethOpenDisable(Protl, Protl, Protl, Part *);
static XkReturn ethOpenDisableAll(Protl, Protl);
static XkReturn ethClose(Sessn);
static XkHandle ethPush(Sessn, Msg *);
static XkHandle ethLoopPush(Sessn, Msg *);
static XkReturn ethPop(Sessn, Sessn, Msg *, VOID *);
static int      ethControlSessn(Sessn, int, char *, int);
static Part     *ethGetParticipants(Sessn);
static long     getRelProtNum(Protl, Protl, char *);
static XkReturn readMtu(Protl, char **, int, int, VOID *);

#else

static void     demuxStub();
static Sessn    ethCreateSessn();
static void     ethSessnInit();
static int      ethControlProtl();
static XkReturn ethDemux();
static Sessn    ethOpen();
static XkReturn ethOpenEnable();
static XkReturn ethOpenDisable();
static XkReturn ethOpenDisableAll();
static XkReturn ethClose();
static XkHandle ethPush();
static XkHandle ethLoopPush();
static XkReturn ethPop();
static int      ethControlSessn();
static Part     *ethGetParticipants();
static long     getRelProtNum();
static XkReturn readMtu();

#endif /* __STDC__ */

static ProtlRomOpt ethOpt[] = {
    { "mtu", 3, readMtu }
};

static long
getRelProtNum(hlp, llp, s)
Protl hlp, llp;
char  *s;
{
    long n;

    n = relProtNum(hlp, llp);
    if (n == -1) {
	xTrace3(ethp, TR_ERRORS,
		"eth %s could not get prot num of %s relative to %s",
		s, hlp->name, llp->name);
    }
    if (n < 0 || n > 0xffff)
	return -1;
    return n;
}

static XkReturn
readMtu(self, str, nFields, line, arg)
Protl self;
int   line, nFields;
char  **str;
VOID  *arg;
{
    PState *ps = (PState *)self->state;

#ifdef XKMACHKERNEL
    return sscanf1(str[2], "%d", &ps->mtu) < 1  ? XK_FAILURE : XK_SUCCESS;
#else
    return sscanf(str[2], "%d", &ps->mtu) < 1  ? XK_FAILURE : XK_SUCCESS;
#endif
}

void
eth_init(self)
Protl self;
{
    PState *ps;
    Protl  llp;

    xTrace0(ethp, TR_EVENTS, "eth_init");
    if (!xIsProtl(llp = xGetProtlDown(self, 0))) {
	xError("eth can not get driver protocol object");
	return;
    }
    if (xOpenEnable(self, self, llp, 0) == XK_FAILURE) {
	xError("eth can not openenable driver protocol");
	return;
    }
    ps = X_NEW(PState);
    self->state = (VOID *)ps;
    ps->actMap = mapCreate(ETH_ACTIVE_MAP_SZ, sizeof(ActiveId));
    ps->pasMap = mapCreate(ETH_PASSIVE_MAP_SZ, sizeof(PassiveId));
    ps->prmSessn = 0;
    ps->mtu = MAX_ETH_DATA_SZ;
    if (xControlProtl(llp, GETMAXPACKET, (char *)&ps->mtu, sizeof(ps->mtu)) <
	    (int)sizeof(ps->mtu)) {
	xError("eth_init: can't get mtu of driver, using default");
    }
    findProtlRomOpts(self, ethOpt, sizeof(ethOpt)/sizeof(ProtlRomOpt), 0);
    xTrace1(ethp, TR_MAJOR_EVENTS, "eth using mtu %d", ps->mtu);
    if (xControlProtl(llp, GETMYHOST, (char *)&ps->myHost, sizeof(ETHhost)) <
	    (int)sizeof(ETHhost)) {
	xError("eth_init: can't get my own host");
	return;
    }
    self->controlprotl   = ethControlProtl;
    self->open           = ethOpen;
    self->openenable     = ethOpenEnable;
    self->opendisable    = ethOpenDisable;
    self->demux          = ethDemux;
    self->opendisableall = ethOpenDisableAll;
}

static Sessn
ethOpen(self, hlp, hlpType, part)
Protl self, hlp, hlpType;
Part  *part;
{
    PState   *ps = (PState *)self->state;
    ActiveId key;
    Sessn    ethSessn;
    ETHhost  *remoteHost;
    long     protNum;

    if (part == 0 || partLength(part) < 1) {
	xTrace0(ethp, TR_SOFT_ERRORS, "ethOpen -- bad participants");
	return ERR_SESSN;
    }
    remoteHost = (ETHhost *)partPop(*part);
    xAssert(remoteHost);
    key.host = *remoteHost;
    if ((protNum = getRelProtNum(hlpType, self, "open")) == -1)
	return ERR_SESSN;
    key.type = protNum;
    xTrace2(ethp, TR_MAJOR_EVENTS, "eth_open: destination address = %s:%4x",
	    ethHostStr(&key.host), key.type);
    key.type = htons(key.type);
    if (mapResolve(ps->actMap, &key, (void **)&ethSessn) == XK_FAILURE)
	ethSessn = ethCreateSessn(self, hlp, hlpType, &key);
    xTrace1(ethp, TR_MAJOR_EVENTS, "eth_open: returning %lX", (u_long)ethSessn);
    return ethSessn;
}

static Sessn
ethCreateSessn(self, hlp, hlpType, key)
Protl    self, hlp, hlpType;
ActiveId *key;
{
    Sessn  s;
    Protl  llp = xGetProtlDown(self, 0);
    SState *ss;
    PState *ps = (PState *)self->state;

    s = xCreateSessn(ethSessnInit, hlp, hlpType, self, 1, (Sessn *)&llp);
    if (ETH_ADS_EQUAL(key->host, ps->myHost)) {
	xTrace0(ethp, TR_MAJOR_EVENTS,
		"ethCreateSessn -- creating loopback session");
	s->push = ethLoopPush;
    }
    s->binding = mapBind(ps->actMap, key, s);
    if (s->binding == ERR_BIND) {
	xTrace0(ethp, TR_ERRORS, "error binding in ethCreateSessn");
	xDestroySessn(s);
	return ERR_SESSN;
    }
    ss           = X_NEW(SState);
    ss->hdr.dst  = key->host;
    ss->hdr.type = key->type;
    ss->hdr.src  = ps->myHost;
    ss->hlp_num  = ntohs(key->type);
    s->state     = (VOID *)ss;
    return s;
}

static XkReturn
ethOpenEnable(self, hlp, hlpType, part)
Protl self, hlp, hlpType;
Part  *part;
{
    PState    *ps = (PState *)self->state;
    PassiveId key;
    long      protNum;

    if ((protNum = getRelProtNum(hlpType, self, "openEnable")) == -1)
	return XK_FAILURE;
    xTrace2(ethp, TR_GROSS_EVENTS, "eth_openenable: hlp=%lx, protlNum=%lx",
	    (u_long)hlp, protNum);
    key = protNum;
    key = htons(key);
    return defaultOpenEnable(ps->pasMap, hlp, hlpType, (VOID *)&key);
}

static XkReturn
ethOpenDisable(self, hlp, hlpType, part)
Protl self, hlp, hlpType;
Part *part;
{
    PState    *ps = (PState *)self->state;
    long      protNum;
    PassiveId key;

    if ((protNum = getRelProtNum(hlpType, self, "opendisable")) == -1)
	return XK_FAILURE;
    xTrace2(ethp, TR_GROSS_EVENTS, "eth_openenable: hlp=%lx, protlNum=%lx",
	    (u_long)hlp, protNum);
    key = protNum;
    key = htons(key);
    return defaultOpenDisable(ps->pasMap, hlp, hlpType, (VOID *)&key);
}

static int
dispActiveMap(key, val, arg)
VOID *key, *val, *arg;
{
    Sessn s = (Sessn)val;

    xPrintSessn(s);
    return MFE_CONTINUE;
}

static int
dispPassiveMap(key, val, arg)
VOID *key, *val, *arg;
{
#ifdef XK_DEBUG
    Enable *e = (Enable *)val;
#endif
    xTrace2(ethp, TR_ALWAYS, "Enable object, hlp == %s, hlpType = %s",
	    e->hlp->fullName, e->hlpType->fullName);
    return MFE_CONTINUE;
}

static XkReturn
ethOpenDisableAll(self, hlp)
Protl self, hlp;
{
    XkReturn xkr;
    PState   *ps = (PState *)self->state;

    xTrace0(ethp, TR_MAJOR_EVENTS, "eth openDisableAll called");

    xTrace0(ethp, TR_ALWAYS, "before passive map contents:");
    mapForEach(ps->pasMap, dispPassiveMap, 0);
    xkr = defaultOpenDisableAll(((PState *)self->state)->pasMap, hlp, 0);
    xTrace0(ethp, TR_ALWAYS, "after passive map contents:");
    mapForEach(ps->pasMap, dispPassiveMap, 0);
    xTrace0(ethp, TR_ALWAYS, "active map contents:");
    mapForEach(ps->actMap, dispActiveMap, 0);
    return XK_SUCCESS;
}

static XkReturn
ethDemux(self, llp, msg)
Protl self;
Sessn llp;
Msg   *msg;
{
    PState    *ps = (PState *)self->state;
    ETHhdr    *hdr = msgGetAttr(msg, 0);
    ActiveId  actKey;
    PassiveId pasKey;
    Enable    *e;
    Sessn     s;

    xTrace0(ethp, TR_EVENTS, "eth_demux");
    xTrace1(ethp, TR_FUNCTIONAL_TRACE, "eth type: %x", hdr->type);
    xTrace2(ethp, TR_FUNCTIONAL_TRACE, "src: %s  dst: %s",
	    ethHostStr(&hdr->src), ethHostStr(&hdr->dst));
    xIfTrace(ethp, TR_DETAILED)
	msgShow(msg);
    xAssert(hdr);
    if (ps->prmSessn PREDICT_FALSE) {
	Msg pMsg;

	xTrace0(ethp, TR_EVENTS,
		"eth_demux: passing msg to promiscuous session");
	msgConstructCopy(&pMsg, msg);
	xDemux(xGetUp(ps->prmSessn), ps->prmSessn, &pMsg);
	msgDestroy(&pMsg);
    }
#ifdef XK_DEBUG
    /* verify that msg is for this host */
    if (!(ETH_ADS_EQUAL(hdr->dst, ps->myHost) ||
	  ETH_ADS_EQUAL(hdr->dst, ethBcastHost) || ETH_ADS_MCAST(hdr->dst))) {
	xError("eth_demux: msg is not for this host");
	return XK_FAILURE;
    }

#if 0
    /* Temporary for testing */
    {
	static int count = 0;

	/*
	 * Every 30 packets there is a burst for 10 packets during
	 * which every other packet is delayed.
	 */
	count++;
	if (((count / 10) % 3) && !(count % 2)) {
	    xError("ethDemux delays packet");
	    Delay(4 * 1000);
	    xError("ethDemux delay returns");
	}
	else
	    xTrace1(ethp, TR_EVENTS, "ethDemux does not delay (%d)", count);
    }
#endif
#endif /* XK_DEBUG */
    bzero((char *)&actKey, sizeof(actKey));
    bcopy((unsigned char *)&hdr->src, (unsigned char *)&actKey,sizeof(actKey));
    if (ntohs(hdr->type) <= MAX_IEEE802_3_DATA_SZ) {
	/* it's an IEEE 802.3 packet---deliver it to protocol 0 */
	actKey.type = 0;
    }
    if (mapResolve(ps->actMap, &actKey, (void **)&s) !=
	    XK_SUCCESS PREDICT_FALSE) {
	pasKey = actKey.type;
	if (mapResolve(ps->pasMap, &pasKey, (void **)&e) == XK_SUCCESS) {
	    xTrace1(ethp, TR_EVENTS,
		    "eth_demux: openenable exists for msg type %x",
		    ntohs(pasKey));
	    xAssert(pasKey == 0 ||
		     ntohs(hdr->type) == relProtNum(e->hlpType, self));
	    s = ethCreateSessn(self, e->hlp, e->hlpType, &actKey);
	    if (s != ERR_SESSN) {
		xOpenDone(e->hlp, self, s);
		xTrace0(ethp, TR_EVENTS,
			"eth_demux: sending message to new session");
		return xPop(s, llp, msg, 0);
	    }
	}
	else {
	    xTrace1(ethp, TR_EVENTS,
		    "eth_demux: openenable does not exist for msg type %x",
		    ntohs(pasKey));
	}
	return XK_SUCCESS;
    }
    return xPop(s, llp, msg, 0);
}

static XkReturn
ethClose(s)
Sessn s;
{
    PState *ps = (PState *)xMyProtl(s)->state;

    xTrace1(ethp, TR_MAJOR_EVENTS, "eth closing session %lx", (u_long)s);
    xAssert(xIsSessn(s));
    xAssert(s->rcnt <= 0);
    mapRemoveBinding(ps->actMap, s->binding);
    xDestroySessn(s);
    return XK_SUCCESS;
}

static void
demuxStub(ev, arg)
Event ev;
VOID  *arg;
{
    RetBlock *b = (RetBlock *)arg;

    ethDemux(b->self, (Sessn)b->llp, &b->msg);
    xFree((char *)arg);
}

static XkHandle
ethLoopPush(s, m)
Sessn s;
Msg   *m;
{
    RetBlock *b;

    b = X_NEW(RetBlock);
    msgConstructCopy(&b->msg, m);
    b->hdr = ((SState *)s->state)->hdr;
    if (((SState*)s->state)->hlp_num <= MAX_IEEE802_3_DATA_SZ) {
	/* it's an 802.3 type packet: set type field to size of packet */
	b->hdr.type = htons(msgLength(m));
    }
    msgSetAttr(&b->msg, 0, (VOID *)&b->hdr, sizeof(b->hdr));
    b->self = s->myprotl;
    b->llp = xGetProtlDown(s->myprotl, 0);
    evDetach(evSchedule(demuxStub, b, 0));
    return XMSG_NULL_HANDLE;
}

static XkHandle
ethPush(s, msg)
Sessn s;
Msg   *msg;
{
    ETHhdr *hdr;

    xTrace0(ethp, TR_EVENTS, "eth_push");
    hdr = &((SState *)s->state)->hdr;
    if (((SState*)s->state)->hlp_num <= MAX_IEEE802_3_DATA_SZ PREDICT_FALSE) {
	/* it's an 802.3 type packet: set type field to size of packet */
	hdr->type = htons(msgLength(msg));
    }
    msgSetAttr(msg, 0, hdr, sizeof(ETHhdr));
    return xPush(xGetSessnDown(s, 0), msg);
}

static XkReturn
ethPop(s, llp, m, h)
Sessn s, llp;
Msg   *m;
VOID  *h;
{
    return xDemux(xGetUp(s), s, m);
}

static int
ethControlSessn(s, op, buf, len)
Sessn s;
int   op, len;
char  *buf;
{
    SState *ss = (SState *)s->state;

    xAssert(xIsSessn(s));
    switch (op) {
        case GETMYHOST:
        case GETMAXPACKET:
        case GETOPTPACKET:
	    return ethControlProtl(xMyProtl(s), op, buf, len);

        case GETPEERHOST:
	    checkLen(len, sizeof(ETHhost));
	    bcopy((char *)&ss->hdr.dst, buf, sizeof(ETHhost));
	    return (sizeof(ETHhost));

        case GETMYHOSTCOUNT:
        case GETPEERHOSTCOUNT:
	    checkLen(len, sizeof(int));
	    *(int *)buf = 1;
	    return sizeof(int);

        case GETMYPROTO:
        case GETPEERPROTO:
	    checkLen(len, sizeof(long));
	    *(long *)buf = ss->hdr.type;
	    return sizeof(long);

        case ETH_SETPROMISCUOUS:
	{
	    PState *ps = (PState *)xMyProtl(s)->state;

	    checkLen(len, sizeof(int));
	    ps->prmSessn = s;
	    /* tell the device driver to go into promiscuous mode */
	    return xControlSessn(xGetSessnDown(s, 0), op, buf, len);
	}

        default:
	    return -1;
    }
}

static Part *
ethGetParticipants(s)
Sessn s;
{
    Part   *p;
    SState *ss = (SState *)s->state;

    p = (Part *)xMalloc(2 * sizeof(Part));
    partInit(p, 2);
    /* remote host */
    partPush(p[0], &ss->hdr.dst, sizeof(ETHhost));
    partPush(p[1], &ss->hdr.src, sizeof(ETHhost));
    return p;
}

static int
ethControlProtl(self, op, buf, len)
Protl self;
int   op, len;
char  *buf;
{
    PState *ps = (PState *)self->state;

    xAssert(xIsProtl(self));
    switch (op) {
        case GETMAXPACKET:
        case GETOPTPACKET:
	    checkLen(len, sizeof(int));
	    *(int *)buf = ps->mtu;
	    return (sizeof(int));

        case GETMYHOST:
	    checkLen(len, sizeof(ETHhost));
	    bcopy((char *)&ps->myHost, buf, sizeof(ETHhost));
	    return (sizeof(ETHhost));

        default:
	    return xControlProtl(xGetProtlDown(self, 0), op, buf, len);
    }
}

static void
ethSessnInit(s)
Sessn s;
{
    s->push            = ethPush;
    s->pop             = ethPop;
    s->close           = ethClose;
    s->controlsessn    = ethControlSessn;
    s->getparticipants = ethGetParticipants;
}
