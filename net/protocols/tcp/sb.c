/*
 * $RCSfile: sb.c,v $
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
 * Modified for x-kernel v3.3
 * Modifications Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: sb.c,v $
 * Revision 1.2  1996/01/29 22:32:07  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  22:15:41  slm
 * Initial revision
 *
 * Revision 1.5.2.2  1994/12/02  18:24:18  hkaram
 * David's TCP
 *
 * Revision 1.5  1993/12/07  18:13:16  menze
 * Added a prototype
 */

/*
 * sb = send buffer ??
 */

#include "xkernel.h"
#include "insque.h"
#include "sb.h"

extern int tracetcpp;
struct sb_i *sbifreelist = 0;


#ifdef __STDC__

static void	print_sb( struct sb *, char * );

#endif


static void
print_sb(sb, m)
    struct sb *sb;
    char *m;
{
    struct sb_i *s;
    printf("%s sbLen == %d:", m, sb->len);
    for (s = sb->next; s != (struct sb_i *)sb; s = s->next) {
	printf("(%d)", msgLength(&s->m));
    }
    printf("\n");
}


void
sbappend(sb, m)
    struct sb *sb;
    Msg *m;
{
    struct sb_i *nsb;
    xTrace3(tcpp, TR_EVENTS, "sbappend on %lx olen %d msglen %d",
	    (u_long)sb, sb->len, msgLength(m));
    if (msgLength(m) == 0) {
	return;
    }
    sbinew(nsb);
    msgConstructCopy(&nsb->m, m);
    if (sb->len==0) {
	sb->next = nsb;
	nsb->prev = (struct sb_i *)sb;
    }
    else {
	nsb->prev = sb->prev;
	nsb->prev->next = nsb;
    }
    nsb->next = (struct sb_i *)sb;
    sb->prev = nsb;
    
    sb->len += msgLength(m);
    /*  insque(nsb, sb->next); */
    xIfTrace(tcpp, 4) print_sb(sb, "append");
}


/*
 * collect 'len' bytes at offset 'off' from send buffer 'sb' and put
 * them in msg 'm'.  'm' is assumed to be uninitialized.
 */
void
sbcollect(sb, m, off, len, delete)
    struct sb *sb;
    Msg *m;
    int off, len, delete;
{
    struct sb_i *s, *next;
    
    xTrace5(tcpp, TR_EVENTS, "sbcollect on %lx olen %d len %d off %d %s",
	    (u_long)sb, sb->len, len, off, delete ? "delete" : "");
    xAssert(!delete || off == 0);
    if (len == 0) {
	msgConstructEmpty(m);
	return;
    }
    xIfTrace(tcpp, 5) print_sb(sb, "collect");
    for (s = sb->next;
	 s != (struct sb_i *)sb && off >= msgLength(&s->m);
	 s = s->next) 
      off -= msgLength(&s->m);
    xAssert(s != (struct sb_i *)sb);
    if (off != 0 PREDICT_FALSE) {
	if (off > 0 && off < msgLength(&s->m)) {
	    struct sb_i *ns;
	    sbinew(ns);
	    msgConstructEmpty(&ns->m);
	    xTrace2(tcpp, TR_MORE_EVENTS,
		    "sbcollect: split0 msg size %d at %d", msgLength(&s->m), off);
	    msgBreak(&s->m, &ns->m, off);
	    insque(ns, s);
	} /* if */
    } /* if */
    if (msgLength(&s->m) > len PREDICT_FALSE) {
	struct sb_i *ns;
	sbinew(ns);
	msgConstructEmpty(&ns->m);
	xTrace2(tcpp, TR_MORE_EVENTS, "sbcollect: split1 msg size %d at %d",
		msgLength(&s->m), len);
	msgBreak(&s->m, &ns->m, len);
	insque(ns, s);
	s = ns;
    }
    /*
     * We now have s pointing to the first msg, collect the rest
     */
    xTrace1(tcpp, TR_MORE_EVENTS, "sbcollect: first piece has size %d",
	    msgLength(&s->m));
    msgConstructCopy(m, &s->m);
    len -= msgLength(m);
    if (len PREDICT_FALSE) {
	s = s->next;
	while (len > 0) {
	    xAssert(s != (struct sb_i *) sb);
	    next = s->next;
	    if (msgLength(&s->m) > len) {
		sbinew(next);
		msgConstructCopy(&next->m, &s->m);
		xTrace2(tcpp, TR_MORE_EVENTS,
			"sbcollect: split2 msg size %d at %d",
			msgLength(&s->m), len);
		msgBreak(&next->m, &s->m, len);
		insque(next, s->next);
	    }
	    /* msg_save(s->m, s->m); */
	    msgJoin(m, m, &s->m);
	    len -= msgLength(&s->m);
	    s = next;
	} /* while */
    } /* if */
}


void
sbflush(sb)
    struct sb *sb;
{
    struct sb_i *s = sb->next, *next;
    
    xTrace2(tcpp, TR_EVENTS, "sbflush on %lx olen %d", (u_long)sb, sb->len);
    while (s != (struct sb_i *)sb) {
	next = s->next;
	xTrace1(tcpp, TR_MORE_EVENTS,
		"sbflush: freeing msg len %d", msgLength(&s->m));
	msgDestroy(&s->m);
	sbifree(s);
	s = next;
    }
    sb->len = 0;
}


void
sbdrop(sb, len)
    struct sb *sb;
    int len;
{
  struct sb_i *s, *next;

  s = sb->next;
  xTrace3(tcpp, TR_EVENTS, "sbdrop on %lx olen %d len %d",
	  (u_long)sb, sb->len, len);
  xIfTrace(tcpp, TR_MORE_EVENTS) {
      print_sb(sb, "drop before");
  } /* if */
  while (s != (struct sb_i *)sb && len > 0) {
    if (len < msgLength(&s->m) PREDICT_FALSE) {
      struct sb_i *ns;
      sbinew(ns);
      msgConstructEmpty(&ns->m);
      xTrace2(tcpp, TR_MORE_EVENTS, "sbdrop: split msg size %d at %d",
	      msgLength(&s->m),len);
      msgBreak(&s->m, &ns->m, len);
      insque(ns, s->next);
    }
    len -= msgLength(&s->m);
    sb->len -= msgLength(&s->m);
    next = s->next;
    remque(s);
    xTrace1(tcpp, TR_MORE_EVENTS, "sbdrop: freeing msg len %d", msgLength(&s->m));
    msgDestroy(&s->m);
    sbifree(s);
    s = next;
  }
  xIfTrace(tcpp, 5) print_sb(sb, "drop after");
}


void
sbdelete(sb)
    struct sb *sb;
{
  xTrace1(tcpp, TR_MAJOR_EVENTS, "sbdelete on %lx", (u_long)sb);
  sbflush(sb);
  xFree((char *)sb);
}
