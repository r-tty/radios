/*
 * udp_port.h
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:38:16 $
 */


typedef unsigned short UDPport;

#define NAME 			udp
#define PROT_NAME		"udp"
#define TRACE_VAR		udpp
#define MAX_PORT		0xffff
#define	FIRST_USER_PORT		0x100
#define PORT_MAP_SIZE		201

/* these defines are to support the Berkeley notion of reserved ports,
 * and are common to both udp and tcp.
 */
#define LOW_PORT_FLOOR 0
#define LOW_PORT_CEILING 1024

#define HIGH_PORT_FLOOR 1024
#define HIGH_PORT_CEILING MAX_PORT

#include "port_mgr.h"
