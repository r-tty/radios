/* 
 * $RCSfile: arp_i.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: arp_i.h,v $
 * Revision 1.2  1996/01/29 21:59:09  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:58:36  slm
 * Initial revision
 *
 * Revision 1.15.1.1.1.1  1994/10/27  01:28:54  hkaram
 * New branch
 *
 * Revision 1.15.1.1  1994/03/14  23:13:01  umass
 * Uses MAC48BitHosts instead of ETHhosts
 */

#ifndef arp_i_h
#define arp_i_h

#include "ip.h"
#include "mac.h"
#include "arp.h"

#define	ARP_HRD	  1
#define	ARP_PROT  0x0800	/* doing IP addresses only */
#define	ARP_HLEN  28		/* the body is null */
#define	ARP_TAB   100		/* arp table size */
#define ARP_TIME  2000		/* 2 seconds */
#define ARP_RTRY  2		/* retries for arp request */
#define ARP_RRTRY 5		/* retries for rarp request */
#define INIT_RARP_DELAY	 5000	/* msec to delay between failed self rarps */

#define	ARP_REQ   1
#define	ARP_RPLY  2
#define	ARP_RREQ  3
#define	ARP_RRPLY 4

#define ARP_MAXOP 4


typedef enum { ARP_ARP, ARP_RARP } ArpType;
typedef enum { ARP_FREE, ARP_ALLOC, ARP_RSLVD } ArpStatus;

typedef struct {
    short  arp_hrd;
    short  arp_prot;
    char   arp_hlen;
    char   arp_plen;
    short  arp_op;
    MAC48bithost arp_sha;
    IPhost       arp_spa;
    MAC48bithost arp_tha;
    IPhost       arp_tpa;
} ArpHdr;


/*
 * An arpWait represents an outstanding request
 */
typedef struct {
    ArpStatus	*status;
    int 	tries;
    Event	event;
    Semaphore 	s;
    int 	numBlocked;
    Protl	self;		/* ARP protocol */
    ArpHdr	reqMsg;		/* ARP requests only */
} ArpWait;


typedef struct ARPprotlstate {
    Protl		rarp;
    struct arpent	*tbl;
    Sessn		arpSessn;
    Sessn		rarpSessn;
    ArpHdr		hdr;
} PSTATE;


#ifdef __STDC__

void		arpPlatformInit( Protl );
void		arpSendRequest( ArpWait * );
void		newArpWait( ArpWait *, Protl, IPhost *, ArpStatus * );
void		newRarpWait( ArpWait *, Protl, MAC48bithost *, ArpStatus * );

#else

void		arpPlatformInit();
void		arpSendRequest();
void		newArpWait();
void		newRarpWait();

#endif


extern int	tracearpp;

#endif /* arp_i_h */
