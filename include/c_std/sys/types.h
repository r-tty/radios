/*
 * types.h - defined system types.
 */

#ifndef _sys_types_h
#define _sys_types_h

/* Types for everyone */
typedef char int8_t;
typedef short int16_t;
typedef int int32_t;
typedef long long int64_t;

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

typedef uint8_t uchar;
typedef uint16_t ushort;
typedef uint32_t uint;
typedef uint32_t ulong;

/* Boolean - it is always useful */
typedef enum { FALSE, TRUE } bool;

/*
 * Standard type definitions.
 */
typedef	int32_t		clockid_t;	/* clock_gettime()... */
typedef	uint32_t	fflags_t;	/* file flags */
typedef	uint64_t	fsblkcnt_t;
typedef	uint64_t	fsfilcnt_t;
typedef	uint32_t	gid_t;
typedef	int64_t		id_t;		/* can hold a gid_t, pid_t, or uid_t */
typedef	long		key_t;		/* IPC key (for Sys V IPC) */
typedef	uint16_t	mode_t;		/* permissions */
typedef uint32_t	nlink_t;
typedef	int64_t		off_t;		/* file offset */
typedef int64_t		ino_t;		/* inode */
typedef int32_t		dev_t;
typedef	int32_t		pid_t;		/* process [group] */
typedef	int64_t		rlim_t;		/* resource limit */
typedef	uint8_t		sa_family_t;
typedef	uint32_t	socklen_t;
typedef	int32_t		timer_t;	/* timer_gettime()... */
typedef	uint32_t	uid_t;
typedef uint32_t	time_t;
typedef uint32_t	blksize_t;
typedef uint64_t	blkcnt_t;

typedef int32_t		intptr_t;

typedef uint32_t	size_t;
typedef int32_t		ssize_t;

#ifndef __cplusplus
typedef uint32_t	wchar_t;
#endif

#endif
