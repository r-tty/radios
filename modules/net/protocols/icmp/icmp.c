/*
 * icmp.c
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:15:40 $
 */

/*
 * x-kernel Internet Control Message Protocol
 *
 * Correctly handle ALL incoming ICMP packets.
 * Generate outgoing ICMP packets when appropriate.
 *
 * For our purposes, the important ICMP messages to handle are
 *	redirects, which modify the routing table
 *	info requests, which generate IP addresses at boot time
 *	source quenches, which allow rudimentary congestion control
 */

#include "xkernel.h"
#include "icmp.h"
#include "icmp_internal.h"

int traceicmpp;


#ifdef __STDC__

static int		controlProtl( Protl, int, char *, int );
static void		getProcProtl(Protl);
static void		getProcSessn(Sessn);
static long 		icmpHdrLoad(void *hdr, char *netHdr, long len, void *);
static XkReturn	icmp_close( Sessn );
static int		icmp_controlSessn( Sessn, int, char *, int );
static XkReturn	icmp_demux( Protl, Sessn, Msg * );
static Sessn		icmp_open( Protl, Protl, Protl, Part * );
static long 		icmpRedirectLoad(void *, char *, long, void *);
static void		updateCksum( u_short *, int, int );


#else

static void	getProcProtl();
static void	getProcSessn();
static long 	icmpHdrLoad();
static long 	icmpRedirectLoad();

#endif


void
icmp_init(self)
    Protl self;
{
  Part	part;
  Pstate *pstate;

  xTrace0(icmpp,3, "ICMP init");

  xAssert(xIsProtl(self));
  getProcProtl(self);
  
  pstate = (Pstate *)xMalloc(sizeof(Pstate));
  self->state = (VOID *)pstate;
  pstate->sessionsCreated = 0;
  pstate->waitMap = mapCreate(23, sizeof(mapId));
  partInit(&part, 1);
  partPush(part, ANY_HOST, 0);
  xOpenEnable(self, self, xGetProtlDown(self, 0), &part);
}


/*
 * icmp_open is here to provide user processes with a limited access to
 * icmp functions.  Returns a session upon which control ops may be executed.
 */
static Sessn
icmp_open(self, hlp, hlpType, p)
    Protl self, hlp, hlpType;
    Part *p;
{
    Sessn 	s;
    Sessn 	down_s;
    Pstate 	*pstate;
    Sstate 	*sstate;
    
    xTrace0(icmpp,3,"ICMP open");
    pstate = (Pstate *)self->state;
    down_s = xOpen(self, self, xGetProtlDown(self, 0), p);
    s = xCreateSessn(getProcSessn, hlp, hlpType, self, 1, &down_s);
    sstate = (Sstate *)xMalloc(sizeof(Sstate));
    sstate->sessId = ++(pstate->sessionsCreated);
    sstate->seqNum = 0;
    semInit(&sstate->replySem, 0);
    s->state = (VOID *)sstate;
    xTrace1(icmpp,3,"ICMP open returns %lx", (u_long)s);
    return s;
}


/*
 * This implementation does no caching of sessions -- close destroys
 * the session
 */
static XkReturn
icmp_close(s)
    Sessn s;
{
    int i;
    
    xAssert(s->rcnt <= 0);
    xAssert(xIsSessn(s));
    /*
     * The holder of a session is not allowed to close a session which
     * has outstanding control operations, so we don't have to worry
     * about freeing the waiter or killing the timeout event.
     */
    for (i=0; i < s->numdown; i++) {
	xClose(xGetSessnDown(s, i));
    }
    xDestroySessn(s);
    return XK_SUCCESS;
}


/*
 * updateCksum: increase the 1's complement short pointed to by 'cksum'
 * by the difference of 'n1' and 'n2'
 */
static void
updateCksum(cksum, n1, n2)
    u_short *cksum;
    int n1;
    int n2;
{
  u_short sum[2];

  xTrace3(icmpp, 7, "updateCksum: original sum == %x, n1=%x, n2=%x",
	  *cksum, n1, n2);
  sum[0] = *cksum;
  /*
   * sum[1] is the 1's complement representation of the difference
   */
  sum[1] = htons ( (n1 >= n2) ? (n1 - n2) : ~(n2 - n1) );
  *cksum = ocsum( sum, 2 );
  xTrace1(icmpp, 7, "updateCksum: new sum == %x", *cksum);
}


static XkReturn
icmp_demux(self, s, msg)
    Protl self;
    Sessn s;
    Msg *msg;
{
  ICMPHeader hdr;
  u_short check_sum;
  VOID *buf;

  /* msg_peek(msg, 0, sizeof(ICMPHeader), (char *)&hdr); */
  xAssert(xIsProtl(self));
  xAssert(xIsSessn(s));
  check_sum = inCkSum(msg, 0, 0);

  buf = msgPop(msg, sizeof(ICMPHeader));
  xAssert(buf);
  icmpHdrLoad(&hdr, buf, sizeof(ICMPHeader), 0);

  xTrace1(icmpp, 3, "Received an ICMP message with type %d", hdr.icmp_type);
  if ( check_sum ) {
    xTrace0(icmpp, 4, "icmp_demux: invalid checksum -- dropping message");
    return XK_SUCCESS;
  }
  switch(hdr.icmp_type)
    {
    case ICMP_ECHO_REQ:
    case ICMP_INFO_REQ:
      {
	u_short origType;

	xTrace1(icmpp, 3, "icmp_demux: echo/info request with msg length %d",
		msgLength(msg) - sizeof(ICMPEcho));
	origType = hdr.icmp_type;
	hdr.icmp_type =
	  ( origType == ICMP_ECHO_REQ ) ? ICMP_ECHO_REP : ICMP_INFO_REP;
	/*
	 * We can just do an incremental update of the msg checksum rather
	 * than recomputing it.
	 */
	updateCksum((unsigned short *)&hdr.icmp_cksum, origType << 8, hdr.icmp_type << 8);

	buf = msgPush(msg, sizeof(ICMPHeader));
	xAssert(buf);
	icmpHdrStore(&hdr, buf, sizeof(ICMPHeader), 0);
	
	xAssert(! inCkSum(msg, 0, 0));
	xTrace0(icmpp, 3, "icmp_demux: sending reply");
	xPush(s, msg);
      }
      break;

    case ICMP_REDIRECT:
      {
	IPhost addrs[2];
	ICMPRedirect rd;
	VOID *buffer;

	buffer = msgPop(msg, sizeof(ICMPRedirect));
	xAssert(buffer);
	icmpRedirectLoad(&rd, buffer, sizeof(ICMPRedirect), 0);

	addrs[0] = rd.icmp_badmsg.icmp_dest.dest;
	addrs[1] = rd.icmp_gw;
	(void)xControlProtl(xGetProtlDown(self, 0), IP_REDIRECT, (char *)addrs,
		       2*sizeof(IPhost));
	
      }
      break;

    case ICMP_ECHO_REP:
      icmpPopEchoRep(self, msg);
      break;

    case ICMP_DEST_UNRCH:
    case ICMP_SRC_QUENCH:
    case ICMP_TIMEOUT:
    case ICMP_SYNTAX:
    case ICMP_TSTAMP_REQ:
    case ICMP_TSTAMP_REP:
    case ICMP_INFO_REP:
    case ICMP_AMASK_REQ:
    case ICMP_AMASK_REP:
      xTrace1(icmpp,3,"I can't handle ICMP packet type %d!\n", hdr.icmp_type);
      break;
      
    default:
      xTrace1(icmpp,3,"ICMP drops nonexistent ICMP message type %d!",
	      hdr.icmp_type);
    }
  return XK_SUCCESS;
}


static int
icmp_controlSessn(s, opCode, buf, len)
    Sessn s;
    int opCode;
    char *buf;
    int len;
{
  xAssert(xIsSessn(s));
  switch (opCode) {
    case ICMP_ECHO_CTL:
      return icmpSendEchoReq(s, *(int *)buf);
    case GETMAXPACKET:
    case GETOPTPACKET:
      /* 
       * These operations are probably only relevant for Echo's and
       * information requests, so we'll subtract that amount from the
       * lls's result.
       */
      if ( xControlSessn(xGetSessnDown(s, 0), opCode, buf, len) <= sizeof(int) ) {
	  return -1;
      }
      *(int *)buf -= sizeof(ICMPHeader) + sizeof(ICMPEcho);
    case GETMYPROTO:
    case GETPEERPROTO:
      return 0;
    default:
      /*
       * Unknown or unimplemented control operation -- send to down session
       */
      return xControlSessn(xGetSessnDown(s, 0), opCode, buf, len);
    }
}


/* 
 * controlProtl -- ICMP doesn't implement any control operations,
 * just forwards them to the lower protocol.
 */
static int
controlProtl(s, opCode, buf, len)
    Protl s;
    int opCode;
    char *buf;
    int len;
{
    return xControlProtl(xGetProtlDown(s, 0), opCode, buf, len);
}


/*
 * icmpHdrLoad -- loads hdr from msg.  Checksum is computed over the
 * entire message and written in the checksum field of the load struct
 * (passed through 'arg')
 */
static long
icmpHdrLoad(hdr, src, len, arg)
    VOID *hdr;
    char *src;
    long int len;
    VOID *arg;
{
    xAssert(len == sizeof(ICMPHeader));
    bcopy(src, (char *)hdr, sizeof(ICMPHeader));
    return sizeof(ICMPHeader);
}  


/*
 * icmpHdrStore -- stores hdr onto msg.
 *
 * If arg is NULL, checksum is assumed to be already computed.
 *
 * Otherwise arg should point to the message and the checksum is computed
 * over the entire message.  In this case the checksum field of *hdr will
 * be modified.
 */
void
icmpHdrStore(hdr, dst, len, arg)
    VOID *hdr;
    char *dst;
    long int len;
    VOID *arg;
{
    xAssert(len == sizeof(ICMPHeader));
    if (arg) {
	((ICMPHeader *)hdr)->icmp_cksum = 0;
	bcopy((char *)hdr, dst, sizeof(ICMPHeader));
	((ICMPHeader *)hdr)->icmp_cksum = inCkSum((Msg *)arg, 0, 0);
	bcopy((char *)hdr, dst, sizeof(ICMPHeader));
	xAssert(! inCkSum((Msg *)arg, 0, 0));
    } else {
	bcopy((char *)hdr, dst, sizeof(ICMPHeader));
    }
}  


long
icmpEchoLoad(hdr, src, len, arg)
    VOID *hdr;
    char *src;
    long int len;
    VOID *arg;
{
    xAssert(len == sizeof(ICMPEcho));
    bcopy(src, (char *)hdr, sizeof(ICMPEcho));
    ((ICMPEcho *)hdr)->icmp_id = ntohs(((ICMPEcho *)hdr)->icmp_id);
    ((ICMPEcho *)hdr)->icmp_seqnum = ntohs(((ICMPEcho *)hdr)->icmp_seqnum);
    return sizeof(ICMPEcho);
}


/*
 * Note: the fields of *hdr will be modified
 */
void
icmpEchoStore(hdr, dst, len, arg)
    VOID *hdr;
    char *dst;
    long int len;
    VOID *arg;
{
    xAssert(len == sizeof(ICMPEcho));
    ((ICMPEcho *)hdr)->icmp_id = ntohs(((ICMPEcho *)hdr)->icmp_id);
    ((ICMPEcho *)hdr)->icmp_seqnum = ntohs(((ICMPEcho *)hdr)->icmp_seqnum);
    bcopy((char *)hdr, dst, sizeof(ICMPEcho));
}


static long
icmpRedirectLoad(hdr, src, len, arg)
    VOID *hdr;
    char *src;
    long int len;
    VOID *arg;
{
    xAssert(len == sizeof(ICMPRedirect));
    bcopy(src, (char *)hdr, sizeof(ICMPRedirect));
    return sizeof(ICMPRedirect);
}


static void
getProcSessn(s)
    Sessn s;
{
  s->controlsessn = icmp_controlSessn;
  s->close = icmp_close;
}


static void
getProcProtl(s)
    Protl s;
{
  s->open = icmp_open;
  s->demux = icmp_demux;
  s->controlprotl = controlProtl;
}
