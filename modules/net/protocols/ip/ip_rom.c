/*     
 * $RCSfile: ip_rom.c,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: ip_rom.c,v $
 * Revision 1.2  1996/01/29 22:19:34  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:27:12  slm
 * Initial revision
 *
 * Revision 1.5.1.1  1994/10/27  01:20:59  hkaram
 * New branch
 *
 * Revision 1.5  1994/01/27  17:09:23  menze
 *   [ 1994/01/13          menze ]
 *   Now uses library routines for rom options
 */

/* 
 * ROM file processing
 */


#include "xkernel.h"
#include "ip_i.h"
#include "romopt.h"

#ifdef __STDC__

static XkReturn   gwOpt( Protl, char **, int, int, VOID * );

#else

static XkReturn   gwOpt();

#endif /* __STDC__ */


static ProtlRomOpt	rOpts[] = {
    { "gateway", 3, gwOpt }
};


static XkReturn
gwOpt( self, str, nFields, line, arg )
    Protl	self;
    char	**str;
    int		nFields, line;
    VOID	*arg;
{
    IPhost	iph;

    if ( str2ipHost(&iph, str[2]) == XK_FAILURE ) {
	return XK_FAILURE;
    }
    ipSiteGateway = iph;
    xTraceP1(self, TR_EVENTS, "loaded default GW %s from rom file",
	    ipHostStr(&ipSiteGateway));
    return XK_SUCCESS;
}


void
ipProcessRomFile( self )
    Protl	self;
{
    findProtlRomOpts(self, rOpts, sizeof(rOpts)/sizeof(ProtlRomOpt), 0);
}
