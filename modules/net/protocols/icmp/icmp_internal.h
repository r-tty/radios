/*
 * icmp_internal.h
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:15:40 $
 */

#include "ip.h"
#include "ip_i.h"

typedef struct icmp_hdr {
	u_char	icmp_type;	
	u_char	icmp_code;	
	short	icmp_cksum;
} ICMPHeader;

typedef struct common_prefix {
	u_short   icmp_id;
	u_short   icmp_seqnum;
	/* ignoring data part */
} ICMPPrefix, ICMPEcho, ICMPInfoReq, ICMPInfoReply;

typedef struct offending_dg {
	IPheader	icmp_dest;
/*
 * Yes, options might be there, but we don't use them even if they are
 * and their presence in this structure causes msgPop to wretch if they
 * aren't there.
 */
#if 0
	char		icmp_bits[48]; /* includes 40 octets for options */
#endif
} ICMPBadMsg;


typedef struct common_format {
  u_long	icmp_zero;
  ICMPBadMsg	icmp_badmsg;
} ICMPUnreach, ICMPSourceQuench, ICMPTimeout;


typedef struct redirect {
  IPhost	icmp_gw;
  ICMPBadMsg	icmp_badmsg;
} ICMPRedirect;

typedef struct bad_param {
  u_char	icmp_pointer;
  u_char	icmp_zero[3];
  ICMPBadMsg	icmp_badmsg;
} ICMPSyntaxError;

typedef struct timestamps {
  ICMPPrefix	icmp_prefix;
  u_long	icmp_originate;
  u_long	icmp_receive;
  u_long	icmp_transmit;
} ICMPTimeStamp;


typedef struct {
  u_short 	sessId;
  Binding	bind;
  int		result;
  Semaphore	replySem;
  Event		timeoutEvent;
  u_short	seqNum;
} Sstate;

typedef struct {
  Map 		waitMap;
  u_short 	sessionsCreated;
} Pstate;

typedef struct {
  Msg		*msg;
  u_short 	sum;
} loadInfo;

typedef struct {
  u_short 	id;
  u_short	seq;
} mapId;


#ifdef __STDC__

int 	icmpSendEchoReq(Sessn, int);
void 	icmpPopEchoRep(Protl, Msg *);
void 	icmpHdrStore(void *, char *, long, void *);
void 	icmpEchoStore(void *, char *, long, void *);
long 	icmpEchoLoad(void *, char *, long, void *);

#else

int 	icmpSendEchoReq();
void 	icmpPopEchoRep();
void 	icmpHdrStore();
void 	icmpEchoStore();
long 	icmpEchoLoad();

#endif


extern int traceicmpp;

#define REQ_TIMEOUT 15000	/* 15 seconds */
