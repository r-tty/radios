/*
 * x-ray.c - a simple system debugging tool.
 * Copyright (c) 2001-2003 RET & COM Research.
 */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <getopt.h>

#ifdef USE_READLINE
# include <readline/readline.h>
# include <readline/history.h>
#endif

#include "x-ray.h"

/* Commands */
const cmd_t commands[] = {
    { "help", xr_print_help, "print the help" },
    { "read", xr_dev_readwrite,	"call driver read function" },
    { "write", xr_dev_readwrite, "call driver write function" },
    { "ioctl", xr_dev_ioctl, "call driver ioctl function" },
    { "set", xr_var_alias, "set or show variable" },
    { "alias", xr_var_alias, "set alias for command" },
    { "unalias", xr_var_alias, "unset alias" },
    { "batch", xr_batch, "execute commands from file" }
};

/* Predefined variables and their values */
const var_t variables[] = {
    { "dev", { STRINGOBJ, { stringval: "/dev/console"  } } },
    { "testseq", { STRINGOBJ, { stringval: "This test sequence will be written to the device" } } },
    { "ioctlreq", { STRINGOBJ, { stringval: "0" } } },
    { "numread", { UINTOBJ, { uintval: 6 } } }
};


/* Other static data */
const char *version = "0.1";
char *rcfile = "xrayrc";
char *prompt = "x-ray> ";

/******************************************************************************/

/*
 * Process one command
 */
int process_command(char *cmdline)
{
    char *s, *cmdname;
    int res = 1;
    cmd_t *cmdp;
    var_t *alp;
    
    if (cmdline[0] == '#') return 0; /* Comment */
    cmdname = strdup(cmdline);
    if ((s = strchr(cmdname, ' ')) != NULL) {
	char *t = s-1;
	while(isspace(*t)) *t-- = '\0';
	*s++ = '\0';
	while(isspace(*s)) s++;
    }
    if ((cmdp = lookup_cmd(cmdname)) != NULL) {
	res = cmdp->fun(cmdname, s);
    } else if ((alp = lookup_var(cmdname)) != NULL) {
	/* Check for alias */
	if (alp->obj.tag == ALIASOBJ)
	    res = process_command(alp->obj.val.stringval);
    }
    efree(cmdname);
    return res;
}

/*
 * Assign a value to command/alias
 */
void cmdassign(char *name, void *handler, char *desc)
{
    cmd_t *c;
    
    c = get_cmd_place(name);
    if (desc) c->desc = strdup(desc);	
    c->fun = handler;
    c->next = cmdhtab.head;
    c->prev = NULL;
    if (cmdhtab.head)
	((cmd_t *)cmdhtab.head)->prev = c;
    cmdhtab.head = c;
}

/*
 * Assign a value to the variable
 */
void varassign(char *name, opaque_t value)
{
    var_t *v;
    
    v = get_var_place(name);
    v->obj.tag = value.tag;
    switch(v->obj.tag) {
	case UINTOBJ:
	    v->obj.val.uintval = value.val.uintval;
	    break;
	case STRINGOBJ:
	case ALIASOBJ:
	    v->obj.val.stringval = strdup(value.val.stringval);
	    break;
    }
    v->next = varhtab.head;
    v->prev = NULL;
    if (varhtab.head)
	((var_t *)varhtab.head)->prev = v;
    varhtab.head = v;
}

/*
 * Initialize hash tables
 */
static void init_hashes(void)
{
    int i;
    
    prepare_hash_tables();
    
    for(i = 0; i < arraysize(commands); i++) {
    	cmdassign(commands[i].id, commands[i].fun, commands[i].desc);
    }
    
    for(i = 0; i < arraysize(variables); i++) {
	varassign(variables[i].id, variables[i].obj);
    }
}

/*
 * Checks whether a variable is in the linked list
 */
var_t *var_in_list(char *name)
{
    var_t *vp = varhtab.head;
    
    while(vp) {
	if (streq(name, vp->id))
	    return vp;
	vp = vp->next;
    }
    return NULL;
}

/*
 * Display a variable
 */
void display_var(var_t *vp, bool alias)
{
    char *val;
    
    if (vp == NULL) return;
    if (vp->obj.tag == 'A') {
	if (alias) printf("alias %s='%s'\n", vp->id, vp->obj.val.stringval);
    } else {
	if (alias) return;
	printf("%s = ", vp->id);
	switch(vp->obj.tag) {
	    case UINTOBJ:
		printf("%d", vp->obj.val.uintval);
		break;
	    case STRINGOBJ:
		val = vp->obj.val.stringval;
		if(!val)
		    printf("NULL");
		else
	    	    printf("\"%s\"", val);
		break;
	}
	putchar('\n');
    }
}

/*
 * Set or show variable
 */
int xr_var_alias(char *cmdname, char *args)
{
    int status = 0;
    char *val, *what = NULL;
    var_t *vp;
    bool alias;
    
    if(args) what = strdup(args);
    if(what && ((val = strchr(what, '=')) != NULL)) {
    	char *t = val-1;
	/* Strip spaces */
	*val++ = '\0';
	while(isspace(*val)) val++;
	while(isspace(*t)) *t-- = '\0';
	
	/* Set value */
	if ((vp = var_in_list(what)) != NULL) {
	    /* Existing variable */
	    if(*val) {
		free_var(vp, FALSE);
	    	switch(vp->obj.tag) {
		    case UINTOBJ:
			vp->obj.val.uintval = atoi(val);
			break;
		    case STRINGOBJ:
		    case ALIASOBJ:
			vp->obj.val.stringval = strdup(val);
			break;
		}
	    } else {
	        puts("value required");
	        status = 1;
	    }
	} else {
	    /* New variable, assume string (or alias) */
	    opaque_t vobj;
	    if (streq(cmdname, "alias"))
		vobj.tag = ALIASOBJ;
	    else
		vobj.tag = STRINGOBJ;
	    vobj.val.stringval = val;
	    varassign(what, vobj);
	}
    } else {
	/* Unset alias? */
	if (streq(cmdname, "unalias") && what) {
	    if ((vp = lookup_var(what)) != NULL) {
		if (vp->obj.tag == ALIASOBJ) delete_var(vp->id);
		else {
		    puts("non-existing alias");
		    status = 1;
		}
	    }
	} else {
	    alias = streq(cmdname, "alias");
	    /* Display value(s) */
	    if (what == NULL) {
		vp = varhtab.head;
		while (vp) {
		    display_var(vp, alias);
		    vp = vp->next;
		}
	    } else {
		if ((vp = lookup_var(what)) != NULL)
		    display_var(vp, alias);
	    }
	}
    }
    free(what);
    return status;
}

/*
 * Call driver's read or write function
 */
int xr_dev_readwrite(char *cmdname, char *args)
{
    int fd, res = 0;
    var_t *vp;
    char *seq = NULL, *dev, *myargs = NULL;
    
    if(args) myargs = strdup(args);
    vp = lookup_var("dev");
    if (streq(cmdname, "read")) {
	char c;
    	/* Read */
	if (myargs) dev = myargs; else dev = vp->obj.val.stringval;
	fd = open(dev, O_RDONLY);
	if (fd < 0) {
	    puts("error opening file");
	    res = 1;
	} else {
	    int i;
	    vp = lookup_var("numread");
	    for (i=0; i < vp->obj.val.uintval; i++) {
		if (read(fd, &c, 1) == 0) {
		    puts("read: got EOF");
		    res = 1;
		} else {
		    if (!isprint(c)) printf("code=0x%X\n", (int)c);
		    else putchar(c);
		}
	    }
	}
    } else {
    	/* Write */
    	if ((seq = strchr(myargs, ' ')) != NULL) {
	    char *t = seq-1;
	    *seq++ = '\0';
	    while(isspace(*seq)) seq++;
	    while(isspace(*t)) *t-- = '\0';
	    if (!strncmp(myargs, "-d", 2))
		dev = myargs + 2;
	    else
		dev = myargs;
	} else {
	    dev = vp->obj.val.stringval;
	    vp = lookup_var("testseq");
	    seq = vp->obj.val.stringval;
	    if (myargs) {
	        if (!strncmp(myargs, "-d", 2))
		    dev = myargs + 2;
		else
		    seq = myargs;
	    }
	}
	fd = open(dev, O_WRONLY);
	if (fd < 0) {
	    puts("error opening file");
	    res = 1;
	} else write(fd, seq, strlen(seq));
    }
    if (fd >= 0) close(fd);
    efree(myargs);
    return res;
}

/*
 * Call driver's ioctl function
 */
int xr_dev_ioctl(char *cmdname, char *args)
{
    int fd, res = 0;
    char *dev, *what, *rfun;
    char *myargs = NULL;
    var_t *vp;
    
    if(args) myargs = strdup(args);
    if(!strncmp(myargs, "-d", 2)) {
	dev = myargs + 2;
	while(isspace(*dev)) dev++;
	rfun = dev;
	while(isgraph(*rfun)) rfun++;
	if(!*rfun) {
	    puts("request number required");
	    res = 1;
	}
	*rfun++ = '\0';
    } else {
	vp = lookup_var("dev");
	dev = vp->obj.val.stringval;
	rfun = myargs;
    }
    if (!res) {
	if ((what = strchr(rfun, ' ')) != NULL) {
	    char *t = what-1;
	    *what++ = '\0';
	    while(isspace(*what)) what++;
	    while(isspace(*t)) *t-- = '\0';
	} else {
	    vp = lookup_var("ioctlreq");
	    what = vp->obj.val.stringval;
	}
	fd = open(dev, O_RDONLY);
	if(fd < 0) {
	    puts("error opening device");
	    res = 2;
	} else {
	    unsigned rcmd, rarg;
	    rcmd = strtoul(rfun, NULL, 0);
	    rarg = strtoul(what, NULL, 0);
	    printf("IOCTL call to %s: function=0x%X, arg=0x%X\n", dev, rcmd, rarg);
	    res = ioctl(fd, rcmd, rarg);
	    if (res >= 0) {
		printf("ok, result=%X\n", res);
		res = 0;
	    }
	    close(fd);
	}
    }
    efree(myargs);
    return res;
}

/*
 * Read commands from file
 */
int xr_batch(char *cmdname, char *filename)
{
    FILE *fp;
    char buf[128];
    
    fp = fopen(filename, "r");
    if(!fp) return 1;
    while(fgets(buf, sizeof(buf)-2, fp)) {
	int i = strlen(buf) - 1;
	if(buf[i] == '\n') buf[i] = '\0';
	process_command(buf);
    }
    fclose(fp);
    return 0;
}

/*
 * Print commands help
 */
int xr_print_help(char *cmdname, char *args)
{
    cmd_t *p;

    if (streq(cmdname, "usage")) {
    	printf("\nUsage: %s [-?] [-h] [-f config] [command [args]]\n", args);
	puts("Options:");
	return 0;
    }
    
    if(args) {
	/* Print help on particular command */
	p = lookup_cmd(args);
	if (p && p->id) {
	    printf("%s: %s\n", p->id, p->desc);
	}
    } else {
	/* Print commands summary */
	puts("\nCommands summary:\n"
	     " batch <file>				- run commands from file\n"
	     " set [variable[=value]]			- set or show variable\n"
	     " alias [name[=value]]			- set or display alias\n"
	     " unalias <name>				- unset alias\n"
	     " read [device]				- read from device\n"
	     " write [-dDevice] [data]		- write to device\n"
	     " ioctl [-dDevice] <function> [args]	- call driver's ioctl function\n"
	     " help [command]				- print the help\n"
	     " quit					- exit program\n");
    }
    return 0;
}


/*
 * Main
 */
int main(int argc, char *argv[])
{
    int opt;
    char *cmdline = NULL;

    printf("X-Ray - a simple testing/diagnostic tool for RadiOS, version %s\n", version);
    puts("Copyright (c) 2001-2003 RET & COM Research");
    init_hashes();
    
    /* Parse options */    
    while ((opt = getopt(argc, argv, "f:h?")) != EOF) {
	switch((char)opt) {
	    case '?':
	    case 'h':
		return xr_print_help("usage", argv[0]);
	    case 'f':
		rcfile = optarg;
		break;
	}
    }
    
    xr_batch("batch", rcfile);
    
    for(;;) {
#ifdef USE_READLINE
	cmdline = readline(prompt);
#else
	int i;
	printf("%s", prompt);
	cmdline = ealloc(128);
	*cmdline = '\0';
	fgets(cmdline, 128, stdin);
	/* Bite off trailing newline if any */
	i = strlen(cmdline);
	if (cmdline[i-1] == '\n') cmdline[i-1] = '\0';
#endif
	if(!cmdline || !strcmp(cmdline,"quit")) break;
	if(!strlen(cmdline) || cmdline[0] == '#') continue;
	if(process_command(cmdline))
	    puts("?");
#ifdef USE_READLINE
	else
	    add_history(cmdline);
#endif
	efree(cmdline);
    };
    return 0;
}
