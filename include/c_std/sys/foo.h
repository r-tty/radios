#if defined(__MODE_T)
typedef __MODE_T	mode_t;
#undef __MODE_T
#endif

#if defined(__DEV_T)
typedef __DEV_T		dev_t;
#undef __DEV_T
#endif

#if defined(__TIME_T)
typedef __TIME_T	time_t;
#undef __TIME_T
#endif

#if defined(__NLINK_T)
typedef __NLINK_T	nlink_t;
#undef __NLINK_T
#endif

#if defined(__OFF_T)
typedef __OFF_T		off_t;
#undef __OFF_T
#endif

#if defined(__OFF64_T)
typedef __OFF64_T	off64_t;
#undef __OFF64_T
#endif

#if defined(__INO_T)
typedef __INO_T		ino_t;
#undef __INO_T
#endif

#if defined(__INO64_T)
typedef __INO64_T	ino64_t;
#undef __INO64_T
#endif

#if defined(__UID_T)
typedef __UID_T		uid_t;
#undef __UID_T
#endif

#if defined(__GID_T)
typedef __GID_T		gid_t;
#undef __GID_T
#endif

#if defined(__BLKSIZE_T)
typedef __BLKSIZE_T			blksize_t;
#undef __BLKSIZE_T
#endif

#if defined(__BLKCNT64_T)
typedef __BLKCNT64_T		blkcnt64_t;
#undef __BLKCNT64_T
#endif

#if defined(__FSBLKCNT64_T)
typedef __FSBLKCNT64_T		fsblkcnt64_t;
#undef __FSBLKCNT64_T
#endif

#if defined(__FSFILCNT64_T)
typedef __FSFILCNT64_T		fsfilcnt64_t;
#undef __FSFILCNT64_T
#endif

#if defined(__BLKCNT_T)
typedef __BLKCNT_T			blkcnt_t;
#undef __BLKCNT_T
#endif

#if defined(__FSBLKCNT_T)
typedef __FSBLKCNT_T		fsblkcnt_t;
#undef __FSBLKCNT_T
#endif

#if defined(__FSFILCNT_T)
typedef __FSFILCNT_T		fsfilcnt_t;
#undef __FSFILCNT_T
#endif

#if defined(__EXT_QNX)
#if defined(__PID_T)
typedef __PID_T		pid_t;
#undef __PID_T
