/*
 * pthread.h - definitions for POSIX Threads.
 */

#ifndef _pthread_h
#define _pthread_h

//#include <time.h>

typedef int32_t	pthread_t;

/*
 * Synchronization structures
 *
 * owner
 *  -1       Static initalized mutex which is auto created on SyncWait
 *  -2       Destroyed mutex
 *  -3       Named semaphore (the count is used as an fd)
 */
typedef struct {
    int		count;		/* Count for recursive mutexs and semaphores */ 
    unsigned	owner;		/* Thread id (valid for mutex only) */
} sync_t;

typedef sync_t	pthread_mutex_t;
typedef sync_t	pthread_cond_t;

/*
 * Synchronization object attributes
 */
typedef struct {
    int	protocol;
    int	flags;
    int	prioceiling;		/* Not implemented */
    int	clockid;		/* Condvars only */
    int	reserved[4];
} sync_attr_t;

typedef sync_attr_t	pthread_mutexattr_t;
typedef sync_attr_t	pthread_condattr_t;

/*
 * Used to define time specifications.
 */
struct timespec {
    time_t	tv_sec;
    long	tv_nsec;
};

/*
 * Scheduling parameters
 */
typedef struct sched_param {
    int32_t	sched_priority;
    int32_t	sched_curpriority;
    int32_t	low_prio;
    int32_t	max_repl;
    struct timespec repl_period;
    struct timespec init_budget;
} sched_param_t;


/*
 * Thread attributes
 */
typedef struct {
    int		flags;
    size_t	stacksize;
    void	*stackaddr;
    void	(*exitfunc)(void *status);
    int		policy;
    sched_param_t param;
    unsigned	guardsize;
    int		spare[3];
} pthread_attr_t;

typedef int pthread_key_t;

#define PTHREAD_PRIO_INHERIT	0
#define PTHREAD_PRIO_NONE	1
#define PTHREAD_PRIO_PROTECT	2

/* thread attribute prototypes */
int pthread_attr_destroy(pthread_attr_t *attr);
int pthread_attr_getdetachstate(const pthread_attr_t *attr, int *detachstate);
int pthread_attr_getstackaddr(const pthread_attr_t *addr, void **stackaddr);
int pthread_attr_getstacksize(const pthread_attr_t *attr, size_t *stacksize);
int pthread_attr_init(pthread_attr_t *attr);
int pthread_attr_setdetachstate(pthread_attr_t *attr, int detachstate);
int pthread_attr_setstackaddr(pthread_attr_t *attr, void *stackaddr);
int pthread_attr_setstacksize(pthread_attr_t *attr, size_t stacksize);

int pthread_attr_getguardsize(const pthread_attr_t *attr, size_t *guardsize);
int pthread_attr_setguardsize(pthread_attr_t *attr, size_t guardsize);
int pthread_getconcurrency(void);
int pthread_setconcurrency(int new_level);

/* Scheduling related functions */
int pthread_attr_getinheritsched(const pthread_attr_t *attr, int *inheritsched);
int pthread_attr_getschedparam(const pthread_attr_t *attr, struct sched_param *param);
int pthread_attr_getschedpolicy(const pthread_attr_t *attr, int *policy);
int pthread_attr_getscope(const pthread_attr_t *attr, int *contentionscope);
int pthread_attr_setinheritsched(pthread_attr_t *attr, int inheritsched);
int pthread_attr_setschedparam(pthread_attr_t *attr, const struct sched_param *param);
int pthread_attr_setschedpolicy(pthread_attr_t *attr, int policy);
int pthread_attr_setscope(pthread_attr_t *attr, int contentionscope);

/* Thread creation prototypes */
int pthread_cancel(pthread_t thread);
int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void *), void *arg);
int pthread_detach(pthread_t thread);
int pthread_equal(pthread_t t1, pthread_t t2);
void pthread_exit(void *value_ptr);
int pthread_join(pthread_t thread, void **value_ptr);
pthread_t pthread_self(void);
int pthread_setcancelstate(int state, int *oldstate);
int pthread_setcanceltype(int type, int *oldtype);

/* dynamic thread scheduling parameters */
int pthread_getschedparam(const pthread_t thread, int *policy, struct sched_param *param);
int pthread_setschedparam(pthread_t thread, int policy, const struct sched_param *param);

/* synchronization stuff */
int pthread_mutexattr_destroy(pthread_mutexattr_t *attr);
int pthread_mutexattr_init(pthread_mutexattr_t *attr);

/* We always allow process shared */
int pthread_mutexattr_getpshared(const pthread_mutexattr_t *attr, int *pshared);
int pthread_mutexattr_setpshared(pthread_mutexattr_t *attr,int pshared);

/* synchronization scheduling */
int pthread_mutexattr_getprioceiling(const pthread_mutexattr_t *attr, int *prioceiling);
int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *attr, int *protocol);
int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *attr, int prioceiling);
int pthread_mutexattr_setprotocol(pthread_mutexattr_t *attr, int protocol);

/* mutex recursion */
int pthread_mutex_destroy(pthread_mutex_t *mutex);
int pthread_mutex_init(pthread_mutex_t *mutex, const pthread_mutexattr_t *attr);
int pthread_mutex_lock(pthread_mutex_t *mutex);
int pthread_mutex_timedlock(pthread_mutex_t *mutex, const struct timespec *abs_timeout);
int pthread_mutex_trylock(pthread_mutex_t *mutex);
int pthread_mutex_unlock(pthread_mutex_t *mutex);
int pthread_mutexattr_getrecursive(const pthread_mutexattr_t *attr, int *recursive);
int pthread_mutexattr_setrecursive(pthread_mutexattr_t *attr, int recursive);
int pthread_mutexattr_gettype(const pthread_mutexattr_t *attr, int *type);
int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type);

/* dynamically change the priority ceiling of a mutex */
int pthread_condattr_destroy(pthread_condattr_t *attr);
int pthread_condattr_init(pthread_condattr_t *attr);
int pthread_mutex_getprioceiling(const pthread_mutex_t *mutex, int *prioceiling);
int pthread_mutex_setprioceiling(pthread_mutex_t *mutex, int prioceiling, int *old_ceiling);

/* Next two functions are not supported currently */
int pthread_cond_broadcast(pthread_cond_t *cond);
int pthread_cond_destroy(pthread_cond_t *cond);
int pthread_cond_init(pthread_cond_t *cond, pthread_condattr_t *attr);
int pthread_cond_signal(pthread_cond_t *cond);
int pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex);
int pthread_condattr_getpshared(const pthread_condattr_t *attr, int *pshared);
int pthread_condattr_setpshared(pthread_condattr_t *attr, int pshared);
int pthread_cond_timedwait(pthread_cond_t *cond, pthread_mutex_t *mutex, const struct timespec *abstime);

int pthread_getcpuclockid(pthread_t id, clockid_t *clock_id);
int pthread_condattr_getclock(const pthread_condattr_t *attr, clockid_t *id);
int pthread_condattr_setclock(pthread_condattr_t *attr, int id);

/* POSIX barriers */
#define PTHREAD_BARRIER_SERIAL_THREAD	((int)-1)

typedef struct _sync_attr pthread_barrierattr_t;
typedef struct {
	unsigned int		barrier;
	unsigned int		count;
	pthread_mutex_t		lock;
	pthread_cond_t		bcond;
} pthread_barrier_t;

/* barrier attribute prototypes */
int pthread_barrierattr_init(pthread_barrierattr_t *attr);
int pthread_barrierattr_destroy(pthread_barrierattr_t *attr);
int pthread_barrierattr_getpshared(const pthread_barrierattr_t *attr, int *pshared);
int pthread_barrierattr_setpshared(pthread_barrierattr_t *attr, int pshared);

/* barrier prototypes */
int pthread_barrier_destroy(pthread_barrier_t *b);
int pthread_barrier_init(pthread_barrier_t *b, const pthread_barrierattr_t *attr, unsigned int count);
int pthread_barrier_wait(pthread_barrier_t *b);

typedef struct _sync_attr pthread_rwlockattr_t;

int pthread_rwlockattr_init(pthread_rwlockattr_t *attr);
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *attr);

int pthread_rwlockattr_getpshared(const pthread_rwlockattr_t *attr, int *pshared);
int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *attr, int pshared);

typedef struct {
    int			active;		/* -1 = writer else # of active readers */
    void		*spare;
    int			blockedwriters;	/* # of waiting readers */
    int			blockedreaders;	/* # of waiting writers */
    int			heavy;		/* the rwlock is under heavy contention */
    pthread_mutex_t	lock;		/* the controlling mutex */
    pthread_cond_t	rcond;		/* condition variable for readers */
    pthread_cond_t	wcond;		/* condition variable for writers */
    unsigned		owner;		/* used to prevent and detect deadlocks */
} pthread_rwlock_t;

int pthread_rwlock_destroy(pthread_rwlock_t *);
int pthread_rwlock_init(pthread_rwlock_t *, const pthread_rwlockattr_t *);
int pthread_rwlock_rdlock(pthread_rwlock_t *);
int pthread_rwlock_tryrdlock(pthread_rwlock_t *);
int pthread_rwlock_timedrdlock(pthread_rwlock_t *, const struct timespec *abs_timeout);
int pthread_rwlock_wrlock(pthread_rwlock_t *);
int pthread_rwlock_trywrlock(pthread_rwlock_t *);
int pthread_rwlock_timedwrlock(pthread_rwlock_t *, const struct timespec *abs_timeout);
int pthread_rwlock_unlock(pthread_rwlock_t *);

/* Posix spin locks */
typedef struct _sync pthread_spinlock_t;
int (*_spin_lock_v)(struct _sync *sync);
int (*_spin_trylock_v)(struct _sync *sync);
int (*_spin_unlock_v)(struct _sync *sync);

/* pthread spin lock prototypes */
int pthread_spin_init(pthread_spinlock_t *lock, int pshared);
int pthread_spin_destroy(pthread_spinlock_t *lock);
int pthread_spin_lock(pthread_spinlock_t *lock);
#define pthread_spin_lock(lock)    ((_spin_lock_v)((struct _sync *)(lock)))
int pthread_spin_trylock(pthread_spinlock_t *lock);
#define pthread_spin_trylock(lock) ((_spin_trylock_v)((struct _sync *)(lock)))
int pthread_spin_unlock(pthread_spinlock_t *lock);
#define pthread_spin_unlock(lock)  ((_spin_unlock_v)((struct _sync *)(lock)))
#endif


#if defined(EXT_QNX)		/* QNX Extensions (1003.1j D5) */
int pthread_timedjoin(pthread_t thread, void **value_ptr, const struct timespec *abstime);
/* Unconditional thread termination */
#define PTHREAD_ABORTED ((void *)(-2))
int pthread_abort(pthread_t thread);
#endif

#if defined(EXT_QNX)
/* QNX Extensions */
#define PTHREAD_BARRIER_INITIALIZER(b)	{ \
	(b), \
	(b), \
	PTHREAD_MUTEX_INITIALIZER, \
	PTHREAD_COND_INITIALIZER \
	}

/* In UNIX98, but removed for alignment with approved 1003.1j */
#define PTHREAD_RWLOCK_INITIALIZER	{ 0, 0, 0, 0, 0, PTHREAD_MUTEX_INITIALIZER, \
	PTHREAD_COND_INITIALIZER, PTHREAD_COND_INITIALIZER, -2 }

/* sleepon */
typedef struct _sleepon_handle sleepon_t;
sleepon_t	_sleepon_default;
int _sleepon_init(sleepon_t **list, unsigned flags);
int _sleepon_destroy(sleepon_t *handle);
int _sleepon_lock(sleepon_t *handle);
int _sleepon_unlock(sleepon_t *handle);
int _sleepon_wait(sleepon_t *handle, const volatile void *addr, _Uint64t nsec);
int _sleepon_signal(sleepon_t *handle, const volatile void *addr);
int _sleepon_broadcast(sleepon_t *handle, const volatile void *addr);

int pthread_sleepon_lock(void);
int pthread_sleepon_unlock(void);
int pthread_sleepon_wait(const volatile void *addr);
int pthread_sleepon_timedwait(const volatile void *addr, _Uint64t nsec);
int pthread_sleepon_signal(const volatile void *addr);
int pthread_sleepon_broadcast(const volatile void *addr);

#endif
