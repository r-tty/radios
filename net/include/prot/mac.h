/*
 * $RCSfile: mac.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: mac.h,v $
 * Revision 1.2  1996/01/29 20:12:10  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:32:09  slm
 * Initial revision
 *
 * Revision 1.2.1.1  1994/11/02  00:14:31  hkaram
 * New branch
 *
 * Revision 1.2  1994/03/14  19:26:37  menze
 *   [ 1994/02/10          yates ]
 *   Changed generic host to 48 bit mac host; moved definitions to mac.h.
 *
 *   [ 1994/01/18          yates ]
 *   Changed ethHost to genericHost; removed MAC_IS_REAL_DRIVER.
 *
 * Revision 1.1  1993/12/15  23:04:38  menze
 * Initial revision
 */

#ifndef mac_h
#define mac_h

/*
 * Type definition for generic 48 bit MAC address.
 */

typedef struct {
    unsigned short high;
    unsigned short mid;
    unsigned short low;
} MAC48bithost;

#define MAC48BIT_ADDRS_EQUAL(A,B) ((A).high==(B).high  && \
                                   (A).mid==(B).mid &&    \
                                   (A).low==(B).low)

#define BCAST_MAC48BIT_ADDRESS { 0xffff, 0xffff, 0xffff }

#ifdef __STDC__
extern XkReturn str2mac48bitHost(MAC48bithost *, char *);
extern char     *mac48bitHostStr(MAC48bithost *);
#else
extern XkReturn str2mac48bitHost();
extern char     *mac48bitHostStr();
#endif

#define MAC_SETPROMISCUOUS   (MAC_CTL * MAXOPS + 0)
#define MAC_CLEARPROMISCUOUS (MAC_CTL * MAXOPS + 1)
#define MAC_REGISTER_ARP     (MAC_CTL * MAXOPS + 2)
#define MAC_DUMP_STATS       (MAC_CTL * MAXOPS + 3)

#endif /* ! mac_h */
