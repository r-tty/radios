/* 
 * ip.h
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 20:10:48 $
 */

#ifndef ip_h
#define ip_h

#include "upi.h"
#include "ip_host.h"


typedef struct ippseudohdr {
  IPhost src;
  IPhost dst;
  u_char zero;
  u_char prot;
  u_short len;
} IPpseudoHdr;

typedef struct iprouteinfo {
  IPhost	net;
  IPhost	mask;
  IPhost	gw;
  int 		metric;
  int 		ttl;
} IProuteInfo;

/*
 * IP control opcodes
 */
#define IP_MYNET	(IP_CTL*MAXOPS+0)
#define IP_REDIRECT	(IP_CTL*MAXOPS+1)
#define IP_GETRTINFO    (IP_CTL*MAXOPS+2)
#define IP_PSEUDOHDR    (IP_CTL*MAXOPS+3)
#define IP_GETPSEUDOHDR    (IP_CTL*MAXOPS+4)
#define IP_CHANGEROUTE    (IP_CTL*MAXOPS+5)
#define IP_SETSOURCEADDR    (IP_CTL*MAXOPS+6)

#define IP_LOCAL_BCAST_HOST	{ 255, 255, 255, 255 }

#define IP_ADS_BCAST(A)		((A).d == 0xff || (A).d == 0)

#  ifdef __STDC__

void	ip_init(Protl);

#  endif


#endif
