/* 
 * eth_host.h
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 20:10:48 $
 */


#ifndef eth_host_h
#define eth_host_h

/* Address types */
typedef struct {
    unsigned short	high;
    unsigned short	mid;
    unsigned short	low;
} ETHhost, ethAd_t;

#endif /* eth_host_h */
