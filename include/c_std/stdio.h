/*
 * stdio.h - definitions for standard file input/output.
 */

#ifndef _stdio_h
#define _stdio_h

#include <stdarg.h>
#include <sys/types.h>

typedef	off_t fpos_t;

/* stdio buffer structure */
struct __sbuf {
    unsigned char *_base;
    int	_size;
};

/* Stream structure */
typedef	struct {
    unsigned char *_p;		/* current position in (some) buffer */
    int	_r;			/* read space left for getc() */
    int	_w;			/* write space left for putc() */
    short _flags;		/* flags, below; this FILE is free if 0 */
    short _file;		/* fileno, if Unix descriptor, else -1 */
    struct __sbuf _bf;		/* the buffer (at least 1 byte, if !NULL) */
    int	_lbfsize;		/* 0 or -_bf._size, for inline putc */

    /* operations */
    void *_cookie;		/* cookie passed to io functions */
    int	(*_close)(void *);
    int	(*_read)(void *, char *, int);
    fpos_t (*_seek)(void *, fpos_t, int);
    int	(*_write)(void *, const char *, int);

    /* ungetc() and getc() buffers */
    unsigned char _ubuf[3];	/* guarantee an ungetc() buffer */
    unsigned char _nbuf[1];	/* guarantee a getc() buffer */

    /* separate buffer for fgetln() when line crosses buffer boundary */
    struct __sbuf _lb;		/* buffer for fgetln() */

    /* Unix stdio files get aligned to block boundaries on fseek() */
    int	_blksize;		/* stat.st_blksize (may be != _bf._size) */
    fpos_t _offset;		/* current lseek offset (see WARNING) */
} FILE;

/* Standard I/O streams */
extern FILE *stdin, *stdout, *stderr;

/* Prototypes */
int vsprintf(char *buf, const char *fmt, va_list args);
int sprintf(char * buf, const char *fmt, ...);
int printf(const char* fmt, ...);

#endif
