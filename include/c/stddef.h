/*
 * stddef.h - some POSIX definitions
 */

#ifndef _STDDEF_H
#define _STDDEF_H

/* NULL pointer */
#ifndef NULL
#define NULL (0)
#endif

/* size_t */
#ifndef _SIZE_T
#define _SIZE_T
typedef unsigned long size_t;
#endif

#endif
