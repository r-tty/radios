/*
 * $RCSfile: tcp_debug.c,v $
 *
 * Derived from:
 *
 * Copyright (c) 1982, 1986 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that this notice is preserved and that due credit is given
 * to the University of California at Berkeley. The name of the University
 * may not be used to endorse or promote products derived from this
 * software without specific prior written permission. This software
 * is provided ``as is'' without express or implied warranty.
 *
 *	@(#)tcp_debug.c	7.2 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: tcp_debug.c,v $
 * Revision 1.2  1996/01/29 22:32:07  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.5.3.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.5  1993/12/16  01:38:38  menze
 * Strict ANSI compilers weren't combining multiple tentative definitions
 * of external variables into a single definition at link time.
 *
 */

#include "tcp_internal.h"
#include "tcp_fsm.h"
#include "tcp_seq.h"
#include "tcp_timer.h"
#include "tcp_var.h"
#include "tcpip.h"
#include "tcp_debug.h"

int	tcpconsdebug = 1;
int	tracetcpp = 0;
struct	tcp_debug tcp_debug[TCP_NDEBUG];
int	tcp_debx = 0;

char *tcpstates[] = {
    "CLOSED",		"LISTEN",	"SYN_SENT",	"SYN_RCVD",
    "ESTABLISHED",	"CLOSE_WAIT",	"FIN_WAIT_1",	"CLOSING",
    "LAST_ACK",		"FIN_WAIT_2",	"TIME_WAIT"
};

static char *tanames[] = {
    "input", "output", "user", "respond", "drop"
};

static char *prurequests[] = {
    "CONNECT", "SLOWTIMO"
};

static char *tcptimers[] = { "REXMT", "PERSIST", "KEEP", "2MSL" };


/*
 * TCP debug routines
 */
void
tcp_trace(act, ostate, ss, ti, req)
     int act, ostate;
     SState *ss;
     struct tcpiphdr *ti;
     int req;
{
    tcp_seq seq, ack;
    int len, flags;
    struct tcp_debug *td = &tcp_debug[tcp_debx++];

    if (tcp_debx == TCP_NDEBUG) {
	tcp_debx = 0;
    } /* if */
/*    td->td_time = iptime(); */
    td->td_act = act;
    td->td_ostate = ostate;
    td->td_tcb = (caddr_t)ss;
    if (ss) {
	td->td_cb = *ss;
    } else {
	bzero((char*)&td->td_cb, sizeof (*ss));
    } /* if */

    if (ti) {
	td->td_ti = *ti;
    } else {
	bzero((char*)&td->td_ti, sizeof (*ti));
    } /* if */
    td->td_req = req;
    if (!tcpconsdebug) {
	return;
    } /* if */
    if (ss) {
	printf("%x %s:", ss, tcpstates[ostate]);
    } else {
	printf("???????? ");
    } /* if */
    printf("%s ", tanames[act]);
    switch (act) {

      case TA_INPUT:
      case TA_OUTPUT:
      case TA_DROP:
	if (ti == 0) {
	    break;
	} /* if */
	seq = ti->ti_seq;
	ack = ti->ti_ack;
	len = ti->ti_len;
	if (act == TA_OUTPUT) {
	    seq = ntohl(seq);
	    ack = ntohl(ack);
	    len = ntohs((u_short)len);
	} /* if */
	if (act == TA_OUTPUT) {
	    len -= sizeof (struct tcphdr);
	} /* if */
	if (len) {
	    printf("[%x..%x)", seq, seq+len);
	} else {
	    printf("%x", seq);
	} /* if */
	printf("@%x, urp=%x", ack, ti->ti_urp);
	flags = ti->ti_flags;
	if (flags) {
	    char *cp = "<";
#ifdef __STDC__
#define pf(f) {if (ti->ti_flags&TH_##f) {printf("%s%s", cp, "f"); cp = ",";}}
#else
#define pf(f) {if (ti->ti_flags&TH_/**/f) {printf("%s%s", cp, "f"); cp = ",";}}
#endif
	    pf(SYN); pf(ACK); pf(FIN); pf(RST); pf(PUSH); pf(URG);
	    printf(">");
	} /* if */
	break;

      case TA_USER:
	printf("%s", prurequests[req&0xff]);
	if ((req & 0xff) == PRU_SLOWTIMO) {
	    printf("<%s>", tcptimers[req>>8]);
	} /* if */
	break;
    } /* switch */
    if (ss) {
	printf(" -> %s", tcpstates[ss->t_state]);
    } /* if */
    /* print out internal state of ss !?! */
    printf("\n");
    if (!ss) {
	return;
    } /* if */
    if (tracetcpp > 3) {
	printf("\trcv_(nxt,wnd,up) (%x,%x,%x) snd_(una,nxt,max) (%x,%x,%x)\n",
	       ss->rcv_nxt, ss->rcv_wnd, ss->rcv_up, ss->snd_una, ss->snd_nxt,
	       ss->snd_max);
	printf("\tsnd_(wl1,wl2,wnd) (%x,%x,%x)\n",
	       ss->snd_wl1, ss->snd_wl2, ss->snd_wnd);
    } /* if */
} /* tcp_trace */


char *
tcpFlagStr(f)
    int f;
{
    static char buf[80];

    buf[0] = 0;
    if ( f & TH_FIN ) {
	strcat( buf, "FIN " );
    }
    if ( f & TH_SYN ) {
	strcat( buf, "SYN " );
    }
    if ( f & TH_RST ) {
	strcat( buf, "RST " );
    }
    if ( f & TH_PUSH ) {
	strcat( buf, "PUSH " );
    }
    if ( f & TH_ACK ) {
	strcat( buf, "ACK " );
    }
    if ( f & TH_URG ) {
	strcat( buf, "URG " );
    }
    return buf;
}
