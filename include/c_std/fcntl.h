/*
 * fcntl.h - File control options used by open.
 */

#ifndef _fcntl_h
#define _fcntl_h

#include <unistd.h>
#include <sys/stat.h>

/*
 *  Flag values accessible to both open() and fcntl()
 *  (The first three can only be set by open)
 */

#define O_RDONLY    000000  /*  Read-only mode  */
#define O_WRONLY    000001  /*  Write-only mode */
#define O_RDWR      000002  /*  Read-Write mode */

/* Mask for file access modes */
#define O_ACCMODE   000003

/* File status flags used for open() and fcntl() */
#define O_NONBLOCK  000200  /*  Non-blocking I/O */
#define O_APPEND    000010  /*  Append (writes guaranteed at the end) */
#define O_NDELAY O_NONBLOCK

#define O_DSYNC     000020  /*  Data integrity sync */
#define O_RSYNC     000100  /*  Data integrity sync */
#define O_SYNC      000040  /*  File integrity sync */

/* oflag values for open() */
#define O_CREAT     000400	/*  Opens with file create */
#define O_TRUNC     001000	/*  Open with truncation */
#define O_EXCL      002000	/*  Exclusive open */
#define O_NOCTTY    004000	/*  Don't assign a controlling terminal */

/* fcntl() requests */
#define F_DUPFD     0		/*  Duplicate file descriptor */
#define F_GETFD     1		/*  Get file descriptor flags */
#define F_SETFD     2		/*  Set file descriptor flags */
#define F_GETFL     3		/*  Get file status flags */
#define F_SETFL     4		/*  Set file status flags */
#define F_SETLK     6		/*  Set record locking info */
#define F_SETLKW    7
#define F_CHKFL     8
#define F_ALLOCSP   10
#define F_FREESP    11
#define F_ISSTREAM  13
#define F_GETLK     14		/*  Get record locking info */
#define F_PRIV      15
#define F_NPRIV     16
#define F_QUOTACTL  17
#define F_BLOCKS    18
#define F_BLKSIZE   19
#define F_RSETLK    20
#define F_RGETLK    21
#define F_RSETLKW   22
#define F_GETOWN    35		/* get SIGIO/SIGURG proc/pgrp */
#define F_SETOWN    36		/* set SIGIO/SIGURG proc/pgrp */

/*
 *  File descriptor flags used for fcntl()
 */
#define FD_CLOEXEC  1		/*  Close on exec */

/*
 *  l_type values for record locking with fcntl()
 */
#define F_RDLCK     1		/* Shared or read lock */
#define F_WRLCK     2		/* Exclusive or write lock */
#define F_UNLCK     3		/* Unlock */

/*
 * operation values to use with flock()
 */
#define LOCK_SH	    1		/* Shared lock */
#define LOCK_EX     2		/* Exclusive lock */
#define LOCK_NB     4		/* Don't block when locking */
#define LOCK_UN     8		/* Unlock */

#define POSIX_FADV_NORMAL	0	/* No advice to give */
#define POSIX_FADV_SEQUENTIAL	1	/* Sequentialy from lower to higher offsets */
#define POSIX_FADV_RANDOM	2	/* Random order */
#define POSIX_FADV_WILLNEED	3	/* Expects to access specified data */
#define POSIX_FADV_DONTNEED	4	/* Will not access specified data */
#define POSIX_FADV_NOREUSE	5	/* Will access specified data once */

typedef struct flock {
    int16_t     type;
    int16_t     whence;
    int32_t     reserved;
    off_t	start;
    off_t	start_hi;
    off_t	len;
    off_t	len_hi;
    pid_t       pid;
    uint32	sysid;			/* node descriptor */
} flock_t;

extern int creat( const char *path, mode_t mode );
extern int fcntl( int fildes, int cmd, ... );
extern int open( const char *path, int oflag, ... );

extern int flock(int fd, int operation);

extern int posix_fadvise(int fd, off_t offset, size_t len, int advice);
extern int posix_fallocate(int fd, off_t offset, size_t len);

struct _io_connect_entry;
extern int _connect_entry(int base, const char *path, mode_t mode, unsigned oflag, unsigned sflag, unsigned subtype, int testcancel, unsigned access, unsigned file_type, unsigned extra_type, unsigned extra_len, const void *extra, unsigned response_len, void *response, int *status, struct _io_connect_entry *entry, int enoretry);
extern int _connect_fd(int base, const char *path, mode_t mode, unsigned oflag, unsigned sflag, unsigned subtype, int testcancel, unsigned access, unsigned file_type, unsigned extra_type, unsigned extra_len, const void *extra, unsigned response_len, void *response, int *status, int *fd_len, void *fd_array);
extern int _connect(int base, const char *path, mode_t mode, unsigned oflag, unsigned sflag, unsigned subtype, int testcancel, unsigned access, unsigned file_type, unsigned extra_type, unsigned extra_len, const void *extra, unsigned response_len, void *response, int *status);
extern int _connect_combine(const char *path, mode_t mode, unsigned oflag, unsigned sflag, int testcancel, unsigned file_type, unsigned extra_len, void *extra, unsigned response_len, void *response);
extern int _connect_object(const char *name, const char *prefix, mode_t mode, int oflag, unsigned file_type, unsigned extra_type, unsigned extra_len, const void *extra);
extern int _unlink_object(const char *name, const char *prefix);

#endif
