/*
 * $RCSfile: iproute.c,v $
 * 
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: iproute.c,v $
 * Revision 1.3  1996/01/29 22:19:34  slm
 * Updated copyright and version.
 *
 * Revision 1.2  1995/09/29  21:54:18  davidm
 * rt_get: changed casts from (u_long*) to (xk_u_int32) as IPv4 addresses
 * are 32 bits long.
 *
 * Revision 1.1  1995/07/28  22:27:12  slm
 * Initial revision
 *
 * Revision 1.26.3.1  1994/10/27  01:21:03  hkaram
 * New branch
 *
 * Revision 1.26  1994/04/20  22:51:29  davidm
 * (rt_init): Added initialization of "tbl->defrt."
 *
 * Revision 1.25  1993/12/16  01:30:22  menze
 * Fixed function parameters to compile with strict ANSI restrictions
 */

#include "xkernel.h"
#include "eth.h"
#include "ip.h"
#include "route.h"
#include "ip_i.h"
#include "arp.h"
#include "route_i.h"

#ifdef __STDC__

static route *	rt_alloc( RouteTable * );
static void	rt_free( RouteTable *, route * );
static int	rt_hash(IPhost *);
static route *	rt_new(RouteTable *, IPhost *, IPhost *, IPhost *, int, int);
static void	rt_timer( Event, void * );

#else

static route *	rt_alloc();
static void	rt_free();
static int	rt_hash();
static route *	rt_new();
static void	rt_timer();

#endif /* __STDC__ */

static IPhost	ipNull = { 0, 0, 0, 0 };


XkReturn
rt_init( ps, defGw)
    PState *ps;
    IPhost *defGw;
{
    RouteTable	*tbl = &ps->rtTbl;
    
    xTrace0(ipp, TR_GROSS_EVENTS, "IP rt_init()");
    tbl->valid = TRUE;
    tbl->defrt = 0;
    tbl->arr = (route **)xMalloc(ROUTETABLESIZE * sizeof(route *));
    bzero((char *)tbl->arr, ROUTETABLESIZE * sizeof(route *));
    tbl->bpoolsize = BPSIZE;
    if ( IP_EQUAL(*defGw, ipNull) ) {
	xTrace0(ipp, TR_GROSS_EVENTS,
		"IP routing -- default routing disabled");
    } else {
	if ( rt_add_def(ps, defGw) ) {
	    return XK_FAILURE;
	}
    }
    evDetach( evSchedule( rt_timer, tbl, RTTABLEUPDATE * 1000 ) );
    xTrace0(ipp, TR_GROSS_EVENTS, "IP rt_init() done");
    return XK_SUCCESS;
}


static route *
rt_alloc( tbl )
    RouteTable	*tbl;
{
    if ( tbl->bpoolsize == 0 ) {
	xTrace0(ipp, TR_SOFT_ERRORS, "ip rt_alloc ... route table is full");
	return 0;
    }
    tbl->bpoolsize--;
    return (route *)xMalloc(sizeof(route));
}


static route *
rt_new(tbl, net, mask, gw, metric, ttl)
    RouteTable	*tbl;
    IPhost *net;
    IPhost *mask;
    IPhost *gw;
    int metric;
    int ttl;
{
    route *ptr;
    
    ptr = rt_alloc(tbl);
    if ( ptr ) {
	ptr->net = *net;
	ptr->mask = *mask;
	ptr->gw = *gw;
	ptr->metric = metric;
	ptr->ttl = ttl;
	ptr->next = NULL;
    }
    return ptr;
}


XkReturn
rt_add_def( ps, gw )
    PState *ps;
    IPhost *gw;
{
    RouteTable	*tbl = &ps->rtTbl;

    xTrace1(ipp, TR_MAJOR_EVENTS,
	    "IP default route changes.  New GW: %s", ipHostStr(gw));
    if ( ! IP_EQUAL(*gw, ipNull) && ! ipHostOnLocalNet(ps, gw) ) {
	xTrace1(ipp, TR_SOFT_ERRORS,
		"ip: rt_add_def couldn't find interface for gw %s",
		ipHostStr(gw));
	return XK_FAILURE;
    }
    if ( tbl->defrt ) {
	rt_free(tbl, tbl->defrt);
    }
    if ( ! IP_EQUAL(*gw, ipNull) ) {
	tbl->defrt = rt_new( tbl, &ipNull, &ipNull, gw, 1,  0 );
	if ( tbl->defrt == 0 ) {
	    return XK_FAILURE;
	}
	/*
	 * Re-open the connection for every remote host not connected to the
	 * local net.  This is certainly overkill, but:
	 * 		-- it is not incorrect
	 *		-- the default route shouldn't change often
	 *		-- keeping track of which hosts use the default route
	 *		   is a pain.
	 */
	ipRouteChanged(ps, tbl->defrt, ipRemoteNet);
    }
    return XK_SUCCESS;
}
  

XkReturn
rt_add( pstate, net, mask, gw, metric, ttl )
    PState *pstate;
    IPhost *net;
    IPhost *mask;
    IPhost *gw;
    int metric;
    int ttl;
{
    route 	*ptr, *srt, *prev;
    u_char  	isdup;
    int  	j;
    u_long 	hashvalue;
    RouteTable	*tbl = &pstate->rtTbl;
    
    ptr = rt_new(tbl, net, mask, gw, metric, ttl);
    if ( ptr == 0 ) {
	return XK_FAILURE;
    }
    
    /* compute sort key - number of set bits in mask 
       so that route are sorted : host, subnet, net */
    for (j = 0; j < 8; j++)
      ptr->key += ((mask->a >> j) & 1) + 
	((mask->b >> j) & 1) +
	  ((mask->c >> j) & 1) +
	    ((mask->d >> j) & 1) ;
    
    prev = NULL;
    hashvalue = rt_hash(net);
    xTrace1(ipp, TR_MORE_EVENTS, "IP rt_add : hash value is %d", hashvalue);
    isdup = FALSE;
    for ( srt = tbl->arr[hashvalue]; srt; srt = srt->next ) {
	if ( ptr->key > srt->key )
	  break;
	if ( IP_EQUAL(srt->net, ptr->net) && 
	    IP_EQUAL(srt->mask, ptr->mask) ) {
	    isdup = TRUE;
	    break;
	}
	prev = srt;
    }
    if ( isdup ) {
	route *tmptr;
	if ( IP_EQUAL(srt->gw, ptr->gw) ) {
	    /* update existing route */
	    xTrace0(ipp, TR_MORE_EVENTS, "IP rt_add: updating existing route");
	    srt->metric = metric;
	    srt->ttl = ttl;
	    rt_free(tbl, ptr);
	    return XK_SUCCESS;
	}
	/* otherwise someone else has a route there */
	/*
	 * negative metric indicates unconditional override
	 */
	if ( ptr->metric > 0 && srt->metric <= ptr->metric ) {
	    /* it's no better, just drop it */
	    xTrace0(ipp, TR_MORE_EVENTS,
		    "IP rt_add : dropping duplicate route with greater metric");
	    rt_free(tbl, ptr);
	    return XK_SUCCESS;
	}
	xTrace0(ipp, TR_MORE_EVENTS,
		"IP rt_add: new duplicate route better, deleting old");
	tmptr = srt;
	srt = srt->next;
	rt_free(tbl, tmptr);
    } else {
	xTrace0(ipp, TR_MORE_EVENTS, "IP rt_add: adding fresh route");
    }
    ipRouteChanged(pstate, ptr, ipSameNet);
    ptr->next = srt;
    if ( prev ) {
	prev->next = ptr;
    } else {
	tbl->arr[hashvalue] = ptr;
    }
    return XK_SUCCESS; 
} /* rt_add */


XkReturn
rt_get( tbl, dest, req )
    RouteTable	*tbl;
    IPhost 	*dest;
    route	*req;
{
    route *ptr;
    u_long hashvalue;
    xk_u_int32 sum;
    IPhost fdest;
    
    hashvalue = rt_hash(dest);
    xTrace1(ipp, TR_MORE_EVENTS, "IP rt_get: hash value is %d",hashvalue);
    for( ptr = tbl->arr[hashvalue]; ptr; ptr = ptr->next ) {
	if ( ptr->ttl == 0 )
	  continue;
	sum =  *(xk_u_int32 *)dest & *(xk_u_int32 *)&(ptr->mask);
	fdest = *(IPhost *) &sum;
	if ( IP_EQUAL(fdest,ptr->net) )
	  break;
    }
    if ( ptr == 0 ) {
	ptr = tbl->defrt;
    }
    if ( ptr ) {
	*req = *ptr;
	xTrace3(ipp, TR_MORE_EVENTS,
		"IP rt_get : Mapped host %s to net %s, gw %s",
		ipHostStr(dest), ipHostStr(&ptr->net), ipHostStr(&ptr->gw));
	return XK_SUCCESS;
    } else {
	xTrace1(ipp, TR_SOFT_ERRORS,
		"IP rt_get: Could not find route for host %s!",
		ipHostStr(dest));
	return XK_FAILURE;
    }
}


void
rt_delete( tbl, net, mask )
    RouteTable	*tbl;
    IPhost 	*net, *mask;
{
    route *ptr, *prev;
    u_long  hashvalue; 
    
    hashvalue = rt_hash(net);
    prev = NULL;
    for ( ptr = tbl->arr[hashvalue]; ptr; ptr = ptr->next ) {
	if ( IP_EQUAL(*net, ptr->net) &&
	    IP_EQUAL(*mask, ptr->mask) )
	  break;
	prev = ptr;
    }
    if ( ptr == NULL ) {
	return;
    }
    if ( prev )
      prev->next = ptr->next;
    else
      tbl->arr[hashvalue] = ptr->next;
    rt_free(tbl, ptr);
    return;
}


/* hash value is sum of net portions of IP address */
static int
rt_hash( net )
     IPhost *net;
{
    IPhost	mask;
    u_long 	hashvalue;
    
    netMaskFind(&mask, net);
    IP_AND(mask, mask, *net);
    hashvalue = mask.a + mask.b + mask.c + mask.d;
    return (hashvalue % ROUTETABLESIZE);
}


static void
rt_free(tbl, rt)
    RouteTable	*tbl;
    route 	*rt;
{
    tbl->bpoolsize++;
    xFree((char *)rt);
}


static void
rt_timer(ev, arg)
    Event	ev;
    VOID 	*arg;
{
    RouteTable	*tbl = (RouteTable *)arg;
    route 	*ptr, *prev;
    int 	i;
    
    xTrace0(ipp, TR_EVENTS, "IP rt_timer called");
    for ( i = 0; i < ROUTETABLESIZE; i++) {
	if ( tbl->arr[i] == 0 ) {
	    continue;
	}
	prev = NULL;
	for ( ptr = tbl->arr[i]; ptr; ) {
	    if ( ptr->ttl != IPROUTE_TTL_INFINITE ) {
		ptr->ttl -= RTTABLEDELTA;
	    }
	    if ( ptr->ttl == 0 ) {
		if ( prev ) {
		    prev->next = ptr->next;
		    rt_free(tbl, ptr);
		    ptr = prev->next;
		} else {
		    tbl->arr[i] = ptr->next;
		    rt_free(tbl, ptr);
		    ptr = tbl->arr[i];
		}
		continue;
	    }
	    prev = ptr;
	    ptr = ptr->next;
	}
    }
    /*
     * Reschedule this event
     */
    evDetach( evSchedule( rt_timer, tbl, RTTABLEUPDATE * 1000 ) );
}
