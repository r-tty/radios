/* 
 * eth.h - Ethernet protocol header.
 */
 
/*
 * x-kernel v3.3  Copyright (c) 1990-1996  Arizona Board of Regents
 */

#ifndef eth_h
#define eth_h

#include "eth_host.h"


/* Header definitions */

#define ETHHOSTLEN sizeof(ETHhost)

#define ETH_SETPROMISCUOUS	(ETH_CTL*MAXOPS + 0)
#define ETH_REGISTER_ARP	(ETH_CTL*MAXOPS + 1)
#define ETH_DUMP_STATS		(ETH_CTL*MAXOPS + 2)
#define ETH_SET_PRIORITY	(ETH_CTL*MAXOPS + 3)

#define ETH_AD_SZ		sizeof(ETHhost)

#define ETH_ADS_EQUAL(A,B)	((A).high==(B).high\
					&&(A).mid==(B).mid\
					&&(A).low==(B).low)
/* is it a multi cast address? */
#define ETH_ADS_MCAST(A)	((A).high & 0x0100)

#define ZERO_ETH_AD(ad)		{ ad.high = ad.mid = ad.low=0; }

#define	BCAST_ETH_AD	{ 0xffff, 0xffff, 0xffff }

#define	ETH_BCAST_HOST	{ 0xffff, 0xffff, 0xffff }

#define	MAX_ETH_DATA_SZ		1500

#define	MAX_IEEE802_3_DATA_SZ	1500

#  ifdef __STDC__

void	eth_init(Protl);

#  endif

#endif /* eth_h */
