/******************************************************************************
 * ndepgen.c - NASM dependencies file generator, version 1.1
 * (c) 1999 RET & COM Research.
 ******************************************************************************/
 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

static char pathsep = '\\';             /* Path separator */
static char pathsep2 = '/';             /* Another path separator */

static char ppctl = '%';                /* Preprocessor control char */
static char *incldir="include";         /* Preprocessor include directive */

struct {
        int separconv;
	int makefilestyle;
       } options = {0};

void error(char *msg, int errorlevel)
 {
  fprintf(stderr,"%s\n",msg);
  exit(errorlevel);
 }

void usage(void)
 {
  puts("\nndepgen - NASM dependencies file generator, version 1.1");
  puts("(c) 2000 RET & COM Research.\n");
  puts("Usage: ngepgen [options] filename\n");
  puts("Options: -c  - path separator conversion;");
  puts("         -M  - generate Makefile-style dependencies.");
  exit(0);
 }
 
char *strlwr(char *src)
 {
  char *t=src;
  while(*t++) {
   *t = tolower(*t);
  }
  return src;
 } 

char *basepath(char *s)
 {
  char *p=s;
  int i;

  for(i=0; i<strlen(s); i++) {
    if (s[i] == pathsep || s[i] == pathsep2)
      p = s+i;
  }
  if (*p == pathsep || *p == pathsep2) {
    *(++p) = 0;
    return s;
  } else return 0;
 }

char *Basename(char *s)
 {
  char *p=s;
  int i;

  for(i=0; i<strlen(s); i++) {
    if (s[i] == pathsep || s[i] == pathsep2)
      p = s+i;
  }
  if (*p == pathsep || *p == pathsep2)
    *(p++) = 0;
  return p;
 }

char *depname(char *s)
 {
  char *p=s, *p1;
  int i;

  for(i=0; i<strlen(s); i++) {
    if (s[i] == pathsep || s[i] == pathsep2)
      p = s+i;
    if (s[i] == '.')
      p1 = s+i;
  }
  if (*p1 == '.')
    *(p1++) = 0;
  return p;
 }

char *convertsep(char *s)
 {
  int i;

  if (!options.separconv) return s;
  for(i=0; i<strlen(s); i++) {
    if (s[i] == pathsep)
      s[i] = pathsep2;
  }
  return s;
 }

int main(int argc, char *argv[])
 {
  FILE *f, *ft;
  char Buf[128], Buf2[256], Buf3[256], *p, *name, *searchpath;
  int k, hasdep=0;
  char *var_suffix="_dep =", *file_suffix=".rdm:";
  char *suffix;

  if(argc<2) usage();
  while(argv[1][0]=='-') {
   switch(argv[1][1]) {

    case 'c': options.separconv = 1;
	      break;
    case 'M': options.makefilestyle = 1;
    	      break;
   }
   argv++;
  }
  f = fopen(argv[1],"r");
  if (errno) error ("file opening error",2);
  while(!feof(f)) {
    fgets(Buf,sizeof(Buf)-1,f);
    if (Buf[0] != ppctl) continue;
    if (strncmp(p=Buf+1,incldir,k=strlen(incldir))) continue;
    p+=k; while(*p != '\"' && *p != '<') p++;
    name = ++p; while(*p != '\"' && *p != '>') p++;
    *p = 0;
    if (!hasdep) {
      hasdep=1;
      searchpath = basepath(strcpy(Buf2,argv[1]));
      if (options.makefilestyle) {
      	suffix = file_suffix;
      } else {
      	suffix = var_suffix;
      }
      printf("%s%s %s ",strlwr(depname(Basename(strcpy(Buf3,argv[1])))),\
                           suffix, strlwr(convertsep(argv[1])));
    }
    if (searchpath) {
      strcat(strcpy(Buf3,searchpath),name);
      ft = fopen(Buf3,"r");
      if (ft) {
        fclose(ft);
        name = Buf3;
      }
    }
    printf("%s ",convertsep(name));
  }
  if (hasdep) putchar('\n');
  fclose(f);
  return 0;
 }

