/*
 * tcp_port.h
 *
 * x-kernel v3.3
 *
 * Copyright (c) 1993,1991,1990,1996  Arizona Board of Regents
 *
 * $Revision: 1.2 $
 * $Date: 1996/01/29 22:30:32 $
 */
#ifndef tcp_port_h
#define tcp_port_h

typedef unsigned short TCPport;

#define MAX_PORT        0xffff
#define MIN_PORT        0

#define NAME            tcp
#define PROT_NAME       "tcp"
#define TRACE_VAR       tcpp
#define FIRST_USER_PORT 0x100
#define PORT_MAP_SIZE   201

#include "port_mgr.h"

#endif /* tcp_port_h */
