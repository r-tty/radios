/* 
 * $RCSfile: eth_i.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: eth_i.h,v $
 * Revision 1.2  1996/01/29 22:13:22  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:12:14  slm
 * Initial revision
 *
 * Revision 1.11.2.1  1994/10/27  01:35:36  hkaram
 * New branch
 *
 * Revision 1.11  1994/01/08  21:33:31  menze
 *   [ 1994/01/03          menze ]
 *   Removed declarations for the obsolete eth protocol-driver interface.
 */

/*
 * Information shared between the ethernet protocol and the driver
 */

#ifndef eth_i_h
#define eth_i_h

#include "eth.h"

extern int traceethp;

/*
 * range of legal data sizes
 */

#define MIN_ETH_DATA_SZ		64


/*
 * Ethernet "types"
 *
 * Ether-speak for protocol numbers is "types."
 * Unfortunately, ether "types" are unsigned shorts,
 * while xkernel PROTLs are ints.
 */

typedef unsigned short				ETHtype, ethType_t;


typedef struct {
    ETHhost	dst;
    ETHhost	src;
    ethType_t	type;
} ETHhdr;

#endif /* ! eth_i_h */
