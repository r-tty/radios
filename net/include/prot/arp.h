/* 
 * arp.h - Address Resolution Protocol header.
 */
 
/*
 * x-kernel v3.3  Copyright (c) 1990-1996  Arizona Board of Regents
 */

#ifndef _ARP_H
#define _ARP_H

#ifndef _UPI_H
#include "upi.h"
#endif
#ifndef _MAC_H
#include "mac.h"
#endif
#ifndef _ETH_H
#include "eth.h"
#endif
#ifndef _IP_H
#include "ip.h"
#endif

void arp_init(Protl);

#define ARP_INSTALL 		( ARP_CTL * MAXOPS + 0 )
#define ARP_GETMYBINDING	( ARP_CTL * MAXOPS + 1 )

typedef struct {
    MAC48bithost   hw;
    IPhost	   ip;
} ArpBinding;


typedef struct {
    VOID		*v;
    ArpForEachFunc	*f;
} ArpForEach;

#define ARP_FOR_EACH		( ARP_CTL * MAXOPS + 2 )

#endif
