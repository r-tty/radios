/*
 * unistd.h - Unix standard definitions and function prototypes
 */

#ifndef _unistd_h
#define	_unistd_h

#include <sys/types.h>

#define	STDIN_FILENO	0	/* standard input file descriptor */
#define	STDOUT_FILENO	1	/* standard output file descriptor */
#define	STDERR_FILENO	2	/* standard error file descriptor */

#ifndef NULL
#define	NULL		0	/* null pointer constant */
#endif

#define	F_ULOCK		0	/* unlock locked section */
#define	F_LOCK		1	/* lock a section for exclusive use */
#define	F_TLOCK		2	/* test and lock a section for exclusive use */
#define	F_TEST		3	/* test a section for locks by other procs */

void	 _exit(int);
int	 access(const char *, int);
uint	 alarm(uint);
int	 chdir(const char *);
int	 chown(const char *, uid_t, gid_t);
int	 close(int);
int	 dup(int);
int	 dup2(int, int);
int	 eaccess(const char *, int);
int	 execl(const char *, const char *, ...);
int	 execle(const char *, const char *, ...);
int	 execlp(const char *, const char *, ...);
int	 execv(const char *, char * const *);
int	 execve(const char *, char * const *, char * const *);
int	 execvp(const char *, char * const *);
pid_t	 fork(void);
long	 fpathconf(int, int);
char	*getcwd(char *, size_t);
gid_t	 getegid(void);
uid_t	 geteuid(void);
gid_t	 getgid(void);
int	 getgroups(int, gid_t []);
char	*getlogin(void);
pid_t	 getpgrp(void);
pid_t	 getpid(void);
pid_t	 getppid(void);
uid_t	 getuid(void);
int	 isatty(int);
int	 link(const char *, const char *);
off_t	 lseek(int, off_t, int);
long	 pathconf(const char *, int);
int	 pause(void);
int	 pipe(int *);
ssize_t	 read(int, void *, size_t);
int	 rmdir(const char *);
int	 setgid(gid_t);
int	 setpgid(pid_t, pid_t);
void	 setproctitle(const char *_fmt, ...);
pid_t	 setsid(void);
int	 setuid(uid_t);
uint	 sleep(uint);
long	 sysconf(int);
pid_t	 tcgetpgrp(int);
int	 tcsetpgrp(int, pid_t);
char	*ttyname(int);
int	 unlink(const char *);
ssize_t	 write(int, const void *, size_t);

size_t	 confstr(int, char *, size_t);

int	 fsync(int);
int	 ftruncate(int, off_t);
int	 truncate(const char *, off_t);
int	 fchown(int, uid_t, gid_t);
int	 readlink(const char *, char *, int);
int	 gethostname(char *, int);
int	 setegid(gid_t);
int	 seteuid(uid_t);
int	 symlink(const char *, const char *);

char	*crypt(const char *, const char *);
int	 encrypt(char *, int);
int	 fchdir(int);
long	 gethostid(void);
int	 getpgid(pid_t _pid);
int	 getsid(pid_t _pid);
int	 lchown(const char *, uid_t, gid_t);
int	 lockf(int, int, off_t);
int	 nice(int);
ssize_t	 pread(int, void *, size_t, off_t);
ssize_t	 pwrite(int, const void *, size_t, off_t);
int	 setregid(gid_t, gid_t);
int	 setreuid(uid_t, uid_t);
void	 sync(void);
uint	 ualarm(uint, uint);
int	 usleep(uint);
pid_t	 vfork(void);

int	 brk(const void *);
int	 chroot(const char *);
int	 getdtablesize(void);
int	 getpagesize(void);
char	*getpass(const char *);
void	*sbrk(intptr_t);

struct timeval;				/* select(2) */
int	 acct(const char *);
int	 async_daemon(void);
int	 check_utility_compat(const char *);
const char *
	 crypt_get_format(void);
int	 crypt_set_format(const char *);
int	 des_cipher(const char *, char *, long, int);
int	 des_setkey(const char *key);
void	 endusershell(void);
int	 exect(const char *, char * const *, char * const *);
char	*fflagstostr(ulong);
int	 getdomainname(char *, int);
int	 getgrouplist(const char *, gid_t, gid_t *, int *);
mode_t	 getmode(const void *, mode_t);
int	 getpeereid(int, uid_t *, gid_t *);
int	 getresgid(gid_t *, gid_t *, gid_t *);
int	 getresuid(uid_t *, uid_t *, uid_t *);
char	*getusershell(void);
int	 initgroups(const char *, gid_t);
int	 iruserok(ulong, int, const char *, const char *);
int	 iruserok_sa(const void *, int, int, const char *, const char *);
int	 issetugid(void);
char	*mkdtemp(char *);
int	 mknod(const char *, mode_t, dev_t);
int	 mkstemp(char *);
int	 mkstemps(char *, int);
char	*mktemp(char *);
int	 nfsclnt(int, void *);
int	 nfssvc(int, void *);
int	 rcmd(char **, int, const char *, const char *, const char *, int *);
int	 rcmd_af(char **, int, const char *,
		const char *, const char *, int *, int);
int	 rcmdsh(char **, int, const char *,
		const char *, const char *, const char *);
char	*re_comp(const char *);
int	 re_exec(const char *);
int	 reboot(int);
int	 revoke(const char *);
pid_t	 rfork(int);
pid_t	 rfork_thread(int, void *, int (*)(void *), void *);
int	 rresvport(int *);
int	 rresvport_af(int *, int);
int	 ruserok(const char *, int, const char *, const char *);
int	 setdomainname(const char *, int);
int	 setgroups(int, const gid_t *);
void	 sethostid(long);
int	 sethostname(const char *, int);
int	 setkey(const char *);
int	 setlogin(const char *);
void	*setmode(const char *);
int	 setresgid(gid_t, gid_t, gid_t);
int	 setresuid(uid_t, uid_t, uid_t);
int	 setrgid(gid_t);
int	 setruid(uid_t);
void	 setusershell(void);
int	 strtofflags(char **, ulong *, ulong *);
int	 swapon(const char *);
int	 syscall(int, ...);
int	 ttyslot(void);
int	 undelete(const char *);
int	 unwhiteout(const char *);

#endif
