/*
 * boot.h - BTL module descriptor and other definitions.
 */

#ifndef _BOOT_H
#define _BOOT_H

#include <sys/types.h>

#define MAXMODNAMELEN 24

/*
 * This describes a module which was created by BTL.
 */
typedef struct {
    void  *imgstart;		/* Used by linker (RDOFF image address) */
    uint  size;			/* Total size (aligned) */
    ulong entry;		/* Entry point */
    ulong virtaddr;		/* Virtual address of module */
    ulong codeaddr;		/* Address of .code */
    uint  codelen;		/* size of .code */
    ulong dataaddr;		/* Address of .data */
    uint  datalen;		/* size of .data */
    uint  bsslen;		/* size of .bss (follows data) */
    ulong argpaddr;		/* Address of argp area */
    uint  argplen;		/* size of argp area */
    ulong symtabaddr;		/* Address of symtab */
    uint  symtablen;		/* size of symtab */
    char  type;			/* Module type (MODTYPE_*) */
    char  name[MAXMODNAMELEN];	/* Module name (NULL terminated) */
} tBMD;

/*
 * Boot parameters structure
 */
typedef struct {
    ulong service_entry;	/* BTL services (print, etc) */
    tBMD  *bmd_kernel;		/* Address of kernel BMD */
    tBMD  *bmd_modules;		/* Addr. of array of module BMDs */
    uint  num_modules;		/* Number of loaded modules */
    uint  mem_lower;		/* Size of lower memory in KB */
    uint  mem_upper;		/* Size of upper memory in KB */
    ulong mmap_addr;		/* BIOS memory map address */
    uint  mmap_length;		/* BIOS memory map size */
    ulong boot_device;		/* Boot device */
} tBootParams;

/*
 * Module information tag, may be embedded as a generic record
 */
#pragma pack(1)
typedef struct {
    uint   Signature;		/* Signature */
    uint   ModVersion;		/* Module version */
    uchar  ModType;		/* Module type */
    uchar  Flags;		/* Flags */
    ushort OStype;		/* Target OS type */
    uint   OSversion;		/* Target OS version */
    long   Base;		/* Base address */
} tModInfoTag;
#pragma pack(0)

#define RBM_SIGNATURE	0x004D4252

/*
 * Module types
 */
#define MODTYPE_EXECUTABLE	0
#define MODTYPE_LIBRARY		1
#define MODTYPE_KERNEL		2

#endif
