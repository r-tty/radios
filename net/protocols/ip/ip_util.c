/*     
 * ip_util.c
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:19:34 $
 */

/* 
 * Internal IP utility functions
 */

#include "xkernel.h"
#include "ip_i.h"


int
ipHostOnLocalNet( ps, host )
    PState	*ps;
    IPhost	*host;
{
    int		res;
    Protl	llp;

    llp = xGetProtlDown(ps->self, 0);
    xAssert(xIsProtl(llp));
    res = xControlProtl(llp, VNET_HOSTONLOCALNET, (char *)host, sizeof(IPhost));
    if ( res > 0 ) {
	return 1;
    }
    if ( res < 0 ) {
	xTrace0(ipp, TR_ERRORS, "ip could not do HOSTONLOCALNET call on llp");
    }
    return 0;
}



/*
 * ismy_addr:  is this IP address one which should reach me
 * (my address or broadcast)
 */
int
ipIsMyAddr( self, h )
    Protl	self;
    IPhost	*h;
{
    Protl	llp = xGetProtlDown(self, 0);
    int		r;
    
    r = xControlProtl(llp, VNET_ISMYADDR, (char *)h, sizeof(IPhost));
    if ( r > 0 ) {
	return 1;
    }
    if ( r < 0 ) {
	xError("ip couldn't do VNET_ISMYADDR on llp");
    }
    return 0;
}



