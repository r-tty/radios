/*
 * stat.h - file state structure and definitions.
 */

#ifndef _sys_stat_h
#define _sys_stat_h

#include <sys/types.h>

struct stat {
    ino_t	st_ino;			/* File serial number */
    ino_t	st_ino_hi;
    off_t	st_size;
    off_t	st_size_hi;
    dev_t	st_dev;			/* ID of device containing file	*/
    dev_t	st_rdev;		/* Device ID, for inode that is device	*/
    uid_t	st_uid;
    gid_t	st_gid;
    time_t	st_mtime;		/* Time of last data modification */
    time_t	st_atime;		/* Time last accessed */
    time_t	st_ctime;		/* Time of last status change */
    mode_t	st_mode;
    nlink_t	st_nlink;
    blksize_t	st_blocksize;		/* Size of a block used by st_nblocks */
    int32_t	st_nblocks;		/* Number of blocks st_blocksize blocks */
    blksize_t	st_blksize;		/* Prefered I/O block size for object   */
    blkcnt_t	st_blocks;
    blkcnt_t	st_blocks_hi;
};

#define _S_IFMT     0xF000              /* Type of file */
#define _S_IFIFO    0x1000              /* FIFO */
#define _S_IFCHR    0x2000              /* Character special */
#define _S_IFDIR    0x4000              /* Directory */
#define _S_IFNAM    0x5000              /* Special named file */
#define _S_IFBLK    0x6000              /* Block special */
#define _S_IFREG    0x8000              /* Regular */
#define _S_IFLNK    0xA000              /* Symbolic link */
#define _S_IFSOCK   0xC000              /* Socket */

#define S_ISFIFO(m) (((m)&_S_IFMT)==_S_IFIFO) /* Test for FIFO */
#define S_ISCHR(m)  (((m)&_S_IFMT)==_S_IFCHR) /* Test for char special file */
#define S_ISDIR(m)  (((m)&_S_IFMT)==_S_IFDIR) /* Test for directory file */
#define S_ISBLK(m)  (((m)&_S_IFMT)==_S_IFBLK) /* Test for block specl file */
#define S_ISREG(m)  (((m)&_S_IFMT)==_S_IFREG) /* Test for regular file */

#define S_ISLNK(m)  (((m)&_S_IFMT)==_S_IFLNK) /* Test for symbolic link */
#define S_ISNAM(m)  (((m)&_S_IFMT)==_S_IFNAM) /* Test for special named file */
#define S_ISSOCK(m) (((m)&_S_IFMT)==_S_IFSOCK)/* Test for socket */

#define S_TYPEISMQ(buf)     (S_ISNAM((buf)->st_mode)&&((buf)->st_rdev==_S_INMQ))
#define S_TYPEISSEM(buf)    (S_ISNAM((buf)->st_mode)&&((buf)->st_rdev==_S_INSEM))
#define S_TYPEISSHM(buf)    (S_ISNAM((buf)->st_mode)&&((buf)->st_rdev==_S_INSHD))
#define S_TYPEISTMO(buf)    (S_ISNAM((buf)->st_mode)&&((buf)->st_rdev==_S_INTMO))

/*
 *  For special named files (IFNAM), the subtype is encoded in st_rdev.
 *  They subtypes are:
 */
#define _S_INSEM        00001           /* Semaphore subtype */
#define _S_INSHD        00002           /* Shared data subtype */
#define _S_INMQ         00003           /* Message queue subtype */
#define _S_INTMP        00004           /* Typed memory object */

/*
 *  Common filetype macros
 */
#define S_IFMT      _S_IFMT             /*  Type of file                    */
#define S_IFIFO     _S_IFIFO            /*  FIFO                            */
#define S_IFCHR     _S_IFCHR            /*  Character special               */
#define S_IFDIR     _S_IFDIR            /*  Directory                       */
#define S_IFNAM     _S_IFNAM            /*  Special named file              */
#define S_IFBLK     _S_IFBLK            /*  Block special                   */
#define S_IFREG     _S_IFREG            /*  Regular                         */
#define S_IFLNK     _S_IFLNK            /*  Symbolic link                   */
#define S_IFSOCK    _S_IFSOCK           /*  Socket                          */

#define S_INSEM     _S_INSEM            /*  Semaphore                       */
#define S_INSHD     _S_INSHD            /*  Shared Memory                   */
#define S_INMQ      _S_INMQ             /*  Message Queue                   */

#define S_IPERMS    000777              /*  Permission mask                 */

#define S_ISUID     004000              /* set user id on execution         */
#define S_ISGID     002000              /* set group id on execution        */
#define S_ISVTX     001000              /* sticky bit (does nothing yet)    */
#define S_ENFMT     002000              /* enforcement mode locking         */

/*
 *  Owner permissions
 */
#define S_IRWXU     000700              /*  Read, write, execute/search     */
#define S_IRUSR     000400              /*  Read permission                 */
#define S_IWUSR     000200              /*  Write permission                */
#define S_IXUSR     000100              /*  Execute/search permission       */
#define S_IREAD     S_IRUSR             /*  Read permission                 */
#define S_IWRITE    S_IWUSR             /*  Write permission                */
#define S_IEXEC     S_IXUSR             /*  Execute/search permission       */

/*
 *  Group permissions
 */
#define S_IRWXG     000070              /*  Read, write, execute/search     */
#define S_IRGRP     000040              /*  Read permission                 */
#define S_IWGRP     000020              /*  Write permission                */
#define S_IXGRP     000010              /*  Execute/search permission       */

/*
 *  Other permissions
 */
#define S_IRWXO     000007              /*  Read, write, execute/search     */
#define S_IROTH     000004              /*  Read permission                 */
#define S_IWOTH     000002              /*  Write permission                */
#define S_IXOTH     000001              /*  Execute/search permission       */

extern int stat(const char *path, struct stat *buf);
extern int lstat(const char *path, struct stat *buf);
extern int fstat(int fildes, struct stat *buf);

extern int chmod(const char *path, mode_t mode);
extern int fchmod(int fildes, mode_t mode);
extern int isfdtype(int fildes, int fdtype);
extern int mkdir(const char *path, mode_t mode);
extern int mkfifo(const char *path, mode_t mode);
extern int mknod(const char *path, mode_t mode, dev_t dev);
extern int _mknod_extra(const char *path, mode_t mode, dev_t dev,
            unsigned extra_type, unsigned extra_len, void *extra);
extern mode_t umask(mode_t cmask);
extern mode_t _umask(pid_t pid, mode_t cmask);

#endif
