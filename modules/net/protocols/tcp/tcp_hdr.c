/* 
 * tcp_hdr.c
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:32:07 $
 */

/*
 * TCP header store and load functions
 */

#include "xkernel.h"
#include "tcp_internal.h"

#define CKSUM_TRACE 8

#ifdef __STDC__

static void	dispPseudoHdr( IPpseudoHdr * );
static void	dispHdr( struct tcphdr * );
static void	dumpBytes( char *, long );


#endif /* __STDC__ */


static void
dispPseudoHdr(h)
    IPpseudoHdr *h;
{
  printf("   IP pseudo header: src: %s  dst: %s  \n   z:  %d  p: %d len: %d\n",
	 ipHostStr(&h->src), ipHostStr(&h->dst), h->zero, h->prot,
	 ntohs(h->len));
}


static void
dispHdr(h)
    struct tcphdr *h;
{
    printf("sp: %d dp: %d ", h->th_sport, h->th_dport);
    printf("seq: %x ack: %x ", h->th_seq, h->th_ack);
    printf("off: %d w: %d ", h->th_off, h->th_win);
    printf("urp: %d fg: %s\n", h->th_urp, tcpFlagStr(h->th_flags));
}


static void
dumpBytes(char *buf, long len)
{
    int i;

    for (i=0; i < len; i++) {
	printf("%x ",*(u_char *)buf++);
	if (i+1 % 50 == 0) {
	    putchar('\n');
	} /* if */
    } /* for */
    putchar('\n');
} /* dumpBytes */



/*
 * tcpHdrStore -- 'arg' should point to an appropriate hdrStore_t 
 * note: '*hdr' and the length field of the pseudoheader in '*arg'
 * will be modified.
 */
void
tcpHdrStore(hdr, dst, len, msg, pHdr)
     VOID *hdr;
     char *dst;
     long len;
     Msg *msg;
     IPpseudoHdr *pHdr;
{
    u_short sum;

    xAssert(len == sizeof(struct tcphdr));
    xIfTrace(tcpp, 6) {
	printf("Outgoing header\n");
	dispHdr((struct tcphdr *)hdr);
    }
    ((struct tcphdr *)hdr)->th_sport = htons(((struct tcphdr *)hdr)->th_sport);
    ((struct tcphdr *)hdr)->th_dport = htons(((struct tcphdr *)hdr)->th_dport);
    xTrace1(tcpp, TR_EVENTS, "Storing hdr with seq # %d",
	    ((struct tcphdr *)hdr)->th_seq);
    ((struct tcphdr *)hdr)->th_seq   = htonl(((struct tcphdr *)hdr)->th_seq);
    ((struct tcphdr *)hdr)->th_ack   = htonl(((struct tcphdr *)hdr)->th_ack);
    ((struct tcphdr *)hdr)->th_win   = htons(((struct tcphdr *)hdr)->th_win);
    ((struct tcphdr *)hdr)->th_urp   = htons(((struct tcphdr *)hdr)->th_urp);
    ((struct tcphdr *)hdr)->th_sum   = 0;
    bcopy(hdr, dst, len);
    /*
     * Checksum
     */
    pHdr->len = htons(msgLength(msg));
    xIfTrace(tcpp, CKSUM_TRACE) {
	printf("Sent: ");
	dispPseudoHdr(pHdr);
    }
    sum = inCkSum(msg, (u_short *)pHdr, sizeof(IPpseudoHdr));

    xTrace1(tcpp, CKSUM_TRACE, "Cksum(x): %x", sum);

    bcopy((char *)&sum, (char *)&((struct tcphdr *)dst)->th_sum,
	  sizeof(u_short));

    xIfTrace(tcpp, CKSUM_TRACE) {
	MsgWalk cxt;
	char *buf;

	msgWalkInit(&cxt, msg);
	while ((buf = msgWalkNext(&cxt, (int *)&len)) != 0) {
	    dumpBytes(buf, len);
	} /* while */
	msgWalkDone(&cxt);
    }
    xAssert(inCkSum(msg, (u_short *)pHdr, sizeof(IPpseudoHdr)) == 0);
}


/*
 * tcpHdrLoad -- 'arg' should be a pointer to the message structure
 * The IP pseudoHdr should be attached as an attribute of the message.
 */
long
tcpHdrLoad(hdr, src, len, msg)
    VOID *hdr;
    char *src;
    long len;
    Msg *msg;
{
    u_short *pHdr;

    xAssert(len == sizeof(struct tcphdr));
    bcopy(src, hdr, len);
    xIfTrace(tcpp, CKSUM_TRACE) {
	pHdr = (u_short *)msgGetAttr(msg, 0);
	xAssert(pHdr);
	printf("Received: ");
	dispPseudoHdr((IPpseudoHdr *)pHdr);
    }
    xTrace1(tcpp, CKSUM_TRACE, "Incoming cksum: %x",
	    ((struct tcphdr *)hdr)->th_sum);

    xIfTrace(tcpp, CKSUM_TRACE) {
	MsgWalk cxt;
	char *buf;

	msgWalkInit(&cxt, msg);
	while ((buf = msgWalkNext(&cxt, (int *)&len)) != 0) {
	    dumpBytes(buf, len);
	} /* while */
	msgWalkDone(&cxt);
    }
    ((struct tcphdr *)hdr)->th_sport = ntohs(((struct tcphdr *)hdr)->th_sport);
    ((struct tcphdr *)hdr)->th_dport = ntohs(((struct tcphdr *)hdr)->th_dport);
    ((struct tcphdr *)hdr)->th_seq   = ntohl(((struct tcphdr *)hdr)->th_seq);
    xTrace1(tcpp, TR_EVENTS, "Loading hdr with seq # %d",
	    ((struct tcphdr *)hdr)->th_seq);
    ((struct tcphdr *)hdr)->th_ack   = ntohl(((struct tcphdr *)hdr)->th_ack);
    ((struct tcphdr *)hdr)->th_win   = ntohs(((struct tcphdr *)hdr)->th_win);
    ((struct tcphdr *)hdr)->th_urp   = ntohs(((struct tcphdr *)hdr)->th_urp);
    return sizeof(struct tcphdr);
}


/*
 * tcpOptionsStore -- pads the options with zero bytes to a 4-byte boundary
 * 'arg' should point to an integer which will contain the actual number of
 * bytes in 'hdr'
 */
void
tcpOptionsStore(hdr, dst, len, hdrLen)
     VOID *hdr;
     char *dst;
     long len;
     long hdrLen;
{
    bcopy(hdr, dst, hdrLen);
    if (hdrLen % 4) {
	dst += hdrLen;
	do {
	    *dst++ = 0;
	    hdrLen++;
	} while (hdrLen % 4);
    }
}


long
tcpOptionsLoad(hdr, src, len)
     VOID *hdr;
     char *src;
     long int len;
{
    bcopy(src, hdr, len);
    return len;
}


