/* 
 * $RCSfile: udp.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: udp.h,v $
 * Revision 1.2  1996/01/29 20:13:09  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:32:09  slm
 * Initial revision
 *
 * Revision 1.9.3.1  1994/11/02  00:15:19  hkaram
 * New branch
 *
 * Revision 1.9  1994/01/10  17:53:33  menze
 *   [ 1994/01/05          menze ]
 *   PROTNUM changed to PORTNUM
 */

#ifndef udp_h
#define udp_h

#ifndef ip_h
#include "ip.h"
#endif

#define UDP_ENABLE_CHECKSUM (UDP_CTL * MAXOPS + 0)
#define UDP_DISABLE_CHECKSUM (UDP_CTL * MAXOPS + 1)
#define UDP_GETFREEPORTNUM	(UDP_CTL * MAXOPS + 2)
#define UDP_RELEASEPORTNUM	(UDP_CTL * MAXOPS + 3)

#  ifdef __STDC__

void	udp_init(Protl);

#  endif


#endif
