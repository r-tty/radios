/*
 * $RCSfile: icmp_reqrep.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: icmp_reqrep.c,v $
 * Revision 1.2  1996/01/29 22:15:40  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:14:39  slm
 * Initial revision
 *
 * Revision 1.17.2.4  1994/12/02  18:13:51  hkaram
 * Changed to new mapResolve interface
 *
 * Revision 1.17.2.3  1994/11/22  21:00:08  hkaram
 * Added cast to mapResolve calls
 *
 * Revision 1.17.2.2  1994/10/27  01:54:10  hkaram
 * Merged changes from Davids version.
 *
 * Revision 1.17  1993/12/13  22:48:49  menze
 * Modifications from UMass:
 *
 *   [ 93/11/12          yates ]
 *   Changed casting of Map manager calls so that the header file does it all.
 */

/*
 * coordination of ICMP requests and replies
 */

#include "xkernel.h"
#include "icmp.h"
#include "icmp_internal.h"

#ifdef __STDC__

static void 	echoReqTimeout( Event, void * );
static void	signalWaiter( Sstate *st, int res );

#else

static void 	echoReqTimeout();
static void	signalWaiter();

#endif

int
icmpSendEchoReq(s, msgLen)
    Sessn s;
    int msgLen;
{
  Msg msg;
  char *b;
  ICMPEcho echoHdr;
  ICMPHeader stdHdr;
  Pstate *pstate = (Pstate *)s->myprotl->state;
  Sstate *sstate = (Sstate *)s->state;
  mapId key;
  VOID *buf;
  
  b = msgConstructAllocate(&msg, msgLen);
  echoHdr.icmp_id = sstate->sessId;
  echoHdr.icmp_seqnum = sstate->seqNum;

  buf = msgPush(&msg, sizeof(ICMPEcho));
  xAssert(buf);
  icmpEchoStore(&echoHdr, buf, sizeof(ICMPEcho), 0);

  stdHdr.icmp_type = ICMP_ECHO_REQ;
  stdHdr.icmp_code = 0;

  buf = msgPush(&msg, sizeof(ICMPHeader));
  xAssert(buf);
  icmpHdrStore(&stdHdr, buf, sizeof(ICMPHeader), &msg);

  key.id = echoHdr.icmp_id;
  key.seq = echoHdr.icmp_seqnum;
  sstate->bind = mapBind(pstate->waitMap, &key, s);
  xPush(xGetSessnDown(s, 0), &msg);
  sstate->timeoutEvent = evSchedule(echoReqTimeout, s, REQ_TIMEOUT * 1000);
  msgDestroy(&msg);
  semWait(&sstate->replySem);
  return sstate->result;
}


void
icmpPopEchoRep(self, msg)
    Protl self;
    Msg *msg;
{
  Pstate *pstate = (Pstate *)self->state;
  Sstate *sstate;
  ICMPEcho echoHdr;
  mapId key;
  VOID *buf;
  Sessn s;
  
  xAssert(xIsProtl(self));
  xTrace0(icmpp, 3, "ICMP echo reply received");

  buf = msgPop(msg, sizeof(ICMPEcho));
  xAssert(buf);
  icmpEchoLoad(&echoHdr, buf, sizeof(ICMPEcho), 0);

  key.id = echoHdr.icmp_id;
  key.seq = echoHdr.icmp_seqnum;
  xTrace3(icmpp, 4, "id = %d, seq = %d, data len = %d",
	  key.id, key.seq, msgLength(msg));
  if (mapResolve(pstate->waitMap, &key, (void **)&s) == XK_FAILURE) {
    xTrace1(icmpp, 3, "ICMP echo reply received for nonexistent session %x",
	    echoHdr.icmp_id);
    return;
  }
  sstate = (Sstate *)s->state;
  if (evCancel(sstate->timeoutEvent) == 1) {
    /*
     * Timeout event will not run
     */
    mapRemoveBinding(pstate->waitMap, sstate->bind);
    signalWaiter(sstate, 0);
  }
}


static void
echoReqTimeout(ev, arg)
    Event	ev;
    VOID 	*arg;
{
  Sessn	s = (Sessn)arg;    
  Sstate *sstate;
  Pstate *pstate;

  xTrace1(icmpp, 3, "ICMP Request timeout for session %x", s);
  xAssert(xIsSessn(s));
  sstate = (Sstate *)s->state;
  pstate = (Pstate *)s->myprotl->state;
  mapRemoveBinding(pstate->waitMap, sstate->bind);
  signalWaiter(sstate, -1);
}


static void
signalWaiter(st, res)
    Sstate *st;
    int res;
{
  st->result = res;
  st->seqNum++;
  semSignal(&st->replySem);
}
