/*
 * rdf.h - Relocatable Dynamic Format (RDF) definitions.
 */

#ifndef _sys_rdf_h
#define _sys_rdf_h

#include <sys/types.h>

/* RDOFF signature */
#define RDOFF_SIGNATURE "RDOFF"

/* Maximum number of segments */
#define	RDF_MAXSEGS 64

/* Don't align structures */
#pragma pack(1)

/* "Master" header */
typedef struct {
    char Signature[5];			/* "RDOFF" */
    char AVersion;			/* '2' (or 2 for big-endian) */
    uint32 ModLen;			/* Module length */
    uint32 HdrLen;			/* Header length */
} tRDFmaster;

/* Record types */
#define RDFREC_RELOC		1
#define RDFREC_IMPORT		2
#define RDFREC_EXPORT		3
#define RDFREC_DLL		4
#define RDFREC_BSS		5
#define RDFREC_SEGRELOC		6
#define RDFREC_FARIMPORT	7
#define RDFREC_MODNAME		8
#define RDFREC_COMMON		10
#define RDFREC_GENERIC		0

/* Relocation record */
typedef struct {
    uint8 Type;				/* 1 */
    uint8 RecLen;			/* Content length */
    uint8 Seg;				/* Only 0 for code, or 1 for data
					   supported, but add 64 for relative
					   refs (i.e. do not require reloc @
					   loadtime, only linkage) */
    uint32 Ofs;				/* From start of segment in which
					   reference is located */
    uint8 Len;				/* 1, 2 or 4 bytes */
    uint16 RefSeg;			/* Segment to which reference refers to */
} tRDFreloc;


/* Import record */
typedef struct {
    uint8 Type;				/* 2 */
    uint8 RecLen;			/* Content length */
    uint8 Flags;			/* SYM_* flags */
    uint16 Seg;				/* Segment number allocated to
					   the label for reloc records -
					   label is assumed to be at
					   offset zero in this segment,
					   so linker must fix up with
					   offset of segment and of
					   offset within segment */
    char Lbl[33];			/* Zero terminated... should be
					   written to file until the zero,
					   but not after it - max len = 32 chars */
} tRDFimport;

/* Export record */
typedef struct {
    uint8 Type;				/* 3 */
    uint8 RecLen;			/* Content length */
    uint8 Flags;			/* SYM_* flags */
    uint8 Seg;				/* Segment referred to (0/1/2) */
    uint32 Ofs;				/* Offset within segment */
    char Lbl[33];			/* Zero terminated as above */
} tRDFexport;				/* (max len = 32 chars) */


/* DLL record */
typedef struct {
    uint8 Type;				/* 4 */
    uint8 RecLen;			/* Content length */
    char LibName[128];			/* Name of library to link with */
} tRDF_DLL;				/* at load time */


/* Module name record */
typedef struct {
    uint8 Type;				/* 4 */
    uint8 RecLen;			/* Content length */
    char ModName[128];			/* Module name */
} tRDF_ModName;


/* BSS record */
typedef struct {
    uint8 Type;				/* 5 */
    uint8 RecLen;			/* Content length */
    uint32 Amount;			/* Number of bytes BSS to reserve */
} tRDF_BSS;


/* Common record */
typedef struct {
    uint8 Type;				/* 10 */
    uint8 RecLen;			/* Content length */
    uint16 Seg;				/* Segment number */
    uint32 Size;			/* Size of common area */
    uint16 Align;			/* Alignment (power of 2) */
    char Lbl[33];			/* Name */
} tRDFcommon;

/* Generic record */
typedef struct {
    uint8 Type;
    uint8 RecLen;
    char Data[128];
} tRDFgeneric;

/* Export record flags */
#define	SYM_DATA		1
#define	SYM_FUNCTION		2
#define	SYM_GLOBAL		4
#define SYM_IMPORT		8

/* Segment types */
#define	RDFSEG_NULL		0
#define	RDFSEG_Text		1
#define	RDFSEG_Data		2
#define	RDFSEG_ObjComment	3
#define	RDFSEG_LinkedComment	4
#define	RDFSEG_LoaderComment	5
#define	RDFSEG_SymDebug		6
#define	RDFSEG_LineNumDebug	7
#define	RDFSEG_Bad		0FFFFh

/* Segment header */
typedef struct {
    uint16 Type;
    uint16 Number;
    uint16 Reserved;
    uint32 Length;
} tRDFsegHeader;

/* Restore default alignment */
#pragma pack(0)

#endif
