/*
 * stdio.h - definitions for standard file input/output.
 */

#ifndef _stdio_h
#define _stdio_h

#include <stdarg.h>

int vsprintf(char *buf, const char *fmt, va_list args);
int sprintf(char * buf, const char *fmt, ...);
int printf(const char* fmt, ...);

#endif
