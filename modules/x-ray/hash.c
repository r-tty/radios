/*
 * hash.c - hash table support.
 */

#include <stdio.h>
 
#include "x-ray.h"

static char *dead = "";

#define HASHSIZE 64

htabparm_t hashtables[] = {
    { NULL, 0, HASHSIZE, NULL },	/* Commands/aliases hash table */
    { NULL, 0, HASHSIZE, NULL }		/* Variable hash table */
};

/*
 * Initialize hash tables
 */
void prepare_hash_tables(void)
{
    int i, k;
    
    for (i = 0; i < arraysize(hashtables); i++) {
	hashtables[i].table = (htab_t *)ealloc(sizeof(htab_t) * HASHSIZE);
	hashtables[i].head = NULL;
	for (k = 0; k < HASHSIZE; k++) {
	    hashtables[i].table[k].name = NULL;    
	}
    }
}

#define ADV()   {if ((c = *s++) == '\0') break;}

/*
 * Hash function
 */
static int hash(char *s, int size)
{
    int c, n = 0;
    while (1) {
	ADV();
	n += (c << 17) ^ (c << 11) ^ (c << 5) ^ (c >> 1);
	ADV();
	n ^= (c << 14) + (c << 7) + (c << 4) + c;
	ADV();
	n ^= (~c << 11) | ((c << 3) ^ (c >> 1));
	ADV();
	n -= (c << 16) | (c << 9) | (c << 2) | (c & 3);
    }
    if (n < 0)
	n = ~n;
    return n & (size - 1); /* need power of 2 size */
}

/*
 * Rehash the table
 */
static bool rehash(htab_t *ht)
{
    int i, j, size = 0;
    int newsize, newused;
    htab_t *newhtab;
    
    for (i = 0; i < arraysize(hashtables); i++) {
    	if (ht == hashtables[i].table) {
	    if (hashtables[i].size > 2 * hashtables[i].used)
		return FALSE;
	    size = hashtables[i].size;
	    break;
	}
    }
	
    newsize = 2 * size;
    newhtab = (htab_t *)ealloc(newsize * sizeof(htab_t));
    for (i = 0; i < newsize; i++)
	newhtab[i].name = NULL;
    for (i = newused = 0; i < size; i++)
	if (ht[i].name != NULL && ht[i].name != dead) {
	    newused++;
	    j = hash(ht[i].name, newsize);
	    while (newhtab[j].name != NULL) {
		j++;
		j &= (newsize - 1);
	    }
	    newhtab[j].name = ht[i].name;
	    newhtab[j].ptr = ht[i].ptr;
	}
	
    for (i = 0; i < arraysize(hashtables); i++) {
    	if (ht == hashtables[i].table) {
	    hashtables[i].table = newhtab;
	    hashtables[i].size = newsize;
	    hashtables[i].used = newused;
	    break;
	}
    }	
	
    efree(ht);
    return TRUE;
}


#define cmdfind(s) find(s, cmdhtab.table, cmdhtab.size)
#define varfind(s) find(s, varhtab.table, varhtab.size)

/*
 * Find an element in the table based on its size
 */
static int find(char *s, htab_t *ht, int size)
{
    int h = hash(s, size);
    while (ht[h].name != NULL && !streq(ht[h].name, s)) {
	h++;
	h &= size - 1;
    }
    return h;
}

/*
 * Table lookup
 */
void *lookup(char *s, htab_t *ht)
{
    int h = find(s, ht, ht == cmdhtab.table ? cmdhtab.size : varhtab.size);
    return (ht[h].name == NULL) ? NULL : ht[h].ptr;
}

/*
 * UNUSED. Destroy the command and optionally delete it from the list
 */
void free_cmd(cmd_t *p, bool listrm)
{
    if (p->desc) {
	efree(p->desc);
	if (listrm) {
	    if (p->prev) p->prev->next = p->next;
	    if (p->next) p->next->prev = p->prev;
	}
    }
}

/*
 * Destroy variable value and optionally delete it from the list
 */
void free_var(var_t *p, bool listrm)
{
    switch(p->obj.tag) {
	case STRINGOBJ:
	    efree(p->obj.val.stringval);
	    break;
    }
    if (listrm) {
        if (p->prev) p->prev->next = p->next;
        if (p->next) p->next->prev = p->prev;
    }
}

/*
 * Get a place for command
 */
cmd_t *get_cmd_place(char *s)
{
    int h = cmdfind(s);
    
    if (cmdhtab.table[h].name == NULL) {
	if (rehash(cmdhtab.table))
	    h = cmdfind(s);
	cmdhtab.used++;
	cmdhtab.table[h].name = ecpy(s);
	cmdhtab.table[h].ptr = enew(cmd_t);
	((cmd_t *)cmdhtab.table[h].ptr)->id = cmdhtab.table[h].name;
    } else
	free_cmd(cmdhtab.table[h].ptr, FALSE);
    return cmdhtab.table[h].ptr;
}

/*
 * Get a place for variable
 */
var_t *get_var_place(char *s)
{
    int h = varfind(s);

    if (varhtab.table[h].name == NULL) {
	if (rehash(varhtab.table))
	    h = varfind(s);
	varhtab.used++;
	varhtab.table[h].name = ecpy(s);
	varhtab.table[h].ptr = enew(var_t);
	((var_t *)varhtab.table[h].ptr)->id = varhtab.table[h].name;
	((var_t *)varhtab.table[h].ptr)->obj.tag = '\0';
    } else
	free_var(varhtab.table[h].ptr, FALSE);
    return varhtab.table[h].ptr;
}

/*
 * Delete the command from table and from the list
 */
void delete_cmd(char *s)
{
    int h = cmdfind(s);
	
    if (cmdhtab.table[h].name == NULL)
	return; /* not found */
    free_cmd(cmdhtab.table[h].ptr, TRUE);
    efree(cmdhtab.table[h].ptr);
    efree(cmdhtab.table[h].name);
    if (cmdhtab.table[(h+1)&(cmdhtab.size-1)].name == NULL) {
	--cmdhtab.used;
	cmdhtab.table[h].name = NULL;
    } else {
	cmdhtab.table[h].name = dead;
    }
}

/*
 * Delete the variable from table and from the list
 */
void delete_var(char *s)
{
    int h = varfind(s);
    
    if (varhtab.table[h].name == NULL)
	return; /* not found */
    free_var(varhtab.table[h].ptr, TRUE);
    efree(varhtab.table[h].ptr);
    efree(varhtab.table[h].name);
    if (varhtab.table[(h+1)&(varhtab.size-1)].name == NULL) {
	--varhtab.used;
	varhtab.table[h].name = NULL;
    } else {
	varhtab.table[h].name = dead;
    }
}
