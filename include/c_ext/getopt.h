/*	
 * getopt.h - getopt_long() and BSD4.4 getsubopt()/optreset extensions.
 */

#ifndef _getopt_h
#define _getopt_h

#include <unistd.h>

struct option {
    /* name of long option */
    const char *name;
    /*
     * one of no_argument, required_argument, and optional_argument:
     * whether option takes an argument
     */
    int has_arg;
    /* if not NULL, set *flag to val when option found */
    int *flag;
    /* if flag not NULL, value to set *flag to; else return value */
    int val;
};

int getopt_long(int, char * const *, const char *, const struct option *, int *);
int getsubopt(char **, char * const *, char **);

extern char *optarg;
extern int optind, opterr, optopt;
extern char *suboptarg;
extern int optreset;
 
#endif
