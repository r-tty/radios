/*
 * string.h - definitions for string handling functions
 */

#ifndef _STRING_H
#define _STRING_H

#include <sys/types.h>

/*
 * Prototypes
 */
void bcopy(const void *src, void *dest, unsigned int n);
void bzero(void *s, size_t n);
int bcmp(const void *s1, const void *s2, unsigned int n);

void *memcpy(void *dest, const void *src, size_t cnt);
int memcmp(const void *s1, const void *s2, size_t n);
void *memmove(void *dest, const void *src, size_t length);
void *memchr(const void *s, unsigned char c, size_t n);
void *memset(void *dest, int c, size_t n);

char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, int len);
char *strcat(char *dest, const char *src);
char *strncat(char *dest, const char *src, int len);
size_t strlen(const char *p);
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, int nbyte);
int strcoll(const char *a, const char *b);
char *strchr(const char *p, int c);
char *strrchr(const char *p, int c);
char *strdup(const char *s);
size_t strspn(const char *s1, const char *s2);
size_t strcspn(const char *s1, const char *s2);
char *strpbrk(const char *s1, const char *s2);
char *strstr(const char *s, const char *find);
char *strtok(char *s, const char *delim);
char *strsep(char **stringp, const char *delim);
int stricmp(const char *s1, const char *s2);
int strnicasecmp(const char *s1, const char *s2, size_t n);
size_t strxfrm(char *s1, const char *s2, size_t n);
void swab(const char *src, char *dest, size_t len);

char *strlwr(char *s);
char *strupr(char *s);
char *strrev(char *s);
char *strset(char *s, int ch);
char *strnset(char *s, int ch, size_t n);

#endif
