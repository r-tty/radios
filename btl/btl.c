/*
 * btl.c - Boot-time RDOFF linker/loader.
 * Copyright (c) 2002 RET & COM Research.
 */
 
#include <stddef.h>
#include <string.h>
#include <sys/rdf.h>
#include <sys/multiboot.h>
#include <sys/boot.h>
#include <mach/param.h>

#include "btl.h"

#define _PGALIGN(x) (((x) + ADDR_OFSMASK) & ~ADDR_OFSMASK)
#define PGALIGN(x) x = _PGALIGN(x)
#define _PARALIGN(x) (((x) + 15) & ~15)
#define PARALIGN(x) x = _PARALIGN(x)

#define PA2VA(btlp,pa) ((ulong)(pa) - (btlp)->codeaddr + (btlp)->virtaddr)

static const char rdf_signature[] = RDOFF_SIGNATURE;

/* This used to dereference any header record */
typedef union {
    tRDFgeneric g;
    tRDFreloc r;
    tRDFimport i;
    tRDFexport e;
    tRDF_DLL l;
    tRDF_ModName m;
    tRDF_BSS b;
    tRDFcommon c;
} tURDFrec;

/* Boot Module Descriptor (BMD) for kernel */
tBMD bmd_kernel;

/* Array of BMDs for modules */
tBMD bmd_modules[MAXMODULES+1];

/* Boot parameters */
tBootParams *bootparam = (void *)BOOTPARM;


/*
 * Create argp area. Layout will be like this:
 *	argc
 *	argv[1]
 *	argv[2]
 *	...
 *	arg string area
 */
static void create_argp_area(char *cmdline, tBMD *btlp)
{
    uint *argc = (uint *)btlp->argpaddr;
    char **argv = (char **)(btlp->argpaddr + sizeof(ulong));
    char *p = cmdline;
    int i, len = strlen(cmdline)+1;

    *argc = 0;
    while (p) {
	argv[*argc] = (char *)PA2VA(btlp, p - cmdline);
	while (*p && (*p != ' '))
	    p++;
	if (!*p) p = 0;
	else *p++ = '\0';
	argc[0]++;
    }
    p = (void *)(argv + argc[0]);
    memcpy(p, cmdline, len);
    for (i = 0; i < argc[0]; i++)
    	argv[i] += (ulong)p;
    btlp->argplen = sizeof(ulong) + sizeof(ulong)*argc[0] + strlen(cmdline) + 1;
}


/*
 * Search in a symbol table
 */
static void *symtab_search(void *stbegin, const char *what)
{
    char *iptr = stbegin;

    while (*iptr) {
	tRDFexport *rp = (void *)iptr;
	int n = rp->RecLen + 2;
	if (strcmp(what, rp->Lbl) == 0)
	    return iptr;
	iptr += n;
    }
    return NULL;
}


/*
 * Check if a module is loaded. Kernel is checked as well.
 */
static tBMD *is_module_loaded(const char *name)
{
    tBMD *btlp = &bmd_kernel;

    while (btlp->size) {
	if (strcmp(btlp->name, name) == 0)
	    return btlp;
	if (btlp == &bmd_kernel)
	    btlp = bmd_modules;
	else
	    btlp++;
    }
    return NULL;
}


/*
 * Walk through header records, pass 1:
 *  - calculate BSS segment size;
 *  - store module name;
 *  - check some global names:
 *      "Start" - fill in entry point address,
 *	"ModuleInfo" - fill in additional module information.
 */
static void modhdr_pass1(tURDFrec *hdrstart, uint hdrlen, tBMD *btlp)
{
    char *iptr = (char *)hdrstart;
    uint bsslen = 0, modnamefound = 0, infotagfound = 0;
    static const char *infotagmsg = "module information tag";
    
    while (hdrlen > 0) {
	tURDFrec *recp = (void *)iptr;
	int n = recp->g.RecLen + 2;
	iptr += n, hdrlen -= n;
	switch (recp->g.Type) {
	    case RDFREC_BSS:
	    	bsslen += recp->b.Amount;
		break;
	    case RDFREC_COMMON:
		panic("%s: COMMON record encountered");
	    case RDFREC_EXPORT:
		if (strcmp(recp->e.Lbl, "ModuleInfo") == 0) {
		    tModInfoTag *mtag = (void *)(btlp->dataaddr + recp->e.Ofs);
		    /* Is module information tag inside the data segment? */
		    if (recp->e.Seg != 1)
		    	panic("%s: %s is not in data segment", btlp->name, infotagmsg);
		    if (mtag->Signature != RBM_SIGNATURE)
		    	panic("%s: invalid %s signature (%#x)", btlp->name, infotagmsg, mtag->Signature);
		    btlp->type = mtag->ModType;
		    if (mtag->Base == -1)
			/* Special case - for kernel extension modules */
		    	btlp->virtaddr = btlp->codeaddr;
		    else
		    	btlp->virtaddr = mtag->Base;
		    if (mtag->Entry != -1)
		    	/* Alternative method to specify entry point */
			btlp->entry = btlp->virtaddr + mtag->Entry;
		    infotagfound = 1;
		    break;
		}
		if (strcmp(recp->e.Lbl, "Start") == 0) {
		    /* Is entry point inside the code segment? */
		    if (recp->e.Seg != 0)
		    	panic("%s: entry point is not in code segment", btlp->name);
		    btlp->entry = btlp->virtaddr + recp->e.Ofs;
		    break;
		}
		break;
	    case RDFREC_MODNAME:
	    	if (!modnamefound) {
		    strncpy(btlp->name, recp->m.ModName, MAXMODNAMELEN);
		    btlp->name[MAXMODNAMELEN-1] = '\0';
		    modnamefound = 1;
		}
		break;
	}
    }
    if (!infotagfound)
	panic("%s: %s not found", btlp->name, infotagmsg);
    btlp->bsslen = _PARALIGN(bsslen);
}


/*
 * Walk through header records, pass 2:
 *  - build symbol table
 */
static void modhdr_pass2(tURDFrec *hdrstart, uint hdrlen, tBMD *btlp)
{
    char *iptr = (char *)hdrstart;
    char *stentry = (char *)btlp->symtabaddr;

    while (hdrlen > 0) {
	tURDFrec *recp = (void *)iptr;
	int rsize = recp->g.RecLen + 2;
	iptr += rsize, hdrlen -= rsize;
	switch (recp->g.Type) {
	    case RDFREC_EXPORT:
		if (recp->e.Flags & SYM_GLOBAL) {
		    memcpy(stentry, recp, rsize);
		    stentry += rsize;
		    btlp->symtablen += rsize;
		}
		break;
	}
    }

    /* If we created symbol table, write trailing zeros */
    if (btlp->symtablen) {
	stentry[0] = 0;
	stentry[1] = 0;
	btlp->symtablen += 2;
    }
}


/*
 * Build a module from its RDF image.
 *
 * Module is built with starting address `destaddr'
 * Layout of the module after building:
 *  code section
 *  data section
 *  BSS space (initialized with zeros)
 *  Arguments area
 *  Symbol table (optional)
 */
void build_module(tBMD *btlp, ulong destaddr, char *cmdline)
{
    char *iptr = btlp->imgstart;
    const tRDFmaster *master = btlp->imgstart;
    void *hdrstart = iptr + sizeof(tRDFmaster);
    uint hdrlen = master->HdrLen;
    ulong destptr = destaddr;
    char *arg1 = NULL;
    int i;

    /* Trim absolute path off first argument */
    if (*cmdline == '/') {
	while (*cmdline && (*cmdline != ' '))
	    ++cmdline;
	arg1 = cmdline;
	while (*--cmdline != '/') ;
	++cmdline;
    }

    /*
     * Until we read module name record, assume that module name is name
     * of the file from which it was loaded.
     */
    i = arg1 ? (arg1 - cmdline + 1) : MAXMODNAMELEN;
    if (i > MAXMODNAMELEN) i = MAXMODNAMELEN;
    strncpy(btlp->name, cmdline, i);
    btlp->name[i-1] = '\0';

    /*
     * If module name begins with '!' - it is a "raw" module (e.g. RAM-disk
     * image or non-RDOFF module). This is a special case, when there is no
     * code and BSS. And we don't copy this module to destaddr!
     */
    if (btlp->name[0] == '!') {
	btlp->type = MODTYPE_RAW;
	btlp->virtaddr = (ulong)btlp->imgstart;
	btlp->dataaddr = (ulong)btlp->imgstart;
	btlp->size = (ulong)btlp->imgend - btlp->dataaddr;
	return;
    }

    /* Check RDOFF signature and version */
    if (memcmp(master->Signature, rdf_signature, sizeof(rdf_signature)-1) != 0)
	panic("%s: invalid RDOFF signature", btlp->name);
    if (master->AVersion != '2')
	panic("%s: bad RDOFF version", btlp->name);

    /* Seek at the beginning of code section */
    iptr += hdrlen + sizeof(tRDFmaster);
    
    /* Copy code and data sections to their locations */
    for (i = 0; i < 2; i++) {
	tRDFsegHeader *secp = (void *)iptr;
	uint seclen = _PARALIGN(secp->Length);
	PGALIGN(destptr);
	switch (secp->Type) {
	    case 0:		/* End of list */
		goto records;
	    case 1:		/* Code */
		btlp->codeaddr = destptr;
		btlp->codelen = seclen;
		break;
	    case 2:		/* Data */
		btlp->dataaddr = destptr;
		btlp->datalen = seclen;
		break;
	    default:
		panic("%s: illegal segment type %d", btlp->name, secp->Type);
	}
	iptr += sizeof(tRDFsegHeader);
	memcpy((void *)destptr, iptr, secp->Length);
	iptr += secp->Length;
	destptr += seclen;
    }

records:
    /* Pass1: BSS, module name, some exports */
    modhdr_pass1(hdrstart, hdrlen, btlp);
    memset((void *)destptr, 0, btlp->bsslen);
    destptr += btlp->bsslen;

    /* Create argp area */
    btlp->argpaddr = PGALIGN(destptr);
    create_argp_area(cmdline, btlp);
    destptr += btlp->argplen;

    /* Pass2: create symbol tables (for library and kernel modules) */
    if (btlp->type != MODTYPE_EXECUTABLE) {
	btlp->symtabaddr = PGALIGN(destptr);
	modhdr_pass2(hdrstart, hdrlen, btlp);
    }

done:
    btlp->size = _PGALIGN(btlp->codelen) + 
                 _PGALIGN(btlp->datalen + btlp->bsslen) +
		 _PGALIGN(btlp->argplen) + _PGALIGN(btlp->symtablen);
}


/*
 * Resolve imported references in a module and fix up relocations.
 * Scratch area is used to build an import table during first pass.
 */
void resolve_module(const tBMD *btlp, ulong imptbuf)
{
    const tRDFmaster *master = btlp->imgstart;
    char *imptentry = (char *)imptbuf;
    tBMD *dll = NULL;
    int pass, unres_links = 0;

    for (pass = 0; pass < 2; pass++) {
	char *iptr = btlp->imgstart;
	uint hdrlen = master->HdrLen;

	iptr += sizeof(tRDFmaster);
	while (hdrlen > 0) {
	    tURDFrec *recp = (void *)iptr;
	    int rsize = recp->g.RecLen + 2;
	    iptr += rsize, hdrlen -= rsize;
	    switch (recp->g.Type) {
		case RDFREC_DLL:
		    if ((dll = is_module_loaded(recp->l.LibName)) == NULL)
			panic("%s: DLL `%s' is not loaded", btlp->name, recp->l.LibName);
		    if (dll->type == MODTYPE_EXECUTABLE)
			panic("%s: module `%s' is not a DLL", btlp->name, dll->name);
		    break;
		case RDFREC_IMPORT:
		    if (pass) break;
		    if (dll == NULL)
			panic("%s: import from undefined DLL", btlp->name);
		    memcpy(imptentry, recp, rsize);
		    imptentry += rsize;
		    break;
		case RDFREC_RELOC: {
		    ulong sn, segstart, refsegstart, *where;
		    tRDFexport *etp;
		    char *impsymbol = NULL;

		    if (!pass) break;

		    sn = (recp->r.Seg & 64) ? recp->r.Seg - 64 : recp->r.Seg;
		    segstart = (sn == 0) ? btlp->codeaddr : btlp->dataaddr;
		    where = (void *)(segstart + recp->r.Ofs);
		    
		    if (recp->r.RefSeg < 3) {
			/* Static relocation */
			switch (recp->r.RefSeg) {
			    case 0:
				*where += btlp->codeaddr;
				break;
			    case 1:
				*where += btlp->dataaddr;
				break;
			    case 2:
				*where += btlp->dataaddr + btlp->datalen;
			}
			*where = PA2VA(btlp, *where);
			continue;
		    }

		    /*
		     * Dynamic relocation (to the external object).
		     *
		     * First, find a segment we're reffering to in the
		     * import table that was just built during 1st pass
		     */
		    imptentry = (char *)imptbuf;
    		    while (*imptentry) {
			tRDFimport *iep = (void *)imptentry;
			int n = iep->RecLen + 2;
			if (recp->r.RefSeg == iep->Seg) {
			    impsymbol = iep->Lbl;
			    break;
			}
			imptentry += n;
		    }
		    if (impsymbol == NULL)
			panic("%s: dynamic relocation to undefined segment %d", btlp->name, recp->r.RefSeg);

		    /* Next, find imported symbol in a symtab */
		    if ((etp = symtab_search((void *)dll->symtabaddr, impsymbol)) == NULL) {
			printf("%s: imported name '%s' not found in %s\n",
			        btlp->name, impsymbol, dll->name);
			unres_links++;
			break;
		    }
#ifdef BTL_DEBUG
		    printf("Relocation in %s @ %#x:%#x -> %s::%s (%#x:%#x)\n",
			    btlp->name, recp->r.Seg, recp->r.Ofs, 
			    dll->name, etp->Lbl, etp->Seg, etp->Ofs);
#endif
		    /* Finally, perform a fix-up */
		    switch (etp->Seg) {
		        case 0:
			    refsegstart = dll->codeaddr;
			    break;
			case 1:
			    refsegstart = dll->dataaddr;
			    break;
			case 2:
			    refsegstart = dll->dataaddr + dll->datalen;
			    break;
			default:
			    panic("%s::%s has unknown segment %#x", \
			    		dll->name, etp->Lbl, etp->Seg);
		    }
		    if (recp->r.Seg & 64)
		    	/* This is relative relocation */
			*where += PA2VA(dll, (refsegstart + etp->Ofs)) -
			          PA2VA(btlp, segstart);
		    else
		    	/* Normal relocation */
		    	*where = PA2VA(dll, (refsegstart + etp->Ofs));
		    break;
		}
	    }
	}
	if (!pass)
	    /* Write null terminator of the import table */
	    imptentry[0] = 0;
	else if (unres_links)
	    panic("%d unresolved links encountered", unres_links);
    }
}


/*
 * Print information about built module
 */
void print_module_info(const tBMD *btlp)
{
    static const char *none = "-";
    char t;
    
    switch (btlp->type) {
	case MODTYPE_EXECUTABLE:
	    t = 'x';
	    break;
	case MODTYPE_LIBRARY:
	    t = 'l';
	    break;
	case MODTYPE_KERNEL:
	    t = 'k';
	    break;
	case MODTYPE_RAW:
	    t = 'r';
	    break;
	default:
	    t = '?';
    }
    printf("%-24s%c\t%-8d", btlp->name, t, btlp->size);
    if (btlp->codeaddr) printf("%#-9X", btlp->codeaddr);
    else printf("%-9s", none);
    if (btlp->dataaddr) printf("%#-9X", btlp->dataaddr);
    else printf("%-9s", none);
    if (btlp->bsslen) printf("%#-9X", btlp->dataaddr + btlp->datalen);
    else printf("%-9s", none);
    if (btlp->symtablen) printf("%#-9X", btlp->symtabaddr);
    else printf("%-9s", none);
    putchar('\n');
}


/*
 * Main - build kernel and modules.
 * Returns kernel entry point.
 */
ulong cmain(ulong magic, tMultibootInfo *mbi)
{
    ulong heap = KERNIMG, impt;
    tRDFimport **import_tables;
    char kcmdline[256];
    int i, nmods = 0;

    /* Check if we were really booted with multiboot loader */
    if (magic != MULTIBOOT_LOADER_MAGIC)
	panic("invalid multiboot loader signature");

    /* Initialize boot parameters area with zeros */
    memset(bootparam, 0, sizeof(tBootParams));

    /* Check memory information */
    if (mbi->flags & MB_INFO_MEMORY) {
	bootparam->mem_lower = mbi->mem_lower;
	bootparam->mem_upper = mbi->mem_upper;
    } else {
	/* Weird case, but let's just assume */
	bootparam->mem_lower = 640;
	bootparam->mem_upper = 1024;
    }
    
    /* If extended memory map is present, copy it to the new location */
    if (mbi->flags & MB_INFO_MEM_MAP) {
	memcpy((void *)MEMMAP, (void *)mbi->mmap_addr, mbi->mmap_length);
	bootparam->mmap_addr = MEMMAP;
	bootparam->mmap_length = mbi->mmap_length;
    }

    /* May be somebody will need boot device information */
    if (mbi->flags & MB_INFO_BOOTDEV)
	bootparam->boot_device = mbi->boot_device;

    puts("Module\t\t\tType    Size    .text    .data    .bss     symtab");

    /* There should be some modules loaded.. */    
    if (mbi->flags & MB_INFO_MODS) {
	tBootModule *bm = (void *)mbi->mods_addr;

	if ((nmods = mbi->mods_count) > MAXMODULES)
	    panic("too many boot modules");
	
	/*
	 * First, walk through module list and find a page after last module
	 * image. This will be a "heap" start address.
	 */
	for (i = 0; i < nmods; i++)
	    if (bm[i].mod_end > heap)
		heap = bm[i].mod_end;
	PGALIGN(heap);

	/*
	 * Initialize the array of Boot Module Descriptors with zeros.
	 * Array contains trailing null element.
	 */
	memset(bmd_modules, 0, (nmods+1) * sizeof(tBMD));

	/* Build modules (sections, argp, symtabs) */
	for (i = 0; i < nmods; i++) {
	    bmd_modules[i].imgstart = (void *)bm[i].mod_start;
	    bmd_modules[i].imgend = (void *)bm[i].mod_end;
	    build_module(bmd_modules+i, heap, (void *)bm[i].string);
	    heap += bmd_modules[i].size;
	    print_module_info(bmd_modules+i);
	}
    }

    /* Copy kernel command line to a safe buffer before use */
    if (mbi->flags & MB_INFO_CMDLINE) {
	strncpy(kcmdline, (char *)mbi->cmdline, sizeof(kcmdline));
	kcmdline[sizeof(kcmdline)-1] = '\0';
    } else strcpy(kcmdline, "kernel");
    
    /*
     * Build the kernel. We do it now because multiboot information resides
     * in lower memory, and it needs to be valid while the modules are
     * being built.
     */
    memset(&bmd_kernel, 0, sizeof(bmd_kernel));
    bmd_kernel.imgstart = (void *)KERNIMG;
    build_module(&bmd_kernel, KERNSTART, kcmdline);
    resolve_module(&bmd_kernel, heap);
    print_module_info(&bmd_kernel);
    
    /* Finally, resolve all imported references in the modules... */
    for (i = 0; i < nmods; i++)
	if (bmd_modules[i].type != MODTYPE_RAW)
	    resolve_module(bmd_modules+i, heap);

    /* ...and let the kernel to do the job. */
    bootparam->bmd_kernel = &bmd_kernel;
    bootparam->num_modules = nmods;
    bootparam->bmd_modules = nmods ? bmd_modules : NULL;
    return bmd_kernel.entry;
}
