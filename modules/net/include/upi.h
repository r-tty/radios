/*
 * upi.h - Uniform Protocol Interface (UPI) definitions.
 */
 
/*
 * x-kernel v3.3  Copyright 1990-1996  Arizona Board of Regents
 */
 
#ifndef _UPI_H
#define _UPI_H

#include "xtype.h"
#include "idmap.h"
#include "msg.h"
#include "part.h"
#include "platform.h"
#include "ocsum.h"

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

/* default number of down protocols or sessions */
#define STD_DOWN 8

typedef struct protl *(*XDummyFunc)(void);
typedef struct sessn *(*XOpenFunc)(struct protl *, struct protl *,
				   struct protl *, Part *);
typedef XkReturn     (*XOpenEnableFunc)(struct protl *, struct protl *,
				        struct protl *, Part *);
typedef XkReturn     (*XOpenDisableFunc)(struct protl *, struct protl *,
					 struct protl *, Part *);
typedef XkReturn     (*XOpenDisableAllFunc)(struct protl *, struct protl *);
typedef XkReturn     (*XOpenDoneFunc)(struct protl *, struct protl *,
				      struct sessn *, struct protl *);
typedef XkReturn     (*XCloseFunc)(struct sessn *);
typedef XkReturn     (*XCloseDoneFunc)(struct sessn *);
typedef XkReturn     (*XDemuxFunc)(struct protl *, struct sessn *, Msg *);
typedef XkReturn     (*XCallDemuxFunc)(struct protl *, struct sessn *, Msg *,
				       Msg *);
typedef XkReturn     (*XPopFunc)(struct sessn *, struct sessn *, Msg *, void *);
typedef XkReturn     (*XCallPopFunc)(struct sessn *, struct sessn *, Msg *,
				     void *, Msg *);
typedef XkHandle     (*XPushFunc)(struct sessn *, Msg *);
typedef XkReturn     (*XCallFunc)(struct sessn *, Msg *, Msg *);
typedef int          (*XControlProtlFunc)(struct protl *, int, char *, int);
typedef int          (*XControlSessnFunc)(struct sessn *, int, char *, int);
typedef Part         *(*XGetParticipantsFunc)(struct sessn *);
typedef XkReturn     (*XDuplicateFunc)(struct sessn *);

typedef struct protl {
    void                *state;
    Binding             binding;
    /* pointers to protocols configured below this one */
    int                 numdown;
    int                 downlistsz;
    struct protl        *down[STD_DOWN];
    struct protl        **downlist;
    xk_int32            id;
    /* interface functions */
    XOpenFunc           open;
    XOpenEnableFunc     openenable;
    XOpenDisableFunc    opendisable;
    XOpenDisableAllFunc opendisableall;
    XOpenDoneFunc       opendone;
    XCloseDoneFunc      closedone;
    XDemuxFunc          demux;
    XCallDemuxFunc      calldemux;
    XCloseFunc          close;		/* sessions only */
    XPopFunc            pop;		/* sessions only */
    XCallPopFunc        callpop;	/* sessions only */
    XPushFunc           push;		/* sessions only (sim_eth) */
    XCallFunc           call;		/* sessions only */
    XDuplicateFunc      duplicate;	/* sessions only */
    struct protl        *myprotl;	/* sessions only */
    struct protl        *up;		/* sessions only (sim_eth) */
    /* protocol only stuff */
    XControlProtlFunc   controlprotl;
    char                *name;
    char                *instName;
    char                *fullName;
    int                 *traceVar;
} *Protl;

typedef struct sessn {
    void                 *state;
    Binding              binding;
    /* pointers to open sessions below this one */
    int                  numdown;
    int                  downlistsz;
    struct sessn         *down[STD_DOWN];
    struct sessn         **downlist;
    xk_int32             id;		/* protocols only */
	/* (removing id from Sessn struct causes example1 not to run) */
    /* interface functions */
    XOpenFunc            open;		/* protocols only */
    XOpenEnableFunc      openenable;	/* protocols only */
    XOpenDisableFunc     opendisable;	/* protocols only */
    XOpenDisableAllFunc  opendisableall;/* protocols only */
    XOpenDoneFunc        opendone;	/* protocols only */
    XCloseDoneFunc       closedone;	/* protocols only */
    XDemuxFunc           demux;		/* protocols only (vdrop/vnet/vsize) */
    XCallDemuxFunc       calldemux;	/* protocols only */
    XCloseFunc           close;
    XPopFunc             pop;
    XCallPopFunc         callpop;
    XPushFunc            push;
    XCallFunc            call;
    XDuplicateFunc       duplicate;
    /* pointers to protocols associated with this session */
    struct protl         *myprotl;
    struct protl         *up;
    /* session only stuff */
    XControlSessnFunc    controlsessn;
    XGetParticipantsFunc getparticipants;
    struct protl         *hlpType;
    int                  rcnt;
    unsigned char        idle;
} *Sessn;

typedef struct xenable {
    Protl   hlp;
    Protl   hlpType;
    Binding binding;
    void    *info;
    int     rcnt;
} Enable;

extern int  globalArgc;
extern char **globalArgv;

/* error stuff */

#define ERR_PROTL   ((Protl)XK_FAILURE)
#define ERR_SESSN   ((Sessn)XK_FAILURE)
#define ERR_ENABLE  ((Enable *)XK_FAILURE)
#define ERR_XK_MSG  ((XkHandle)XK_FAILURE)
#define ERR_XMALLOC 0

/* protocol and session operations */
/* (xPop and xCallPop prototypes are in upi_inline.h) */
extern Sessn    xOpen(Protl, Protl, Protl, Part *);
extern XkReturn xOpenEnable(Protl, Protl, Protl, Part *);
extern XkReturn xOpenDisable(Protl, Protl, Protl, Part *);
extern XkReturn xOpenDisableAll(Protl, Protl);
extern XkReturn xOpenDone(Protl, Protl, Sessn);
extern XkReturn xClose(Sessn);
extern XkReturn xCloseDone(Sessn);
extern XkReturn xDemux(Protl, Sessn, Msg *);
extern XkReturn xCallDemux(Protl, Sessn, Msg *, Msg *);
extern XkHandle xPush(Sessn, Msg *);
extern XkReturn xCall(Sessn, Msg *, Msg *);
extern int      xControlProtl(Protl, int, char *, int);
extern int      xControlSessn(Sessn, int, char *, int);
extern Part     *xGetParticipants(Sessn);
extern XkReturn xDuplicate(Sessn);

/* default operations */

typedef void (*DisableAllFunc)(void *, Enable *);

extern XkReturn defaultOpenEnable(Map, Protl, Protl, void *);
extern XkReturn defaultOpenDisable(Map, Protl, Protl, void *);
extern XkReturn defaultOpenDisableAll(Map, Protl, DisableAllFunc);
extern XkReturn defaultVirtualOpenEnable(Protl, Map, Protl, Protl, Protl *,
					 Part *);
extern XkReturn defaultVirtualOpenDisable(Protl, Map, Protl, Protl, Protl *,
					  Part *);

/* initialization operations */

typedef void (*ProtlInitFunc)(Protl);
typedef void (*SessnInitFunc)(Sessn);

extern Protl    xCreateProtl(ProtlInitFunc, char *, char *, int *, int,
			     Protl *);
extern Sessn    xCreateSessn(SessnInitFunc, Protl, Protl, Protl, int, Sessn *);
extern XkReturn xDestroySessn(Sessn);
extern void     upiInit(void);

/* utility routines */

extern Protl    xGetProtlByName(char *);
extern XkReturn xSetProtlDown(Protl, int, Protl);
extern XkReturn xSetSessnDown(Sessn, int, Sessn);
extern void     xPrintProtl(Protl);
extern void     xPrintSessn(Sessn);
extern bool     xIsValidProtl(Protl);
extern bool     xIsValidSessn(Sessn);


typedef void (*ProtlInitFunc)();
typedef void (*SessnInitFunc)();

/* object macros */

#define xIsProtl(self)    ((self) && (self) != ERR_PROTL)
#define xIsSessn(self)    ((self) && (self) != ERR_SESSN)
#define xMyProtl(self)    ((self)->myprotl)
#define xSetUp(self, hlp) ((self)->up = (hlp))
#define xGetUp(self)      ((self)->up)
#define xHlpType(self)    ((self)->hlpType)

/*
 * control operation definitions
 *
 * NOTE: if you change the standard control ops, make the corresponding change
 * to the controlops string array in upi.c
 */
enum {
    GETMYHOST = 0,		/* standard control operations */
    GETMYHOSTCOUNT,		/* common to all protocols */
    GETPEERHOST,
    GETPEERHOSTCOUNT,
    GETBCASTHOST,
    GETMAXPACKET,
    GETOPTPACKET,
    GETMYPROTO,
    GETPEERPROTO,
    RESOLVE,
    RRESOLVE,
    FREERESOURCES,
    SETNONBLOCKINGIO
};

#define ARP_CTL         1	/* like a protocol number; used to */
#define BLAST_CTL       2	/* partition opcode space */
#define ETH_CTL         3
#define IP_CTL          4
#define SCR_CTL         5
#define VCHAN_CTL       6
#define PSYNC_CTL       7
#define SS_CTL          8
#define SUNRPC_CTL      9
#define NFS_CTL         10
#define TCP_CTL         11
#define UDP_CTL         12
#define ICMP_CTL        13
#define VNET_CTL        14
#define BIDCTL_CTL      15
#define CHAN_CTL        16
#define VDROP_CTL       17
#define KM_CTL          18
#define VTAP_CTL        19
#define JOIN_CTL        20
#define CRYPT_CTL       21
#define BIND_CTL        22
#define SIMETH_CTL      23
#define HASH_CTL        24
#define SIM_CTL         25
#define MAC_CTL         26
#define FDDI_CTL        27
#define KERBSERV_CTL    28
#define KERBSERVBOT_CTL 29
#define RECVAUTH_CTL    30
#define TOTAL_CTL       31
#define DISPATCH_CTL    32
#define DIVIDER_CTL     33
#define PPP_CTL         34
#define LCP_CTL         35
#define IPCP_CTL        36
#define SERIAL_CTL      37
#define VDELAY_CTL      38
#define SWP_CTL         39
#define MSP_CTL         40

#define TMP0_CTL 100		/* for use by new/tmp protocols until */
#define TMP1_CTL 101		/* a standard CTL number is assigned  */
#define TMP2_CTL 102
#define TMP3_CTL 103
#define TMP4_CTL 104

#define MAXOPS   100		/* maximum number of ops per protocol */

/* Check the length of a control argument */
#define checkLen(A, B) { \
    if ((A) < (B))       \
        return -1;       \
}

#include "ip_host.h"
#include "eth_host.h"

extern XkReturn str2ipHost(IPhost *, char *);
extern XkReturn str2ethHost(ETHhost *, char *);
extern XkReturn str2fddiHost(FDDIhost *, char *);
extern char     *ipHostStr(IPhost *);
extern char     *ethHostStr(ETHhost *);
extern char     *fddiHostStr(FDDIhost *);

extern Protl xNullProtl;

#define X_NEW(_type) (_type *)xMalloc(sizeof(_type))

/*
 * Optimize xDemux, xCallDemux, xPush and xCall as macros.  The other critical
 * path upi functions (xPop and xCallPop) are defined as inline functions
 * in upi_inline.h
 */
#if ! defined(XK_DEBUG) || defined(XK_UPI_MACROS)

#define xDemux(P, S, M)         ((*((S)->up->demux))((P), (S), (M)))
#define xCallDemux(P, S, M, RM) ((*((S)->up->calldemux))((P), (S), (M), (RM)))
#define xPush(S, M)             ((*((S)->push))((S), (M)))
#define xCall(S, M, RM)         ((*((S)->call))((S), (M), (RM)))

#endif /* ! XK_DEBUG */

#endif
