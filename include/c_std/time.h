/*
 * time.h - time functions.
 */

#ifndef _time_h
#define _time_h

#include <stddef.h>

/*
 * Unix98 says that the value of CLOCKS_PER_SEC is required to be 1 million
 * on all XSI-conformant systems, and it may be variable on other systems
 * and it should not be assumed that CLOCKS_PER_SEC is a compile-time constant.
 */
#define CLOCKS_PER_SEC  1000000

#define CLK_TCK     _sysconf(3)		/* 3 == _SC_CLK_TCK */

struct itimerspec {
    struct timespec it_value,
                    it_interval;
    } ;

/*  Clock types */
#define CLOCK_REALTIME      0
#if defined(EXT_QNX)
#define CLOCK_SOFTTIME      1
#define CLOCK_MONOTONIC	2
#endif
#if defined(EXT_QNX)		/* Approved 1003.1d D14 */
#define CLOCK_PROCESS_CPUTIME_ID	3
#define CLOCK_THREAD_CPUTIME_ID		4
#endif


/* Timer settime flags */
#define TIMER_ABSTIME       0x80000000

BEGIN_DECLS

#if defined(EXT_POSIX1_199309)

struct sigevent; /* for C++ */

extern int clock_getres(clockid_t clock_id, struct timespec *res );
extern int clock_gettime(clockid_t clock_id, struct timespec *tp );
extern int clock_setres(clockid_t clock_id, struct timespec *res );
extern int clock_settime(clockid_t clock_id, const struct timespec *tp );
#if defined(EXT_QNX)		/* Approved 1003.1d D14 */
#if defined(PID_T)
typedef PID_T	pid_t;
#undef PID_T
#endif
extern int clock_getcpuclockid(pid_t pid, clockid_t *clock_id);
#endif
extern int nanosleep( const struct timespec *rqtp, struct timespec *rmtp );
extern int timer_create ( clockid_t clock_id, struct sigevent *evp, timer_t *timerid );
extern int timer_delete ( timer_t timerid );
extern int timer_getoverrun( timer_t timerid);
extern int timer_gettime ( timer_t timerid, struct itimerspec *value );
extern int timer_settime ( timer_t timerid, int flags, struct itimerspec *value, struct itimerspec *ovalue );
#endif

#if defined(EXT_QNX)	/* QNX Extensions (1003.1j D5) */
extern int nanosleep_abs(clockid_t clock_id, const struct timespec *rqtp);
extern int nanosleep_rel(clockid_t clock_id, const struct timespec *rqtp, struct timespec *rmtp );
#endif
#if defined(EXT_QNX)	/* Approved 1003.1j D10 */
extern int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec *rqtp, struct timespec *rmtp );
extern int timer_getexpstatus(timer_t timerid);
#endif

#if defined(EXT_QNX)
extern int nanospin_calibrate(int disable);
extern int nanospin(const struct timespec *rqtp);
extern void nanospin_count(unsigned long count);
extern int nanospin_ns(unsigned long nsec);
extern unsigned long nanospin_ns_to_count(unsigned long nsec);
extern int timer_timeout(clockid_t id, int flags, const struct sigevent *notify,
		const struct timespec *ntime, struct timespec *otime);
extern int timer_timeout_r(clockid_t id, int flags, const struct sigevent *notify,
		const struct timespec *ntime, struct timespec *otime);
extern void nsec2timespec(struct timespec *timespec, _Uint64t nsec);
extern _Uint64t timespec2nsec(const struct timespec *ts);
#define timespec2nsec(ts) ((ts)->tv_sec*(_Uint64t)1000000000+(ts)->tv_nsec)
#endif

_C_STD_BEGIN
struct  tm {
        int  tm_sec;    /* seconds after the minute -- [0,61] */
        int  tm_min;    /* minutes after the hour   -- [0,59] */
        int  tm_hour;   /* hours after midnight     -- [0,23] */
        int  tm_mday;   /* day of the month         -- [1,31] */
        int  tm_mon;    /* months since January     -- [0,11] */
        int  tm_year;   /* years since 1900                   */
        int  tm_wday;   /* days since Sunday        -- [0,6]  */
        int  tm_yday;   /* days since January 1     -- [0,365]*/
        int  tm_isdst;  /* Daylight Savings Time flag */
		long int tm_gmtoff;	/* Offset from gmt */
		const char *tm_zone;	/* String for zone name */
};

extern char *asctime( const struct tm *timeptr );
extern char *ctime( const time_t *timer );
extern clock_t clock( void );
extern double difftime( time_t t1, time_t t0 );
extern struct tm *gmtime( const time_t *timer );
extern struct tm *localtime( const time_t *timer );
extern time_t mktime( struct tm *timeptr );
extern size_t strftime( char *s, size_t maxsiz, const char *fmt, const struct tm *tp );
extern time_t time( time_t *timer );
_C_STD_END

#define	leap_year(year) ((year% 4) == 0 && ((year% 100) != 0 || (year%400) == 100))

#if defined(_POSIX_SOURCE) || defined(_QNX_SOURCE) || !defined(NO_EXT_KEYS)

extern char *asctime_r( const struct  tm *timeptr, char *buff );
extern char *ctime_r( const  time_t *timer, char *buff );
extern struct  tm *gmtime_r( const  time_t *timer, struct  tm *tm );
extern struct  tm *localtime_r( const  time_t *timer, struct  tm *tm );
extern void tzset( void );

#if defined(SLIB_DATA_INDIRECT) && !defined(tzname) && !defined(SLIB)
  char **get_tzname_ptr(void);
  #define tzname (get_tzname_ptr())
#else
  extern char    *tzname[];	/*  time zone names */
#endif
#if defined(SLIB_DATA_INDIRECT) && !defined(daylight) && !defined(SLIB)
  int *get_daylight_ptr(void);
  #define daylight *(get_daylight_ptr())
#else
  extern int     daylight;    /* d.s.t. indicator */
#endif
#if defined(SLIB_DATA_INDIRECT) && !defined(timezone) && !defined(SLIB)
  long int *get_timezone_ptr(void);
  #define timezone *(get_timezone_ptr())
#else
  extern long  int  timezone;    /* # of seconds from GMT */
#endif

#endif

#if defined(EXT_XOPEN_EX)
extern struct  tm *getdate(const char *string);
extern char *strptime(const char *buf, const char *format, struct tm *tm);
#endif

#endif
