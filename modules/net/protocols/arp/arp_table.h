/* 
 * $RCSfile: arp_table.h,v $
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Log: arp_table.h,v $
 * Revision 1.2  1996/01/29 21:59:09  slm
 * Updated copyright and version.
 *
 * Revision 1.1  1995/07/28  21:58:36  slm
 * Initial revision
 *
 * Revision 1.6.2.1.1.1  1994/10/27  01:29:00  hkaram
 * New branch
 *
 * Revision 1.6.2.1  1994/03/14  23:21:09  umass
 * Uses MAC48BitHosts instead of ETHhosts
 */

typedef struct arpent *ArpTbl;

/*
 * arpLookup -- Find the ETH/FDDI host equivalent of the given IP host.
 * If the value is not in the table, network ARP requests will be sent.
 * Returns 0 if the lookup was successful and -1 if it was not.
 */
#ifdef __STDC__
int arpLookup(Protl, IPhost *, MAC48bithost *);
#else
int arpLookup();
#endif

/*
 * arpRevLookup -- Find the IP host equivalent of the given ETH/FDDI host.
 * If the value is not in the table, network RARP requests will be sent.
 * Returns 0 if the lookup was successful and -1 if it was not.
 */
#ifdef __STDC__
int arpRevLookup(Protl, IPhost *, MAC48bithost *);
#else
int arpRevLookup();
#endif

/*
 * arpRevLookupTable -- Find the IP host equivalent of the given ETH/FDDI host.
 * Only looks in the local table, does not send network requests.
 * Returns 0 if the lookup was successful and -1 if it was not.
 */
#ifdef __STDC__
int arpRevLookupTable(Protl, IPhost *, MAC48bithost *);
#else
int arpRevLookupTable();
#endif

/*
 * Initialize the arp table.
 */
#ifdef __STDC__
ArpTbl arpTableInit(void);
#else
ArpTbl arpTableInit();
#endif

/*
 * Save the IPhost <-> ETHorFDDIhost binding, releasing any previous bindings
 * that either of these addresses might have had.  Unblocks processes
 * waiting for this binding.  One of ip or eth/fddi can be null, in which case 
 * the blocked processes will be freed and told that the address could not 
 * be resolved
 */
#ifdef __STDC__
void  arpSaveBinding(ArpTbl, IPhost *ip, MAC48bithost *ptr);
#else
void  arpSaveBinding();
#endif

/* 
 * Remove all entries from the table which are not on the same subnet
 * as the given host.  Entries will be removed regardless of lock
 * status. 
 */
#ifdef __STDC__
void arpTblPurge(ArpTbl, IPhost *);
#else
void arpTblPurge();
#endif

/*
 * arpLock -- lock the entry with the given IP host so the entry always
 * remains in the cache.
 */
#ifdef __STDC__
void arpLock(ArpTbl, IPhost *h);
#else
void arpLock();
#endif

/*
 * arpForEach -- call the function in ArpForEach for each of the
 * entries in the arp table
 */
#ifdef __STDC__
void arpForEach(ArpTbl, ArpForEach *);
#else
void arpForEach();
#endif
