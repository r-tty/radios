/*
 * ctype.h - ctype macros anddefinitions.
 */

#ifndef _CTYPE_H
#define _CTYPE_H

#include <sys/types.h>

#define _C_ALN 		(0x0001)
#define _C_ALP		(0x0002)
#define _C_CTL		(0x0004)
#define _C_DIG		(0x0008)
#define _C_GRA		(0x0010)
#define _C_LOW		(0x0020)
#define _C_PRN		(0x0040)
#define _C_PUN		(0x0080)
#define _C_SPC		(0x0100)
#define _C_UPE		(0x0200)
#define _C_HEX		(0x0400)

extern const ushort __ctab[];
extern const uchar __toupper_tab[];
extern const uchar __tolower_tab[];

#define isalnum(c) (__ctab[((c)&0xff)+1] & _C_ALN)
#define isalpha(c) (__ctab[((c)&0xff)+1] & _C_ALP)
#define iscntrl(c) (__ctab[((c)&0xff)+1] & _C_CTL)
#define isdigit(c) (__ctab[((c)&0xff)+1] & _C_DIG)
#define isgraph(c) (__ctab[((c)&0xff)+1] & _C_GRA)
#define islower(c) (__ctab[((c)&0xff)+1] & _C_LOW)
#define isprint(c) (__ctab[((c)&0xff)+1] & _C_PRN)
#define ispunct(c) (__ctab[((c)&0xff)+1] & _C_PUN)
#define isspace(c) (__ctab[((c)&0xff)+1] & _C_SPC)
#define isupper(c) (__ctab[((c)&0xff)+1] & _C_UPE)
#define isxdigit(c) (__ctab[((c)&0xff)+1] & _C_HEX)

#define isascii(c) ((uchar)(c) <= 0x7F)

#define tolower(c) (__tolower_tab[((c)&0xff)+1])
#define toupper(c) (__toupper_tab[((c)&0xff)+1])

#endif
