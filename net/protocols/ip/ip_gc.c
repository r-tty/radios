/*     
 * ip_gc.c
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:19:34 $
 */

/*
 * When fragments of IP messages are lost, the resources dedicated to
 * the reassembly of those messages remain allocated.  This code scans
 * throught the fragment map looking for such fragments and deallocates
 * their resources.
 */

#include "xkernel.h"
#include "ip_i.h"

/*
 * Trace levels
 */
#define GC1 TR_EVENTS
#define GC2 TR_MORE_EVENTS

#ifdef __STDC__

static char *	fragIdStr( FragId *, char * );
static void	ipFragCollect( Event, void * );
static int	markFrag( void *, void *, void * );

#else

static char *	fragIdStr();
static void	ipFragCollect();
static int	markFrag();

#endif /* __STDC__ */


void
scheduleIpFragCollector(pstate)
    PState *pstate;
{
    evDetach( evSchedule( ipFragCollect, pstate, IP_GC_INTERVAL ) );
}


#ifdef XK_DEBUG

static char *
fragIdStr(key, buf)
    FragId *key;
    char *buf;
{
    sprintf(buf, "s: %s  d: %s  p: %d  seq: %d",
	    ipHostStr(&key->source), ipHostStr(&key->dest),
	    key->prot, key->seqid);
    return buf;
}

#endif /* XK_DEBUG */



static int
markFrag(key, value, arg)
    VOID *key;
    VOID *value;
    VOID *arg;
{
    FragList	*list = (FragList *)value;
    PState	*pstate = (PState *)arg;
    XkReturn	xkr;
#ifdef XK_DEBUG
    char	buf[80];
#endif

    if ( list->gcMark ) {
	xTrace1(ipp, GC2, "IP GC removing %s", fragIdStr(key, buf));
	xkr = mapRemoveBinding(pstate->fragMap, list->binding);
	if ( xkr != XK_SUCCESS ) {
	    xTrace0(ipp, TR_ERRORS, "IP GC couldn't unbind!");
	}
	ipFreeFragList(list);
    } else {
	xTrace1(ipp, GC2, "IP GC marking  %s", fragIdStr(key, buf));
	list->gcMark = TRUE;
    }
    return MFE_CONTINUE;
}


static void
ipFragCollect(ev, arg)
    Event	ev;
    VOID 	*arg;
{
    PState	*pstate = (PState *)arg;

    xTrace0(ipp, GC1, "IP fragment garbage collector");
    mapForEach(pstate->fragMap, markFrag, pstate);
    scheduleIpFragCollector(pstate);
    xTrace0(ipp, GC2, "IP GC exits");
}
