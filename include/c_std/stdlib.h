/*
 * stdlib.h - standard library functions.
 */

#ifndef _stdlib_h
#define _stdlib_h

#include <sys/types.h>

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
void abort(void);
int abs(int j);
int atexit(void (*func)(void));
double atof(const char *nptr);
int atoi(const char *nptr);
long atol(const char *nptr);
void *calloc(size_t nmemb, size_t size);
div_t div(int numer, int denom);
void exit(int status);
void free(void *_ptr);
char *getenv(const char *_name);
long labs(long j);
ldiv_t ldiv(long numer, long denom);
void *malloc(size_t size);
int mblen(const char *_s, size_t n);
size_t mbstowcs(wchar_t *_pwcs, const char *_s, size_t n);
int mbtowc(wchar_t *_pwc, const char *_s, size_t n);
int rand(void);
void *realloc(void *_ptr, size_t size);
void srand(unsigned int seed);
double strtod(const char *_nptr, char **_endptr);
long strtol(const char *_nptr, char **_endptr, int base);
int system(const char *_string);
size_t wcstombs(char *_s, const wchar_t *_pwcs, size_t n);
int wctomb(char *_s, wchar_t wchar);
void *bsearch(const void *_key, const void *_base,
		size_t nmemb, size_t size, 
		int (*compar) (const void *, const void *));
void qsort(void *_base, size_t nmemb, size_t size,
		int (*compar) (const void *, const void *));
unsigned long strtoul(const char *_nptr, char **_endptr, int base);

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
