/*
 * $RCSfile: ip_i.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: ip_i.h,v $
 * Revision 1.2  1996/01/29 22:18:06  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:27:12  slm
 * Initial revision
 *
 * Revision 1.39.1.1.1.1  1994/10/27  01:20:57  hkaram
 * New branch
 *
 * Revision 1.39.1.1  1994/10/11  19:38:17  menze
 * Cleaner separation of local outgoing address and incoming address,
 * reporting the latter as result in GETMYHOST
 *
 * Revision 1.39  1994/09/20  19:03:27  gkim
 * added support for IP source address spoofing
 *
 * Revision 1.38  1994/01/27  17:07:01  menze
 *   [ 1994/01/13          menze ]
 *   Now uses library routines for rom options
 */

#include "route.h"

#ifndef ip_i_h
#define ip_i_h

#ifndef ip_h
#include "ip.h"
#endif

#ifndef vnet_h
#include "vnet.h"
#endif

/* 
 * Length in bytes of the standard IP header (no options)
 */
#define	IPHLEN	20

#define IPVERS	(4 << 4)
#define VERS_MASK 0xf0
#define HLEN_MASK 0x0f
#define GET_HLEN(h) ((h)->vers_hlen & HLEN_MASK)
#define GET_VERS(h) ( ((h)->vers_hlen & VERS_MASK) >> 4 )

#define IPMAXINTERFACES  10

/* 
 * Default MTU.  This will normally be overridden by querying lower
 * protocols. 
 */
#define IPOPTPACKET 512
/* 
 * MAXPACKET -- how many octets of user data will fit in an IP datagram.  
 * Maximal length field - maximal IP header.
 */
#define IPMAXPACKET (0xffff - (15 << 2))
#define IPDEFAULTDGTTL  30
#define IP_GC_INTERVAL 30 * 1000 * 1000		/* 30 seconds */

/* fragment stuff */
#define DONTFRAGMENT  0x4000
#define MOREFRAGMENTS  0x2000
#define FRAGOFFMASK   0x1fff
#define FRAGOFFSET(fragflag)  ((fragflag) & FRAGOFFMASK)
#define COMPLETEPACKET(hdr) (!((hdr).frag & (FRAGOFFMASK | MOREFRAGMENTS)))
#define INFINITE_OFFSET      0xffff

#define IP_ACTIVE_MAP_SZ	101
#define IP_FORWARD_MAP_SZ	101
#define IP_PASSIVE_MAP_SZ	23
#define IP_PASSIVE_SPEC_MAP_SZ	23
#define IP_FRAG_MAP_SZ		23

typedef struct ipheader {
  	u_char 	vers_hlen;	/* high 4 bits are version, low 4 are hlen */
	u_char  type;
	u_short	dlen;
	u_short ident;
	u_short frag;
	u_char  time;
	u_char  prot;
	u_short checksum;
  	IPhost	source;		/* source address */
  	IPhost	dest;		/* destination address */
} IPheader; 


typedef struct pstate {
    Protl	self;
    Map 	activeMap;
    Map		fwdMap;
    Map  	passiveMap;
    Map  	passiveSpecMap;
    Map		fragMap;
    int		numIfc;
    RouteTable	rtTbl;
} PState;


typedef struct sstate {
    IPheader	hdr;
    /* 
     * rcvAddr is the address used to bind this session in the map.
     * Packets delivered to this session will be addressed to rcvAddr,
     * and rcvAddr is what this session returns as GETMYHOST. 
     * This may be different from hdr.source when the session is
     * receiving broadcast packets or if hdr.source is explicitly
     * changed via IP_SETSOURCEADDR.
     */
    IPhost      rcvAddr;         
    int		mtu;		   /* maximum transmission unit on intface */
} SState;

/*
 * The active map is keyed on the local and remote hosts rather than
 * the lls because the lls may change due to routing while the hosts
 * in the IP header will not.
 */
typedef struct {
    long	protNum;
    IPhost	remote;	/* remote host  */
    IPhost	local;	/* local host	*/
}	ActiveId;

typedef IPhost	FwdId;

typedef long	PassiveId;

typedef struct {
    long	prot;
    IPhost	host;
} PassiveSpecId;


/*
 * fragmentation structures
 */

typedef struct {
    IPhost source, dest;
    u_char prot;
    u_char pad;
    u_short seqid;
} FragId;


typedef struct hole {
    u_int	first, last;
} Hole;

#define RHOLE  1
#define RFRAG  2

typedef struct fragif {
    u_char type;
    union {
	Hole	hole;
	Msg	frag;
    } u;
    struct fragif *next, *prev;
} FragInfo;


/* 
 * FragId's map into this structure, a list of fragments/holes 
 */
typedef struct FragList {
    u_short  	nholes;
    FragInfo	head;	/* dummy header node */	
    Binding    	binding;
    bool	gcMark;
} FragList;

#define ERR_FRAG ((Fragtable *)-1)


#ifdef __STDC__

int		ipControlProtl( Protl, int, char *, int );
int		ipControlSessn( Sessn, int, char *, int );
Part            *ipGetParticipants(Sessn);
Sessn		ipCreatePassiveSessn( Protl, Sessn, ActiveId *, FwdId * );
XkReturn	ipDemux( Protl, Sessn, Msg * );
void 		ipDumpHdr( IPheader * );
void 		ipDumpHdr( IPheader * );
Enable *	ipFindEnable( Protl, int, IPhost * );
XkReturn 	ipForwardPop( Sessn, Sessn, Msg *, VOID * );
void		ipFreeFragList( FragList * );
XkReturn 	ipFwdBcastPop( Sessn, Sessn, Msg *, VOID * );
int		ipGetHdr( Msg *, IPheader *, char * );
void		ipHdrStore( VOID *, char *, long, VOID * );
int		ipHostOnLocalNet( PState *, IPhost *);
int		ipIsMyAddr( Protl, IPhost * );
XkReturn	ipMsgComplete( Sessn, Sessn, Msg *, VOID * );
void		ipProcessRomFile( Protl );
XkReturn	ipReassemble( Sessn, Sessn, Msg *, IPheader * );
int		ipRemoteNet( PState *, IPhost *, route *);
void		ipRouteChanged( PState *, route *,
			       int (*)(PState *, IPhost *, route *) );
int		ipSameNet( PState *, IPhost *, route *);
XkHandle	ipSend( Sessn s, Sessn lls, Msg *msg, IPheader *hdr );
XkReturn	ipStdPop( Sessn, Sessn, Msg *, VOID * );
void		scheduleIpFragCollector( PState * );

#else

int		ipControlProtl();
int		ipControlSessn();
Part            *ipGetParticipants();
Sessn		ipCreatePassiveSessn();
XkReturn	ipDemux();
Enable *	ipFindEnable();
XkReturn 	ipForwardPop();
void		ipFreeFragList();
void		ipFreeFragtable();
XkReturn 	ipFwdBcastPop();
int		ipGetHdr();
void		ipHdrStore();
int		ipIsMyAddr();
XkReturn	ipMsgComplete();
void		ipProcessRomFile();
XkReturn	ipReassemble();
int		ipRemoteNet();
void		ipRouteChanged();
int		ipSameNet();
XkHandle	ipSend();
XkReturn	ipStdPop();
void		scheduleIpFragCollector();

#endif

extern int 	traceipp;
extern IPhost	ipSiteGateway;

#endif /* ip_i_h */
