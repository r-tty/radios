/* 
 * $RCSfile: arp_rom.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: arp_rom.c,v $
 * Revision 1.2  1996/01/29 21:59:42  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:58:36  slm
 * Initial revision
 *
 * Revision 1.2.1.1.1.1  1994/10/27  01:28:56  hkaram
 * New branch
 *
 * Revision 1.2.1.1  1994/03/14  23:15:25  umass
 * Uses MAC48BitHosts instead of ETHhosts
 */

/*
 * initialize table from ROM entries
 */

#include "xkernel.h"
#include "arp.h"
#include "arp_i.h"
#include "arp_table.h"
#include "romopt.h"
#include "sim.h"

#ifdef __STDC__

static XkReturn loadEntry( Protl, char **, int, int, VOID * );

#else

static XkReturn loadEntry();

#endif



static ProtlRomOpt arpOpts[] = {
    { "", 3, loadEntry }
};
 

static XkReturn
loadEntry( self, str, nFields, line, arg )
    Protl	self;
    char	**str;
    int		nFields, line;
    VOID	*arg;
{
    MAC48bithost genericHost;
    IPhost	 ipHost;
    PSTATE	 *ps = (PSTATE *)self->state;
    int		 nextField;

    if ( str2ipHost(&ipHost, str[1]) == XK_FAILURE )
    	return XK_FAILURE;
    if ( str2mac48bitHost(&genericHost, str[2]) == XK_SUCCESS ) {
	nextField = 3;
    } else {
	/* 
	 * Second field isn't an Ethernet/FDDI address.  See if it's
	 * one of the alternate ways of specifying a hardware address
	 * (there is currently only one alternate)
	 */
	{
	    /* 
	     * Look for SIM address, an IP-host/UDP-port pair
	     */
	    SimAddrBuf	buf;

	    if ( nFields < 4 ) return XK_FAILURE;
	    if ( str2ipHost(&buf.ipHost, str[2]) == XK_FAILURE ) {
		return XK_FAILURE;
	    }
	    if ( sscanf(str[3], "%d", &buf.udpPort) < 1 ) {
		return XK_FAILURE;
	    }
	    if ( xControlProtl(xGetProtlDown(self, 0), SIM_SOCK2ADDR,
			  (char *)&buf, sizeof(buf)) < 0 ) {
		xTraceP0(self, TR_ERRORS, "llp couldn't translate rom entry");
		return XK_FAILURE;
	    }
	    bcopy((char *)&buf.genericHost, (char *)&genericHost, 
	          sizeof(MAC48bithost));
	    nextField = 4;
	}
    }
    arpSaveBinding( ps->tbl, &ipHost, &genericHost );
    xTraceP1(self, TR_MAJOR_EVENTS, "loaded (%s) from rom file",
	    ipHostStr(&ipHost));
    xTraceP1(self, TR_MAJOR_EVENTS, "corresponding ETH/FDDI address: %s",
	    mac48bitHostStr(&genericHost));

    if ( nFields > nextField ) {
	if ( ! strcmp(str[nextField], "lock") ) {
	    arpLock(ps->tbl, &ipHost);
	} else {
	    return XK_FAILURE;
	}
    }
    return XK_SUCCESS;
}


void
arpPlatformInit( self )
    Protl self;
{
    /*
     * Check the rom file for arp initialization 
     */
    findProtlRomOpts(self, arpOpts, sizeof(arpOpts)/sizeof(ProtlRomOpt), 0);
}
