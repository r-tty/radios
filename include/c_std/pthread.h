/*
 * pthread.h - definitions for POSIX Threads.
 */

#ifndef _pthread_h
#define _pthread_h

#include <time.h>
#include <sched.h>
#include <sys/storage.h>

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
} sync_attr_t

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

/* This is needed for cond_get/setclock */
typedef int clockid_t;

typedef int pthread_key_t;

#define PTHREAD_PRIO_INHERIT	0
#define PTHREAD_PRIO_NONE	1
#define PTHREAD_PRIO_PROTECT	2

/* thread attribute prototypes */
int pthread_attr_destroy(pthread_attr_t *__attr);
int pthread_attr_getdetachstate(const pthread_attr_t *__attr, int *__detachstate);
int pthread_attr_getstackaddr(const pthread_attr_t *__addr, void **__stackaddr);
int pthread_attr_getstacksize(const pthread_attr_t *__attr, size_t *__stacksize);
int pthread_attr_init(pthread_attr_t *__attr);
int pthread_attr_setdetachstate(pthread_attr_t *__attr, int __detachstate);
int pthread_attr_setstackaddr(pthread_attr_t *__attr, void *__stackaddr);
int pthread_attr_setstacksize(pthread_attr_t *__attr, size_t __stacksize);

int pthread_attr_getguardsize(const pthread_attr_t *__attr, size_t *__guardsize);
int pthread_attr_setguardsize(pthread_attr_t *__attr, size_t __guardsize);
int pthread_getconcurrency(void);
int pthread_setconcurrency(int __new_level);

#if defined(__EXT_QNX)
int pthread_attr_getstacklazy(const pthread_attr_t *__attr, int *__lazystack);
int pthread_attr_setstacklazy(pthread_attr_t *__attr, int __lazystack);
#if defined(__SLIB_DATA_INDIRECT) && !defined(pthread_attr_default) && !defined(__SLIB)
  pthread_attr_t *const __get_pthread_attr_default_ptr(void);
  #define pthread_attr_default (const pthread_attr_t)(*(__get_pthread_attr_default_ptr()))
#else
  const pthread_attr_t pthread_attr_default;
#endif
#endif

/* Scheduling related functions */
int pthread_attr_getinheritsched(const pthread_attr_t *__attr, int *__inheritsched);
int pthread_attr_getschedparam(const pthread_attr_t *__attr, struct sched_param *__param);
int pthread_attr_getschedpolicy(const pthread_attr_t *__attr, int *__policy);
int pthread_attr_getscope(const pthread_attr_t *__attr, int *__contentionscope);
int pthread_attr_setinheritsched(pthread_attr_t *__attr, int __inheritsched);
int pthread_attr_setschedparam(pthread_attr_t *__attr, const struct sched_param *__param);
int pthread_attr_setschedpolicy(pthread_attr_t *__attr, int __policy);
int pthread_attr_setscope(pthread_attr_t *__attr, int __contentionscope);

/* Thread creation prototypes */
int pthread_cancel(pthread_t __thread);
int pthread_create(pthread_t *__thread, const pthread_attr_t *__attr, void *(*__start_routine)(void *), void *__arg);
int pthread_detach(pthread_t __thread);
int pthread_equal(pthread_t __t1, pthread_t __t2);
void pthread_exit(void *__value_ptr);
int pthread_join(pthread_t __thread, void **__value_ptr);
pthread_t pthread_self(void);
int pthread_setcancelstate(int __state, int *__oldstate);
int pthread_setcanceltype(int __type, int *__oldtype);
#ifdef __INLINE_FUNCTIONS__
#define pthread_self()				(__tls()->tid)
#define pthread_equal(__t1, __t2)	((__t1) == (__t2))
#endif

/* dynamic thread scheduling parameters */
int pthread_getschedparam(const pthread_t __thread, int *__policy, struct sched_param *__param);
int pthread_setschedparam(pthread_t __thread, int __policy, const struct sched_param *__param);

void pthread_testcancel(void);
#ifdef __INLINE_FUNCTIONS__
#define pthread_testcancel() if((__tls()->flags & (PTHREAD_CSTATE_MASK|PTHREAD_CANCEL_PENDING)) == \
				(PTHREAD_CANCEL_ENABLE|PTHREAD_CANCEL_PENDING)) pthread_exit(PTHREAD_CANCELED);
#endif


/* thread cancelation handlers */

struct __cleanup_handler;
struct __cleanup_handler {
    struct __cleanup_handler *__next;
    void (*__routine)(void *__arg);
    void *__save;
};

#define pthread_cleanup_push(__func, __arg) \
	{ \
	struct __cleanup_handler __cleanup_handler; \
	__cleanup_handler.__routine = (__func); \
	__cleanup_handler.__save = (__arg); \
	__cleanup_handler.__next = (struct __cleanup_handler *)__tls()->cleanup; \
	__tls()->cleanup = (void *)&__cleanup_handler;

#define pthread_cleanup_pop(__ex) \
	__tls()->cleanup = (void *)__cleanup_handler.__next; \
	((__ex) ? __cleanup_handler.__routine(__cleanup_handler.__save) : (void)0);\
	}

/* pthread_key prototypes */
void *pthread_getspecific(pthread_key_t __key);
int pthread_key_create(pthread_key_t *__key, void (*__destructor)(void *));
int pthread_key_delete(pthread_key_t __key);
int pthread_setspecific(pthread_key_t __key, const void *__value);
#ifdef __INLINE_FUNCTIONS__
#define pthread_getspecific(key)	((key) < __tls()->numkeys ? __tls()->keydata[key] : 0)
#endif


/* pthread synchronization prototypes */
#define PTHREAD_MUTEX_INITIALIZER	{ _NTO_SYNC_NONRECURSIVE, _NTO_SYNC_INITIALIZER }
#if defined(__EXT_XOPEN_EX)
#define PTHREAD_MUTEX_DEFAULT		0	/* ((int)(_NTO_SYNC_NONRECURSIVE)) */
#define PTHREAD_MUTEX_ERRORCHECK	1	/* ((int)(_NTO_SYNC_NONRECURSIVE)) */
#define PTHREAD_MUTEX_RECURSIVE		2	/* (0) */
#define PTHREAD_MUTEX_NORMAL		3	/* ((int)(_NTO_SYNC_NONRECURSIVE|_NTO_SYNC_NOERRORCHECK)) */
#endif
#if defined(__EXT_QNX)
#define PTHREAD_RMUTEX_INITIALIZER	{ 0, _NTO_SYNC_INITIALIZER }
#endif

#define PTHREAD_COND_INITIALIZER	{ (int)_NTO_SYNC_COND, _NTO_SYNC_INITIALIZER }

#define PTHREAD_PROCESSSHARED_MASK		0x01
#define PTHREAD_PROCESS_PRIVATE				0x00
#define PTHREAD_PROCESS_SHARED				0x01

#define PTHREAD_RECURSIVE_MASK			0x02
#define PTHREAD_RECURSIVE_DISABLE			0x00
#define PTHREAD_RECURSIVE_ENABLE			0x02

#define PTHREAD_ERRORCHECK_MASK			0x04
#define PTHREAD_ERRORCHECK_ENABLE			0x00
#define PTHREAD_ERRORCHECK_DISABLE			0x04

#define _NTO_ATTR_FLAGS					0x0000ffff	/* These flags are verified for each type */

#define _NTO_ATTR_MASK					0x000f0000
#define _NTO_ATTR_UNKNOWN				0x00000000
#define _NTO_ATTR_MUTEX					0x00010000
#define _NTO_ATTR_COND					0x00020000
#define _NTO_ATTR_RWLOCK				0x00030000
#define _NTO_ATTR_BARRIER				0x00040000

#define PTHREAD_MUTEX_TYPE				0x40000000	/* non-default mutex type */
/*
 * Used to identify that more than the first three ints
 * of struct _sync_attr are valid. This is for compatibility with old apps
 */
#define _NTO_ATTR_EXTRA_FLAG			0x80000000

/*
 * These are inline mutex macros that do not perform error checking
 * and does not handle recursive. i.e. type PTHREAD_MUTEX_NORMAL
 * They can be used with mutexes initialized with PTHREAD_MUTEX_DEFAULT,
 * PTHREAD_MUTEX_ERRORCHECK, or PTHREAD_MUTEX_NORMAL. 
 */
#define _mutex_lock(__m)	(_smp_cmpxchg(&(__m)->owner, 0, __tls()->owner) ? SyncMutexLock_r(__m) : 0 /* EOK */)
#define _mutex_trylock(__m)	(_smp_cmpxchg(&(__m)->owner, 0, __tls()->owner) ? 16 /* EBUSY */ : 0 /* EOK */)
#define _mutex_unlock(__m)	((_smp_xchg(&(__m)->owner, 0) & _NTO_SYNC_WAITING) ? __cpu_membarrier(), SyncMutexUnlock_r((__m)) : 0 /* EOK */)


/* synchronization stuff */
int pthread_mutexattr_destroy(pthread_mutexattr_t *__attr);
int pthread_mutexattr_init(pthread_mutexattr_t *__attr);

/* We always allow process shared */
int pthread_mutexattr_getpshared(const pthread_mutexattr_t *__attr, int *__pshared);
int pthread_mutexattr_setpshared(pthread_mutexattr_t *__attr,int __pshared);

/* synchronization scheduling */
int pthread_mutexattr_getprioceiling(const pthread_mutexattr_t *__attr, int *__prioceiling);
int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *__attr, int *__protocol);
int pthread_mutexattr_setprioceiling(pthread_mutexattr_t *__attr, int __prioceiling);
int pthread_mutexattr_setprotocol(pthread_mutexattr_t *__attr, int __protocol);

/* mutex recursion */
int pthread_mutex_destroy(pthread_mutex_t *__mutex);
int pthread_mutex_init(pthread_mutex_t *__mutex, const pthread_mutexattr_t *__attr);
int pthread_mutex_lock(pthread_mutex_t *__mutex);
#if defined(__EXT_QNX)		/* Approved 1003.1d D14 */
int pthread_mutex_timedlock(pthread_mutex_t *__mutex, const struct timespec *__abs_timeout);
#endif
int pthread_mutex_trylock(pthread_mutex_t *__mutex);
int pthread_mutex_unlock(pthread_mutex_t *__mutex);
#if defined(__INLINE_FUNCTIONS__) && 0	/* Not needed yet... */
#define pthread_mutex_lock(__m)		(_smp_cmpxchg(&(__m)->owner, 0, __tls()->owner) ? (pthread_mutex_lock)(__m) : ((__m)->count++, 0/* EOK */))
#define pthread_mutex_trylock(__m)	(_smp_cmpxchg(&(__m)->owner, 0, __tls()->owner) ? 16 /* EBUSY */ : ((__m)->count++, 0 /* EOK */))
#define pthread_mutex_unlock(__m)	(((__m)->owner & ~_NTO_SYNC_WAITING) == __tls()->owner ? (--(__m)->count <= 0 && \
									(__cpu_membarrier(), (_smp_xchg(&(__m)->owner, 0) & _NTO_SYNC_WAITING)) ? SyncMutexUnlock_r(__m) : 0 /* EOK */) : 1 /* EPERM */)
#if defined(__EXT_QNX)		/* Approved 1003.1d D14 */
#define pthread_mutex_timedlock(__m, __t)	(_smp_cmpxchg(&(__m)->owner, 0, __tls()->owner) ? (pthread_mutex_timedlock)((__m), (__t)) : 0 /* EOK */)
#endif
#endif
#if defined(__EXT_QNX)
int pthread_mutexattr_getrecursive(const pthread_mutexattr_t *__attr, int *__recursive);
int pthread_mutexattr_setrecursive(pthread_mutexattr_t *__attr, int __recursive);
#endif
#if defined(__EXT_XOPEN_EX)
int pthread_mutexattr_gettype(const pthread_mutexattr_t *__attr, int *__type);
int pthread_mutexattr_settype(pthread_mutexattr_t *__attr, int __type);
#endif

/* dynamically change the priority ceiling of a mutex */
int pthread_condattr_destroy(pthread_condattr_t *__attr);
int pthread_condattr_init(pthread_condattr_t *__attr);
int pthread_mutex_getprioceiling(const pthread_mutex_t *__mutex, int *__prioceiling);
int pthread_mutex_setprioceiling(pthread_mutex_t *__mutex, int __prioceiling, int *__old_ceiling);

/* Next two functions are not supported currently */
int pthread_cond_broadcast(pthread_cond_t *__cond);
int pthread_cond_destroy(pthread_cond_t *__cond);
int pthread_cond_init(pthread_cond_t *__cond, pthread_condattr_t *__attr);
int pthread_cond_signal(pthread_cond_t *__cond);
int pthread_cond_wait(pthread_cond_t *__cond, pthread_mutex_t *__mutex);
int pthread_condattr_getpshared(const pthread_condattr_t *__attr, int *__pshared);
int pthread_condattr_setpshared(pthread_condattr_t *__attr, int __pshared);
#if defined(__EXT_QNX)		/* Approved 1003.1d D14 */
int pthread_cond_timedwait(pthread_cond_t *__cond, pthread_mutex_t *__mutex, const struct timespec *__abstime);
#endif

/* pthread_once prototypes */
typedef struct {
	int					once;
	pthread_mutex_t		mutex;
} pthread_once_t;

#define PTHREAD_ONCE_INIT		{ 0, PTHREAD_MUTEX_INITIALIZER }

int pthread_once(pthread_once_t *__once_control, void (*__init_routine)(void));
#ifdef __INLINE_FUNCTIONS__
int __pthread_once(pthread_once_t *__once_control, void (*__init_routine)(void));
#define pthread_once(_c, _f)	((_c)->once ? 0 : __pthread_once((_c),(_f)) )
#endif

#if defined(__EXT_QNX)		/* Approved 1003.1d D14 */
int pthread_getcpuclockid(pthread_t __id, clockid_t *__clock_id);
#endif

#if defined(__EXT_QNX)		/* Approved 1003.1j D10 */
int pthread_condattr_getclock(const pthread_condattr_t *__attr, clockid_t *__id);
int pthread_condattr_setclock(pthread_condattr_t *__attr, int __id);

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
int pthread_barrierattr_init(pthread_barrierattr_t *__attr);
int pthread_barrierattr_destroy(pthread_barrierattr_t *__attr);
int pthread_barrierattr_getpshared(const pthread_barrierattr_t *__attr, int *__pshared);
int pthread_barrierattr_setpshared(pthread_barrierattr_t *__attr, int __pshared);

/* barrier prototypes */
int pthread_barrier_destroy(pthread_barrier_t *__b);
int pthread_barrier_init(pthread_barrier_t *__b, const pthread_barrierattr_t *__attr, unsigned int __count);
int pthread_barrier_wait(pthread_barrier_t *__b);

typedef struct _sync_attr pthread_rwlockattr_t;

int pthread_rwlockattr_init(pthread_rwlockattr_t *__attr);
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *__attr);

int pthread_rwlockattr_getpshared(const pthread_rwlockattr_t *__attr, int *__pshared);
int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *__attr, int __pshared);

typedef struct {
	int				active;			/* -1 = writer else # of active readers */
	void			*spare;
	int				blockedwriters;	/* # of waiting readers */
	int				blockedreaders;	/* # of waiting writers */
	int				heavy;			/* the rwlock is under heavy contention */
	pthread_mutex_t	lock;			/* the controlling mutex */
	pthread_cond_t	rcond;			/* condition variable for readers */
	pthread_cond_t	wcond;			/* condition variable for writers */
	unsigned		owner;			/* used to prevent and detect deadlocks */
} pthread_rwlock_t;

int pthread_rwlock_destroy(pthread_rwlock_t *);
int pthread_rwlock_init(pthread_rwlock_t *, const pthread_rwlockattr_t *);
int pthread_rwlock_rdlock(pthread_rwlock_t *);
int pthread_rwlock_tryrdlock(pthread_rwlock_t *);
int pthread_rwlock_timedrdlock(pthread_rwlock_t *, const struct timespec *__abs_timeout);
int pthread_rwlock_wrlock(pthread_rwlock_t *);
int pthread_rwlock_trywrlock(pthread_rwlock_t *);
int pthread_rwlock_timedwrlock(pthread_rwlock_t *, const struct timespec *__abs_timeout);
int pthread_rwlock_unlock(pthread_rwlock_t *);

/* Posix spin locks */
typedef struct _sync pthread_spinlock_t;
int (*_spin_lock_v)(struct _sync *__sync);
int (*_spin_trylock_v)(struct _sync *__sync);
int (*_spin_unlock_v)(struct _sync *__sync);

/* pthread spin lock prototypes */
int pthread_spin_init(pthread_spinlock_t *__lock, int __pshared);
int pthread_spin_destroy(pthread_spinlock_t *__lock);
int pthread_spin_lock(pthread_spinlock_t *__lock);
#define pthread_spin_lock(__lock)    ((_spin_lock_v)((struct _sync *)(__lock)))
int pthread_spin_trylock(pthread_spinlock_t *__lock);
#define pthread_spin_trylock(__lock) ((_spin_trylock_v)((struct _sync *)(__lock)))
int pthread_spin_unlock(pthread_spinlock_t *__lock);
#define pthread_spin_unlock(__lock)  ((_spin_unlock_v)((struct _sync *)(__lock)))
#endif


#if defined(__EXT_QNX)		/* QNX Extensions (1003.1j D5) */
int pthread_timedjoin(pthread_t __thread, void **__value_ptr, const struct timespec *__abstime);
/* Unconditional thread termination */
#define PTHREAD_ABORTED ((void *)(-2))
int pthread_abort(pthread_t __thread);
#endif

#if defined(__EXT_QNX)
/* QNX Extensions */
#define PTHREAD_BARRIER_INITIALIZER(__b)	{ \
	(__b), \
	(__b), \
	PTHREAD_MUTEX_INITIALIZER, \
	PTHREAD_COND_INITIALIZER \
	}

/* In UNIX98, but removed for alignment with approved 1003.1j */
#define PTHREAD_RWLOCK_INITIALIZER	{ 0, 0, 0, 0, 0, PTHREAD_MUTEX_INITIALIZER, \
	PTHREAD_COND_INITIALIZER, PTHREAD_COND_INITIALIZER, -2 }

/* sleepon */
typedef struct _sleepon_handle sleepon_t;
sleepon_t	_sleepon_default;
int _sleepon_init(sleepon_t **__list, unsigned __flags);
int _sleepon_destroy(sleepon_t *__handle);
int _sleepon_lock(sleepon_t *__handle);
int _sleepon_unlock(sleepon_t *__handle);
int _sleepon_wait(sleepon_t *__handle, const volatile void *__addr, _Uint64t __nsec);
int _sleepon_signal(sleepon_t *__handle, const volatile void *__addr);
int _sleepon_broadcast(sleepon_t *__handle, const volatile void *__addr);

int pthread_sleepon_lock(void);
int pthread_sleepon_unlock(void);
int pthread_sleepon_wait(const volatile void *__addr);
int pthread_sleepon_timedwait(const volatile void *__addr, _Uint64t __nsec);
int pthread_sleepon_signal(const volatile void *__addr);
int pthread_sleepon_broadcast(const volatile void *__addr);
#ifdef __INLINE_FUNCTIONS__
#define pthread_sleepon_lock()					_sleepon_lock(&_sleepon_default)
#define pthread_sleepon_unlock()				_sleepon_unlock(&_sleepon_default)
#define pthread_sleepon_wait(__addr)			_sleepon_wait(&_sleepon_default, (__addr), 0)
#define pthread_sleepon_timedwait(__addr, __nsec)_sleepon_wait(&_sleepon_default, (__addr), (__nsec))
#define pthread_sleepon_signal(__addr)			_sleepon_signal(&_sleepon_default, (__addr))
#define pthread_sleepon_brodcast(__addr)		_sleepon_brodcast(&_sleepon_default, (__addr))
#endif

#endif

#endif
