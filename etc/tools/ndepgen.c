/*
 * ndepgen.c - NASM dependencies file generator.
 * Copyright (c) 2002 RET & COM Research.
 */
 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

#define VERSION "1.2"

const char pathsep = '/';		/* Path separator */
const char ppctl = '%';			/* Preprocessor control char */
const char incdirective[] = "include";  /* Preprocessor include directive */

char *var_suffix = "_dep =", *obj_suffix=".rdm:";

struct {
    int makefilestyle;
} options = {0};

/*
 * Print an error message and exit
 */
void error(char *msg, int errorlevel)
{
  fprintf(stderr, "%s\n", msg);
  exit(errorlevel);
}


/*
 * Print version information
 */
inline void version(void) {
    puts ("ndepgen - NASM dependencies file generator, version " VERSION "\n"
          "Copyright (c) 2002 RET & COM Research. All rights reserved");
}


/*
 * Print usage and exit
 */
void usage(void)
{
    printf("Usage: ngepgen [options] files\n\n"
           "Options: -s<suffix>   - specify a suffix for target dependency\n"
           "         -M           - generate Makefile-style dependencies\n"
	   "         -V           - print defaults\n"
	   "         -v           - print program version\n"
	   "         -h           - get the usage\n");
    exit(0);
}

 
/*
 * Strip non-directory suffix from the path.
 * Returns NULL if path doesn't contain any slashes; otherwise returns
 * directory name with trailing slash.
 */
char *n_dirname(char *s)
{
    char *p = s;

    if (!s) return NULL;
    if ((p = strrchr(s, pathsep)) != NULL) {
	*(++p) = '\0';
	return s;
    } else return NULL;
}


/*
 * Strip directory and suffix from the path.
 */
char *n_basename(char *s, char suffixsep)
{
    char *p = s, *t = s;
  
    if (!s) return NULL;
    if (suffixsep && ((t = strchr(s, suffixsep)) != NULL)) *t = '\0';
    if ((p = strrchr(s, pathsep)) != NULL) {
	*p++ = '\0';
	return p;
    } else return s;
}


/*
 * Main
 */
int main(int argc, char *argv[])
{
    FILE *fd, *ft;
    char Buf[128], Buf2[256], Buf3[256];
    char *suffix = NULL, *p, *name, *searchpath = NULL;
    int i, wl;

    if (argc<2) usage();
    for (++argv, --argc; argc; ++argv, --argc) {
    	if (*(p = *argv) != '-')
	    break;
	switch(p[1]) {
	    case 's':
		if (!p[2]) error("Invalid suffix", 3);
		suffix = p + 2;
		break;
	    case 'M':
		options.makefilestyle = 1;
		break;
	    case 'V':
		printf("Default suffixes: '%s', '%s'\n", var_suffix, obj_suffix);
		exit(0);
	    case 'v':
		version();
		exit(0);
	    case 'h':
	    case '?':
		usage();
	    default:
		error("Unrecognized option. Run with '-h' to get usage", 2);
	}
    }

    if (!suffix) {
	if (options.makefilestyle)
	    suffix = obj_suffix;
	else
	    suffix = var_suffix;
    }
    
    wl = strlen(incdirective);
    for (i = 0; i < argc; i++) {
	int hasdep = 0;
	fd = fopen(argv[i],"r");
	if (!fd) error ("file opening error", errno);
	while (!feof(fd)) {
	    Buf[0] = 0;
	    fgets(Buf, sizeof(Buf), fd);
	    if (Buf[0] != ppctl)
		continue;
	    if (strncmp(p = Buf+1, incdirective, wl))
		continue;
	    p += wl;
	    while (*p != '"' && *p != '<') {
		if(!p++) error("Invalid include directive syntax", 4);
	    }
	    name = ++p;
	    while (*p != '"' && *p != '>') {
		if(!p++) error("Invalid include directive syntax", 4);
	    }
	    *p = 0;
	    if (!hasdep) {
		hasdep = 1;
		strcpy(Buf2, argv[i]);
		searchpath = n_dirname(Buf2);
		strcpy(Buf3, argv[i]);
		printf("%s%s %s ",n_basename(Buf3, '.'), suffix, argv[i]);
	    }
	    if (searchpath) {
		strcat(strcpy(Buf3,searchpath), name);
		ft = fopen(Buf3, "r");
		if (ft) {
		    fclose(ft);
		    name = Buf3;
		}
	    }
	    printf("%s ", name);
	}
	if (hasdep) putchar('\n');
	fclose(fd);
    }
  return 0;
}
