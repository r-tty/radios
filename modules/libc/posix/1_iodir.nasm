;-------------------------------------------------------------------------------
; posix/1_iodir.nasm - POSIX directory routines.
;-------------------------------------------------------------------------------

module libc.iodir

exportproc _opendir, _closedir, _readdir, _rewinddir

#define BUF_SIZE		2048

#include "connect.h"

#define D_DEFAULT_FLAGS	(D_FLAG_FILTER)

struct _fd_block {
    int     count, index;
    int     *fds;
};

#define DATA_COUNT	50			/* The bigger the better */
typedef struct _cursor {
	struct _cursor	*next;
	int		count;
	char		*data[DATA_COUNT];
} cursor_t;


struct _dir {
	struct _fd_block	dd_fd_block;	/* Storage for multiple fd's */
	struct _cursor	   *dd_cursor;		/* Unique directory stored names */
	unsigned			dd_flags;		/* Flags for stuff */
	int					dd_loc;
	int					dd_size;
	char				*dd_buf;
	char				*dd_path;
};

static pthread_mutex_t		readdir_mutex = PTHREAD_MUTEX_INITIALIZER;

static void readdir_cleanup(void *data) {
	pthread_mutex_t	*mutex = data;

	pthread_mutex_unlock(mutex);
}

static int compare( const void *p1, const void *p2 ) {
    const char *p1c = (const char *) p1;
    const char **p2c = (const char **) p2;
    return( strcmp( p1c, *p2c ) );
}

/*
 Returns 0 if the item with the name did not
already exist in the cursor list, adds the item 
to the structure.
 Returns 1 if the item with the name did exist
in the list, doesn't add the item to the structure
*/
static int find_with_insert(cursor_t **chead, char *name) {
	cursor_t *ctarget;
	int		  indx;

	if (!(ctarget = *chead)) {
		ctarget = calloc(sizeof(cursor_t), 1);
		if (!(*chead = ctarget)) {
			errno = ENOMEM;
			return 0;		//XXX: We want the item reported
		}
		ctarget->data[0] = strdup(name);
		ctarget->count++;
		return 0;
	}

	/* Search this target for the item */
	do {
		if (bsearch(name, ctarget->data, ctarget->count, sizeof(char *), compare)) {
			return 1;
		}
	} while (ctarget->next && (ctarget = ctarget->next));

	/* This item was not found, create a new block or insert internally */
	if (ctarget->count >= DATA_COUNT) {
		return find_with_insert(&ctarget->next, name);
	}

	//TODO: Fix this later to make it faster, use the bs results from above 
	for (indx = 0; indx < ctarget->count; indx++) {
		if (strcmp(name, ctarget->data[indx]) < 0) {
			break;
		}
	}
	memmove(&ctarget->data[indx+1], &ctarget->data[indx], (ctarget->count - indx) * sizeof(char *)); 
	ctarget->data[indx] = strdup(name);
	ctarget->count++;
	return 0;
}

static void free_cursor(cursor_t **chead) {
	cursor_t *cursor;
	int i;

	for (cursor = *chead; cursor; cursor = *chead) {
		*chead = cursor->next;

		for (i=0; i<cursor->count; i++) {
			free(cursor->data[i]);
		}
		free(cursor);
	}
}

#if 0
static void dump_cursor(cursor_t *cursor) {
	int i, indx;

	printf("Cursor dump ----\n");

	indx = 0;
	while (cursor) {
		printf("Cursor %d %d items \n", indx++, cursor->count); 
		for (i=0; i<cursor->count; i++) {
			printf(" %s\n", cursor->data[i]);
		}
		cursor = cursor->next;
	}
}
#endif

/*** Exported  Functions ***/ 
DIR *opendir(const char *path) {
	DIR							*dirp;
	struct fcntl_stat {
		struct {
			struct _io_devctl			i;
			int							flags;
		}							devctl;
		struct _io_stat				stat;
	}							msg;
	struct stat					buff;

	//Add the extra 8 bytes to guarantee that dd_buf aligns properly
	if(!(dirp = malloc(sizeof *dirp + 8 + BUF_SIZE))) {
		errno = ENOMEM;
		return(0);
	}
	memset(dirp, 0, sizeof(*dirp) + BUF_SIZE);
	dirp->dd_flags = D_DEFAULT_FLAGS;
	dirp->dd_buf = (char *)(((uintptr_t)(dirp + 1) + 7) & ~7);

	// A storage place for us to put our fd's for dirs we meet
	dirp->dd_fd_block.fds = NULL;
	dirp->dd_fd_block.index = 0;
	dirp->dd_fd_block.count = 0;

	// get the stat info
	msg.devctl.i.type = _IO_DEVCTL;
	msg.devctl.i.combine_len = offsetof(struct fcntl_stat, stat) | _IO_COMBINE_FLAG;
	msg.devctl.i.dcmd = DCMD_ALL_SETFLAGS;
	msg.devctl.i.nbytes = sizeof msg.devctl.flags;
	msg.devctl.i.zero = 0;
	msg.devctl.flags = 0;
	msg.stat.type = _IO_STAT;
	msg.stat.combine_len = sizeof msg.stat;
	msg.stat.zero = 0;


	/* We used to make this connection with _NTO_SIDE_CHANNEL. Posix says that
	   on a fork() that both the child and the parent should have access to the
	   DIR stream, though the result of both of them operating on the stream
	   is undefined (which is good since we can't synchronize the fd 'index' 
	   field between them!).  As a result open these connections as normal
	   fd's and dup them over the fork.
	*/
	if(_connect_fd(0 /*_NTO_SIDE_CHANNEL*/, path, 0, O_NONBLOCK | O_RDONLY, SH_DENYNO, _IO_CONNECT_COMBINE, 1,
						_IO_FLAG_RD, 0, 0, sizeof msg, &msg, sizeof buff, &buff, 0, 
						&dirp->dd_fd_block.count, &dirp->dd_fd_block.fds) == -1) {
		goto bad_alloc;
	}

	//This is only the stat for the first (and prefered) fd
	if(!S_ISDIR(buff.st_mode)) {
		dirp->dd_fd_block.count--; 
		while (dirp->dd_fd_block.fds && dirp->dd_fd_block.count >=0) {
			close(dirp->dd_fd_block.fds[dirp->dd_fd_block.count--]);
		}
		errno = ENOTDIR;
		goto bad_alloc;
	}

	dirp->dd_size = dirp->dd_loc = 0;
	//The count should be initialize to the number of fd's by connect
	dirp->dd_fd_block.index = 0;

	//Optimization ... turn off filtering if we only have one fd
	if (dirp->dd_fd_block.count <= 1) {
		dirp->dd_flags &= ~D_FLAG_FILTER;
	}

	return dirp;

bad_alloc:
	if (dirp) {
		if (dirp->dd_fd_block.fds) {
			free(dirp->dd_fd_block.fds);
		}
		free(dirp);
	}
	return 0;
}

struct dirent *readdir(DIR *dirp) {
	struct dirent	*d;
	int				xtype;

	xtype = (dirp->dd_flags & D_FLAG_STAT) ? _IO_XFLAG_DIR_EXTRA_HINT : 0;
do {

	if(dirp->dd_loc >= dirp->dd_size) {
		dirp->dd_loc = 0;

		do {
			if ((dirp->dd_fd_block.index >= dirp->dd_fd_block.count) ||
			    (dirp->dd_size = _readx(dirp->dd_fd_block.fds[dirp->dd_fd_block.index],
										dirp->dd_buf, BUF_SIZE, xtype, "", 0)) == -1) {
				//Error condition (read == -1) ... exit with a null
				dirp->dd_size = 0;
				return(0);
			}
			//Return null after traversing all the directories, on all fd's
			if (dirp->dd_size == 0) {
				if (++dirp->dd_fd_block.index >= dirp->dd_fd_block.count) {
					return 0;
				}
				else {
					;//We should probably bump ahead by two loc's to skip . and .. on subsequent fd's
				}
			}
		} while (dirp->dd_size == 0);

	}

	d = (struct dirent *)&dirp->dd_buf[dirp->dd_loc];
	dirp->dd_loc += d->d_reclen;

} while ((dirp->dd_flags & D_FLAG_FILTER) && 
		 find_with_insert(&dirp->dd_cursor, d->d_name));

	return d;
}

int readdir_r(DIR *dirp, struct dirent *entry, struct dirent **result) {
	int					save, status;

	save = errno;
	if((errno = pthread_mutex_lock(&readdir_mutex)) == EOK) {
		struct dirent				*ent;

		pthread_cleanup_push(readdir_cleanup, &readdir_mutex);
		if(*result = ent = readdir(dirp)) {
			memcpy(*result = entry, ent, offsetof(struct dirent, d_name) + ent->d_namelen + 1);
		}
		pthread_cleanup_pop(1);
	}
	status = errno;
	errno = save;
	return status;
}

void rewinddir(DIR *dirp) {
	int				i, save = errno;

	for (i=0; i<dirp->dd_fd_block.count;i++) {
		lseek(dirp->dd_fd_block.fds[i], 0, SEEK_SET);
	}
	dirp->dd_fd_block.index = 0;

	if (dirp->dd_cursor) {
		free_cursor(&dirp->dd_cursor);
	}

	errno = save;
	dirp->dd_size = dirp->dd_loc = 0;
}

int closedir(DIR *dirp) {
	int			ret = 0;

	while (--dirp->dd_fd_block.count >= 0) {
		ret |= close(dirp->dd_fd_block.fds[dirp->dd_fd_block.count]);
	}

	if (dirp->dd_fd_block.fds) {
		free(dirp->dd_fd_block.fds);
	}
	if (dirp->dd_cursor) {
		free_cursor(&dirp->dd_cursor);
	} 
	free(dirp);
	return ret;
}

/*** DIRCTL Functionality undocumented and in dirent.h ***/

#include <stdarg.h>
static int _dircntl(DIR *dir, int cmd, va_list ap) {

	switch(cmd) {
	case D_GETFLAG: 
		/* This value CANNOT BE NEGATIVE */
		return dir->dd_flags;

	case D_SETFLAG: 
		dir->dd_flags = va_arg(ap, int);
		return 0;

	default:
		break;
	}

	errno = ENOSYS;
	return -1;
}

int dircntl(DIR *dir, int cmd, ...) {
	va_list  	ap;
	int			ret;

	va_start(ap, cmd);
	ret = _dircntl(dir, cmd, ap);
	va_end(ap);
	return ret;
}

