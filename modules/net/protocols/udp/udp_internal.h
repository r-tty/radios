/*
 * $RCSfile: udp_internal.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: udp_internal.h,v $
 * Revision 1.2  1996/01/29 22:38:16  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:19:18  slm
 * Initial revision
 *
 * Revision 1.13.2.1  1994/10/27  01:57:28  hkaram
 * New branch
 *
 * Revision 1.13  1993/12/07  00:59:41  menze
 * Now uses IP_GETPSEUDOHDR to determine protocol number relative to IP,
 * so llpProtNum no longer stored in protocol state
 */

#include "udp_port.h"

#define	HLEN	(sizeof(HDR))

typedef struct header {
    UDPport 	sport;	/* source port */
    UDPport 	dport;	/* destination port */
    u_short 	ulen;	/* udp length */
    u_short	sum;	/* udp checksum */
} HDR;

typedef struct pstate {
    Map   	activemap;
    Map		passivemap;
    VOID	*portstate;
} PSTATE;

typedef struct sstate {
    HDR         hdr;
    IPpseudoHdr	pHdr;
    u_char	useCkSum;
} SSTATE;

/*
 * The active map is keyed on the pair of ports and the lower level IP
 * session.
 */
typedef struct {
    UDPport   	localport;
    UDPport  	remoteport;
    Sessn	lls;
} ActiveId;

/*
 * The key for the passive map is just the local UDP port number.
 */
typedef UDPport PassiveId;

#define USE_CHECKSUM_DEF 0


