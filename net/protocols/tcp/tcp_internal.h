/*
 * $RCSfile: tcp_internal.h,v $
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
 *	@(#)tcp.h	7.3 (Berkeley) 12/7/87
 *
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: tcp_internal.h,v $
 * Revision 1.4  1996/06/03 18:39:57  slm
 * Added declaration for tcp_send().
 *
 * Revision 1.3  1996/01/29  22:30:32  slm
 * Updated copyright and version.
 *
 * Revision 1.2  1995/09/26  21:23:52  davidm
 * Got rid of bogus myHost global variable.  Host is now determined based
 * on lower-level session at tcp_establishopen time.  This works even in
 * the case of multi-homed hosts.
 *
 * (Larry Brakmo found & fixed this bug, actually).
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.38.1.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.37  1994/04/22  02:15:35  davidm
 * struct in_addr and tcp_seq are now of type xk_u_int32
 * instead of u_long.
 *
 * Revision 1.36  1993/12/16  01:41:38  menze
 * fixed '#else' comment
 */
#ifndef tcp_internal_h
#define tcp_internal_h

#include "xkernel.h"
#include "sb.h"
#include "ip.h"
#include "tcp.h"
#include "tcp_port.h"
#include "tcp_timer.h"
#include "tcpip.h"

#ifndef ENDIAN
/*
 * Definitions for byte order,
 * according to byte significance from low address to high.
 */
#define	LITTLE	1234		/* least-significant byte first (vax) */
#define	BIG	4321		/* most-significant byte first */
#define	PDP	3412		/* LSB first in word, MSW first in long (pdp) */
#if defined(vax) || defined(pmax)
#define	ENDIAN	LITTLE
#else
#define	ENDIAN	BIG		/* byte order on mc68000, tahoe, most others */
#endif
#endif /* ENDIAN */

typedef u_long 		n_time;
#undef KPROF
#define PR_SLOWHZ	2
#define PR_FASTHZ	5
/* #define KERNEL */
#define BSD 43
#define TCP_COMPAT_42

#ifndef MIN
# ifdef __GNUC__
#   define MIN(A,B) ({typeof(A) _a=(A), _b=(B); _a < _b ? _a : _b;})
# else
#   define MIN(A,B) ((A) <= (B) ? (A) : (B))
# endif
#endif
#ifndef MAX
# ifdef __GNUC__
#   define MAX(A,B) ({typeof(A) _a=(A), _b=(B); _a > _b ? _a : _b;})
# else
#   define MAX(A,B) ((A) >= (B) ? (A) : (B))
# endif
#endif

typedef struct {
    Semaphore	s;
    int		waitCount;
} TcpSem;

struct reass {
    struct reass *next, *prev;
    struct tcphdr th;
    Msg m;
};

typedef struct sstate {
    u_int	flags;		/* see below */
    TcpSem	waiting;
    TcpSem	lock;
    Protl	hlpType;	/* for passively opened sessions */
    struct sb	*snd;
    int		rcv_space;	/* amount of space in the receiver's buffer */
    int		rcv_hiwat;	/* size of receiver's buffer */
    /*
     * TCP control block, one per tcp connection.
     */
    struct	reass *seg_next;	/* sequencing queue */
    struct	reass *seg_prev;
    int		t_state;		/* state of this connection */
    int		t_timer[TCPT_NTIMERS];	/* tcp timers */
    int		t_rxtshift;		/* log(2) of rexmt exp. backoff */
    int		t_rxtcur;		/* current retransmit value */
    int		t_dupacks;		/* consecutive dup acks recd */
    u_int	t_maxseg;		/* maximum segment size */
    int		t_force;		/* 1 if forcing out a byte */
    u_int	t_flags;
#define	TF_ACKNOW		(1<<0)	/* ack peer immediately */
#define	TF_DELACK		(1<<1)	/* ack, but try to delay it */
#define	TF_NODELAY		(1<<2)	/* don't delay packets to coalesce */
#define	TF_NOOPT		(1<<3)	/* don't use tcp options */
#define	TF_SENTFIN		(1<<4)	/* have sent FIN */
#define TF_EMBRYONIC		(1<<5)	/* is session embrionic? */
#define TF_USRCLOSED		(1<<6)	/* user has requested close */
#define TF_NETCLOSED		(1<<7)	/* network closed on us */
#define TF_NBIO			(1<<8)	/* non-blocking i/o operations */
#define TF_OOBINLINE		(1<<9)	/* inline urgent data */
#define TF_RCV_ACK_ALWAYS	(1<<10)	/* assume infinite receive buffer */
#define TF_KEEP_ALIVE		(1<<11)	/* keep connection alive */


    struct	tcpiphdr t_template;	/* skeletal packet for transmit */
    /*
     * The following fields are used as in the protocol specification.
     * See RFC783, Dec. 1981, page 21.
     */
    /* send sequence variables */
    tcp_seq	snd_una;		/* send unacknowledged */
    tcp_seq	snd_nxt;		/* send next */
    tcp_seq	snd_up;			/* send urgent pointer */
    tcp_seq	snd_wl1;		/* window update seg seq number */
    tcp_seq	snd_wl2;		/* window update seg ack number */
    tcp_seq	iss;			/* initial send sequence number */
    u_int	snd_wnd;		/* send window */
    /* receive sequence variables */
    u_int	rcv_wnd;		/* receive window */
    tcp_seq	rcv_nxt;		/* receive next */
    tcp_seq	rcv_up;			/* receive urgent pointer */
    tcp_seq	irs;			/* initial receive sequence number */
    /*
     * Additional variables for this implementation.
     */
    /* receive variables */
    tcp_seq	rcv_adv;		/* advertised window */
    /* retransmit variables */
    tcp_seq	snd_max;		/* highest sequence number sent
					 * used to recognize retransmits
					 */
    /*
     * Congestion control (for slow start, source quench, retransmit
     * after loss):
     */
    u_int	snd_cwnd;		/* congestion-controlled window */
    u_int	snd_ssthresh;		/* snd_cwnd size threshhold for
					 * for slow start exponential to
					 * linear switch */
    /*
     * Transmit timing stuff.
     * srtt and rttvar are stored as fixed point; for convenience in
     * smoothing, srtt has 3 bits to the right of the binary point,
     * rttvar has 2.  "Variance" is actually smoothed difference.
     */
    int		t_idle;			/* inactivity time */
    int		t_rtt;			/* round trip time */
    tcp_seq	t_rtseq;		/* sequence number being timed */
    int		t_srtt;			/* smoothed round-trip time */
    int		t_rttvar;		/* variance in round-trip time */
    u_int	max_rcvd;		/* most peer has sent into window */
    u_int	max_sndwnd;		/* largest window peer has offered */
    /* out-of-band data */
    char	t_oobflags;		/* have some */
    char	t_iobc;			/* input character */
#define	TCPOOB_HAVEDATA	0x01
#define	TCPOOB_HADDATA	0x02
} SState;

#define sotoss(S)	((SState*)(S)->state)

extern int tracetcpp;

/*
 * The arguments to usrreq are:
 *	(*protosw[].pr_usrreq)(up, req, m, nam, opt);
 * where up is a (struct socket *), req is one of these requests,
 * m is a optional mbuf chain containing a message,
 * nam is an optional mbuf chain containing an address,
 * and opt is a pointer to a socketopt structure or nil.
 * The protocol is responsible for disposal of the mbuf chain m,
 * the caller is responsible for any space held by nam and opt.
 * A non-zero return from usrreq gives an
 * UNIX error number which should be passed to higher level software.
 */
#define	PRU_CONNECT		0	/* establish connection to peer */
#define	PRU_SLOWTIMO		1	/* 500ms timeout */

#define RCV 0
#define SND 1

#ifndef XKMACHKERNEL
#include <sys/errno.h>
#else
#define	EINVAL		22		/* Invalid argument */
#define	EWOULDBLOCK	35		/* Operation would block */
#define	EOPNOTSUPP	45		/* Operation not supported on socket */
#define ECONNRESET	54
#define ENOBUFS		55
#define	EISCONN		56		/* Socket is already connected */
#define ETIMEDOUT	60
#define ECONNREFUSED	61
#endif /* XKMACHKERNEL */

#define	TCPOPT_EOL	0
#define	TCPOPT_NOP	1
#define	TCPOPT_MAXSEG	2

/*
 * Default maximum segment size for TCP.
 * With an IP MSS of 576, this is 536,
 * but 512 is probably more convenient.
 */
#ifndef IP_MSS
# define	IP_MSS	576
#endif
#define		TCP_MSS	MIN(512, IP_MSS - sizeof (struct tcpiphdr))

/*
 * User-settable options (used with setsockopt).
 */
#define	TCP_NODELAY	0x01	/* don't delay send to coalesce packets */
#define	TCP_MAXSEG	0x02	/* set maximum segment size */


#ifdef TCP_STATISTICS
# define TCP_STAT(s)	{s;}
#else
# define TCP_STAT(s)	do { ;} while (0);
#endif

/*
 * x-kernel defines
 */

typedef struct pstate  {
    Map     	activeMap;
    Map      	passiveMap;
    VOID	*portstate;
#ifdef TCP_STATISTICS
    /*
     * TCP statistics.
     * Many of these should be kept per connection,
     * but that's inconvenient at the moment.
     */
#if BSD<=43
    int	tcps_badsum;
    int	tcps_badoff;
    int	tcps_hdrops;
    int	tcps_badsegs;
    int	tcps_unack;
    /* 4.3+ BSD stats start here */
#endif
    u_int tcps_connattempt;	/* connections initiated */
    u_int tcps_accepts;		/* connections accepted */
    u_int tcps_connects;	/* connections established */
    u_int tcps_drops;		/* connections dropped */
    u_int tcps_conndrops;	/* embryonic connections dropped */
    u_int tcps_closed;		/* conn. closed (includes drops) */
    u_int tcps_segstimed;	/* segs where we tried to get rtt */
    u_int tcps_rttupdated;	/* times we succeeded */
    u_int tcps_delack;		/* delayed acks sent */
    u_int tcps_timeoutdrop;	/* conn. dropped in rxmt timeout */
    u_int tcps_rexmttimeo;	/* retransmit timeouts */
    u_int tcps_persisttimeo;	/* persist timeouts */
    u_int tcps_keeptimeo;	/* keepalive timeouts */
    u_int tcps_keepprobe;	/* keepalive probes sent */
    u_int tcps_keepdrops;	/* connections dropped in keepalive */

    u_int tcps_sndtotal;	/* total packets sent */
    u_int tcps_sndpack;		/* data packets sent */
    u_int tcps_sndbyte;		/* data bytes sent */
    u_int tcps_sndrexmitpack;	/* data packets retransmitted */
    u_int tcps_sndrexmitbyte;	/* data bytes retransmitted */
    u_int tcps_sndacks;		/* ack-only packets sent */
    u_int tcps_sndprobe;	/* window probes sent */
    u_int tcps_sndurg;		/* packets sent with URG only */
    u_int tcps_sndwinup;	/* window update-only packets sent */
    u_int tcps_sndctrl;		/* control (SYN|FIN|RST) packets sent */

    u_int tcps_rcvtotal;	/* total packets received */
    u_int tcps_rcvpack;		/* packets received in sequence */
    u_int tcps_rcvbyte;		/* bytes received in sequence */
    u_int tcps_rcvbadsum;	/* packets received with ccksum errs */
    u_int tcps_rcvbadoff;	/* packets received with bad offset */
    u_int tcps_rcvshort;	/* packets received too short */
    u_int tcps_rcvduppack;	/* duplicate-only packets received */
    u_int tcps_rcvdupbyte;	/* duplicate-only bytes received */
    u_int tcps_rcvpartduppack;	/* packets with some duplicate data */
    u_int tcps_rcvpartdupbyte;	/* dup. bytes in part-dup. packets */
    u_int tcps_rcvoopack;	/* out-of-order packets received */
    u_int tcps_rcvoobyte;	/* out-of-order bytes received */
    u_int tcps_rcvpackafterwin;	/* packets with data after window */
    u_int tcps_rcvbyteafterwin;	/* bytes rcvd after window */
    u_int tcps_rcvafterclose;	/* packets rcvd after "close" */
    u_int tcps_rcvwinprobe;	/* rcvd window probe packets */
    u_int tcps_rcvdupack;	/* rcvd duplicate acks */
    u_int tcps_rcvacktoomuch;	/* rcvd acks for unsent data */
    u_int tcps_rcvackpack;	/* rcvd ack packets */
    u_int tcps_rcvackbyte;	/* bytes acked by rcvd acks */
    u_int tcps_rcvwinupd;	/* rcvd window update packets */
#endif /* TCP_STATISTICS */
} PState;


typedef TCPport  PassiveId;

typedef struct {
    unsigned short localport;
    unsigned short remoteport;
    IPhost         remoteaddr;
} ActiveId;

#define FROM_ENABLE	-1
#define TCPRCVWIN	(TCP_BUFFER_SPACE)

extern char *tcpstates[];

#if defined(__STDC__) || defined(__GNUC__)

/*
 * tcp_subr.c
 */
void	tcp_drop( Sessn so, int errnum );
void	tcp_destroy( Sessn so );
void	tcp_template( Sessn so );
void	tcp_respond(Sessn so, struct tcphdr *, IPpseudoHdr *,
		    tcp_seq ack, tcp_seq seq, int flags,
		    Protl tcpProtl );
void	tcp_quench( SState *ss );
 
/*
 * tcp_hdr.c
 */
void 	tcpHdrStore(void *, char *, long, Msg *, IPpseudoHdr *);
void 	tcpOptionsStore(void *, char *, long, long);
long	tcpOptionsLoad(void *, char *, long);
long 	tcpHdrLoad(void *, char *, long, Msg *);

/*
 * tcp_timer.c
 */
void	tcp_fasttimo( Event, void * );
void	tcp_slowtimo( Event, void * );
void	tcp_canceltimers( SState* );

/*
 * tcp_x.c
 */
void	delete_session_state( SState* );
void	socantrcvmore( Sessn );
void	sohasoutofband( Sessn, u_int );
void	soisdisconnected( Sessn );
void	soisconnected( Sessn );
Sessn	sonewconn( Protl, Protl, Protl, IPhost *, IPhost *, int, int );
void	tcpSemWait( TcpSem * );
void	tcpSemSignal( TcpSem * );
void	tcpSemInit( TcpSem *, int );
void	tcpSemVAll( TcpSem * );
void	tcpSemDestroy( TcpSem * );

/* 
 * tcp_output.c
 */
int	tcp_output( Sessn so );
void	tcp_setpersist( SState * );
int     tcp_send( Sessn, int, int, int, int );

/* 
 * tcp_input.c
 */
void	print_reass( SState*, char * );
int	tcp_mss( Sessn so );
XkReturn	tcpDemux( Protl, Sessn, Msg * );
XkReturn	tcpPop( Sessn, Sessn, Msg *, VOID * );

/* 
 * tcp_debug.c
 */
void	tcp_trace(int, int, SState*, struct tcpiphdr *, int );
char *	tcpFlagStr( int );

#else

/*
 * in_hacks.c
 */
int	in_pcballoc();
void	in_pcbdisconnect();
void 	in_pcbdetach();
u_short	in_cksum();

/*
 * tcp_subr.c
 */
void	tcp_drop();
void 	tcp_destroy();
void	tcp_template();
void	tcp_quench();
void	tcp_respond();
 
/*
 * tcp_hdr.c
 */
void 	tcpHdrStore();
void 	tcpOptionsStore();
long	tcpOptionsLoad();
long 	tcpHdrLoad();

/*
 * tcp_timer.c
 */
void	tcp_fasttimo();
void	tcp_slowtimo();
void	tcp_canceltimers();

/*
 * tcp_x.c
 */
void	delete_session_state();
void	socantrcvmore();
void	sohasoutofband();
void	soisdisconnected();
void	soisconnected();
Sessn	sonewconn();
void	tcpSemWait();
void	tcpSemSignal();
void	tcpSemInit();
void	tcpSemVAll();
void	tcpSemDestroy();

/* 
 * tcp_output.c
 */
int	tcp_output();
void	tcp_setpersist();
int	tcp_send();

/* 
 * tcp_input.c
 */
void	print_reass();
XkReturn	tcp_input();
int	tcp_mss();
XkReturn	tcpPop();
int	tcp_reass();

/* 
 * tcp_debug.c
 */
void	tcp_trace();
char *	tcpFlagStr();

#endif /* __STDC__ */

#include "insque.h"

#endif /* tcp_internal_h */
