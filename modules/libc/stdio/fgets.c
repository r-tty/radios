/*
 * Based on FreeBSD 5.0 C library.
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 */

#include <stdio.h>
#include <stddef.h>
#include <string.h>

/*
 * Read at most n-1 characters from the given file.
 * Stop when a newline has been read, or the count runs out.
 * Return first argument, or NULL if no characters were read.
 */
char *fgets(char *buf, int n, FILE *fp)
{
	size_t len;
	char *s;
	unsigned char *p, *t;

	if (n <= 0)		/* sanity check */
		return (NULL);

	flockfile(fp);
	ORIENT(fp, -1);
	s = buf;
	n--;			/* leave space for NUL */
	while (n != 0) {
		/*
		 * If the buffer is empty, refill it.
		 */
		if ((len = fp->_r) <= 0) {
			if (__srefill(fp)) {
				/* EOF/error: stop with partial or no line */
				if (s == buf) {
					funlockfile(fp);
					return (NULL);
				}
				break;
			}
			len = fp->_r;
		}
		p = fp->_p;

		/*
		 * Scan through at most n bytes of the current buffer,
		 * looking for '\n'.  If found, copy up to and including
		 * newline, and stop.  Otherwise, copy entire chunk
		 * and loop.
		 */
		if (len > n)
			len = n;
		t = memchr((void *)p, '\n', len);
		if (t != NULL) {
			len = ++t - p;
			fp->_r -= len;
			fp->_p = t;
			(void)memcpy((void *)s, (void *)p, len);
			s[len] = 0;
			funlockfile(fp);
			return (buf);
		}
		fp->_r -= len;
		fp->_p += len;
		(void)memcpy((void *)s, (void *)p, len);
		s += len;
		n -= len;
	}
	*s = 0;
	funlockfile(fp);
	return (buf);
}
