/*
 * xti.h - X/Open Transport Interface definitions.
 * Copyright (c) 1992 X/Open Company Ltd. All rights reserved.
 */

/*
 * The following are the error codes needed by both the kernel 
 * level transport providers and the user level library. 
 */
#define TBADADDR	1	/* incorrect addr format */
#define TBADOPT		2	/* incorrect option format */
#define TACCES		3	/* incorrect permissions */
#define TBADF		4	/* illegal transport fd */
#define TNOADDR		5	/* couldn't allocate addr */
#define TOUTSTATE	6	/* out of state */
#define TBADSEQ		7	/* bad call sequence number */
#define TSYSERR		8	/* system error */
#define TLOOK		9	/* event requires attention */
#define TBADDATA	10	/* illegal amount of data */
#define TBUFOVFLW	11	/* buffer not large enough */
#define TFLOW		12	/* flow control */
#define TNODATA		13	/* no data */
#define TNODIS		14	/* discon_ind not found on queue */
#define TNOUDERR	15	/* unitdata error not found */
#define TBADFLAG	16	/* bad flags */
#define TNOREL		17	/* no ord rel found on queue */
#define TNOTSUPPORT	18	/* primitive/action not supported */
#define TSTATECHNG	19	/* state is in process of changing */
#define TNOSTRUCTYPE	20	/* unsupported struct-type requested */
#define TBADNAME	21	/* invalid transport provider name */
#define TBADQLEN	22	/* qlen is zero */
#define TADDRBUSY	23	/* address in use */
#define TINDOUT		24	/* outstanding connection indications */
#define TPROVMISMATCH	25	/* transport provider mismatch */
#define TRESQLEN	26	/* resfd specified to accept w/qlen >0 */
#define TRESADDR	27	/* resfd not bound to same addr as fd */
#define TQFULL		28	/* incoming connection queue full */
#define TPROTO		29	/* XTI protocol error */

/*
 * The following are the events returned.
 */
#define T_LISTEN	0x0001	/* connection indication received */
#define T_CONNECT	0x0002	/* connect confirmation received */
#define T_DATA		0x0004	/* normal data received */
#define T_EXDATA	0x0008	/* expedited data received */
#define T_DISCONNECT	0x0010	/* disconnect received */
#define T_UDERR		0x0040	/* datagram error indication */
#define T_ORDREL	0x0080	/* orderly release indication */
#define T_GODATA	0x0100	/* sending normal data is again possible */
#define T_GOEXDATA	0x0200	/* sending expedited data is again possible */

/* 
 * The following are the flag definitions needed by the 
 * user level library routines. 
 */
#define T_MORE		0x001	/* more data */
#define T_EXPEDITED	0x002	/* expedited data */
#define T_NEGOTIATE	0x004	/* set opts */
#define T_CHECK		0x008	/* check opts */
#define T_DEFAULT	0x010	/* get default opts */
#define T_SUCCESS	0x020	/* successful */
#define T_FAILURE	0x040	/* failure */
#define T_CURRENT	0x080	/* get current options */
#define T_PARTSUCCESS	0x100	/* partial success */
#define T_READONLY	0x200	/* read-only */
#define T_NOTSUPPORT	0x400	/* not supported */

/* 
 * XTI error return. 
 */
extern int t_errno; 

/*
 * XTI LIBRARY FUNCTIONS
 *
 * t_accept	- accept a connect request
 * t_alloc	- allocate a library structure
 * t_bind	- bind an address to a transport endpoint
 * t_close	- close a transport endpoint
 * t_connect	- establish a connection 
 * t_error	- produce error message
 * t_free	- free a library structure
 * t_getprotaddr - get protocol addresses
 * t_getinfo	- get protocol-specific service information
 * t_getstate	- get the current state
 * t_listen	- listen for a connect indication
 * t_look	- look at current event on a transport endpoint
 * t_open	- establish a transport endpoint
 * t_optmgmt	- manage options for a transport endpoint
 * t_rcv	- receive data or expedited data on a connection
 * t_rcvconnect	- receive the confirmation from a connect request
 * t_rcvdis	- retrieve information from disconnect
 * t_rcvrel	- acknowledge receipt of an orderly release indication
 * t_rcvudata	- receive a data unit
 * t_rcvuderr	- receive a unit data error indication
 * t_snd	- send data or expedited data over a connection
 * t_snddis	- send user-initiated disconnect request
 * t_sndrel	- initiate an orderly release
 * t_sndudata	- send a data unit
 * t_strerror	- generate error message string
 * t_sync	- synchronise transport library
 * t_unbind	- disable a transport endpoint
 */

int t_accept(int fd, int resfd, struct *t_call call);
char *t_alloc(int fd, int struct_type, int fields);
int t_bind(int fd, struct t_bind *req, struct t_bind *ret);
int t_close(int fd);
int t_connect(int fd, struct t_call *sndcall, struct t_call *rcvcall);
int t_error(char *errmsg);
int t_free(char *ptr, int struct_type);
int t_getinfo(int fd, struct t_info *info);
int t_getprotaddr(int fd, struct t_bind *boundaddr, struct t_bind *peeraddr);
int t_getstate(int fd);
int t_listen(int fd, struct t_call *call);
int t_look(int fd);
int t_open(const char *path, int oflag, struct t_info *info);
int t_optmgmt(int fd, struct t_optmgmt *req, struct t_optmgmt *ret);
int t_rcv(int fd, char *buf, unsigned int nbytes, int *flags);
int t_rcvconnect(int fd, struct t_call *call);
int t_rcvdis(int fd, struct t_discon *discon);	
int t_rcvrel(int fd);
int t_rcvudata(int fd, struct t_unitdata *unitdata, int *flags);
int t_rcvuderr(int fd, struct t_uderr *uderr);
int t_snd(int fd, char *buf, unsigned int nbytes, int flags);
int t_snddis(int fd, struct t_call *call);
int t_sndrel(int fd);
int t_sndudata(int fd, struct t_unitdata *unitdata);
char *t_strerror(int errnum);
int t_sync(int fd);	
int t_unbind(int fd);

/*
 * Protocol-specific service limits. 
 */
struct t_info { 
	long addr;	/* max size of the transport protocol address */
	long options;	/* max number of bytes of protocol-specific options */
	long tsdu;	/* max size of a transport service data unit */
	long etsdu;	/* max size of expedited transport service data unit */
	long connect;	/* max amount of data allowed on connection */
	
	/* establishment functions */
	long discon;	/* max data allowed on t_snddis and t_rcvdis functions */
	long servtype;	/* service type supported by transport provider */
	long flags;	/* other info about the transport provider */
}; 

/*
 * Service type defines. 
 */
#define T_COTS		01	/* connection-oriented transport service */
#define T_COTS_ORD	02	/* connection-oriented with orderly release */
#define T_CLTS		03	/* connectionless transport service */

/*
 * Flags defines (other info about the transport provider). 
 */
#define T_SENDZERO	0x001	/* supports 0-length TSDUs */

/*
 * netbuf structure. 
 */
struct netbuf {
	unsigned int maxlen; 
	unsigned int len; 
	char buf; 
};

/*
 * t_opthdr structure.
 */
struct t_opthdr {
	unsigned long len;	/* total length of option; i.e.
				   sizeof (struct t_opthdr) + length of
				   option value in bytes */
	unsigned long level;	/* protocol affected */
	unsigned long name;	/* option name */
	unsigned long status;	/* status value */
	/* followed by the option value */
};

/*
 * t_bind - format of the address and options arguments of bind.
 */
struct t_bind { 
	struct netbuf addr;
	unsigned qlen;
};

/*
 * Options management structure. 
 */
struct t_optmgmt {
	struct netbuf opt;
	long flags;
};

/*
 * Disconnectstructure. 
 */
struct t_discon { 
	struct netbuf udata;	/* user data */
	int reason;		/* reason code */
	int sequence;		/* sequence number */
};

/*
 * Call structure. 
 */
struct t_call {
	struct netbuf addr;	/* address */
	struct netbuf opt;	/* options */
	struct netbuf udata;	/* user data */
	int sequence;		/* sequence number */
};

/*
 * Datagram structure. 
 */
struct t_unitdata { 
	struct netbuf addr;	/* address */
	struct netbuf opt;	/* options */
	struct netbuf udata;	/* user data */
};

/*
 * Unit data error structure. 
 */
struct t_uderr {
	struct netbuf addr;	/* address */
	struct netbuf opt;	/* options */
	long error;		/* error code */
};

/*
 * The following are structure types used when dynamically
 * allocating the above structures via t_alloc(). 
*/
#define T_BIND		1	/* struct t_bind */
#define T_OPTMGMT	2	/* struct t_optmgmt */
#define T_CALL		3	/* struct t_call */
#define T_DIS		4	/* struct t_discon */
#define T_UNITDATA	5	/* struct t_unitdata */
#define T_UDERROR	6	/* struct t_uderr */
#define T_INFO		7	/* struct t_info */

/*
 * The following bits specify which fields of the above
 * structures should be allocated by t_alloc().
 */
#define T_ADDR		0x01	/* address */
#define T_OPT		0x02	/* options */
#define T_UDATA		0x04	/* user data */
#define T_ALL		0xffff	/* all the above fields supported */

/*
 * The following are the states for the user. 
 */
#define T_UNBND		1	/* unbound */
#define T_IDLE		2	/* idle */
#define T_OUTCON	3	/* outgoing connection pending */
#define T_INCON		4	/* incoming connection pending */
#define T_DATAXFER	5	/* data transfer */
#define T_OUTREL	6	/* outgoing release pending */
#define T_INREL		7	/* incoming release pending */

/*
 * General purpose defines.
 */
#define T_YES		1
#define T_NO		0
#define T_UNUSED	-1
#define T_NULL		0
#define T_ABSREQ	0x8000
#define T_INFINITE	-1		/* T_INFINITE and T_INVALID are */
#define T_INVALID	-2		/* values of t_info */

/*
 * General definitions for option management.
 */
#define T_UNSPEC (~0 - 2)	/* applicable to u_long, long, char ... */
#define T_ALLOPT 0 
#define T_ALIGN(p) (((unsigned long) (p) + (sizeof(long) - 1)) & ~(sizeof(long) - 1)) 
#define OPT_NEXTHDR(pbuf, buflen, popt) \
		(((char *)(popt) + T_ALIGN((popt)->len) < pbuf + buflen) ? \
		(struct t_opthdr *) ((char *)(popt) + T_ALIGN((popt)->len)) : \
		(struct t_opthdr *) NULL) 


/* OPTIONS ON XTI LEVEL */

/* XTI-level */

#define XTI_GENERIC 0xffff 

/*
 * XTI-level Options.
 */
#define XTI_DEBUG	0x0001	/* enable debugging */
#define XTI_LINGER	0x0080	/* linger on close if data present */
#define XTI_RCVBUF	0x1002	/* receive buffer size */
#define XTI_RCVLOWAT	0x1004	/* receive low-water mark */
#define XTI_SNDBUF	0x1001	/* send buffer size */
#define XTI_SNDLOWAT	0x1003	/* send low-water mark */

/*
 * Structure used with linger option. 
 */
struct t_linger {
	long l_onoff;	/* option on/off */
	long l_linger;	/* linger time */
};


/* SPECIFIC ISO OPTION AND MANAGEMENT PARAMETERS */

/*
 * Definition of the ISO transport classes 
 */
#define T_CLASS0 0 
#define T_CLASS1 1 
#define T_CLASS2 2 
#define T_CLASS3 3 
#define T_CLASS4 4 

/*
 * Definition of the priorities. 
 */
#define T_PRITOP 0 
#define T_PRIHIGH 1 
#define T_PRIMID 2 
#define T_PRILOW 3 
#define T_PRIDFLT 4 

/*
 * Definitions of the protection levels.
 */
#define T_NOPROTECT 1 
#define T_PASSIVEPROTECT 2 
#define T_ACTIVEPROTECT 4 

/*
 * Default value for the length of TPDUs. 
 */
#define T_LTPDUDFLT 128		/* define obsolete in XPG4 */

/*
 * ratestructure. 
 */
struct rate { 
	long targetvalue;	/* target value */
	long minacceptvalue;	/* value of minimum acceptable quality */
};
 
/*
 * reqvalue structure. 
 */
struct reqvalue { 
	struct rate called; /* called rate */
	struct rate calling; /* calling rate */
};

/*
 * thrptstructure. 
 */
struct thrpt { 
	struct reqvalue maxthrpt;	/* maximum throughput */
	struct reqvalue avgthrpt;	/* average throughput */
};

/*
 * transdel structure.
 */
struct transdel { 
	struct reqvalue maxdel;	/* maximum transit delay */
	struct reqvalue avgdel;	/* average transit delay */
};

/*
 * Protocol Levels 
 */
#define ISO_TP 0x0100 

/*
 * Options for Quality of Service and Expedited Data (ISO8072:1986) 
 */
#define TCO_THROUGHPUT 0x0001 
#define TCO_TRANSDEL 0x0002 
#define TCO_RESERRORRATE 0x0003 
#define TCO_TRANSFFAILPROB 0x0004 
#define TCO_ESTFAILPROB 0x0005 
#define TCO_RELFAILPROB 0x0006 
#define TCO_ESTDELAY 0x0007 
#define TCO_RELDELAY 0x0008 
#define TCO_CONNRESIL 0x0009 
#define TCO_PROTECTION 0x000a 
#define TCO_PRIORITY 0x000b 
#define TCO_EXPD 0x000c 

#define TCL_TRANSDEL 0x000d 
#define TCL_RESERRORRATE TCO_RESERRORRATE 
#define TCL_PROTECTION TCO_PROTECTION 
#define TCL_PRIORITY TCO_PRIORITY 

/*
 * Management Options 
 */
#define TCO_LTPDU 0x0100 
#define TCO_ACKTIME 0x0200 
#define TCO_REASTIME 0x0300 
#define TCO_EXTFORM 0x0400 
#define TCO_FLOWCTRL 0x0500 
#define TCO_CHECKSUM 0x0600 
#define TCO_NETEXP 0x0700 
#define TCO_NETRECPTCF 0x0800 
#define TCO_PREFCLASS 0x0900 
#define TCO_ALTCLASS1 0x0a00 
#define TCO_ALTCLASS2 0x0b00 
#define TCO_ALTCLASS3 0x0c00 
#define TCO_ALTCLASS4 0x0d00 

#define TCL_CHECKSUM TCO_CHECKSUM 


/* INTERNET SPECIFIC ENVIRONMENT */

/*
 * TCP level 
 */
#define INET_TCP 0x6 

/*
 * TCP-level Options 
 */
#define TCP_NODELAY	0x1	/* don't delay packets to coalesce */
#define TCP_MAXSEG	0x2	/* get maximum segment size */
#define TCP_KEEPALIVE	0x8	/* check, if connections are alive */

/*
 * Structure used with TCP_KEEPALIVE option.
 */
struct t_kpalive {
	long kp_onoff;		/* option on/off */
	long kp_timeout;	/* timeout in minutes */
}; 

#define T_GARBAGE 0x02 

/*
 * UDPlevel 
 */
#define INET_UDP 0x11

/*
 * UDP-level Options 
 */
#define UDP_CHECKSUM TCO_CHECKSUM /* checksum computation */

/*
 * IP level 
 */
#define INET_IP	0x0

/*
 * IP-level Options 
 */
#define IP_OPTIONS	0x1	/* IP per-packet options */
#define IP_TOS		0x2	/* IP per-packet type of service */
#define IP_TTL		0x3	/* IP per-packet time to live */
#define IP_REUSEADDR	0x4	/* allow local address reuse */
#define IP_DONTROUTE	0x10	/* just use interface addresses */
#define IP_BROADCAST	0x20	/* permit sending of broadcast msgs */

/*
 * IP_TOS precedence levels 
 */
#define T_ROUTINE	0
#define T_PRIORITY	1
#define T_IMMEDIATE	2
#define T_FLASH		3
#define T_OVERRIDEFLASH	4
#define T_CRITIC_ECP	5
#define T_INETCONTROL	6
#define T_NETCONTROL	7

/*
 * IP_TOS typeofservice 
 */
#define T_NOTOS		0
#define T_LDELAY	1 << 4
#define T_HITHRPT	1 << 3
#define T_HIREL		1 << 2

#define SET_TOS(prec, tos) ((0x7 & (prec)) << 5 | (0x1c & (tos)))
