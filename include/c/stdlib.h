/*
 * stdlib.h - standard library functions.
 */

#ifndef _stdlib_h
#define _stdlib_h

#define RAND_MAX        32767u
#define EXIT_SUCCESS    0
#define EXIT_FAILURE    1

typedef struct  {
    int quot;
    int rem;
} div_t;

typedef struct  {
    long quot;
    long rem;
} ldiv_t;

typedef struct  {
    long long quot;
    long long rem;
} lldiv_t;

/* Prototypes */
ldiv_t ldiv(long numer, long denom);

/* min and max macros */
#if !defined(__max)
#define __max(a,b)  (((a) > (b)) ? (a) : (b))
#endif
#if !defined(max) && !defined(__cplusplus)
#define max(a,b)  (((a) > (b)) ? (a) : (b))
#endif
#if !defined(__min)
#define __min(a,b)  (((a) < (b)) ? (a) : (b))
#endif
#if !defined(min) && !defined(__cplusplus)
#define min(a,b)  (((a) < (b)) ? (a) : (b))
#endif

#endif
