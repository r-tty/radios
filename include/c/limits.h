/*
 * limits.h - limits of integral types.
 */

#ifndef _LIMITS_H
#define _LIMITS_H

/* Number of bits in a `char' */
#define CHAR_BIT	8

/* Maximum length of any multibyte character in any locale */
#define MB_LEN_MAX	6

/* Minimum and maximum values a `signed char' can hold */
#define SCHAR_MIN	(-128)
#define SCHAR_MAX	127

/* Maximum value an `unsigned char' can hold (minimum is 0) */
#define UCHAR_MAX	255

/* Minimum and maximum values a `char' can hold */
#define CHAR_MIN	0
#define CHAR_MAX	UCHAR_MAX

/* Minimum and maximum values a `signed short int' can hold */
#define SHRT_MIN	(-32768)
#define SHRT_MAX	32767

/* Maximum value an `unsigned short int' can hold (minimum is 0) */
#define USHRT_MAX	65535

/* Minimum and maximum values a `signed int' can hold */
#define INT_MIN		(-INT_MAX - 1)
#define INT_MAX		2147483647

/* Maximum value an `unsigned int' can hold (minimum is 0) */
#define UINT_MAX	4294967295U

/* Minimum and maximum values a `signed long int' can hold */
#define LONG_MAX	2147483647L
#define LONG_MIN	(-LONG_MAX - 1L)

/* Maximum value an `unsigned long int' can hold (minimum is 0) */
#define ULONG_MAX	4294967295UL

#endif
