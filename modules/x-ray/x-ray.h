/*
 * x-ray.h - global declarations.
 */
 
#ifndef _XRAY_H
#define _XRAY_H

/** Macros **/
#define arraysize(a) ((int)(sizeof(a)/sizeof(*a)))
#define memzero(s, n) memset(s, 0, n)
#define enew(x) ((x *) ealloc(sizeof(x)))
#define ecpy(x) strcpy((char *) ealloc(strlen(x) + 1), x)
#define lookup_cmd(s) ((cmd_t *) lookup(s, cmdhtab.table))
#define lookup_var(s) ((var_t *) lookup(s, varhtab.table))
#define streq(x, y) (*(x) == *(y) && strcmp(x, y) == 0)

#define BYTEOBJ 'c'
#define WORDOBJ 'w'
#define UINTOBJ 'u'
#define STRINGOBJ 's'
#define	ALIASOBJ 'A'

/** Types **/

typedef struct {
    char tag;
    union {
	char byteval;
	short wordval;
	unsigned uintval;
	char *stringval;
    } val;
} opaque_t;

/* Command or alias */
typedef struct cmd_t {
    char *id;				/* Points to key string in hash table */
    int (*fun)(char *, char *);
    char *desc;
    struct cmd_t *next, *prev;
} cmd_t;

/* Variable */
typedef struct var_t {
    char *id;				/* Points to key string in hash table */
    opaque_t obj;
    struct var_t *next, *prev;
} var_t;

/* Hash table entry */
typedef struct {
    char *name;				/* Key */
    void *ptr;				/* Pointer to the data */
} htab_t;

/* Hash table object */
typedef struct {
    htab_t *table;			/* Pointer to the table */
    int used;				/* Number of used entries */
    int size;				/* Table size */
    void *head;				/* List head */
} htabparm_t;

/** Global data **/

extern htabparm_t hashtables[];

#define cmdhtab hashtables[0]		/* We assume only 2 tables */
#define varhtab hashtables[1]		/* in this version */

/** Function prototypes **/

/* hash.c */
void prepare_hash_tables(void);
void *lookup(char *, htab_t *);
void free_cmd(cmd_t *, bool);
void free_var(var_t *, bool);
void delete_cmd(char *);
void delete_var(char *);
cmd_t *get_cmd_place(char *);
var_t *get_var_place(char *);

/* util.c */
void *ealloc(size_t);
void *erealloc(void *, size_t);
void efree(void *);

/* x-ray.c */
int xr_dev_readwrite(char *, char *);
int xr_dev_ioctl(char *, char *);
int xr_var_alias(char *, char *);
int xr_print_help(char *, char *);
int xr_batch(char *, char *);

#endif
