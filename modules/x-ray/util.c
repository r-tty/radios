/*
 * util.c - some utilities.
 */
 
#include <stdio.h>
#include <stdlib.h>

void *ealloc(size_t n)
{
    void *p = malloc(n);

    if (p == NULL) {
	perror("malloc");
	exit(1);
    }
    return p;
}

void *erealloc(void *p, size_t n)
{
    if (p == NULL)		/* erealloc() has POSIX realloc() semantics */
	return ealloc(n);
    if ((p = realloc(p, n)) == NULL) {
	perror("realloc");
	exit(1);
    }
    return p;
}

void efree(void *p)
{
    if (p != NULL)
	free(p);
}
